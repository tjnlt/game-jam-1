# WeaponEquipped.gd
class_name WeaponEquipped
extends Node3D

# This signal will be sent up to the WeaponManager when we hit something.
signal deal_damage(damage_amount: int, hit_point: Vector3, hit_normal: Vector3, collider: Object)

signal reload_started()
signal ammo_changed(current_magazine: int, total_ammo: int)
signal reload_finished()

var _original_model_position: Vector3
var _original_model_rotation: Vector3

# This will hold the data resource for the specific weapon (e.g, revolver.tres)
var weapon_data: WeaponData
var reload_timer: Timer

# We'll export node paths so we can link them easily in the editor.
@export var weapon_model: Node3D # The visual part of the weapon that will move.
@export var fire_ray: RayCast3D  # The raycast that determines where we hit.

# This variable will be set by the WeaponManager so we know who is shooting.
@export var shooter_body: CharacterBody3D


func _process(delta: float) -> void:
	if not weapon_model or not weapon_data:
		return
	
	weapon_model.position = weapon_model.position.lerp(_original_model_position, weapon_data.recovery_speed * delta)
	weapon_model.rotation = weapon_model.rotation.lerp(_original_model_rotation, weapon_data.recovery_speed * delta)

func _ready() -> void:
	if weapon_model:
		_original_model_position = weapon_model.position
		_original_model_rotation = weapon_model.rotation
	pass
	


# This function is the crucial link. The WeaponManager will call this
# right after it creates the weapon instance.
func set_weapon_data(data: WeaponData) -> void:
	weapon_data = data
	_initialize_ammo_system()

# This is a "virtual" function. We define it here, but each specific weapon
# script (like our revolver) will provide its own implementation.
func attack() -> void:
	# Base implementation does nothing.
	# The child script (RevolverEquipped.gd) will override this.
	pass


func fire_hitscan() -> void:
	if not can_fire():
		print("Cannot fire: No ammo or reloading!")
		return
	
	consume_ammo()
	
	if not fire_ray:
		printerr("Fire Ray not assigned for ", self.name)
		return
	var space_state = get_world_3d().direct_space_state
	
	var query = PhysicsRayQueryParameters3D.create(
		fire_ray.global_position,
		fire_ray.to_global(fire_ray.get_target_position())
	)
	
	query.exclude = [shooter_body.get_rid()]
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		var hit_point = result.position
		var hit_normal = result.normal
		
		print("Hit: ", collider.name, " at position ", hit_point)
		_spawn_impact_effect(hit_point, hit_normal, collider)
		#var hit_marker = MeshInstance3D.new()
		#var box_mesh = BoxMesh.new()
		#var material = StandardMaterial3D.new()
		#
		#material.albedo_color = Color.RED
		#box_mesh.material = material
		#box_mesh.size = Vector3(0.1, 0.1, 0.1)
		#hit_marker.mesh = box_mesh
		#
		#get_tree().root.add_child(hit_marker)
		#hit_marker.global_position = hit_point
		
		deal_damage.emit(weapon_data.damage, hit_point, hit_normal, collider)
		

func _initialize_ammo_system() -> void:
	if not weapon_data or not weapon_data.uses_ammo:
		return
		
	if weapon_data.total_ammo == 0:
		weapon_data.initialize_ammo()
	
	if not reload_timer:
		reload_timer = Timer.new()
		reload_timer.one_shot = true
		reload_timer.timeout.connect(_on_reload_finished)
		add_child(reload_timer)
	reload_timer.wait_time = weapon_data.reload_time
	
	ammo_changed.emit(weapon_data.current_magazine_ammo, weapon_data.total_ammo)
	
func can_fire() -> bool:
	if not weapon_data: return false
	if not weapon_data.uses_ammo: return true
	return weapon_data.current_magazine_ammo > 0 and not weapon_data.is_reloading
	
func consume_ammo() -> void:
	if not can_fire(): return
	
	weapon_data.current_magazine_ammo -= 1
	ammo_changed.emit(weapon_data.current_magazine_ammo, weapon_data.total_ammo)
	
	if weapon_data.current_magazine_ammo <= 0 and weapon_data.total_ammo > 0:
		start_reload()
		
func start_reload() -> void:
	if not weapon_data or not weapon_data.uses_ammo or weapon_data.is_reloading: return
	if weapon_data.current_magazine_ammo >= weapon_data.max_magazine_capacity: return
	if weapon_data.total_ammo <= 0: return
	
	weapon_data.is_reloading = true
	reload_timer.start()
	reload_started.emit()
	
func _on_reload_finished() -> void:
	var ammo_needed = weapon_data.max_magazine_capacity - weapon_data.current_magazine_ammo
	var ammo_to_transfer = min(ammo_needed, weapon_data.total_ammo)
	
	weapon_data.current_magazine_ammo += ammo_to_transfer
	weapon_data.total_ammo -= ammo_to_transfer
	
	weapon_data.is_reloading = false
	reload_finished.emit()
	ammo_changed.emit(weapon_data.current_magazine_ammo, weapon_data.total_ammo)

func manual_reload() -> void:
	start_reload()
	
func apply_recoil(kickback_amount: float, rotation_kick_degrees: Vector3) -> void:
	if not weapon_model: return
	
	#Apply positional kickback
	weapon_model.position.z += kickback_amount
	
	# Apply rotational kick
	weapon_model.rotate_object_local(Vector3.RIGHT, deg_to_rad(rotation_kick_degrees.x))
	weapon_model.rotate_object_local(Vector3.UP, deg_to_rad(rotation_kick_degrees.y))
	weapon_model.rotate_object_local(Vector3.FORWARD, deg_to_rad(rotation_kick_degrees.z))
		
func _spawn_impact_effect(hit_point: Vector3, hit_normal: Vector3, collider: Object) -> void:
	if not weapon_data or weapon_data.impacts.is_empty():
		return
	var default_impact_scene: PackedScene = null
	var specific_impact_scene: PackedScene = null
	
	for impact_data in weapon_data.impacts:
		if not impact_data: continue
		
		if impact_data.group_name.is_empty():
			default_impact_scene = impact_data.impact_scene
		
		elif collider and collider.is_in_group(impact_data.group_name):
			specific_impact_scene = impact_data.impact_scene
			break
	
	var scene_to_spawn = specific_impact_scene if specific_impact_scene else default_impact_scene
	
	if scene_to_spawn:
		var impact_instance = scene_to_spawn.instantiate()
		get_tree().get_root().add_child(impact_instance)
		
		impact_instance.global_position = hit_point
		
		impact_instance.look_at(hit_point + hit_normal)
