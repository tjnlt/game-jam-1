extends Node3D

const RUN_SPEED := 6.0
const FAST_RUN_SPEED := 12.0
const BACKWARD_SPEED := 1.0
const RETREAT_RADIUS := 2.0
const RETREAT_DURATION := 1.4
const FOOTSTEP_DISTANCE := 2.0 # distance travelled between footstep sounds
const FAST_FOOTSTEP_DISTANCE := 3.5 # wider stride while sprinting so footsteps don't double in rate
const SEPARATION_RADIUS := 1.0 # creatures closer than this get pushed apart
const SEPARATION_SPEED := 4.0
const PICKUP_RADIUS := 1.5 # how close a creature must get to grab a rod
const DELIVER_RADIUS := 1.5 # how close to its spawn before the rod counts as stolen
const IDLE_RADIUS := 3.0 # how close to the reactor counts as "waiting there"
const ROD_CARRY_OFFSET := Vector3(0, 0.5, 0.6) # where a carried rod sits on the creature
const CARRY_SPEED_MULTIPLIER := 0.25 # creatures move slower while lugging a stolen rod
const RAVE_SPREAD_RADIUS := 12.0 # how far idling creatures scatter around the reactor
const DESPAWN_MIN_DELAY := 30.0 # once idling with nothing to steal, wait this long before maybe despawning
const DESPAWN_MAX_DELAY := 60.0
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var damage_sounds: Array[AudioStreamPlayer3D] = [
	$DamageSound1, $DamageSound2, $DamageSound3, $DamageSound4
]
@onready var footstep_sounds: Array[AudioStreamPlayer3D] = [
	$FootStepSound1, $FootStepSound2, $FootStepSound3, $FootStepSound4
]

@export var dance_only: bool = false

var player: Node3D
var _retreating := false
var _retreat_timer := 0.0
var _fast_mode := false
var _distance_since_footstep := 0.0
var health := 2
var move_dir
var carried_rod: Node3D = null
var _idling := false
var _warned_no_reactor := false
var spawn_position: Vector3
var _rave_spot: Vector3
var _rave_spot_set := false
var _despawn_timer := 0.0

var timer = 0.25

func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	spawn_position = global_position

	if dance_only:
		animation_player.stop()
	else: 
		animation_player.play("local/run")
		
	await get_tree().physics_frame

func _unhandled_key_input(event: InputEvent) -> void:
	# Debug-only toggle for testing the fast_run animation/speed.
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		_fast_mode = not _fast_mode
		if not _retreating:
			animation_player.play(_movement_animation())

func _physics_process(delta: float) -> void:
	if dance_only:
		return

	if not player:
		return

	var to_player := player.global_position - global_position
	to_player.y = 0
	var to_player_dir := to_player.normalized()

	# Once retreating starts, commit to it for RETREAT_DURATION instead of
	# re-checking distance every frame - otherwise hovering right at
	# RETREAT_RADIUS flips between chase/retreat each frame and the
	# creature spazzes in place.
	if _retreating:
		_retreat_timer -= delta
		global_position -= to_player_dir * BACKWARD_SPEED * delta
		_apply_separation(delta)
		look_at(global_position - to_player_dir, Vector3.UP)
		_advance_footsteps(BACKWARD_SPEED * delta)

		if _retreat_timer <= 0.0:
			_retreating = false
			animation_player.play(_movement_animation())
		return

	var distance := to_player.length()

	if distance <= RETREAT_RADIUS:
		_retreating = true
		_retreat_timer = RETREAT_DURATION
		animation_player.play("local/walk_backward")
		global_position -= to_player_dir * BACKWARD_SPEED * delta
		_apply_separation(delta)
		look_at(global_position - to_player_dir, Vector3.UP)
		_advance_footsteps(BACKWARD_SPEED * delta)
		return

	if carried_rod == null:
		_try_pickup()
	else:
		_try_deliver()

	var speed := FAST_RUN_SPEED if _fast_mode else RUN_SPEED
	if carried_rod:
		speed *= CARRY_SPEED_MULTIPLIER
	#nav_agent.target_position = player.global_position
	timer += delta
	if timer >= 0.25:
		_update_idle_state()
		nav_agent.target_position = _get_target()
		timer = 0.0
		move_dir = global_position.direction_to(nav_agent.get_next_path_position())
		
		_apply_separation(delta)
		var look_dir = move_dir
		look_dir.y = 0.0
		if look_dir != Vector3.ZERO:
			look_at(global_position - look_dir.normalized(), Vector3.UP)
	
	if _idling:
		_despawn_timer -= delta
		if _despawn_timer <= 0.0:
			queue_free()
		return

	# An almost purely vertical move_dir means we are standing on the target.
	# Following it just bounces the creature up and down in place.
	if Vector2(move_dir.x, move_dir.z).length() < 0.1:
		return

	global_position += move_dir * speed * delta
	_advance_footsteps(speed * delta, FAST_FOOTSTEP_DISTANCE if _fast_mode else FOOTSTEP_DISTANCE)

# Pushes this creature away from other nearby creatures so they don't stack
# on top of each other. O(n) per creature per frame - fine for this game's
# enemy counts, but would need spatial partitioning at much larger scale.
func _apply_separation(delta: float) -> void:
	var push := Vector3.ZERO

	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue

		var offset := global_position - (other as Node3D).global_position
		offset.y = 0.0
		var dist := offset.length()

		if dist > 0.0001 and dist < SEPARATION_RADIUS:
			push += offset.normalized() * (SEPARATION_RADIUS - dist)

	if push != Vector3.ZERO:
		global_position += push * SEPARATION_SPEED * delta

