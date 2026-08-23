extends Node

const EndScreenScene := preload("res://ui/end_screen.tscn")

const TOTAL_RODS : int = 8

@export var rods_in_reactor : int = TOTAL_RODS
@export var rods_stolen : int = 0   # currently in a goblin's possession, still recoverable
@export var rods_lost : int = 0     # goblin escaped with it, gone forever

var elapsed_time: float = 0.0
var goblins_killed: int = 0
var is_game_over: bool = false

@onready var ambience_player: AudioStreamPlayer3D = $Ambience
@onready var radio_player: AudioStreamPlayer3D = $RadioMusic


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("environment")

	# Loop the ambience for as long as the environment scene is alive,
	# regardless of whether the imported .wav itself is set to loop.
	ambience_player.finished.connect(ambience_player.play)
	ambience_player.play()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_game_over:
		return
	elapsed_time += delta


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == KEY_P:
		if radio_player.playing:
			radio_player.stop()
		else:
			radio_player.play()

	if is_game_over:
		return

	# Debug-only trigger for testing the end screen without losing all 8 rods.
	if OS.is_debug_build() and event.keycode == KEY_K:
		trigger_game_over()


func register_goblin_kill() -> void:
	goblins_killed += 1


# Call when a goblin reaches a rod and grabs it (e.g. on collision with the rod).
func steal_rod() -> void:
	if rods_in_reactor <= 0:
		return
	rods_in_reactor -= 1
	rods_stolen += 1


# Call when a goblin carrying a stolen rod is killed before escaping.
# The rod is recovered and returned to the reactor.
func recover_rod() -> void:
	if rods_stolen <= 0:
		return
	rods_stolen -= 1
	rods_in_reactor += 1


# Call when a goblin carrying a stolen rod escapes (reaches its spawn/exit).
# The rod is lost permanently.
func lose_rod() -> void:
	if rods_stolen <= 0:
		return
	rods_stolen -= 1
	rods_lost += 1

	if rods_lost >= TOTAL_RODS:
		_on_all_rods_lost()


func _on_all_rods_lost() -> void:
	# All rods have been stolen and lost - player loses the game.
	trigger_game_over()


func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true

	var end_screen: Control = EndScreenScene.instantiate()
	add_child(end_screen)
	end_screen.show_results(elapsed_time, goblins_killed)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
