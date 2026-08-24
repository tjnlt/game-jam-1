extends Node3D

@onready var label_3d: Label3D = $Label3D
var environment_node: Node = null

# Set your desired maximum base font size
const BASE_FONT_SIZE: int = 10
# Set the length threshold where shrinking starts
const MAX_UNSCALED_CHARS: int = 2

func _process(_delta: float) -> void:
	if not is_instance_valid(environment_node):
		environment_node = get_tree().get_first_node_in_group("environment")
		return

	var text_string: String = "%d" % environment_node.goblins_killed
	
	# Dynamically shrink font size if text exceeds comfortable char length\
	var overflow: int = text_string.length() - 3
	label_3d.font_size = 32

	label_3d.text = text_string
