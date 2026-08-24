extends Node3D


# ------------------------------
# DOOR MOVEMENT
# ------------------------------

@export var closed_offset: Vector3 = Vector3(0, -10, 0)
@export var movement_time: float = 0.5


# ------------------------------
# NAVIGATION
# ------------------------------

# Assign this door's NavigationLink3D here.
@export var navigation_link: NavigationLink3D


# ------------------------------
# INTERNAL
# ------------------------------

var open_position: Vector3
var closed_position: Vector3

var is_closed: bool = false
var current_tween: Tween


func _ready() -> void:
	open_position = position
	closed_position = open_position + closed_offset

	# Door starts open, so navigation through this doorway is allowed.
	if navigation_link:
		navigation_link.enabled = true


func close_door() -> void:
	if is_closed:
		return

	is_closed = true

	# Disable the link immediately so enemies stop choosing this door.
	if navigation_link:
		navigation_link.enabled = false

	_refresh_enemy_navigation_after_change()

	if current_tween:
		current_tween.kill()

	current_tween = create_tween()

	current_tween.tween_property(
		self,
		"position",
		closed_position,
		movement_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func open_door() -> void:
	if not is_closed:
		return

	is_closed = false

	if current_tween:
		current_tween.kill()

	current_tween = create_tween()

	current_tween.tween_property(
		self,
		"position",
		open_position,
		movement_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# Wait until the door is physically open before enabling the link.
	await current_tween.finished

	if navigation_link:
		navigation_link.enabled = true

	_refresh_enemy_navigation_after_change()


func _refresh_enemy_navigation_after_change() -> void:
	# Give NavigationServer one physics frame to register
	# the NavigationLink3D enable/disable change.
	await get_tree().physics_frame

	get_tree().call_group(
		"enemies",
		"refresh_navigation"
	)
