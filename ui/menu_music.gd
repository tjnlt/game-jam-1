extends Node

const MUSIC := preload("res://addons/audio/main_menu_music_ambient.wav")

@onready var player: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready() -> void:
	player.stream = MUSIC
	add_child(player)
	player.finished.connect(player.play)


func play_music() -> void:
	if not player.playing:
		player.play()


func stop_music() -> void:
	player.stop()
