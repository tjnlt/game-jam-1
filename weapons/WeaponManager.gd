class_name WeaponManager
extends Node3D

@export var weapon_data_array: Array[WeaponData]

@export var shooter_body: Node3D

var current_weapon_index: int = -1
var current_weapon_instance:  Node3D
var weapon_instances: Array[Node3D] = []

var weapons_initialized: bool = false

func _ready() -> void:
	_initialize_all_weapons.call_deferred()
	
	if not weapon_data_array.is_empty():
		switch_weapon.call_deferred(0)
	else:
		print("WeaponManager: No Weapon data assigned.")

func _initialize_all_weapons() -> void:
	if weapons_initialized:
		return
	for child in get_children():
		child.queue_free()
	weapon_instances.clear()

	# Godot loads revolver.tres once and hands the same object to every player
	# body on this machine, so without copies all players would share one
	# magazine. Ammo lives on WeaponData, so each manager gets its own.
	var own_copies: Array[WeaponData] = []
	for weapon_data in weapon_data_array:
		own_copies.append(weapon_data.duplicate() if weapon_data else null)
	weapon_data_array = own_copies

	for weapon_data in weapon_data_array:
		if weapon_data and weapon_data.weapon_equipped_scene:
			var weapon_instance = weapon_data.weapon_equipped_scene.instantiate()
			weapon_instance.shooter_body = shooter_body
			weapon_instance.deal_damage.connect(_on_weapon_deal_damage)

			if weapon_instance.has_method("set_weapon_data"):
				weapon_instance.set_weapon_data(weapon_data)
				
			add_child(weapon_instance)
			weapon_instance.visible = false
			weapon_instance.set_process_mode(Node.PROCESS_MODE_DISABLED)
			
			weapon_instances.append(weapon_instance)
		else:
			weapon_instances.append(null)
			printerr("WeaponManager: Invalid WeaponData or missing weapon_equipped_scene.")
	weapons_initialized = true
	
func switch_weapon(index: int) -> void:
	if not weapons_initialized or index < 0 or index >= weapon_instances.size():
		return
		
	if current_weapon_instance:
		current_weapon_instance.visible = false
		current_weapon_instance.set_process_mode(Node.PROCESS_MODE_DISABLED)
		
	current_weapon_instance = weapon_instances[index]
	current_weapon_index = index
	
	if current_weapon_instance:
		current_weapon_instance.visible = true
		current_weapon_instance.set_process_mode(Node.PROCESS_MODE_INHERIT)
		print("WeaponManager: Switched to weapon %s" % current_weapon_instance.name)
	else:
		printerr("WeaponManager: Weapon instance at index %d is null." % index)
		
func switch_to_next_weapon() -> void:
	if weapon_data_array.size() <= 1:
		return
	var new_index = current_weapon_index + 1
	if new_index >= weapon_data_array.size():
		new_index = 0
	switch_weapon(new_index)
	
func switch_to_previous_weapon() -> void:
	if weapon_data_array.size() <= 1:
		return
	var new_index = current_weapon_index - 1
	if new_index < 0:
		new_index = weapon_data_array.size() - 1
	switch_weapon(new_index)
	
	
	
func attack() -> void:
	if current_weapon_instance and current_weapon_instance.has_method("attack"):
		current_weapon_instance.attack()
	
## Every peer simulates each shot so everyone sees the impact, but only the host
## applies damage (same rule as gun/bullet.gd) so one shot can't hit four times.
## The ray hits a goblin's HurtBox, and take_damage lives on its parent.
func _on_weapon_deal_damage(damage_amount: int, _hit_point: Vector3, _hit_normal: Vector3, collider: Object) -> void:
	if not Net.is_authority():
		return
	if collider.has_method("take_damage"):
		collider.take_damage(damage_amount)
	elif collider is Node and collider.get_parent() and collider.get_parent().has_method("take_damage"):
		collider.get_parent().take_damage(damage_amount)

