extends Node3D
# Attach to each individual light (must stay in the "lights" group)

@onready var light: Light3D = $"SM Street Light/Light3D"
@onready var light2: Light3D =$"SM Street Light/Light3D2"
@onready var light3: Light3D =$"SM Street Light/SpotLight3D"
var is_on: bool = true

func TurnOff() -> void:
	is_on = false
	light.visible = false
	light2.visible = false
	light3.visible = false

func TurnOn() -> void:
	is_on = true
	light.visible = true
	light2.visible = true
	light3.visible = true
	
