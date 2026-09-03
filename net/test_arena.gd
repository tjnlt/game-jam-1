extends Node3D
## Bare multiplayer sandbox: a floor, some landmarks, and four spawn points.
## No goblins, rods, or minigames - this level exists purely to prove that
## connecting, spawning, moving and shooting replicate correctly. Once a
## system works here, it gets layered into the real level.

const SPAWN_RADIUS: float = 5.0
const SPAWN_HEIGHT: float = 1.0

@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var info_label: Label = $HUD/InfoLabel


func _ready() -> void:
	Net.begin_level(player_spawner, _spawn_transforms())
	_update_info()
	Net.players_changed.connect(_update_info)
	Net.server_disconnected.connect(_on_server_disconnected)


## Four points evenly spaced around the arena centre, each facing inward so
## players can see each other the moment they spawn.
func _spawn_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for i in Net.MAX_PLAYERS:
		var angle := TAU * float(i) / float(Net.MAX_PLAYERS)
		var origin := Vector3(
			cos(angle) * SPAWN_RADIUS,
			SPAWN_HEIGHT,
			sin(angle) * SPAWN_RADIUS
		)
		transforms.append(Transform3D(Basis(Vector3.UP, angle + PI * 0.5), origin))
	return transforms


func _update_info() -> void:
	var role := "offline"
	if Net.is_host():
		role = "host"
	elif Net.is_online():
		role = "client"

	info_label.text = "TEST ARENA - %s | players: %d\nEsc: release mouse | click: capture | Backspace: back to lobby" % [
		role, maxi(Net.players.size(), 1)
	]


func _on_server_disconnected() -> void:
	get_tree().change_scene_to_file("res://ui/lobby.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_BACKSPACE:
		Net.leave()
		get_tree().change_scene_to_file("res://ui/lobby.tscn")
