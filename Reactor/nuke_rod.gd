extends Node3D

var home_holder: Node3D = null
var carrier: Node3D = null

func _ready() -> void:
	add_to_group("rods")
