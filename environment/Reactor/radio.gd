extends Area3D


@export var dancer: Node3D

@onready var radio_player: AudioStreamPlayer3D = $RadioMusic

var player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact"):
		_toggle_radio()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false


func _toggle_radio() -> void:
	if radio_player == null:
		return

	if radio_player.playing:
		radio_player.stop()
	else:
		radio_player.play()

	if dancer and dancer.has_method("set_dancing"):
		dancer.set_dancing(radio_player.playing)
