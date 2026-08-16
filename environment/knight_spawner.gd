extends Node3D


# ─────────────────────────────────────────────
# SETTINGS
# ─────────────────────────────────────────────

@export var knight_scene: PackedScene

@export var spawn_points: Node3D

@export var starting_spawn_interval: float = 4.0

@export var minimum_spawn_interval: float = 0.10

@export var difficulty_step_time: float = 15.0

@export_range(0.1, 1.0, 0.05)
var spawn_interval_multiplier: float = 0.80

@export var maximum_knights: int = 1000


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

	if knight_scene == null:

		push_error(
			"KnightSpawner: Knight Scene is missing."
		)

		return


	if spawn_points == null:

		push_error(
			"KnightSpawner: SpawnPoints is missing."
		)

		return


	if spawn_points.get_child_count() == 0:

		push_error(
			"KnightSpawner: SpawnPoints has no children."
		)

		return


	print("================================")

	print("KNIGHT SPAWNER WORKING")

	print(
		"Knight scene: ",
		knight_scene
	)

	print(
		"Spawn points: ",
		spawn_points.get_child_count()
	)

	print("Spawning first knight NOW.")

	print("================================")


	# Spawn one immediately.
	spawn_knight()

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
			"Next knight in: ",
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

		spawn_knight()


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
# SPAWN KNIGHT
# ─────────────────────────────────────────────

func spawn_knight() -> void:

	print("spawn_knight() CALLED")


	# ─────────────────────────────────────────
	# CHECK KNIGHT SCENE
	# ─────────────────────────────────────────

	if knight_scene == null:

		push_error(
			"KnightSpawner: Knight Scene is null."
		)

		return


	# ─────────────────────────────────────────
	# CHECK SPAWN POINTS
	# ─────────────────────────────────────────

	if spawn_points == null:

		push_error(
			"KnightSpawner: SpawnPoints is null."
		)

		return


	# ─────────────────────────────────────────
	# KNIGHT CAP
	# ─────────────────────────────────────────

	var existing_knights: int = (
		get_tree()
		.get_nodes_in_group("enemies")
		.size()
	)


	if (
		maximum_knights > 0
		and existing_knights >= maximum_knights
	):

		print(
			"Knight cap reached: ",
			existing_knights
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
			"KnightSpawner: No valid 3D spawn points."
		)

		return


	# ─────────────────────────────────────────
	# CHOOSE RANDOM POINT
	# ─────────────────────────────────────────

	var spawn_point: Node3D = (
		available_spawn_points.pick_random()
	)


	# ─────────────────────────────────────────
	# CREATE KNIGHT
	# ─────────────────────────────────────────

	var new_knight: Node = (
		knight_scene.instantiate()
	)


	if not (new_knight is Node3D):

		push_error(
			"KnightSpawner: Knight root is not Node3D."
		)

		new_knight.queue_free()

		return


	var knight_3d: Node3D = (
		new_knight as Node3D
	)


	# ─────────────────────────────────────────
	# ADD KNIGHT
	# ─────────────────────────────────────────

	get_tree().current_scene.add_child(
		knight_3d
	)


	knight_3d.global_position = (
		spawn_point.global_position
	)


	print(
		"KNIGHT SPAWNED at ",
		spawn_point.name,
		" | Active knights: ",
		existing_knights + 1
	)


# ─────────────────────────────────────────────
# STOP SPAWNING
# ─────────────────────────────────────────────

func stop_spawning() -> void:

	spawning_enabled = false
