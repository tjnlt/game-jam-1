extends CharacterBody3D

@export var speed := 100.0
@export var lifetime := 1.0

func _ready():
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	var direction = -global_transform.basis.z
	var collision = move_and_collide(direction * speed * delta)

	if collision:
		queue_free()
