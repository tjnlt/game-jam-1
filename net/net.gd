extends Node
## Autoloaded as `Net`. Owns the ENet peer, the roster of connected players,
## and the host-driven scene changes that keep every peer on the same level.
##
## Model: listen-server. The host plays the game *and* is peer 1, the authority
## for all shared game state. Clients never decide anything on their own - they
## ask the host and apply what it sends back.

signal players_changed
signal connection_failed
signal server_disconnected
## Emitted once the player bodies for this level have been spawned.
signal level_started

const DEFAULT_PORT: int = 24565
const MAX_PLAYERS: int = 4

const PLAYER_SCENE: PackedScene = preload("res://playercharacter/proto_controller.tscn")

## Levels the host can start. Keyed by the label shown in the lobby.
const LEVELS: Dictionary = {
	"Test Arena": "res://net/test_arena.tscn",
	"Reactor": "res://environment/environment.tscn",
}

## peer_id -> { "name": String }. Identical on every peer.
var players: Dictionary = {}

var local_player_name: String = "Player"

## Host-side: peer_id -> true once that peer has the level loaded. Spawning
## before every peer is ready would send spawn packets to peers that have no
## container to put them in, and those players would simply never appear.
var _peers_ready: Dictionary = {}

var _pending_spawner: MultiplayerSpawner = null
var _pending_transforms: Array[Transform3D] = []


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# ─────────────────────────────────────────────
# CONNECTING
# ─────────────────────────────────────────────

func host_game(player_name: String, port: int = DEFAULT_PORT) -> Error:
	local_player_name = player_name

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("Net: could not host on port %d (error %d)." % [port, err])
		return err

	multiplayer.multiplayer_peer = peer

	# The host is always peer 1 and is in the roster from the start.
	players = {1: {"name": player_name}}
	players_changed.emit()
	return OK


func join_game(address: String, player_name: String, port: int = DEFAULT_PORT) -> Error:
	local_player_name = player_name

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("Net: could not reach %s:%d (error %d)." % [address, port, err])
		return err

	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	players.clear()
	_reset_level_state()
	players_changed.emit()


func is_host() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()


func is_online() -> bool:
	return multiplayer.multiplayer_peer != null


## True when this peer decides shared game state - AI, damage, rods, timers.
## The host in a networked game, or the only peer in a solo session.
func is_authority() -> bool:
	return not is_online() or multiplayer.is_server()


# ─────────────────────────────────────────────
# ROSTER
# ─────────────────────────────────────────────

func _on_peer_connected(_id: int) -> void:
	# The newcomer introduces itself via _request_register once it is fully
	# connected, so there is nothing to do here but wait for that.
	pass


func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	_peers_ready.erase(id)
	players_changed.emit()

	# We may have been waiting on the peer that just left.
	_try_spawn_players()


func _on_connected_to_server() -> void:
	_request_register.rpc_id(1, local_player_name)


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	connection_failed.emit()


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	players.clear()
	_reset_level_state()
	players_changed.emit()
	server_disconnected.emit()


## Client -> host: "I'm here, this is my name."
@rpc("any_peer", "reliable")
func _request_register(player_name: String) -> void:
	if not multiplayer.is_server():
		return

	var id := multiplayer.get_remote_sender_id()

	# Catch the newcomer up on everyone already connected...
	for existing_id: int in players:
		_register_player.rpc_id(id, existing_id, players[existing_id]["name"])

	# ...then tell everyone (the newcomer included) about the newcomer.
	players[id] = {"name": player_name}
	_register_player.rpc(id, player_name)
	players_changed.emit()


@rpc("authority", "reliable")
func _register_player(id: int, player_name: String) -> void:
	players[id] = {"name": player_name}
	players_changed.emit()


# ─────────────────────────────────────────────
# LEVEL LOADING
# ─────────────────────────────────────────────

