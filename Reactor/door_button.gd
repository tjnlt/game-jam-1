extends Area3D


# ------------------------------
# DOORS
# ------------------------------

@export var door_1: Node3D
@export var door_2: Node3D
@export var door_3: Node3D
@export var door_4: Node3D


# ------------------------------
# MALFUNCTION MESSAGE
# ------------------------------

@export var malfunction_message: Label3D
@export var message_duration: float = 3.0


# ------------------------------
# SOUNDS
# ------------------------------

@onready var door_close_sound: AudioStreamPlayer3D = $DoorCloseSound
@onready var denied_sound: AudioStreamPlayer3D = $DeniedSound


# ------------------------------
# INDICATORS
# ------------------------------

@export var indicator_1: MeshInstance3D
@export var indicator_2: MeshInstance3D
@export var indicator_3: MeshInstance3D
@export var indicator_4: MeshInstance3D


# ------------------------------
# TIMING
# ------------------------------

@export var closed_time: float = 5.0
@export var cooldown_time: float = 10.0


var player_in_range: bool = false
var button_available: bool = true

var message_showing: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Start with all indicators off.
	_set_indicator(indicator_1, false)
	_set_indicator(indicator_2, false)
	_set_indicator(indicator_3, false)
	_set_indicator(indicator_4, false)

	# Start with malfunction message hidden.
	if malfunction_message != null:
		malfunction_message.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range:
		return

	if event.is_action_pressed("interact"):

		if button_available:
			_activate_button()

		else:
			denied_sound.play()
			_show_malfunction_message()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false


func _activate_button() -> void:
	if not button_available:
		return

	button_available = false

	var door_pairs: Array = [
		{
			"door": door_1,
			"indicator": indicator_1
		},
		{
			"door": door_2,
			"indicator": indicator_2
		},
		{
			"door": door_3,
			"indicator": indicator_3
		},
		{
			"door": door_4,
			"indicator": indicator_4
		}
	]

	# Remove any unassigned doors.
	door_pairs = door_pairs.filter(
		func(pair):
			return pair["door"] != null
	)

	if door_pairs.is_empty():
		print("Door button has no doors assigned.")
		button_available = true
		return

	door_pairs.shuffle()

	# Randomly choose 1, 2, or 3 doors.
	var amount_to_close: int = randi_range(1, 3)
	amount_to_close = min(amount_to_close, door_pairs.size())

	var selected_pairs: Array = []

	for i in range(amount_to_close):
		selected_pairs.append(door_pairs[i])

	# Play the closing sound once.
	door_close_sound.play()

	# Close selected doors and activate their indicators.
	for pair in selected_pairs:
		var door: Node3D = pair["door"]
		var indicator: MeshInstance3D = pair["indicator"]

		if door.has_method("close_door"):
			door.close_door()

		_set_indicator(indicator, true)

	# Keep the doors closed.
	await get_tree().create_timer(closed_time).timeout

	# Reopen selected doors and deactivate their indicators.
	for pair in selected_pairs:
		var door: Node3D = pair["door"]
		var indicator: MeshInstance3D = pair["indicator"]

		if is_instance_valid(door) and door.has_method("open_door"):
			door.open_door()

		_set_indicator(indicator, false)

	# Keep the button unavailable during cooldown.
	await get_tree().create_timer(cooldown_time).timeout

	button_available = true


func _set_indicator(
	indicator: MeshInstance3D,
	turned_on: bool
) -> void:
	if indicator == null:
		return

	indicator.visible = turned_on


func _show_malfunction_message() -> void:
	if malfunction_message == null:
		return

	# Prevent multiple overlapping timers if the player spams E.
	if message_showing:
		return

	message_showing = true

	malfunction_message.text = "Hmmm... The doors seem to only work every 5 minutes."
	malfunction_message.visible = true

	await get_tree().create_timer(message_duration).timeout

	if is_instance_valid(malfunction_message):
		malfunction_message.visible = false

	message_showing = false
