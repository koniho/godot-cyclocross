# audio_manager.gd
# Centralized audio system with pooling and variations
# Add as Autoload: Project Settings > Autoload > audio_manager.gd as "AudioManager"

extends Node

# Sound effect pools
const SFX_POOL_SIZE = 8
const MUSIC_CROSSFADE_TIME = 1.0

@export var master_volume: float = 1.0
@export var sfx_volume: float = 1.0
@export var music_volume: float = 0.7

# Audio buses (create these in Project Settings > Audio)
const BUS_MASTER = "Master"
const BUS_SFX = "SFX"
const BUS_MUSIC = "Music"

# Preloaded sounds - add paths to your audio files
var sounds: Dictionary = {
	# Rider
	"pedal_tick": [],  # Will hold array of variations
	"hop_launch": null,
	"land_good": null,
	"land_perfect": null,
	"crash": null,
	"dismount": null,
	"mount": null,
	"bonk_start": null,
	"breathing_loop": null,
	
	# Terrain (loops)
	"terrain_grass": null,
	"terrain_mud": null,
	"terrain_sand": null,
	"terrain_snow": null,
	"terrain_ice": null,
	"terrain_pavement": null,
	
	# UI/Race
	"countdown_beep": null,
	"countdown_go": null,
	"position_up": null,
	"position_down": null,
	"lap_complete": null,
	"finish_cheer": null,
	"handup_grab": null,
	
	# Powerups
	"powerup_beer": null,
	"powerup_cowbell": null,
	"powerup_dollar": null,
	"powerup_hotdog": null,
}

# Runtime
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_pool_index: int = 0
var terrain_player: AudioStreamPlayer = null
var current_terrain_sound: String = ""
var music_player: AudioStreamPlayer = null
var music_player_next: AudioStreamPlayer = null

func _ready():
	_setup_audio_buses()
	_create_sfx_pool()
	_create_terrain_player()
	_create_music_players()
	_load_sounds()

func _setup_audio_buses():
	# Ensure buses exist (they should be created in Project Settings)
	# This just sets initial volumes
	var sfx_idx = AudioServer.get_bus_index(BUS_SFX)
	var music_idx = AudioServer.get_bus_index(BUS_MUSIC)
	
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume))
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(music_volume))

func _create_sfx_pool():
	for i in range(SFX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		sfx_pool.append(player)

func _create_terrain_player():
	terrain_player = AudioStreamPlayer.new()
	terrain_player.bus = BUS_SFX
	terrain_player.volume_db = linear_to_db(0.5)  # Quieter background
	add_child(terrain_player)

func _create_music_players():
	music_player = AudioStreamPlayer.new()
	music_player.bus = BUS_MUSIC
	add_child(music_player)
	
	music_player_next = AudioStreamPlayer.new()
	music_player_next.bus = BUS_MUSIC
	music_player_next.volume_db = linear_to_db(0.0)
	add_child(music_player_next)

func _load_sounds():
	# Load all sound resources
	# Adjust paths based on your project structure
	var base_path = "res://assets/audio/sfx/"
	
	for sound_name in sounds.keys():
		var path = base_path + sound_name + ".wav"
		if ResourceLoader.exists(path):
			sounds[sound_name] = load(path)
		else:
			# Try .ogg
			path = base_path + sound_name + ".ogg"
			if ResourceLoader.exists(path):
				sounds[sound_name] = load(path)
			else:
				push_warning("AudioManager: Sound not found: " + sound_name)

# --- PLAYBACK ---

## Play a one-shot sound effect
func play(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0):
	var sound = sounds.get(sound_name)
	if not sound:
		print("AudioManager: Unknown sound: ", sound_name)
		return
	
	# Handle sound variations (arrays)
	if sound is Array:
		if sound.size() == 0:
			return
		sound = sound[randi() % sound.size()]
	
	# Get next available player from pool
	var player = sfx_pool[sfx_pool_index]
	sfx_pool_index = (sfx_pool_index + 1) % SFX_POOL_SIZE
	
	# Stop if already playing (prevents overlap issues)
	player.stop()
	
	player.stream = sound
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()

## Play with random pitch variation (great for repetitive sounds)
func play_varied(sound_name: String, pitch_variance: float = 0.1, volume_db: float = 0.0):
	var pitch = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	play(sound_name, volume_db, pitch)

## Play terrain loop (crossfades between terrain types)
func play_terrain(terrain_name: String):
	if terrain_name == current_terrain_sound:
		return
	
	current_terrain_sound = terrain_name
	var sound = sounds.get("terrain_" + terrain_name)
	if not sound:
		sound = sounds.get(terrain_name)
	
	if not sound:
		terrain_player.stop()
		return
	
	# Crossfade to new terrain sound
	var tween = create_tween()
	tween.tween_property(terrain_player, "volume_db", linear_to_db(0.0), 0.2)
	tween.tween_callback(func():
		terrain_player.stream = sound
		terrain_player.play()
	)
	tween.tween_property(terrain_player, "volume_db", linear_to_db(0.5), 0.2)

func stop_terrain():
	var tween = create_tween()
	tween.tween_property(terrain_player, "volume_db", linear_to_db(0.0), 0.3)
	tween.tween_callback(terrain_player.stop)
	current_terrain_sound = ""

## Play music with crossfade
func play_music(music_path: String, loop: bool = true):
	var music = load(music_path) if ResourceLoader.exists(music_path) else null
	if not music:
		push_warning("AudioManager: Music not found: " + music_path)
		return
	
	# Setup next player
	music_player_next.stream = music
	music_player_next.volume_db = linear_to_db(0.0)
	music_player_next.play()
	
	# Crossfade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(music_player, "volume_db", linear_to_db(0.0), MUSIC_CROSSFADE_TIME)
	tween.tween_property(music_player_next, "volume_db", linear_to_db(music_volume), MUSIC_CROSSFADE_TIME)
	tween.set_parallel(false)
	tween.tween_callback(func():
		music_player.stop()
		# Swap players
		var temp = music_player
		music_player = music_player_next
		music_player_next = temp
	)

func stop_music(fade_time: float = 1.0):
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", linear_to_db(0.0), fade_time)
	tween.tween_callback(music_player.stop)

# --- VOLUME CONTROL ---

func set_master_volume(value: float):
	master_volume = clampf(value, 0.0, 1.0)
	var idx = AudioServer.get_bus_index(BUS_MASTER)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(master_volume))

func set_sfx_volume(value: float):
	sfx_volume = clampf(value, 0.0, 1.0)
	var idx = AudioServer.get_bus_index(BUS_SFX)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(sfx_volume))

func set_music_volume(value: float):
	music_volume = clampf(value, 0.0, 1.0)
	var idx = AudioServer.get_bus_index(BUS_MUSIC)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(music_volume))

# --- CONVENIENCE ---

## Play countdown sequence
func play_countdown():
	play("countdown_beep")
	await get_tree().create_timer(1.0).timeout
	play("countdown_beep")
	await get_tree().create_timer(1.0).timeout
	play("countdown_beep")
	await get_tree().create_timer(1.0).timeout
	play("countdown_go", 3.0)  # Louder

## Position change sound
func play_position_change(new_position: int, old_position: int):
	if new_position < old_position:
		play("position_up")
	elif new_position > old_position:
		play("position_down")
