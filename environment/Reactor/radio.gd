extends Area3D


@export var dancer: Node3D

@onready var radio_player: AudioStreamPlayer3D = $RadioMusic

## True only when *this peer's own* player is standing at the radio. All four
## bodies exist on every peer, so without the authority check one player walking
## up would let everyone else press E from across the map.
var player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact"):
		_request_toggle()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.is_multiplayer_authority():
		player_in_range = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and body.is_multiplayer_authority():
		player_in_range = false


## The host owns whether the radio is on, so two players pressing E at the same
## moment cannot leave it playing on some screens and silent on others.
func _request_toggle() -> void:
	if Net.is_authority():
		Net.broadcast(self, &"_set_radio", [not radio_player.playing])
	else:
		_ask_host_to_toggle.rpc_id(1)


@rpc("any_peer", "reliable")
func _ask_host_to_toggle() -> void:
	if not Net.is_authority():
		return
	Net.broadcast(self, &"_set_radio", [not radio_player.playing])


@rpc("authority", "call_local", "reliable")
func _set_radio(should_play: bool) -> void:
	if radio_player == null:
		return

	if should_play:
		radio_player.play()
	else:
		radio_player.stop()

	if dancer and dancer.has_method("set_dancing"):
		dancer.set_dancing(should_play)
