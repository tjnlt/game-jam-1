extends Area3D

signal state_changed(is_broken: bool)

const MINIGAME_SCENE: PackedScene = preload("res://environment/minigames/generator/generator_minigame.tscn")

@export var min_break_seconds: float = 60
@export var max_break_seconds: float = 120

var player_in_range: bool = false
var is_broken: bool = false
var active_minigame: Control = null
var break_timer: Timer
var player_ref: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	break_timer = Timer.new()
	break_timer.one_shot = true
	break_timer.timeout.connect(_break_generator)
	add_child(break_timer)
	_schedule_next_break()

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and is_broken and active_minigame == null and event.is_action_pressed("interact"):
		_open_minigame()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null

func _schedule_next_break() -> void:
	break_timer.start(randf_range(min_break_seconds, max_break_seconds))

func _break_generator() -> void:
	is_broken = true
	state_changed.emit(true)
	for light in get_tree().get_nodes_in_group("lights"):
		if light.has_method("TurnOff"):
			light.TurnOff()

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
	is_broken = false
	state_changed.emit(false)
	if player_ref:
		player_ref.can_move = true
		player_ref.can_shoot = true
		player_ref.capture_mouse()
	for light in get_tree().get_nodes_in_group("lights"):
		if light.has_method("TurnOn"):
			light.TurnOn()
	_schedule_next_break()
