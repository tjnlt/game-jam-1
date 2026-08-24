extends Control

const CHARGED_TEX  := preload("res://ui/textures/charged_rod.svg")
const STOLEN_TEX   := preload("res://ui/textures/stolen_rod.svg")
const LOST_TEX     := preload("res://ui/textures/bw_rod.svg")
const BULB_TEX     := preload("res://ui/textures/bulb.svg")
const OUT_BULB_TEX := preload("res://ui/textures/out_bulb.svg")
const GEN_TEX      := preload("res://ui/textures/generator.svg")
const OUT_GEN_TEX  := preload("res://ui/textures/out_generator.svg")

@onready var rod_slots: Array[TextureRect] = [
	$HBoxContainer/Rod1, $HBoxContainer/Rod2, $HBoxContainer/Rod3, $HBoxContainer/Rod4,
	$HBoxContainer/Rod5, $HBoxContainer/Rod6, $HBoxContainer/Rod7, $HBoxContainer/Rod8,
]
@onready var bulb_icon: TextureRect = $HBoxContainer/Bulb
@onready var gen_icon: TextureRect  = $HBoxContainer/Generator

var environment: Node


func _ready() -> void:
	# Set default textures immediately — no waiting
	bulb_icon.texture = BULB_TEX
	gen_icon.texture  = GEN_TEX

	await get_tree().process_frame

	environment = get_tree().get_first_node_in_group("environment")
	if environment == null:
		push_warning("rod_display: no node in group 'environment' found.")
		return
	environment.rods_changed.connect(_update_display)
	_update_display()

	var generator := get_tree().get_first_node_in_group("generator")
	if generator:
		generator.state_changed.connect(_on_generator_changed)
		_on_generator_changed(generator.is_broken)
	else:
		push_warning("rod_display: no node in group 'generator' found.")

	var oxygentank := get_tree().get_first_node_in_group("oxygentank")
	if oxygentank:
		oxygentank.state_changed.connect(_on_oxygentank_changed)
		_on_oxygentank_changed(oxygentank.is_leaking)
	else:
		push_warning("rod_display: no node in group 'oxygentank' found.")


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


func _on_generator_changed(is_broken: bool) -> void:
	gen_icon.texture = OUT_GEN_TEX if is_broken else GEN_TEX


func _on_oxygentank_changed(is_leaking: bool) -> void:
	bulb_icon.texture = OUT_BULB_TEX if is_leaking else BULB_TEX