## Host only. Moves every peer into the same level at the same time.
func start_game(level_path: String) -> void:
	if not is_host():
		return

	# Godot pushes the level's spawns at a peer as soon as it connects, so a
	# peer arriving mid-game receives state for a scene it has never loaded and
	# drops all of it. It would register into the roster and then sit in the
	# lobby forever waiting for a _load_level that was already broadcast. Until
	# there is real late-join support, stop taking connections once we start.
	multiplayer.multiplayer_peer.refuse_new_connections = true

	_load_level.rpc(level_path)


@rpc("authority", "call_local", "reliable")
func _load_level(level_path: String) -> void:
	_reset_level_state()
	get_tree().change_scene_to_file(level_path)


func _reset_level_state() -> void:
	_peers_ready.clear()
	_pending_spawner = null
	_pending_transforms = []


# ─────────────────────────────────────────────
# PLAYER BODIES
# ─────────────────────────────────────────────

## Called by a level from its _ready(), passing the MultiplayerSpawner that
## covers the node the player bodies live under.
##
## Nothing spawns until every connected peer reports its level loaded: a spawn
## sent to a peer that is still loading arrives at a path that does not exist
## yet and is dropped, leaving that player permanently invisible to it.
func begin_level(spawner: MultiplayerSpawner, spawn_transforms: Array[Transform3D]) -> void:
	# Every peer builds its bodies through this same function so the host's
	# chosen spawn transform is applied everywhere. Simply setting `transform`
	# before add_child does not survive replication - the spawner sends the
	# scene and the node name and nothing else, so the clients would build a
	# default body at the world origin instead.
	spawner.spawn_function = _make_player_body

	# Running a level directly from the editor with no peer: one local player,
	# so levels stay testable without going through the lobby.
	if not is_online():
		var container := spawner.get_node(spawner.spawn_path)
		var solo_transform := Transform3D()
		if not spawn_transforms.is_empty():
			solo_transform = spawn_transforms[0]
		container.add_child(_make_player_body({"id": 1, "transform": solo_transform}))
		level_started.emit()
		return

	_pending_spawner = spawner
	_pending_transforms = spawn_transforms

	if is_host():
		_peers_ready[1] = true
		_try_spawn_players()
	else:
		_report_level_ready.rpc_id(1)


## Runs on every peer with the data the host chose. The body's name is its peer
## id - ProtoController turns that into its multiplayer authority, so every peer
## agrees on who drives which body.
func _make_player_body(data: Dictionary) -> Node:
	var body := PLAYER_SCENE.instantiate()
	body.name = str(data["id"])
	body.transform = data["transform"]
	return body


@rpc("any_peer", "reliable")
func _report_level_ready() -> void:
	if not multiplayer.is_server():
		return
	_peers_ready[multiplayer.get_remote_sender_id()] = true
	_try_spawn_players()


## Host only. Spawns one body per peer once everybody is loaded in.
func _try_spawn_players() -> void:
	if not is_host() or _pending_spawner == null:
		return

	for id: int in players:
		if not _peers_ready.get(id, false):
			return

	if not is_instance_valid(_pending_spawner):
		_reset_level_state()
		return

	var index := 0
	for id: int in players:
		var body_transform := Transform3D()
		if index < _pending_transforms.size():
			body_transform = _pending_transforms[index]
		_pending_spawner.spawn({"id": id, "transform": body_transform})
		index += 1

	_pending_spawner = null
	_pending_transforms = []
	_level_started.rpc()
	level_started.emit()


@rpc("authority", "reliable")
func _level_started() -> void:
	level_started.emit()


## Calls one of `node`'s @rpc("authority", "call_local") methods on every peer,
## or just locally when no session is running - so the same gameplay code path
## works online and in a solo test run.
func broadcast(node: Node, method: StringName, args: Array = []) -> void:
	if is_online():
		node.callv("rpc", [method] + args)
	else:
		node.callv(method, args)


## The body this peer actually controls, or null before it has spawned.
func local_player() -> Node:
	for body in get_tree().get_nodes_in_group("player"):
		if body.is_multiplayer_authority():
			return body
	return null
