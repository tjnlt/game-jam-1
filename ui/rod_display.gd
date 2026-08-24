extends Control

const CHARGED_TEX := preload("res://ui/textures/charged_rod.svg")
const STOLEN_TEX := preload("res://ui/textures/stolen_rod.svg")
const LOST_TEX := preload("res://ui/textures/bw_rod.svg")

@onready var rod_slots: Array[TextureRect] = [
	$HBoxContainer/Rod1, $HBoxContainer/Rod2, $HBoxContainer/Rod3, $HBoxContainer/Rod4,
	$HBoxContainer/Rod5, $HBoxContainer/Rod6, $HBoxContainer/Rod7, $HBoxContainer/Rod8,
]

var environment: Node


func _ready() -> void:
	await get_tree().process_frame

	environment = get_tree().get_first_node_in_group("environment")
	if environment == null:
		push_warning("rod_display: no node in group 'environment' found.")
		return

	environment.rods_changed.connect(_update_display)
	_update_display()


func _update_display() -> void:
	var i := 0

	for n in environment.rods_in_reactor:
		rod_slots[i].texture = CHARGED_TEX
		i += 1

	for n in environment.rods_stolen:
		rod_slots[i].texture = STOLEN_TEX
		i += 1

	for n in environment.rods_lost:
		rod_slots[i].texture = LOST_TEX
		i += 1
