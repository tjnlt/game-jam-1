extends Node3D
##
## MULTIPLAYER
## Creatures are host-authoritative: only the host runs the AI in
## _physics_process, and a MultiplayerSynchronizer pushes the resulting
## transform to the clients. Anything a client can see or hear for itself
## (footsteps, animations) is derived locally so it costs no bandwidth;
## anything that changes shared state (rods, kills, deaths) is an RPC from
## the host.
##

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
## Kept alongside carried_rod so the rod can still be named in an RPC after it
## has been reparented onto this creature.
var carried_rod_id: String = ""
var _idling := false
var _warned_no_reactor := false
var spawn_position: Vector3
var _rave_spot: Vector3
var _rave_spot_set := false
var _despawn_timer := 0.0
var _last_position: Vector3

var timer = 0.25

func _ready() -> void:
	add_to_group("enemies")
	spawn_position = global_position
	_last_position = global_position

	if dance_only:
		animation_player.stop()
	else:
		animation_player.play("local/run")

	_setup_synchronizer()

	await get_tree().physics_frame


## Pushes this creature's transform to the clients. The radio dancer is skipped:
## it is a fixed scene node that never moves, so there is nothing to replicate.
func _setup_synchronizer() -> void:
	if dance_only or not Net.is_online():
		return

	var config := SceneReplicationConfig.new()
	for path in [".:position", ".:rotation"]:
		var property := NodePath(path)
		config.add_property(property)
		config.property_set_replication_mode(
			property, SceneReplicationConfig.REPLICATION_MODE_ALWAYS
		)

	var sync := MultiplayerSynchronizer.new()
	sync.name = "NetSync"
	sync.replication_config = config
	sync.replication_interval = 1.0 / 20.0
	add_child(sync)


func _unhandled_key_input(event: InputEvent) -> void:
	# Debug-only toggle for testing the fast_run animation/speed. Host only -
	# a client pressing L must not change how the creature moves for everyone.
	if not Net.is_authority():
		return
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		_fast_mode = not _fast_mode
		if not _retreating:
			_play_animation(_movement_animation())


## Footsteps are driven by distance actually travelled rather than by the AI, so
## clients - which only receive the transform - still hear creatures moving.
func _process(_delta: float) -> void:
	if dance_only:
		return

	var moved := global_position.distance_to(_last_position)
	_last_position = global_position

	if _idling:
		return

	_advance_footsteps(moved, FAST_FOOTSTEP_DISTANCE if _fast_mode else FOOTSTEP_DISTANCE)


func _physics_process(delta: float) -> void:
	if dance_only:
		return

	# Clients receive this creature's position from the host and must not run
	# their own copy of the AI, or the two would fight over the transform.
	if not Net.is_authority():
		return

	# Re-picked every frame: the creature chases whoever is closest right now,
	# not whichever player happened to exist when it spawned.
	player = _get_nearest_player()

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

		if _retreat_timer <= 0.0:
			_retreating = false
			_play_animation(_movement_animation())
		return

	var distance := to_player.length()

	if distance <= RETREAT_RADIUS:
		_retreating = true
		_retreat_timer = RETREAT_DURATION
		_play_animation("local/walk_backward")
		global_position -= to_player_dir * BACKWARD_SPEED * delta
		_apply_separation(delta)
		look_at(global_position - to_player_dir, Vector3.UP)
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

	# Only the host resolves hits, so one trigger pull cannot be counted by
	# four peers at once. Bullets on clients are visual only.
	if not Net.is_authority():
		return

	health -= amount

	var sound_index := randi() % damage_sounds.size()
	var died := health <= 0

	_broadcast(&"_react_to_damage", [sound_index, died])

	if died:
		var environment := get_tree().get_first_node_in_group("environment")
		if environment and environment.has_method("register_goblin_kill"):
			environment.register_goblin_kill()

		if carried_rod:
			if environment and environment.has_method("recover_rod"):
				environment.recover_rod()
			_broadcast(&"_detach_rod", [carried_rod_id, true])

		# The MultiplayerSpawner that spawned this creature replicates the
		# despawn, so freeing it here removes it on every peer.
		queue_free()


