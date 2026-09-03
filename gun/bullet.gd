extends CharacterBody3D

@export var speed := 100.0
@export var lifetime := 1.0
@export var damage := 1

func _ready():
	add_to_group("bullet")
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	var direction = -global_transform.basis.z
	var collision = move_and_collide(direction * speed * delta)

	if collision:
		var collider = collision.get_collider()
		print("bullet hit: ", collider.name if collider else "null")
		# Every peer flies its own copy of this bullet so the tracer looks right
		# locally, but only the host resolves the hit - otherwise four peers
		# would each apply the same damage to the same creature.
		if Net.is_authority():
			if collider.has_method("take_damage"):
				collider.take_damage(damage)
			elif collider.get_parent() and collider.get_parent().has_method("take_damage"):
				collider.get_parent().take_damage(damage)
		queue_free()
