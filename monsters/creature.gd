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

func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")

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
			animation_player.play("local/fast_run" if _fast_mode else "local/run")

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
			animation_player.play("local/fast_run" if _fast_mode else "local/run")
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

	var speed := FAST_RUN_SPEED if _fast_mode else RUN_SPEED
	#nav_agent.target_position = player.global_position
	nav_agent.target_position = _get_rod_target()
	var move_dir := global_position.direction_to(nav_agent.get_next_path_position())
	global_position += move_dir * speed * delta
	_apply_separation(delta)
	var look_dir := move_dir
	look_dir.y = 0.0
	if look_dir != Vector3.ZERO:
		look_at(global_position - look_dir.normalized(), Vector3.UP)
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

		# Let the killing hit's sound finish playing instead of getting cut
		# off when this creature (and its child AudioStreamPlayer3D) is freed.
		sound.reparent(get_tree().current_scene, true)
		sound.finished.connect(sound.queue_free)
		sound.play()

		queue_free()
	else:
		sound.play()
		
		
	
	
	# --- ROD LOGIC ---
func _get_rod_target():
	var closest: Node3D = null
	var closest_dist := INF
	for rod in get_tree().get_nodes_in_group("rods"):
		var d:= global_position.distance_squared_to((rod as Node3D).global_position)
		if d < closest_dist:
			closest_dist = d
			closest = rod
	return closest.global_position if closest else global_position


# Called by Door.gd (via the "enemies" group) when a navigation link is
# toggled. Disabling a link does not invalidate paths agents have already
# computed, so nudge the target to force a fresh query next frame.
func refresh_navigation() -> void:
	nav_agent.target_position = global_position
