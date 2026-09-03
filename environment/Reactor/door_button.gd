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
@export var door_close_sound_offset: float = 0.15


## True only when this peer's own player is at the button - every peer has all
## four bodies, so the authority check is what makes "in range" mean "me".
var player_in_range: bool = false

## Host-owned. Clients ask the host to press and it decides.
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
		_request_press()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.is_multiplayer_authority():
		player_in_range = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and body.is_multiplayer_authority():
		player_in_range = false


# ─────────────────────────────────────────────
# PRESSING
#
# Which doors close is random, so the host has to roll it once and send the
# result - four peers each rolling their own would close different doors.
# ─────────────────────────────────────────────

func _request_press() -> void:
	if Net.is_authority():
		_handle_press()
	else:
		_ask_host_to_press.rpc_id(1)


@rpc("any_peer", "reliable")
func _ask_host_to_press() -> void:
	if not Net.is_authority():
		return
	_handle_press()


func _handle_press() -> void:
	if not button_available:
		Net.broadcast(self, &"_deny_press")
		return

	var indices := _pick_door_indices()
	if indices.is_empty():
		print("Door button has no doors assigned.")
		return

	Net.broadcast(self, &"_run_door_sequence", [indices])


## Host only. Picks 1-3 of the assigned doors at random and returns their
## indices, which are the same on every peer because the doors come from
## exported slots rather than from scene order.
func _pick_door_indices() -> PackedInt32Array:
	var assigned: Array[int] = []
	for i in 4:
		if _door_at(i) != null:
			assigned.append(i)

	if assigned.is_empty():
		return PackedInt32Array()

	assigned.shuffle()

	var amount_to_close: int = randi_range(1, 3)
	amount_to_close = min(amount_to_close, assigned.size())

	var chosen := PackedInt32Array()
	for i in range(amount_to_close):
		chosen.append(assigned[i])
	return chosen


func _door_at(index: int) -> Node3D:
	match index:
		0: return door_1
		1: return door_2
		2: return door_3
		3: return door_4
	return null


func _indicator_at(index: int) -> MeshInstance3D:
	match index:
		0: return indicator_1
		1: return indicator_2
		2: return indicator_3
		3: return indicator_4
	return null


@rpc("authority", "call_local", "reliable")
func _deny_press() -> void:
	denied_sound.play()
	_show_malfunction_message()


## Runs on every peer with the same door indices, so the doors, indicators and
## cooldown stay in step everywhere.
@rpc("authority", "call_local", "reliable")
func _run_door_sequence(indices: PackedInt32Array) -> void:
	button_available = false

	# Play one close sound per door, slightly offset so each is audible.
	_play_door_close_sounds(indices.size())

	# Close selected doors and activate their indicators.
	for index in indices:
		var door := _door_at(index)
		if door and door.has_method("close_door"):
			door.close_door()
		_set_indicator(_indicator_at(index), true)

	# Keep the doors closed.
	await get_tree().create_timer(closed_time).timeout

	# Reopen selected doors and deactivate their indicators.
	for index in indices:
		var door := _door_at(index)
		if is_instance_valid(door) and door.has_method("open_door"):
			door.open_door()
		_set_indicator(_indicator_at(index), false)

	# Keep the button unavailable during cooldown.
	await get_tree().create_timer(cooldown_time).timeout

	button_available = true


func _play_door_close_sounds(count: int) -> void:
	for i in range(count):
		_play_door_close_sound()
		if i < count - 1:
			await get_tree().create_timer(door_close_sound_offset).timeout


func _play_door_close_sound() -> void:
	var sound: AudioStreamPlayer3D = door_close_sound.duplicate()
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()


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
