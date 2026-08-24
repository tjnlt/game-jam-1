extends Node3D

var home_holder: Node3D = null
var home_transform: Transform3D
var carrier: Node3D = null

func _ready() -> void:
	add_to_group("rods")
	home_holder = get_parent()
	home_transform = transform


# Called when the creature carrying this rod is killed before reaching its
# spawn point - puts the rod back where it started so it can be stolen again.
func return_home() -> void:
	carrier = null

	if home_holder == null:
		return

	reparent(home_holder, false)
	transform = home_transform
	add_to_group("rods")
