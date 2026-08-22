extends Node3D


const RUN_SPEED := 6.0
const FAST_RUN_SPEED := 12.0
const BACKWARD_SPEED := 1.0
const RETREAT_RADIUS := 2.0
const RETREAT_DURATION := 1.4

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var player: Node3D
var _retreating := false
var _retreat_timer := 0.0
var _fast_mode := false
var health := 2

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	animation_player.play("local/run")

func _unhandled_key_input(event: InputEvent) -> void:
	# Debug-only toggle for testing the fast_run animation/speed.
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		_fast_mode = not _fast_mode
		if not _retreating:
			animation_player.play("local/fast_run" if _fast_mode else "local/run")

func _physics_process(delta: float) -> void:
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
		look_at(global_position - to_player_dir, Vector3.UP)

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
		look_at(global_position - to_player_dir, Vector3.UP)
		return

	var speed := FAST_RUN_SPEED if _fast_mode else RUN_SPEED
	global_position += to_player_dir * speed * delta
	look_at(global_position - to_player_dir, Vector3.UP)

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		var environment := get_tree().get_first_node_in_group("environment")
		if environment and environment.has_method("register_goblin_kill"):
			environment.register_goblin_kill()
		queue_free()
