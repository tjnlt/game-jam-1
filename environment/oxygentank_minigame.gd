extends Control

signal minigame_success

@export var spins_required: float = 6.0
@export var concurrent_holes_min: int = 2
@export var concurrent_holes_max: int = 3
@export var total_holes_min: int = 7
@export var total_holes_max: int = 9
@export var hole_size: Vector2 = Vector2(40, 40)
@export var panel_margin: float = 20.0

@onready var panel: Panel = $Panel
@onready var wheel: Control = $Panel/Wheel
@onready var fill_bar: ProgressBar = $Panel/FillBar
@onready var seal_button: Button = $Panel/SealButton

var hole_style: StyleBoxFlat
var bandage_style: StyleBoxFlat

var active_holes: Array[Button] = []
var reserved_rects: Array[Rect2] = []
var total_target: int = 0
var sealed_count: int = 0
var concurrent_target: int = 0

var wheel_active: bool = false
var dragging_wheel: bool = false
var last_angle: float = 0.0
var accumulated_radians: float = 0.0

func _ready() -> void:
	_build_styles()

	wheel.visible = false
	fill_bar.visible = false
	seal_button.visible = false
	fill_bar.min_value = 0.0
	fill_bar.max_value = 100.0
	fill_bar.value = 0.0
	seal_button.disabled = true

	seal_button.pressed.connect(_on_seal_pressed)
	wheel.gui_input.connect(_on_wheel_input)

	reserved_rects = [fill_bar.get_rect(), wheel.get_rect(), seal_button.get_rect()]

	total_target = randi_range(total_holes_min, total_holes_max)
	concurrent_target = randi_range(concurrent_holes_min, concurrent_holes_max)

	for i in concurrent_target:
		_spawn_hole()

func _build_styles() -> void:
	hole_style = StyleBoxFlat.new()
	hole_style.bg_color = Color(0.05, 0.05, 0.05, 1)
	hole_style.set_corner_radius_all(20)

	bandage_style = StyleBoxFlat.new()
	bandage_style.bg_color = Color(0.75, 0.1, 0.1, 1)
	bandage_style.set_corner_radius_all(22)
	bandage_style.set_border_width_all(3)
	bandage_style.border_color = Color(0.4, 0.05, 0.05, 1)

func _spawn_hole() -> void:
	var rect: Rect2 = _find_free_rect()

	var hole: Button = Button.new()
	hole.position = rect.position
	hole.size = rect.size
	hole.add_theme_stylebox_override("normal", hole_style)
	hole.add_theme_stylebox_override("hover", hole_style)
	hole.add_theme_stylebox_override("pressed", hole_style)
	hole.text = ""
	panel.add_child(hole)

	hole.pressed.connect(_on_hole_pressed.bind(hole))
	active_holes.append(hole)
	reserved_rects.append(rect)

func _find_free_rect() -> Rect2:
	var panel_size: Vector2 = panel.size
	for attempt in 200:
		var pos := Vector2(
			randf_range(panel_margin, panel_size.x - panel_margin - hole_size.x),
			randf_range(panel_margin, panel_size.y - panel_margin - hole_size.y)
		)
		var candidate := Rect2(pos, hole_size)
		var overlaps := false
		for r in reserved_rects:
			if candidate.grow(6.0).intersects(r):
				overlaps = true
				break
		if not overlaps:
			return candidate
	return Rect2(Vector2(panel_margin, panel_margin), hole_size)

func _on_hole_pressed(hole: Button) -> void:
	sealed_count += 1
	active_holes.erase(hole)

	var bandage: Panel = Panel.new()
	bandage.position = hole.position
	bandage.size = hole.size
	bandage.add_theme_stylebox_override("panel", bandage_style)
	panel.add_child(bandage)
	hole.queue_free()

	if sealed_count >= total_target:
		_begin_seal_phase()
	else:
		_spawn_hole()

func _begin_seal_phase() -> void:
	wheel_active = true
	wheel.visible = true
	fill_bar.visible = true
	seal_button.visible = true

func _on_wheel_input(event: InputEvent) -> void:
	if not wheel_active:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging_wheel = event.pressed
		if event.pressed:
			last_angle = (event.position - wheel.size / 2.0).angle()

	elif event is InputEventMouseMotion and dragging_wheel:
		var current_angle: float = (event.position - wheel.size / 2.0).angle()
		var delta_angle: float = wrapf(current_angle - last_angle, -PI, PI)
		accumulated_radians += abs(delta_angle)
		last_angle = current_angle
		wheel.rotation += delta_angle

		fill_bar.value = clampf((accumulated_radians / (TAU * spins_required)) * 100.0, 0.0, 100.0)
		seal_button.disabled = fill_bar.value < 100.0

func _on_seal_pressed() -> void:
	minigame_success.emit()
	queue_free()
