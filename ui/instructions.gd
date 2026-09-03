extends Control

@onready var title_label: Label = $Margin/VBoxContainer/Title
@onready var back_button: Button = $Margin/VBoxContainer/ButtonRow/BackButton
@onready var next_button: Button = $Margin/VBoxContainer/ButtonRow/NextButton

@onready var pages: Array[Dictionary] = [
	{"title": "MISSION BRIEFING", "node": $Margin/VBoxContainer/BriefingPanel/TextMargin/Pages/PageControls},
	{"title": "DOOR CONTROLS", "node": $Margin/VBoxContainer/BriefingPanel/TextMargin/Pages/PageDoor},
	{"title": "LIGHTS TASK", "node": $Margin/VBoxContainer/BriefingPanel/TextMargin/Pages/PageLights},
	{"title": "OXYGEN TASK", "node": $Margin/VBoxContainer/BriefingPanel/TextMargin/Pages/PageOxygen},
	{"title": "RADIO", "node": $Margin/VBoxContainer/BriefingPanel/TextMargin/Pages/PageRadio},
]

var page_index := 0


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	next_button.pressed.connect(_on_next_pressed)
	MenuMusic.play_music()
	_update_page()


func _on_back_pressed() -> void:
	if page_index <= 0:
		return
	page_index -= 1
	_update_page()


func _on_next_pressed() -> void:
	if page_index < pages.size() - 1:
		page_index += 1
		_update_page()
		return

	# The lobby decides which level to load, so the music keeps playing until
	# the host actually starts the game.
	get_tree().change_scene_to_file("res://ui/lobby.tscn")


func _update_page() -> void:
	for i in pages.size():
		(pages[i]["node"] as Control).visible = (i == page_index)

	title_label.text = pages[page_index]["title"]
	back_button.disabled = page_index == 0
	next_button.text = "Let's go!" if page_index == pages.size() - 1 else "Next"
	next_button.grab_focus()
