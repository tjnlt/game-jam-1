extends Control
## Host/join screen. Everything here talks to the `Net` autoload; this script
## only drives the widgets and mirrors Net's roster into the player list.

@onready var name_edit: LineEdit = $Center/Panel/Margin/VBox/NameRow/NameEdit
@onready var address_edit: LineEdit = $Center/Panel/Margin/VBox/AddressRow/AddressEdit
@onready var host_button: Button = $Center/Panel/Margin/VBox/ConnectRow/HostButton
@onready var join_button: Button = $Center/Panel/Margin/VBox/ConnectRow/JoinButton
@onready var status_label: Label = $Center/Panel/Margin/VBox/StatusLabel
@onready var player_list: Label = $Center/Panel/Margin/VBox/PlayerList
@onready var level_row: HBoxContainer = $Center/Panel/Margin/VBox/LevelRow
@onready var level_option: OptionButton = $Center/Panel/Margin/VBox/LevelRow/LevelOption
@onready var start_button: Button = $Center/Panel/Margin/VBox/ActionRow/StartButton
@onready var leave_button: Button = $Center/Panel/Margin/VBox/ActionRow/LeaveButton
@onready var back_button: Button = $Center/Panel/Margin/VBox/ActionRow/BackButton

## A host that has already started the game stops answering, so a join attempt
## has to give up on its own rather than wait for a refusal that never comes.
const JOIN_TIMEOUT_SECONDS: float = 8.0

## Bumped per attempt so a timeout left over from an abandoned one cannot
## cancel the attempt that replaced it.
var _join_attempt: int = 0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	MenuMusic.play_music()

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_button.pressed.connect(_on_start_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	back_button.pressed.connect(_on_back_pressed)

	Net.players_changed.connect(_refresh)
	Net.connection_failed.connect(_on_connection_failed)
	Net.server_disconnected.connect(_on_server_disconnected)

	for label: String in Net.LEVELS:
		level_option.add_item(label)

	name_edit.text = "Player %d" % (randi() % 900 + 100)
	address_edit.text = "127.0.0.1"

	# Coming back here after a game leaves the old peer lying around.
	if Net.is_online():
		Net.leave()

	_refresh()


# ─────────────────────────────────────────────
# BUTTONS
# ─────────────────────────────────────────────

func _on_host_pressed() -> void:
	var err := Net.host_game(_player_name())
	if err != OK:
		status_label.text = "Could not host on port %d - is a game already running?" % Net.DEFAULT_PORT
		return
	status_label.text = "Hosting on port %d. Share your address with the others." % Net.DEFAULT_PORT
	_refresh()


func _on_join_pressed() -> void:
	var address := address_edit.text.strip_edges()
	if address.is_empty():
		status_label.text = "Enter the host's address first."
		return

	var err := Net.join_game(address, _player_name())
	if err != OK:
		status_label.text = "Could not reach %s." % address
		return
	status_label.text = "Connecting to %s..." % address
	_refresh()
	_time_out_join(address)


## ENet greets a host that has stopped taking connections with silence, not a
## refusal, so neither connection_failed nor players_changed would ever fire and
## the lobby would sit on "Connecting..." for good.
func _time_out_join(address: String) -> void:
	_join_attempt += 1
	var attempt := _join_attempt

	await get_tree().create_timer(JOIN_TIMEOUT_SECONDS).timeout

	# Superseded by a later attempt, or we left, or the host answered.
	if attempt != _join_attempt or not Net.is_online():
		return
	if Net.players.has(multiplayer.get_unique_id()):
		return

	Net.leave()
	status_label.text = "No answer from %s - the host may have already started the game." % address
	_refresh()


func _on_start_pressed() -> void:
	var label: String = level_option.get_item_text(level_option.selected)
	MenuMusic.stop_music()
	Net.start_game(Net.LEVELS[label])


func _on_leave_pressed() -> void:
	Net.leave()
	status_label.text = "Disconnected."
	_refresh()


func _on_back_pressed() -> void:
	Net.leave()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


# ─────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────

func _on_connection_failed() -> void:
	status_label.text = "Connection failed - check the address, and that the host is running and has not started the game yet."
	_refresh()


func _on_server_disconnected() -> void:
	status_label.text = "The host closed the game."
	_refresh()


func _refresh() -> void:
	var online := Net.is_online()
	var host := Net.is_host()

	host_button.disabled = online
	join_button.disabled = online
	name_edit.editable = not online
	address_edit.editable = not online

	# Only the host chooses the level and starts the game.
	level_row.visible = host
	start_button.visible = host
	start_button.disabled = not host
	leave_button.visible = online

	if not online:
		player_list.text = "Not connected."
		return

	# A client has no button to press until the host starts, so the
	# "Connecting..." line from the join button would otherwise sit there for
	# the whole lobby and make a fully connected client look like a stuck one.
	if not host and Net.players.has(multiplayer.get_unique_id()):
		status_label.text = "Connected. Waiting for the host to start the game..."

	var lines: PackedStringArray = []
	for id: int in Net.players:
		var suffix := ""
		if id == 1:
			suffix = " (host)"
		if id == multiplayer.get_unique_id():
			suffix += " - you"
		lines.append("%s%s" % [Net.players[id]["name"], suffix])

	player_list.text = "Players %d/%d\n%s" % [
		Net.players.size(), Net.MAX_PLAYERS, "\n".join(lines)
	]


func _player_name() -> String:
	var chosen := name_edit.text.strip_edges()
	return chosen if not chosen.is_empty() else "Player"
