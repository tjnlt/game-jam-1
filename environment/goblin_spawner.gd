extends Node3D


# ─────────────────────────────────────────────
# SETTINGS
# ─────────────────────────────────────────────

@export var goblin_scene: PackedScene

@export var starting_spawn_interval: float = 4.0
@export var minimum_spawn_interval: float = 0.10
@export var difficulty_step_time: float = 15.0

@export_range(0.1, 1.0, 0.05)
var spawn_interval_multiplier: float = 0.80

@export var maximum_goblins: int = 1000


# ─────────────────────────────────────────────
# INTERNAL
# ─────────────────────────────────────────────

var elapsed_spawn_time: float = 0.0
var spawning_enabled: bool = true

var spawn_points: Array[Marker3D] = []


# ─────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	randomize()

	print("================================")
	print("STARTING GOBLIN SPAWNER")
	print("================================")

	# Find every Marker3D directly underneath this Spawner.
	for child in get_children():
		if child is Marker3D:
			spawn_points.append(child as Marker3D)

	print("Found spawn points: ", spawn_points.size())

	# Make sure goblin scene is assigned.
	if goblin_scene == null:
		push_error(
			"GoblinSpawner: Goblin Scene is NOT assigned. " +
			"Select Spawner and drag goblin.tscn into Goblin Scene."
		)
		return

	# Make sure we actually found markers.
	if spawn_points.is_empty():
		push_error(
			"GoblinSpawner: No Marker3D spawn points found."
		)
		return

	print("Goblin scene: ", goblin_scene)

	# Wait one frame so the rest of the level finishes loading.
	await get_tree().process_frame

	print("Spawning first goblin...")

	spawn_goblin()

	# Start continuous spawning.
	spawn_loop()


# ─────────────────────────────────────────────
# SPAWN LOOP
# ─────────────────────────────────────────────

func spawn_loop() -> void:
	while spawning_enabled:

		var wait_time := get_current_spawn_interval()

		print("Next goblin in ", wait_time, " seconds")

		await get_tree().create_timer(wait_time).timeout

		if not is_inside_tree():
			return

		if not spawning_enabled:
			return

		elapsed_spawn_time += wait_time

		spawn_goblin()


# ─────────────────────────────────────────────
# SPAWN INTERVAL
# ─────────────────────────────────────────────

func get_current_spawn_interval() -> float:

	if difficulty_step_time <= 0.0:
		return minimum_spawn_interval

	var difficulty_steps := int(
		elapsed_spawn_time / difficulty_step_time
	)

	var new_interval := (
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

	if goblin_scene == null:
		push_error("Goblin scene is null.")
		return

	if spawn_points.is_empty():
		push_error("No spawn points available.")
		return


	# Count existing goblins.
	var existing_goblins := (
		get_tree()
		.get_nodes_in_group("enemies")
		.size()
	)


	# Stop if we've hit the cap.
	if (
		maximum_goblins > 0
		and existing_goblins >= maximum_goblins
	):
		print("Goblin cap reached.")
		return


	# Pick random Marker3D.
	var spawn_point: Marker3D = spawn_points.pick_random()

	print(
		"Selected spawn point: ",
		spawn_point.name,
		" at ",
		spawn_point.global_position
	)


	# Create goblin.
	var goblin := goblin_scene.instantiate()


	# Make sure its root is 3D.
	if not goblin is Node3D:
		push_error(
			"GoblinSpawner: goblin.tscn root must be Node3D."
		)

		goblin.queue_free()
		return


	var goblin_3d := goblin as Node3D


	# Add it to the main scene.
	get_tree().current_scene.add_child(goblin_3d)


	# Put it EXACTLY on the Marker3D.
	goblin_3d.global_position = spawn_point.global_position


	# Ensure the spawner can count it.
	if not goblin_3d.is_in_group("enemies"):
		goblin_3d.add_to_group("enemies")


	print(
		"GOBLIN SPAWNED SUCCESSFULLY!"
	)

	print(
		"Position: ",
		goblin_3d.global_position
	)

	print(
		"Spawn point: ",
		spawn_point.name
	)

	print(
		"Total goblins: ",
		existing_goblins + 1
	)

	print("--------------------------------")


# ─────────────────────────────────────────────
# STOP SPAWNER
# ─────────────────────────────────────────────

func stop_spawning() -> void:
	spawning_enabled = false
