extends Control

signal minigame_success
signal minigame_failed

@export var green_zone_min: float = 80.0
@export var green_zone_max: float = 100.0
@export var decay_rate: float = 12.0
@export var fill_per_click: float = 8.0

@onready var bar: ProgressBar = $Panel/VBox/Bar
@onready var fill_button: Button = $Panel/VBox/FillButton
@onready var start_button: Button = $Panel/VBox/StartButton
@onready var switches: Array[Button] = [
	$Panel/VBox/Switches/Switch1/SwitchButton1,
	$Panel/VBox/Switches/Switch2/SwitchButton2,
	$Panel/VBox/Switches/Switch3/SwitchButton3,
]
@onready var switch_lights: Array[ColorRect] = [
	$Panel/VBox/Switches/Switch1/SwitchLight1,
	$Panel/VBox/Switches/Switch2/SwitchLight2,
	$Panel/VBox/Switches/Switch3/SwitchLight3,
]

var switch_states: Array[bool] = [false, false, false]
var bar_value: float = 0.0

func _ready() -> void:
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	fill_button.disabled = true
	fill_button.pressed.connect(_on_fill_pressed)
	start_button.pressed.connect(_on_start_pressed)
	for i in switches.size():
		switches[i].pressed.connect(_on_switch_pressed.bind(i))

func _process(delta: float) -> void:
	bar_value = max(0.0, bar_value - decay_rate * delta)
	bar.value = bar_value

func _on_switch_pressed(index: int) -> void:
	switch_states[index] = not switch_states[index]
	switch_lights[index].color = Color.GREEN if switch_states[index] else Color.RED
	fill_button.disabled = switch_states.has(false)

func _on_fill_pressed() -> void:
	bar_value = min(100.0, bar_value + fill_per_click)
	bar.value = bar_value

func _on_start_pressed() -> void:
	if bar_value >= green_zone_min and bar_value <= green_zone_max:
		minigame_success.emit()
		queue_free()
	else:
		minigame_failed.emit()
		bar_value = 0.0
		bar.value = 0.0
