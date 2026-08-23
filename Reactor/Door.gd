extends Node3D

@export var closed_offset: Vector3 = Vector3(0, -10, 0)
@export var movement_time: float = 0.5

var open_position: Vector3
var closed_position: Vector3

var is_closed := false
var current_tween: Tween


func _ready() -> void:
	open_position = position
	closed_position = open_position + closed_offset


func close_door() -> void:
	if is_closed:
		return

	is_closed = true

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
