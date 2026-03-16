# audio_manager.gd
# Centralized audio system
# Autoload: AudioManager

extends Node

const SFX_POOL_SIZE = 8

var sounds: Dictionary = {}
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_pool_index: int = 0
var terrain_player: AudioStreamPlayer = null
var current_terrain_sound: String = ""

func _ready():
	_create_sfx_pool()
	_create_terrain_player()

func _create_sfx_pool():
	for i in range(SFX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		add_child(player)
		sfx_pool.append(player)

func _create_terrain_player():
	terrain_player = AudioStreamPlayer.new()
	terrain_player.volume_db = linear_to_db(0.5)
	add_child(terrain_player)

func play(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0):
	var sound = sounds.get(sound_name)
	if not sound:
		# Placeholder - just print for now
		print("[SFX] ", sound_name)
		return

	var player = sfx_pool[sfx_pool_index]
	sfx_pool_index = (sfx_pool_index + 1) % SFX_POOL_SIZE

	player.stop()
	player.stream = sound
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()

func play_varied(sound_name: String, pitch_variance: float = 0.1, volume_db: float = 0.0):
	var pitch = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	play(sound_name, volume_db, pitch)

func play_terrain(terrain_name: String):
	if terrain_name == current_terrain_sound:
		return
	current_terrain_sound = terrain_name
	# Would load and play terrain loop here
	print("[Terrain] ", terrain_name)

func stop_terrain():
	terrain_player.stop()
	current_terrain_sound = ""

func set_master_volume(value: float):
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(value, 0.0, 1.0)))

func set_sfx_volume(value: float):
	var idx = AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(value, 0.0, 1.0)))

func set_music_volume(value: float):
	var idx = AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(value, 0.0, 1.0)))