## Plays the hit sound on every peer, and on a killing blow moves it out of the
## creature first so it is not cut off when the creature is freed.
@rpc("authority", "call_local", "reliable")
func _react_to_damage(sound_index: int, died: bool) -> void:
	if sound_index < 0 or sound_index >= damage_sounds.size():
		return

	var sound: AudioStreamPlayer3D = damage_sounds[sound_index]

	if died:
		sound.reparent(get_tree().current_scene, true)
		sound.finished.connect(sound.queue_free)

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


## Nearest player body. With four of them the creature has to re-evaluate as
## they move, instead of committing to one for its whole life.
func _get_nearest_player() -> Node3D:
	var closest: Node3D = null
	var closest_dist := INF
	for candidate in get_tree().get_nodes_in_group("player"):
		var body := candidate as Node3D
		if body == null or not is_instance_valid(body):
			continue
		var d := global_position.distance_squared_to(body.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = body
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
	_play_animation(_movement_animation())

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

	var environment := get_tree().get_first_node_in_group("environment")
	if environment and environment.has_method("steal_rod"):
		environment.steal_rod()

	_broadcast(&"_attach_rod", [String(rod.get("rod_id"))])


func _try_deliver() -> void:
	if global_position.distance_to(spawn_position) > DELIVER_RADIUS:
		return

	var environment := get_tree().get_first_node_in_group("environment")
	if environment and environment.has_method("lose_rod"):
		environment.lose_rod()

	_broadcast(&"_detach_rod", [carried_rod_id, false])
	queue_free()


## Moves a rod onto this creature on every peer. Rods are ordinary scene nodes
## rather than spawned ones, so each peer has to be told to reparent its own.
@rpc("authority", "call_local", "reliable")
func _attach_rod(rod_id: String) -> void:
	var rod := _find_rod(rod_id)
	if rod == null:
		return

	carried_rod = rod
	carried_rod_id = rod_id

	# Drop it out of the group immediately so other creatures stop pathing
	# to a rod that is already spoken for.
	rod.remove_from_group("rods")
	rod.set("carrier", self)

	# false = keep the local transform rather than the world one, so the
	# offset below positions it relative to the creature.
	rod.reparent(self, false)
	rod.position = ROD_CARRY_OFFSET

	_idling = false
	animation_player.play(_movement_animation())

	if Net.is_authority():
		nav_agent.target_position = spawn_position


## send_home = the creature was killed and the rod goes back to its holder.
## Otherwise the creature escaped with it and the rod is gone for good.
@rpc("authority", "call_local", "reliable")
func _detach_rod(rod_id: String, send_home: bool) -> void:
	var rod := _find_rod(rod_id)
	carried_rod = null
	carried_rod_id = ""

	if rod == null:
		return

	if send_home and rod.has_method("return_home"):
		rod.return_home()
	elif not send_home:
		rod.queue_free()


## Rods leave the "rods" group while carried, so the lookup uses "all_rods",
## which they never leave.
func _find_rod(rod_id: String) -> Node3D:
	for rod in get_tree().get_nodes_in_group("all_rods"):
		if String(rod.get("rod_id")) == rod_id:
			return rod as Node3D
	return null


# --- NETWORK HELPERS ---

func _broadcast(method: StringName, args: Array = []) -> void:
	Net.broadcast(self, method, args)


## Animation changes are decided by the host and mirrored to the clients.
## A client reaching this (from inside an RPC handler) just plays it locally.
func _play_animation(anim: String) -> void:
	if Net.is_online() and Net.is_authority():
		_remote_play_animation.rpc(anim)
	else:
		animation_player.play(anim)


@rpc("authority", "call_local", "reliable")
func _remote_play_animation(anim: String) -> void:
	animation_player.play(anim)


# Called by Door.gd (via the "enemies" group) when a navigation link is
# toggled. Disabling a link does not invalidate paths agents have already
# computed, so nudge the target to force a fresh query next frame.
func refresh_navigation() -> void:
	nav_agent.target_position = global_position
