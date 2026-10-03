# RevolverEquipped.gd
extends WeaponEquipped

# We will override the base attack function here.
func attack() -> void:
	if not can_fire():
		return
		
		
	fire_hitscan()
	# We will call the hitscan logic here soon.
	
	# After firing, apply recoil
	apply_recoil(weapon_data.recoil_kickback, weapon_data.recoil_rotation_degrees)
