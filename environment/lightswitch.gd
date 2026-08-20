extends Area3D

var player_in_range: bool = false
var lights_on: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact"):
		toggle_lights()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func toggle_lights() -> void:
	lights_on = not lights_on
	for light in get_tree().get_nodes_in_group("lights"):
		if lights_on and light.has_method("TurnOn"):
			light.TurnOn()
		elif not lights_on and light.has_method("TurnOff"):
			light.TurnOff()
