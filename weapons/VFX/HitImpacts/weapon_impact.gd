# weapon_impact.gd
class_name WeaponImpact
extends Resource

# The scene to spawn on impact (e.g., a dust puff or blood splatter)
@export var impact_scene: PackedScene

# The group the hit object must belong to for this impact to be used.
# If left empty, this is treated as the "default" impact.
@export var group_name: String = ""
