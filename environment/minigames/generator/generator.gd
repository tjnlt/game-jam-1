extends Area3D
##
## MULTIPLAYER
## The host owns whether the generator is broken and when it breaks next. The
## minigame itself is local: it opens only for the player who pressed E and
## locks only that player. Finishing it asks the host to mark the generator
## fixed, and the host tells everyone - which is what turns the lights back on
## and closes any minigame another player still had open.
##

signal state_changed(is_broken: bool)

const MINIGAME_SCENE: PackedScene = preload("res://environment/minigames/generator/generator_minigame.tscn")

@export var min_break_seconds: float = 60
@export var max_break_seconds: float = 120

## True only when this peer's own player is at the generator.
var player_in_range: bool = false
var is_broken: bool = false
var active_minigame: Control = null
var break_timer: Timer
var player_ref: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Only the host runs the break schedule; clients are told when it happens.
	if not Net.is_authority():
		return

	break_timer = Timer.new()
	break_timer.one_shot = true
	break_timer.timeout.connect(_break_generator)
	add_child(break_timer)
	_schedule_next_break()

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and is_broken and active_minigame == null and event.is_action_pressed("interact"):
		_open_minigame()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.is_multiplayer_authority():
		player_in_range = true
		player_ref = body

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and body.is_multiplayer_authority():
		player_in_range = false
		player_ref = null

func _schedule_next_break() -> void:
	break_timer.start(randf_range(min_break_seconds, max_break_seconds))

func _break_generator() -> void:
	Net.broadcast(self, &"_set_broken", [true])

# ─────────────────────────────────────────────
# LOCAL MINIGAME
# ─────────────────────────────────────────────

func _open_minigame() -> void:
	active_minigame = MINIGAME_SCENE.instantiate()
	get_tree().current_scene.add_child(active_minigame)
	active_minigame.minigame_success.connect(_on_minigame_success)
	_lock_player()

func _on_minigame_success() -> void:
	# The minigame frees itself once it succeeds.
	active_minigame = null
	_release_player()

	if Net.is_authority():
		Net.broadcast(self, &"_set_broken", [false])
	else:
		_ask_host_to_repair.rpc_id(1)

func _lock_player() -> void:
	if player_ref and is_instance_valid(player_ref):
		player_ref.can_move = false
		player_ref.can_shoot = false
		player_ref.release_mouse()

func _release_player() -> void:
	if player_ref and is_instance_valid(player_ref):
		player_ref.can_move = true
		player_ref.can_shoot = true
		player_ref.capture_mouse()

## Someone else finished the repair first - drop this peer's half-done attempt
## and give the player back their controls.
func _close_minigame() -> void:
	if active_minigame != null and is_instance_valid(active_minigame):
		active_minigame.queue_free()
	active_minigame = null
	_release_player()

# ─────────────────────────────────────────────
# SHARED STATE
# ─────────────────────────────────────────────

@rpc("any_peer", "reliable")
func _ask_host_to_repair() -> void:
	if not Net.is_authority():
		return
	if not is_broken:
		return
	Net.broadcast(self, &"_set_broken", [false])

@rpc("authority", "call_local", "reliable")
func _set_broken(broken: bool) -> void:
	is_broken = broken
	state_changed.emit(broken)

	for light in get_tree().get_nodes_in_group("lights"):
		if broken:
			if light.has_method("TurnOff"):
				light.TurnOff()
		elif light.has_method("TurnOn"):
			light.TurnOn()

	if not broken:
		_close_minigame()
		if Net.is_authority():
			_schedule_next_break()
