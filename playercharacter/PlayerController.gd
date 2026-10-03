extends CharacterBody3D

@export_group("Components")
@export var weapons_manager: WeaponManager

## Minigames (generator, oxygen tank) flip these off while their UI is open.
@export var can_move: bool = true
@export var can_shoot: bool = true

@export var walk_speed = 5.0
@export var crouch_speed = 2.5
@export var sprint_speed = 8.0
@export var jump_strength = 5.0
@export var gravity = 9.8

@export var mouse_sensitivity = 0.002
@export var base_fov = 75.0
@export var sprint_fov = 95.0

@onready var uncrouch_check = $UncrouchCheck
var is_crouching = false
var crouch_depth = -0.6
# The body's origin sits at its feet so it lines up with the level's spawn
# points, which is 1.0 lower than in the sandbox - hence 2.2 instead of 1.2.
var stand_height = 2.2
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var hud: CanvasLayer = $HUD

var mouse_captured: bool = false


## MULTIPLAYER
## Net.begin_level names each body after the peer id that owns it, so the name
## decides who drives this controller.
func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())


func handle_crouch(delta):
	if can_move and Input.is_action_just_pressed("crouch"):
		if is_crouching and uncrouch_check.is_colliding():
			return
		is_crouching = !is_crouching
	var target_height = stand_height + crouch_depth if is_crouching else stand_height
	head.position.y = lerp(head.position.y, target_height, delta * 10.0)

func _ready():
	add_to_group("player")
	_setup_synchronizer()

	# Only the owner simulates its body. Other players' bodies are just visuals
	# moved by the synchronizer: no input, no physics, no camera, and no HUD
	# (a CanvasLayer draws over every screen, not just its owner's).
	var mine := is_multiplayer_authority()
	camera.current = mine
	hud.visible = mine
	hud.process_mode = Node.PROCESS_MODE_INHERIT if mine else Node.PROCESS_MODE_DISABLED
	set_physics_process(mine)
	set_process_unhandled_input(mine)

	if mine:
		capture_mouse()


## Sends this body's movement and look direction to the other peers.
func _setup_synchronizer() -> void:
	if not Net.is_online():
		return

	var config := SceneReplicationConfig.new()

	# Head:position carries crouching, Head:rotation carries looking up/down.
	for path in [".:position", ".:rotation", "Head:rotation", "Head:position"]:
		var property := NodePath(path)
		config.add_property(property)
		config.property_set_replication_mode(
			property, SceneReplicationConfig.REPLICATION_MODE_ALWAYS
		)

	var sync := MultiplayerSynchronizer.new()
	sync.name = "NetSync"
	sync.replication_config = config
	sync.replication_interval = 1.0 / 30.0
	sync.set_multiplayer_authority(get_multiplayer_authority())
	add_child(sync)


# _unhandled_input instead of _input so clicks on minigame UI never reach the gun.
func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		release_mouse()
		return

	if not mouse_captured:
		# The first click just grabs the mouse back; it doesn't fire.
		if can_move and event is InputEventMouseButton and event.pressed:
			capture_mouse()
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)

		head.rotate_x(-event.relative.y * mouse_sensitivity)

		head.rotation.x = clamp(head.rotation.x, -PI/2, PI/2)

	if weapons_manager and can_shoot:
		# Weapon actions go through RPCs so every peer plays the same shot,
		# recoil and impact on their copy of this player.
		if event.is_action_pressed("fire"):
			_fire.rpc()
		if event.is_action_pressed("reload"):
			_reload.rpc()

		if event.is_action_pressed("weapon_scroll_up"):
			_switch_weapon.rpc(1)
		elif event.is_action_pressed("weapon_scroll_down"):
			_switch_weapon.rpc(-1)
		if event.is_action_pressed("throw_weapon"):
			# Worked out here because only the owner's camera is the one aiming.
			var throw_force = weapons_manager.get_throw_direction()
			_throw_weapon.rpc(throw_force)

func _physics_process(delta):
	handle_crouch(delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	if can_move and Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = jump_strength

	var is_sprinting = can_move and Input.is_action_pressed("sprint") and is_on_floor()

	if is_sprinting:
		camera.fov = lerp(camera.fov, sprint_fov, delta * 10.0)
	else:
		camera.fov = lerp(camera.fov, base_fov, delta * 10.0)

	var input_dir = Vector2.ZERO
	if can_move:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	var direction = (transform.basis * Vector3(input_dir.x,0,input_dir.y)).normalized()

	var target_speed = walk_speed
	if is_crouching:
		target_speed = crouch_speed
	elif is_sprinting:
		target_speed = sprint_speed

	velocity.x = direction.x * target_speed
	velocity.z = direction.z * target_speed

	move_and_slide()


## WEAPON RPCs
## Each runs on every peer (call_local includes ourselves). Only the host's copy
## of a shot deals damage - see WeaponManager._on_weapon_deal_damage.

@rpc("any_peer", "call_local", "reliable")
func _fire() -> void:
	if _sent_by_owner():
		weapons_manager.attack()

@rpc("any_peer", "call_local", "reliable")
func _reload() -> void:
	if _sent_by_owner():
		weapons_manager.reload_current_weapon()

@rpc("any_peer", "call_local", "reliable")
func _switch_weapon(step: int) -> void:
	if not _sent_by_owner():
		return
	if step > 0:
		weapons_manager.switch_to_next_weapon()
	else:
		weapons_manager.switch_to_previous_weapon()

@rpc("any_peer", "call_local", "reliable")
func _throw_weapon(throw_force: Vector3) -> void:
	if _sent_by_owner():
		weapons_manager.throw_current_weapon(throw_force)

## A peer may only trigger actions on the body it owns.
func _sent_by_owner() -> bool:
	var sender := multiplayer.get_remote_sender_id()
	return sender == 0 or sender == get_multiplayer_authority()


func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false
