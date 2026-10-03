extends CharacterBody3D

@export_group("Components")
@export var weapons_manager: WeaponManager

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
var stand_height = 1.2
@onready var head = $Head
@onready var camera = $Head/Camera3D

func handle_crouch(delta):
	if Input.is_action_just_pressed("crouch"):
		if is_crouching and uncrouch_check.is_colliding():
			return
		is_crouching = !is_crouching
	var target_height = stand_height + crouch_depth if is_crouching else stand_height
	head.position.y = lerp(head.position.y, target_height, delta * 10.0)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		head.rotate_x(-event.relative.y * mouse_sensitivity)
	
		head.rotation.x = clamp(head.rotation.x, -PI/2, PI/2)
	if weapons_manager:
		if event.is_action_pressed("fire"):
			weapons_manager.attack()
		if event.is_action_pressed("reload"):
			weapons_manager.reload_current_weapon()
			
		if event.is_action_pressed("weapon_scroll_up"):
			weapons_manager.switch_to_next_weapon()
		elif event.is_action_pressed("weapon_scroll_down"):
			weapons_manager.switch_to_previous_weapon()
		if event.is_action_pressed("throw_weapon"):
			var throw_force = weapons_manager.get_throw_direction()
			weapons_manager.throw_current_weapon(throw_force)
		
func _physics_process(delta):
	handle_crouch(delta)
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = jump_strength
		
	var is_sprinting = Input.is_action_pressed("sprint") and is_on_floor()
	
	if is_sprinting:
		camera.fov = lerp(camera.fov, sprint_fov, delta * 10.0)
	else:
		camera.fov = lerp(camera.fov, base_fov, delta * 10.0)
		
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	var direction = (transform.basis * Vector3(input_dir.x,0,input_dir.y)).normalized()
	
	var target_speed = walk_speed
	if is_crouching:
		target_speed = crouch_speed
	elif is_sprinting:
		target_speed = sprint_speed
	
	velocity.x = direction.x * target_speed
	velocity.z = direction.z * target_speed
	
	move_and_slide()
