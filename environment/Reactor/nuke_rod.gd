extends Node3D

var home_holder: Node3D = null
var home_transform: Transform3D
var carrier: Node3D = null

## Stable name for this rod across every peer. Rods are ordinary scene nodes, so
## their path in the level is identical everywhere - but it changes once a
## creature carries one off, which is why the path is captured at load and kept.
var rod_id: String = ""


func _ready() -> void:
	add_to_group("rods")
	# "rods" is left while a creature is carrying this rod, so creature.gd
	# cannot use it to find one again. "all_rods" is never left.
	add_to_group("all_rods")
	home_holder = get_parent()
	home_transform = transform
	rod_id = String(get_tree().current_scene.get_path_to(self))


# Called when the creature carrying this rod is killed before reaching its
# spawn point - puts the rod back where it started so it can be stolen again.
func return_home() -> void:
	carrier = null

	if home_holder == null:
		return

	reparent(home_holder, false)
	transform = home_transform
	add_to_group("rods")