func _advance_footsteps(moved_distance: float, footstep_distance: float = FOOTSTEP_DISTANCE) -> void:
	_distance_since_footstep += moved_distance
	if _distance_since_footstep < footstep_distance:
		return
	_distance_since_footstep -= footstep_distance
	var footstep: AudioStreamPlayer3D = footstep_sounds.pick_random()
	footstep.play()

func set_dancing(active: bool) -> void:
	if not dance_only:
		return

	if active:
		animation_player.play("local/dance")
	else:
		animation_player.stop()


func take_damage(amount: int) -> void:
	if dance_only:
		return

	health -= amount

	var sound: AudioStreamPlayer3D = damage_sounds.pick_random()

	if health <= 0:
		var environment := get_tree().get_first_node_in_group("environment")
		if environment and environment.has_method("register_goblin_kill"):
			environment.register_goblin_kill()

		if carried_rod:
			if environment and environment.has_method("recover_rod"):
				environment.recover_rod()
			if carried_rod.has_method("return_home"):
				carried_rod.return_home()
			carried_rod = null

		# Let the killing hit's sound finish playing instead of getting cut
		# off when this creature (and its child AudioStreamPlayer3D) is freed.
		sound.reparent(get_tree().current_scene, true)
		sound.finished.connect(sound.queue_free)
		sound.play()

		queue_free()
	else:
		sound.play()

# --- ROD LOGIC ---

# Nearest unclaimed rod, or null when every rod is taken or gone.
func _get_nearest_rod() -> Node3D:
	var closest: Node3D = null
	var closest_dist := INF
	for rod in get_tree().get_nodes_in_group("rods"):
		var d := global_position.distance_squared_to((rod as Node3D).global_position)
		if d < closest_dist:
			closest_dist = d
			closest = rod
	return closest


func _get_reactor() -> Node3D:
	return get_tree().get_first_node_in_group("reactor") as Node3D


# Carrying -> home. Otherwise the nearest rod, or the reactor to wait at
# when there are none. Never returns our own position: targeting yourself
# produces a vertical move_dir that bounces the creature in place.
func _get_target() -> Vector3:
	if carried_rod:
		return spawn_position

	var rod := _get_nearest_rod()
	if rod:
		_rave_spot_set = false
		return rod.global_position

	var reactor := _get_reactor()
	if reactor:
		return _get_rave_spot(reactor)

	return global_position


# Picks (once) a random spot scattered around the reactor so creatures with
# nothing left to steal fan out and dance like a rave instead of stacking on
# the reactor's exact center. Cleared whenever a rod becomes available again.
func _get_rave_spot(reactor: Node3D) -> Vector3:
	if not _rave_spot_set:
		var angle := randf_range(0.0, TAU)
		var radius := randf_range(RAVE_SPREAD_RADIUS * 0.5, RAVE_SPREAD_RADIUS)
		_rave_spot = reactor.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
		_rave_spot_set = true
	return _rave_spot


func _at_reactor() -> bool:
	var reactor := _get_reactor()
	if reactor == null:
		if not _warned_no_reactor:
			_warned_no_reactor = true
			push_warning("creature: no node is in the \"reactor\" group - idling in place instead of regrouping there.")
		# Nothing to walk to, so idle where we stand
		# rather than jittering.
		return true
	# The reactor origin usually sits inside its own housing where there is no
	# navmesh, so "arrived" means the agent got as far as the path allows -
	# not that we are literally within IDLE_RADIUS of the centre.
	if nav_agent.is_navigation_finished():
		return true

	return global_position.distance_to(reactor.global_position) <= IDLE_RADIUS


# Idle means: empty-handed, no rod to go for, and already loitering at the
# reactor. Only touches the animation on a state change so we don't restart
# the dance every frame.
func _update_idle_state() -> void:
	var should_idle := carried_rod == null and _get_nearest_rod() == null and _at_reactor()
	if should_idle == _idling:
		return
	_idling = should_idle
	animation_player.play(_movement_animation())

	if _idling:
		_despawn_timer = randf_range(DESPAWN_MIN_DELAY, DESPAWN_MAX_DELAY)


func _movement_animation() -> String:
	if _idling:
		return "local/dance"
	if carried_rod:
		return "local/carry"
	return "local/fast_run" if _fast_mode else "local/run"


func _try_pickup() -> void:
	var rod := _get_nearest_rod()
	if rod == null:
		return
	if global_position.distance_to(rod.global_position) > PICKUP_RADIUS:
		return
	_grab_rod(rod)


func _grab_rod(rod: Node3D) -> void:
	carried_rod = rod

	var environment := get_tree().get_first_node_in_group("environment")
	if environment and environment.has_method("steal_rod"):
		environment.steal_rod()

	# Drop it out of the group immediately so other creatures stop pathing
	# to a rod that is already spoken for.
	rod.remove_from_group("rods")
	if "carrier" in rod:
		rod.carrier = self

	# false = keep the local transform rather than the world one, so the
	# offset below positions it relative to the creature.
	rod.reparent(self, false)
	rod.position = ROD_CARRY_OFFSET

	_idling = false
	animation_player.play(_movement_animation())
	nav_agent.target_position = spawn_position


func _try_deliver() -> void:
	if global_position.distance_to(spawn_position) > DELIVER_RADIUS:
		return

	var environment := get_tree().get_first_node_in_group("environment")
	if environment and environment.has_method("lose_rod"):
		environment.lose_rod()

	carried_rod.queue_free()
	carried_rod = null
	queue_free()


# Called by Door.gd (via the "enemies" group) when a navigation link is
# toggled. Disabling a link does not invalidate paths agents have already
# computed, so nudge the target to force a fresh query next frame.
func refresh_navigation() -> void:
	nav_agent.target_position = global_position
