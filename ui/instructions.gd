extends Control

@onready var lets_go_button: Button = $Margin/VBoxContainer/LetsGoButton

func _ready() -> void:
	lets_go_button.pressed.connect(_on_lets_go_pressed)
	lets_go_button.grab_focus()
	MenuMusic.play_music()

func _on_lets_go_pressed() -> void:
	MenuMusic.stop_music()
	get_tree().change_scene_to_file("res://environment/environment.tscn")
