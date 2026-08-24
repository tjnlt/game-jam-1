extends Control

@onready var time_label: Label = $HBoxContainer/TimeLabel

var environment: Node


func _ready() -> void:
	await get_tree().process_frame

	environment = get_tree().get_first_node_in_group("environment")
	if environment == null:
		push_warning("timer_display: no node in group 'environment' found.")


func _process(_delta: float) -> void:
	if environment == null:
		return
	time_label.text = _format_time(environment.elapsed_time)


func _format_time(total_seconds: float) -> String:
	var seconds_total := int(total_seconds)
	var minutes := seconds_total / 60
	var seconds := seconds_total % 60
	return "%02d:%02d" % [minutes, seconds]
