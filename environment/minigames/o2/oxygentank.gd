extends Area3D
##
## MULTIPLAYER
## Same shape as generator.gd: the host owns the leak schedule and the leaking
## flag, while the patch-up minigame is local to whoever pressed E. See that
## file for the reasoning.
##

signal state_changed(is_leaking: bool)

const MINIGAME_SCENE: PackedScene = preload("res://environment/minigames/o2/oxygentank_minigame.tscn")

@export var min_leak_seconds: float = 45.0
@export var max_leak_seconds: float = 75.0


## True only when this peer's own player is at the tank.
var player_in_range: bool = false
var is_leaking: bool = false
var active_minigame: Control = null
var leak_timer: Timer
var player_ref: Node = null

@onready var steam: GPUParticles3D = $Steam
@onready var steam2: GPUParticles3D = $Steam2
@onready var steam3: GPUParticles3D = $Steam3
@onready var steam4: GPUParticles3D = $Steam4

func _ready() -> void:
	add_to_group("oxygentank")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	steam.emitting = false
	steam2.emitting = false
	steam3.emitting = false
	steam4.emitting = false

	# Only the host runs the leak schedule; clients are told when it happens.
	if not Net.is_authority():
		return

	leak_timer = Timer.new()
	leak_timer.one_shot = true
	leak_timer.timeout.connect(_start_leak)
	add_child(leak_timer)
	_schedule_next_leak()

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and is_leaking and active_minigame == null and event.is_action_pressed("interact"):
		_open_minigame()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.is_multiplayer_authority():
		player_in_range = true
		player_ref = body

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and body.is_multiplayer_authority():
		player_in_range = false
		player_ref = null

func _schedule_next_leak() -> void:
	leak_timer.start(randf_range(min_leak_seconds, max_leak_seconds))

func _start_leak() -> void:
	Net.broadcast(self, &"_set_leaking", [true])

# ─────────────────────────────────────────────
# LOCAL MINIGAME
# ─────────────────────────────────────────────

func _open_minigame() -> void:
	active_minigame = MINIGAME_SCENE.instantiate()
	get_tree().current_scene.add_child(active_minigame)
	active_minigame.minigame_success.connect(_on_minigame_success)
	_lock_player()

func _on_minigame_success() -> void:
	# The minigame frees itself once it succeeds.
	active_minigame = null
	_release_player()

	if Net.is_authority():
		Net.broadcast(self, &"_set_leaking", [false])
	else:
		_ask_host_to_repair.rpc_id(1)

func _lock_player() -> void:
	if player_ref and is_instance_valid(player_ref):
		player_ref.can_move = false
		player_ref.can_shoot = false
		player_ref.release_mouse()

func _release_player() -> void:
	if player_ref and is_instance_valid(player_ref):
		player_ref.can_move = true
		player_ref.can_shoot = true
		player_ref.capture_mouse()

## Someone else sealed the leak first - drop this peer's half-done attempt.
func _close_minigame() -> void:
	if active_minigame != null and is_instance_valid(active_minigame):
		active_minigame.queue_free()
	active_minigame = null
	_release_player()

# ─────────────────────────────────────────────
# SHARED STATE
# ─────────────────────────────────────────────

@rpc("any_peer", "reliable")
func _ask_host_to_repair() -> void:
	if not Net.is_authority():
		return
	if not is_leaking:
		return
	Net.broadcast(self, &"_set_leaking", [false])

@rpc("authority", "call_local", "reliable")
func _set_leaking(leaking: bool) -> void:
	is_leaking = leaking
	state_changed.emit(leaking)

	steam.emitting = leaking
	steam2.emitting = leaking
	steam3.emitting = leaking
	steam4.emitting = leaking

	if not leaking:
		_close_minigame()
		if Net.is_authority():
			_schedule_next_leak()
