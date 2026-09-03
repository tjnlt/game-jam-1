extends Node

signal rods_changed

const EndScreenScene := preload("res://ui/end_screen.tscn")

const TOTAL_RODS : int = 8

## Where the four players appear. The first entry is the original single-player
## spawn; the rest are spread sideways from it so nobody spawns inside anyone.
const SPAWN_ORIGIN := Vector3(-13.188936, 0.29461694, 78.47974)
const SPAWN_SPACING : float = 1.6
## How often the host re-sends the clock so clients cannot drift.
const CLOCK_SYNC_INTERVAL : float = 1.0

@export var rods_in_reactor : int = TOTAL_RODS
@export var rods_stolen : int = 0   # currently in a goblin's possession, still recoverable
@export var rods_lost : int = 0     # goblin escaped with it, gone forever

var elapsed_time: float = 0.0
var goblins_killed: int = 0
var is_game_over: bool = false

var _clock_sync_timer: float = 0.0

@onready var ambience_player: AudioStreamPlayer3D = $Ambience
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("environment")

	# Loop the ambience for as long as the environment scene is alive,
	# regardless of whether the imported .wav itself is set to loop.
	ambience_player.finished.connect(ambience_player.play)
	ambience_player.play()

	Net.begin_level(player_spawner, _spawn_transforms())

	if Net.is_online():
		Net.server_disconnected.connect(_on_server_disconnected)


## Keeps the original spawn's facing, fanning the players out along the level's
## X axis so four bodies do not appear inside one another.
func _spawn_transforms() -> Array[Transform3D]:
	var basis := Basis(
		Vector3(-0.16399916, 0, -0.9864605),
		Vector3(0, 1, 0),
		Vector3(0.9864605, 0, -0.16399916)
	)

	var transforms: Array[Transform3D] = []
	for i in Net.MAX_PLAYERS:
		# 0, +1.6, -1.6, +3.2 ... so the group stays centred on the old spawn.
		var step := float((i + 1) / 2) * SPAWN_SPACING
		if i % 2 == 0:
			step = -step
		transforms.append(Transform3D(basis, SPAWN_ORIGIN + basis.x * step))
	return transforms


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_game_over:
		return

	# Every peer runs its own clock so the HUD stays smooth, but the host is
	# the one that counts - it re-broadcasts the real value once a second.
	elapsed_time += delta

	if not Net.is_authority() or not Net.is_online():
		return

	_clock_sync_timer += delta
	if _clock_sync_timer >= CLOCK_SYNC_INTERVAL:
		_clock_sync_timer = 0.0
		_sync_clock.rpc(elapsed_time, goblins_killed)


@rpc("authority", "reliable")
func _sync_clock(host_time: float, host_kills: int) -> void:
	elapsed_time = host_time
	goblins_killed = host_kills


func _on_server_disconnected() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/lobby.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if is_game_over:
		return

	# Debug-only trigger for testing the end screen without losing all 8 rods.
	# Host only: the end of the game is not a client's call to make.
	if OS.is_debug_build() and event.keycode == KEY_K and Net.is_authority():
		trigger_game_over()


func register_goblin_kill() -> void:
	goblins_killed += 1


# ─────────────────────────────────────────────
# ROD STATE
#
# Only the host mutates these - every caller (creature.gd) runs its AI on the
# host alone. Clients receive the resulting totals and just redraw their HUD.
# ─────────────────────────────────────────────

# Call when a goblin reaches a rod and grabs it (e.g. on collision with the rod).
func steal_rod() -> void:
	if not Net.is_authority():
		return
	if rods_in_reactor <= 0:
		return
	rods_in_reactor -= 1
	rods_stolen += 1
	_broadcast_rods()


# Call when a goblin carrying a stolen rod is killed before escaping.
# The rod is recovered and returned to the reactor.
func recover_rod() -> void:
	if not Net.is_authority():
		return
	if rods_stolen <= 0:
		return
	rods_stolen -= 1
	rods_in_reactor += 1
	_broadcast_rods()


# Call when a goblin carrying a stolen rod escapes (reaches its spawn/exit).
# The rod is lost permanently.
func lose_rod() -> void:
	if not Net.is_authority():
		return
	if rods_stolen <= 0:
		return
	rods_stolen -= 1
	rods_lost += 1
	_broadcast_rods()

	if rods_lost >= TOTAL_RODS:
		_on_all_rods_lost()


func _broadcast_rods() -> void:
	rods_changed.emit()
	if Net.is_online():
		_sync_rods.rpc(rods_in_reactor, rods_stolen, rods_lost)


@rpc("authority", "reliable")
func _sync_rods(in_reactor: int, stolen: int, lost: int) -> void:
	rods_in_reactor = in_reactor
	rods_stolen = stolen
	rods_lost = lost
	rods_changed.emit()


func _on_all_rods_lost() -> void:
	# All rods have been stolen and lost - the players lose the game.
	trigger_game_over()


## Host only. Ends the game for everyone at once.
func trigger_game_over() -> void:
	if is_game_over or not Net.is_authority():
		return

	if Net.is_online():
		_show_end_screen.rpc(elapsed_time, goblins_killed)
	else:
		_show_end_screen(elapsed_time, goblins_killed)


@rpc("authority", "call_local", "reliable")
func _show_end_screen(time_survived: float, kills: int) -> void:
	if is_game_over:
		return
	is_game_over = true

	var end_screen: Control = EndScreenScene.instantiate()
	add_child(end_screen)
	end_screen.show_results(time_survived, kills)

	MenuMusic.play_music()

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
