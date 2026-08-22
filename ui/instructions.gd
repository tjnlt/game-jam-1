extends Control

@onready var lets_go_button: Button = $Margin/VBoxContainer/LetsGoButton

func _ready() -> void:
	lets_go_button.pressed.connect(_on_lets_go_pressed)
	lets_go_button.grab_focus()

func _on_lets_go_pressed() -> void:
	get_tree().change_scene_to_file("res://environment/environment.tscn")