func reload_current_weapon() -> void:
	if current_weapon_instance and current_weapon_instance.has_method("manual_reload"):
		current_weapon_instance.manual_reload()
		
func throw_current_weapon(throw_force: Vector3 = Vector3.ZERO) -> bool:
	if not current_weapon_instance:
		return false
	
	# Get the data from the weapon we're about to throw.
	var weapon_data = weapon_data_array[current_weapon_index]
	
	if weapon_data and weapon_data.weapon_pickup_scene:
		# Instantiate the pickup/world scene for the weapon.
		var weapon_pickup = weapon_data.weapon_pickup_scene.instantiate()
		# Add it to the main game world, not as a child of the player.
		# current_scene rather than root, so it goes away when the level changes.
		get_tree().current_scene.add_child(weapon_pickup)
		weapon_pickup.global_position = current_weapon_instance.global_position
		
		# IMPORTANT: Copy the current weapon's data (including ammo state) to the pickup.
		if weapon_pickup.has_method("set_weapon_data"):
			weapon_pickup.set_weapon_data(weapon_data)
		
		# If it's a RigidBody3D, give it a shove.
		if weapon_pickup is RigidBody3D and throw_force != Vector3.ZERO:
			weapon_pickup.apply_central_impulse(throw_force)
		
		# Now, permanently remove the weapon from our inventory.
		remove_current_weapon()
		return true
	return false
	
	
func get_throw_direction(throw_strength: float = 7.5) -> Vector3:
	# We'll use the camera's forward direction to aim the throw.
	var camera = get_viewport().get_camera_3d()
	if camera:
		return -camera.global_transform.basis.z * throw_strength
	return Vector3.ZERO

func remove_current_weapon() -> void:
	if current_weapon_index == -1:
		return
	
	# Remove the data and the instance. Keeping these arrays in sync is critical!
	weapon_data_array.remove_at(current_weapon_index)
	weapon_instances.remove_at(current_weapon_index)
	current_weapon_instance.queue_free()
	
	# Reset the current weapon and switch to the next available one.
	current_weapon_instance = null
	current_weapon_index = -1
	
	if not weapon_data_array.is_empty():
		switch_weapon(0)
# This function adds a new weapon to our inventory.
# It will be called by our interaction system in a future tutorial.
func pickup_weapon(new_weapon_data: WeaponData) -> bool:
	if not new_weapon_data:
		return false

	# First, check if we already have this type of weapon.
	for i in range(weapon_data_array.size()):
		if weapon_data_array[i].weapon_name == new_weapon_data.weapon_name:
			# If we do, just take its ammo instead of picking up a duplicate weapon.
			var existing_data = weapon_data_array[i]
			if existing_data.uses_ammo:
				existing_data.total_ammo += new_weapon_data.current_magazine_ammo + new_weapon_data.total_ammo
				existing_data.total_ammo = min(existing_data.total_ammo, existing_data.max_total_ammo)
				print("Added ammo to %s" % existing_data.weapon_name)
				return true # Indicate success
			else:
				return false # Can't pick up duplicate melee weapon

	# If it's a new weapon, add it to our inventory.
	weapon_data_array.append(new_weapon_data)

	# Now, instantiate it and add it to our pool of weapon instances, just like in _initialize_all_weapons.
	if new_weapon_data.weapon_equipped_scene:
		var weapon_instance = new_weapon_data.weapon_equipped_scene.instantiate()
		if weapon_instance.has_method("set_weapon_data"):
			weapon_instance.set_weapon_data(new_weapon_data)

		weapon_instance.shooter_body = shooter_body
		weapon_instance.deal_damage.connect(_on_weapon_deal_damage)

		add_child(weapon_instance)
		weapon_instance.visible = false
		weapon_instance.set_process_mode(Node.PROCESS_MODE_DISABLED)
		weapon_instances.append(weapon_instance)
		
		# Switch to the new weapon we just picked up.
		switch_weapon(weapon_instances.size() - 1)
		return true
	else:
		weapon_instances.append(null) # Keep arrays in sync
		return false
		
