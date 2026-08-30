extends Node3D


# ─────────────────────────────────────────────
# SETTINGS
# ─────────────────────────────────────────────

@export var goblin_scene: PackedScene

@export var spawn_points: Node3D

@export var starting_spawn_interval: float = 4.0

@export var minimum_spawn_interval: float = 0.10

@export var difficulty_step_time: float = 15.0

@export_range(0.1, 1.0, 0.05)
var spawn_interval_multiplier: float = 0.80

@export var maximum_goblins: int = 50

@export var ground_ray_height: float = 10.0

@export var ground_ray_depth: float = 20.0


# ─────────────────────────────────────────────
# INTERNAL
# ─────────────────────────────────────────────

var elapsed_spawn_time: float = 0.0

var spawning_enabled: bool = true


# ─────────────────────────────────────────────
# START
# ─────────────────────────────────────────────

func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS

	randomize()

	# Try to find SpawnPoints automatically
	# if it was not assigned in the Inspector.
	if spawn_points == null:

		spawn_points = (
			get_tree()
			.current_scene
			.find_child(
				"SpawnPoints",
				true,
				false
			) as Node3D
		)


	# ─────────────────────────────────────────
	# CHECK REFERENCES
	# ─────────────────────────────────────────

	if goblin_scene == null:

		push_error(
			"GoblinSpawner: Goblin Scene is missing."
		)

		return


	if spawn_points == null:

		push_error(
			"GoblinSpawner: SpawnPoints is missing."
		)

		return


	if spawn_points.get_child_count() == 0:

		push_error(
			"GoblinSpawner: SpawnPoints has no children."
		)

		return


	print("================================")

	print("GOBLIN SPAWNER WORKING")

	print(
		"Goblin scene: ",
		goblin_scene
	)

	print(
		"Spawn points: ",
		spawn_points.get_child_count()
	)

	print("Spawning first goblin NOW.")

	print("================================")


	# Spawn one immediately.
	spawn_goblin()

	# Start repeating spawns.
	spawn_loop()


# ─────────────────────────────────────────────
# SPAWN LOOP
# ─────────────────────────────────────────────

func spawn_loop() -> void:

	while spawning_enabled:

		var wait_time: float = (
			get_current_spawn_interval()
		)

		print(
			"Next goblin in: ",
			wait_time,
			" seconds"
		)

		await get_tree().create_timer(
			wait_time
		).timeout


		if not is_inside_tree():
			return


		if not spawning_enabled:
			return


		elapsed_spawn_time += wait_time

		spawn_goblin()


# ─────────────────────────────────────────────
# SPAWN SPEED
# ─────────────────────────────────────────────

func get_current_spawn_interval() -> float:

	if difficulty_step_time <= 0.0:
		return minimum_spawn_interval


	var difficulty_steps: int = int(
		elapsed_spawn_time
		/ difficulty_step_time
	)


	var new_interval: float = (
		starting_spawn_interval
		* pow(
			spawn_interval_multiplier,
			difficulty_steps
		)
	)


	return max(
		new_interval,
		minimum_spawn_interval
	)


# ─────────────────────────────────────────────
# SPAWN GOBLIN
# ─────────────────────────────────────────────

func spawn_goblin() -> void:

	print("spawn_goblin() CALLED")


	# ─────────────────────────────────────────
	# CHECK GOBLIN SCENE
	# ─────────────────────────────────────────

	if goblin_scene == null:

		push_error(
			"GoblinSpawner: Goblin Scene is null."
		)

		return


	# ─────────────────────────────────────────
	# CHECK SPAWN POINTS
	# ─────────────────────────────────────────

	if spawn_points == null:

		push_error(
			"GoblinSpawner: SpawnPoints is null."
		)

		return


	# ─────────────────────────────────────────
	# GOBLIN CAP
	# ─────────────────────────────────────────

	var existing_goblins: int = (
		get_tree()
		.get_nodes_in_group("enemies")
		.size()
	)


	if (
		maximum_goblins > 0
		and existing_goblins >= maximum_goblins
	):

		print(
			"Goblin cap reached: ",
			existing_goblins
		)

		return


	# ─────────────────────────────────────────
	# GET SPAWN POINTS
	# ─────────────────────────────────────────

	var available_spawn_points: Array[Node3D] = []


	for child in spawn_points.get_children():

		if child is Node3D:

			available_spawn_points.append(
				child as Node3D
			)


	if available_spawn_points.is_empty():

		push_error(
			"GoblinSpawner: No valid 3D spawn points."
		)

		return


	# ─────────────────────────────────────────
	# CHOOSE RANDOM POINT
	# ─────────────────────────────────────────

	var spawn_point: Node3D = (
		available_spawn_points.pick_random()
	)


	# ─────────────────────────────────────────
	# CREATE GOBLIN
	# ─────────────────────────────────────────

	var new_goblin: Node = (
		goblin_scene.instantiate()
	)


	if not (new_goblin is Node3D):

		push_error(
			"GoblinSpawner: Goblin root is not Node3D."
		)

		new_goblin.queue_free()

		return


	var goblin_3d: Node3D = (
		new_goblin as Node3D
	)


	# ─────────────────────────────────────────
	# ADD GOBLIN
	# ─────────────────────────────────────────

	_place_goblin.call_deferred(
		goblin_3d,
		_get_ground_position(spawn_point.global_position)
	)


	print(
		"GOBLIN SPAWNED at ",
		spawn_point.name,
		" | Active goblins: ",
		existing_goblins + 1
	)


func _place_goblin(goblin_3d: Node3D, ground_position: Vector3) -> void:

	get_tree().current_scene.add_child(
		goblin_3d
	)

	goblin_3d.global_position = ground_position

	# Remember where it came from so it can carry a stolen rod back here.
	if "spawn_position" in goblin_3d:
		goblin_3d.spawn_position = ground_position


# ─────────────────────────────────────────────
# GROUND SNAP
# ─────────────────────────────────────────────

func _get_ground_position(spawn_position: Vector3) -> Vector3:

	var space_state := get_world_3d().direct_space_state

	var query := PhysicsRayQueryParameters3D.create(
		spawn_position + Vector3.UP * ground_ray_height,
		spawn_position + Vector3.DOWN * ground_ray_depth
	)

	var result := space_state.intersect_ray(query)

	if result:
		return result.position

	return spawn_position


# ─────────────────────────────────────────────
# STOP SPAWNING
# ─────────────────────────────────────────────

func stop_spawning() -> void:

	spawning_enabled = false
