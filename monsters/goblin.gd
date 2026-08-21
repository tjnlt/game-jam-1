extends Node3D


const RUN_SPEED := 3.0
const DANCE_RADIUS := 2.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var player: Node3D
var _dancing := false
var health := 5

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	animation_player.play("local/sneaky_run")

func _physics_process(delta: float) -> void:
	if not player:
		return

	var to_player := player.global_position - global_position
	to_player.y = 0
	var distance := to_player.length()

	if distance <= DANCE_RADIUS:
		if not _dancing:
			_dancing = true
			animation_player.play("local/dance")
		return

	if _dancing:
		_dancing = false
		animation_player.play("local/sneaky_run")

	var direction := to_player.normalized()
	global_position += direction * RUN_SPEED * delta
	look_at(global_position - direction, Vector3.UP)

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()
