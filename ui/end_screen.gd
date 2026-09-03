extends Control

@onready var time_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TimeLabel
@onready var kills_label: Label = $CenterContainer/PanelContainer/VBoxContainer/KillsLabel
@onready var retry_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonRow/RetryButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonRow/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	retry_button.pressed.connect(_on_retry_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	retry_button.grab_focus()


func show_results(time_survived: float, goblins_killed: int) -> void:
	time_label.text = "You survived: %s" % _format_time(time_survived)
	kills_label.text = "Creatures slain: %d" % goblins_killed


func _format_time(total_seconds: float) -> String:
	var seconds_total := int(total_seconds)
	var minutes := seconds_total / 60
	var seconds := seconds_total % 60
	return "%02d:%02d" % [minutes, seconds]


func _on_retry_pressed() -> void:
	get_tree().paused = false

	# A rematch has to be agreed by everyone, so it is set up back in the lobby
	# rather than by one peer reloading the level under the others' feet.
	if Net.is_online():
		Net.leave()
		get_tree().change_scene_to_file("res://ui/lobby.tscn")
		return

	MenuMusic.stop_music()
	get_tree().change_scene_to_file("res://environment/environment.tscn")


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
