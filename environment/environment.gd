extends Node3D

const EndScreenScene := preload("res://ui/end_screen.tscn")

var elapsed_time: float = 0.0
var goblins_killed: int = 0
var is_game_over: bool = false


func _ready() -> void:
	add_to_group("environment")


func _process(delta: float) -> void:
	if is_game_over:
		return
	elapsed_time += delta


func _unhandled_key_input(event: InputEvent) -> void:
	if is_game_over:
		return
	# Debug-only trigger until the real reactor-meltdown condition (rod theft) lands.
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		trigger_game_over()


func register_goblin_kill() -> void:
	goblins_killed += 1


func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true

	var end_screen: Control = EndScreenScene.instantiate()
	add_child(end_screen)
	end_screen.show_results(elapsed_time, goblins_killed)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
