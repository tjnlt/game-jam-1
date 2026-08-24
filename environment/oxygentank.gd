extends Area3D

signal state_changed(is_leaking: bool)

const MINIGAME_SCENE: PackedScene = preload("res://environment/oxygentank_minigame.tscn")

@export var min_leak_seconds: float = 45.0
@export var max_leak_seconds: float = 75.0


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

	leak_timer = Timer.new()
	leak_timer.one_shot = true
	leak_timer.timeout.connect(_start_leak)
	add_child(leak_timer)
	_schedule_next_leak()

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and is_leaking and active_minigame == null and event.is_action_pressed("interact"):
		_open_minigame()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null

func _schedule_next_leak() -> void:
	leak_timer.start(randf_range(min_leak_seconds, max_leak_seconds))

func _start_leak() -> void:
	is_leaking = true
	state_changed.emit(true)
	steam.emitting = true
	steam2.emitting = true
	steam3.emitting = true
	steam4.emitting = true

func _open_minigame() -> void:
	active_minigame = MINIGAME_SCENE.instantiate()
	get_tree().current_scene.add_child(active_minigame)
	active_minigame.minigame_success.connect(_on_minigame_success)
	if player_ref:
		player_ref.can_move = false
		player_ref.can_shoot = false
		player_ref.release_mouse()

func _on_minigame_success() -> void:
	active_minigame = null
	is_leaking = false
	state_changed.emit(false)
	steam.emitting = false
	steam2.emitting = false
	steam3.emitting = false
	steam4.emitting = false
	if player_ref:
		player_ref.can_move = true
		player_ref.can_shoot = true
		player_ref.capture_mouse()
	_schedule_next_leak()
