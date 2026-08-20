extends Node3D
# Attach to each individual light (must stay in the "lights" group)

@onready var light: Light3D = $Light3D

var is_on: bool = true

func TurnOff() -> void:
	is_on = false
	light.visible = false

func TurnOn() -> void:
	is_on = true
	light.visible = true
