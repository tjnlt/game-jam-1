extends Node
 
const TOTAL_RODS : int = 8
 
@export var rods_in_reactor : int = TOTAL_RODS
@export var rods_stolen : int = 0   # currently in a goblin's possession, still recoverable
@export var rods_lost : int = 0     # goblin escaped with it, gone forever
 
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
 
 
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
 
 
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
	# get_tree().change_scene_to_file("res://path/to/game_over.tscn")
	pass
 
