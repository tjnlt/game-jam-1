# WeaponPickup.gd
class_name WeaponPickup
extends RigidBody3D

@export var weapon_data: WeaponData

# This function allows a thrown weapon to pass its current data (like ammo count)
# to the pickup object that gets spawned.
func set_weapon_data(data: WeaponData) -> void:
	weapon_data = data
