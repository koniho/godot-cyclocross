# Cyclocross Godot Project - Claude Code Integration

## Project Overview

Create a complete Godot 4.x project for a cyclocross arcade racing game inspired by Iron Man Off-Road Racing. The game features top-down/isometric view, simple controls, terrain variation, bunny hop mechanics, and AI opponents.

**Target:** Godot 4.3+ compatible project with all source files, scenes, and placeholder assets ready to open and run.

---

## Directory Structure

Create the following folder structure:

```
cyclocross/
├── project.godot
├── export_presets.cfg
├── assets/
│   ├── sprites/
│   │   ├── rider/
│   │   ├── terrain/
│   │   └── objects/
│   ├── audio/
│   │   ├── sfx/
│   │   └── music/
│   └── ui/
├── src/
│   ├── autoload/
│   │   ├── game_manager.gd
│   │   └── audio_manager.gd
│   ├── rider/
│   │   ├── rider.gd
│   │   └── ai_controller.gd
│   ├── course/
│   │   ├── course.gd
│   │   ├── course_segment.gd
│   │   ├── course_data.gd
│   │   ├── terrain_types.gd
│   │   └── obstacles/
│   │       ├── barrier.gd
│   │       ├── handup.gd
│   │       └── ramp_trigger.gd
│   ├── camera/
│   │   └── race_camera.gd
│   └── ui/
│       ├── hud.gd
│       ├── minimap.gd
│       ├── stamina_bar.gd
│       ├── title_screen.gd
│       ├── results_screen.gd
│       └── pause_menu.gd
├── resources/
│   ├── terrain_tileset.tres
│   └── courses/
│       └── course_01.tres
└── scenes/
    ├── rider/
    │   ├── rider.tscn
    │   └── ai_rider.tscn
    ├── course/
    │   ├── barrier.tscn
    │   ├── handup.tscn
    │   └── ramp_trigger.tscn
    ├── ui/
    │   ├── hud.tscn
    │   ├── minimap.tscn
    │   ├── stamina_bar.tscn
    │   ├── title_screen.tscn
    │   ├── results_screen.tscn
    │   └── pause_menu.tscn
    ├── title.tscn
    ├── race.tscn
    └── test_arena.tscn
```

---

## File Contents

### project.godot

```ini
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; but this provides a base configuration.

config_version=5

[application]

config/name="Cyclocross"
config/description="Arcade cyclocross racing game"
config/version="0.1.0"
run/main_scene="res://scenes/title.tscn"
config/features=PackedStringArray("4.3", "Forward Plus")
config/icon="res://icon.svg"

[autoload]

GameManager="*res://src/autoload/game_manager.gd"
AudioManager="*res://src/autoload/audio_manager.gd"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[input]

steer_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":97,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
steer_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":100,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
pedal={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":119,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194320,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
action={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":32,"location":0,"echo":false,"script":null)
]
}
pause={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194305,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
debug_restart={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":82,"key_label":0,"unicode":114,"location":0,"echo":false,"script":null)
]
}

[layer_names]

2d_physics/layer_1="ground_riders"
2d_physics/layer_2="bridge_riders"
2d_physics/layer_3="course_bounds"
2d_physics/layer_4="obstacles"
2d_physics/layer_5="triggers"

[rendering]

renderer/rendering_method="forward_plus"
textures/canvas_textures/default_texture_filter=0
```

---

### src/autoload/game_manager.gd

```gdscript
# game_manager.gd
# Central game state management
# Autoload: GameManager

extends Node

signal state_changed(new_state: GameState)
signal race_countdown_tick(count: int)
signal race_started
signal race_finished(results: Array)

enum GameState {
	TITLE,
	COURSE_SELECT,
	RACE_INTRO,
	RACE_COUNTDOWN,
	RACING,
	RACE_PAUSED,
	RACE_RESULTS,
	SETTINGS
}

var state: GameState = GameState.TITLE
var previous_state: GameState = GameState.TITLE

var current_course_id: String = ""
var race_results: Array = []
var player_stats: Dictionary = {}

var session_stats: Dictionary = {
	"races_completed": 0,
	"total_wins": 0,
	"perfect_hops": 0,
	"total_crashes": 0,
	"total_play_time": 0.0
}

var save_data: Dictionary = {
	"unlocked_courses": ["course_01"],
	"best_times": {},
	"total_races": 0,
	"settings": {
		"master_volume": 1.0,
		"sfx_volume": 1.0,
		"music_volume": 0.7,
		"screen_shake": true,
		"haptics": true
	}
}

const SAVE_PATH = "user://cyclocross_save.json"

func _ready():
	load_game()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta):
	if state == GameState.RACING:
		session_stats.total_play_time += delta

func _input(event):
	if event.is_action_pressed("pause"):
		if state in [GameState.RACING, GameState.RACE_PAUSED]:
			toggle_pause()
	if event.is_action_pressed("debug_restart"):
		if state == GameState.RACING:
			restart_race()

func change_state(new_state: GameState):
	previous_state = state
	state = new_state
	state_changed.emit(new_state)
	
	match new_state:
		GameState.RACE_PAUSED:
			get_tree().paused = true
		_:
			get_tree().paused = false

func go_back():
	match state:
		GameState.RACE_PAUSED:
			change_state(GameState.RACING)
		GameState.RACE_RESULTS:
			change_state(GameState.COURSE_SELECT)
		GameState.COURSE_SELECT:
			change_state(GameState.TITLE)
		GameState.SETTINGS:
			change_state(previous_state)

func start_race(course_id: String = "course_01"):
	current_course_id = course_id
	race_results.clear()
	player_stats = {
		"crashes": 0,
		"perfect_hops": 0,
		"good_hops": 0,
		"handups_grabbed": 0,
		"time_bonking": 0.0
	}
	get_tree().change_scene_to_file("res://scenes/race.tscn")
	change_state(GameState.RACE_INTRO)

func begin_countdown():
	change_state(GameState.RACE_COUNTDOWN)
	_run_countdown()

func _run_countdown():
	for i in range(3, 0, -1):
		race_countdown_tick.emit(i)
		AudioManager.play("countdown_beep")
		await get_tree().create_timer(1.0).timeout
	
	race_countdown_tick.emit(0)
	AudioManager.play("countdown_go")
	
	change_state(GameState.RACING)
	race_started.emit()

func finish_race(results: Array):
	race_results = results
	change_state(GameState.RACE_RESULTS)
	
	session_stats.races_completed += 1
	save_data.total_races += 1
	
	if results.size() > 0 and results[0].get("is_player", false):
		session_stats.total_wins += 1
	
	session_stats.perfect_hops += player_stats.perfect_hops
	session_stats.total_crashes += player_stats.crashes
	
	race_finished.emit(results)
	save_game()

func restart_race():
	start_race(current_course_id)

func quit_to_menu():
	get_tree().change_scene_to_file("res://scenes/title.tscn")
	change_state(GameState.TITLE)

func toggle_pause():
	if state == GameState.RACING:
		change_state(GameState.RACE_PAUSED)
	elif state == GameState.RACE_PAUSED:
		change_state(GameState.RACING)

func record_hop_result(result: String):
	match result:
		"perfect":
			player_stats.perfect_hops += 1
		"good":
			player_stats.good_hops += 1
		"crash", "too_late":
			player_stats.crashes += 1

func record_handup_grab():
	player_stats.handups_grabbed += 1

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func load_game():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var json = JSON.new()
			var result = json.parse(file.get_as_text())
			if result == OK:
				var data = json.get_data()
				for key in data:
					save_data[key] = data[key]
			file.close()

func get_setting(key: String):
	return save_data.settings.get(key)

func set_setting(key: String, value):
	save_data.settings[key] = value
	save_game()
```

---

### src/autoload/audio_manager.gd

```gdscript
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
```

---

### src/course/terrain_types.gd

```gdscript
# terrain_types.gd
class_name TerrainTypes

enum Type {
	GRASS,
	PAVEMENT,
	MUD,
	SAND,
	SNOW,
	ICE
}

const PROPERTIES = {
	Type.GRASS: {
		"name": "Grass",
		"friction": 0.85,
		"max_speed_mult": 1.0,
		"grip": 0.9,
		"color": Color(0.3, 0.5, 0.2)
	},
	Type.PAVEMENT: {
		"name": "Pavement",
		"friction": 0.92,
		"max_speed_mult": 1.15,
		"grip": 1.0,
		"color": Color(0.4, 0.4, 0.4)
	},
	Type.MUD: {
		"name": "Mud",
		"friction": 0.70,
		"max_speed_mult": 0.75,
		"grip": 0.5,
		"color": Color(0.4, 0.25, 0.1)
	},
	Type.SAND: {
		"name": "Sand",
		"friction": 0.60,
		"max_speed_mult": 0.60,
		"grip": 0.4,
		"color": Color(0.8, 0.7, 0.4)
	},
	Type.SNOW: {
		"name": "Snow",
		"friction": 0.80,
		"max_speed_mult": 0.85,
		"grip": 0.6,
		"color": Color(0.9, 0.95, 1.0)
	},
	Type.ICE: {
		"name": "Ice",
		"friction": 0.95,
		"max_speed_mult": 0.90,
		"grip": 0.2,
		"color": Color(0.7, 0.85, 0.95)
	}
}

static func get_properties(type: Type) -> Dictionary:
	return PROPERTIES.get(type, PROPERTIES[Type.GRASS])
```

---

### src/rider/rider.gd

```gdscript
# rider.gd
class_name Rider
extends CharacterBody2D

signal state_changed(new_state)
signal stamina_changed(new_value)
signal barrier_result(result: String)

@export_group("Movement")
@export var max_speed: float = 400.0
@export var acceleration: float = 800.0
@export var steering_speed: float = 3.5
@export var drag: float = 0.98
@export var drift_factor: float = 0.9

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 15.0
@export var stamina_regen_rate: float = 8.0
@export var bonk_threshold: float = 10.0
@export var bonk_speed_penalty: float = 0.5

@export_group("Bunny Hop")
@export var hop_force: float = 150.0
@export var gravity: float = 400.0
@export var hop_speed_boost: float = 1.1

@export_group("Dismount")
@export var run_speed_multiplier: float = 0.6
@export var mount_dismount_time: float = 0.3

enum State { RIDING, DISMOUNTED, JUMPING, MOUNTING, DISMOUNTING, CRASHED }
var state: State = State.RIDING

var current_layer: int = 0
var height: float = 0.0
var vertical_velocity: float = 0.0

var stamina: float = max_stamina
var current_speed: float = 0.0
var heading: float = 0.0
var is_pedaling: bool = false
var is_bonking: bool = false
var current_terrain: int = 0

var approaching_barrier: Node2D = null
var hop_result: String = ""

var course: Node2D = null
var is_player: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready():
	stamina = max_stamina
	add_to_group("riders")
	if is_player:
		add_to_group("player")
	
	# Find course
	var parent = get_parent()
	while parent and not parent.has_method("get_terrain_at"):
		parent = parent.get_parent()
	course = parent

func _physics_process(delta):
	if is_player:
		_handle_input()
	
	match state:
		State.RIDING:
			_process_riding(delta)
		State.JUMPING:
			_process_jumping(delta)
		State.DISMOUNTED:
			_process_dismounted(delta)
		State.MOUNTING, State.DISMOUNTING:
			_process_transition(delta)
		State.CRASHED:
			_process_crashed(delta)
	
	_update_elevation(delta)
	_update_stamina(delta)
	_update_visuals()
	
	move_and_slide()

func _handle_input():
	is_pedaling = Input.is_action_pressed("pedal")
	
	if Input.is_action_just_pressed("action"):
		if state == State.RIDING and approaching_barrier:
			attempt_bunny_hop()
		elif state == State.DISMOUNTED:
			begin_mount()

func _process_riding(delta):
	var terrain_props = _get_terrain_properties()
	
	var steer_input = Input.get_axis("steer_left", "steer_right") if is_player else 0.0
	var effective_steering = steering_speed * terrain_props.grip
	heading += steer_input * effective_steering * delta
	
	if is_pedaling and stamina > 0:
		var terrain_max = max_speed * terrain_props.max_speed_mult
		if is_bonking:
			terrain_max *= bonk_speed_penalty
		current_speed = minf(current_speed + acceleration * delta, terrain_max)
	
	current_speed *= drag * terrain_props.friction
	
	var forward = Vector2.RIGHT.rotated(heading)
	var lateral_velocity = velocity - forward * velocity.dot(forward)
	var forward_velocity = forward * current_speed
	velocity = forward_velocity + lateral_velocity * drift_factor * terrain_props.grip

func _process_jumping(delta):
	var forward = Vector2.RIGHT.rotated(heading)
	velocity = forward * current_speed
	current_speed *= 0.998

func _process_dismounted(delta):
	var terrain_props = _get_terrain_properties()
	var steer_input = Input.get_axis("steer_left", "steer_right") if is_player else 0.0
	heading += steer_input * steering_speed * 1.5 * delta
	
	if is_pedaling:
		var run_max = max_speed * run_speed_multiplier * terrain_props.max_speed_mult
		current_speed = minf(current_speed + acceleration * 0.8 * delta, run_max)
	
	current_speed *= drag * terrain_props.friction
	velocity = Vector2.RIGHT.rotated(heading) * current_speed

func _process_transition(_delta):
	current_speed *= 0.95
	velocity = Vector2.RIGHT.rotated(heading) * current_speed

func _process_crashed(_delta):
	current_speed *= 0.9
	velocity = Vector2.RIGHT.rotated(heading) * current_speed

func _update_elevation(delta):
	var terrain_height = _get_terrain_height()
	var terrain_layer = _get_terrain_layer()
	
	if state == State.JUMPING or height > terrain_height + 1.0:
		vertical_velocity -= gravity * delta
		height += vertical_velocity * delta
		
		if height <= terrain_height:
			height = terrain_height
			vertical_velocity = 0.0
			current_layer = terrain_layer
			if state == State.JUMPING:
				_land()
	else:
		height = terrain_height
		current_layer = terrain_layer
	
	collision_layer = 1 << current_layer
	collision_mask = 1 << current_layer

func _land():
	state = State.RIDING
	state_changed.emit(state)
	_squash_sprite()
	
	match hop_result:
		"perfect":
			current_speed *= hop_speed_boost
		"early", "late":
			current_speed *= 0.7
	hop_result = ""

func _update_stamina(delta):
	if state in [State.CRASHED, State.MOUNTING, State.DISMOUNTING]:
		return
	
	if is_pedaling and state != State.JUMPING:
		stamina -= stamina_drain_rate * delta
		stamina = maxf(stamina, 0.0)
	else:
		stamina += stamina_regen_rate * delta
		stamina = minf(stamina, max_stamina)
	
	is_bonking = stamina < bonk_threshold
	stamina_changed.emit(stamina)

func _update_visuals():
	sprite.rotation = heading
	sprite.position.y = -height * 0.5
	z_index = int(global_position.y) + (current_layer * 10000) + int(height)

func _squash_sprite():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.05)
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.08)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)

func attempt_bunny_hop():
	if state != State.RIDING or height > 5.0:
		return
	
	if approaching_barrier and approaching_barrier.has_method("attempt_hop"):
		hop_result = approaching_barrier.attempt_hop(self)
		
		match hop_result:
			"perfect", "good":
				_execute_hop()
				barrier_result.emit(hop_result)
			"too_late":
				_crash()
				barrier_result.emit("crash")
	else:
		hop_result = "good"
		_execute_hop()

func _execute_hop():
	state = State.JUMPING
	state_changed.emit(state)
	vertical_velocity = hop_force
	AudioManager.play("hop_launch")

func begin_dismount():
	if state != State.RIDING:
		return
	state = State.DISMOUNTING
	state_changed.emit(state)
	get_tree().create_timer(mount_dismount_time).timeout.connect(_finish_dismount)

func _finish_dismount():
	if state == State.DISMOUNTING:
		state = State.DISMOUNTED
		state_changed.emit(state)

func begin_mount():
	if state != State.DISMOUNTED:
		return
	state = State.MOUNTING
	state_changed.emit(state)
	get_tree().create_timer(mount_dismount_time).timeout.connect(_finish_mount)

func _finish_mount():
	if state == State.MOUNTING:
		state = State.RIDING
		state_changed.emit(state)

func _crash():
	state = State.CRASHED
	state_changed.emit(state)
	current_speed *= 0.3
	AudioManager.play("crash")
	get_tree().create_timer(2.0).timeout.connect(_recover_from_crash)

func _recover_from_crash():
	if state == State.CRASHED:
		state = State.RIDING
		state_changed.emit(state)

func _get_terrain_properties() -> Dictionary:
	if course and course.has_method("get_terrain_at"):
		current_terrain = course.get_terrain_at(global_position)
		return TerrainTypes.PROPERTIES.get(current_terrain, TerrainTypes.PROPERTIES[0])
	return TerrainTypes.PROPERTIES[0]

func _get_terrain_height() -> float:
	if course and course.has_method("get_height_at"):
		return course.get_height_at(global_position)
	return 0.0

func _get_terrain_layer() -> int:
	if course and course.has_method("get_layer_at"):
		return course.get_layer_at(global_position)
	return 0
```

---

### src/rider/ai_controller.gd

```gdscript
# ai_controller.gd
class_name AIController
extends Node

@export var rider: Rider
@export var course: Node2D

@export_group("Skill")
@export var path_accuracy: float = 0.8
@export var hop_skill: float = 0.5
@export var mistake_chance: float = 0.1
@export var base_speed_mult: float = 1.0

@export_group("Rubber Banding")
@export var enable_rubber_band: bool = true
@export var rubber_band_strength: float = 0.1
@export var max_speed_boost: float = 1.15
@export var max_speed_penalty: float = 0.9

var target_point: Vector2 = Vector2.ZERO
var path_progress: float = 0.0
var look_ahead_distance: float = 100.0
var hop_decision_made: bool = false
var will_hop: bool = false

func _ready():
	if not rider:
		rider = get_parent() as Rider
	if rider:
		rider.is_player = false

func _physics_process(delta):
	if not rider or not course:
		return
	if GameManager.state != GameManager.GameState.RACING:
		rider.is_pedaling = false
		return
	
	_update_path_following()
	_update_steering(delta)
	_update_pedaling()
	_update_barrier_decisions()
	_apply_rubber_banding()

func _update_path_following():
	# Simple: head toward a point ahead on an oval path
	var center = Vector2(640, 360)
	var radius = 250.0
	var angle = rider.global_position.angle_to_point(center) + 0.3
	target_point = center + Vector2.RIGHT.rotated(angle) * radius

func _update_steering(delta):
	var to_target = target_point - rider.global_position
	var target_angle = to_target.angle()
	var angle_diff = wrapf(target_angle - rider.heading, -PI, PI)
	var steer_input = clampf(angle_diff * 2.0, -1.0, 1.0)
	
	var grip = 0.9
	if rider.course and rider.course.has_method("get_terrain_at"):
		var terrain = rider.course.get_terrain_at(rider.global_position)
		grip = TerrainTypes.PROPERTIES.get(terrain, {}).get("grip", 0.9)
	
	rider.heading += steer_input * rider.steering_speed * grip * delta

func _update_pedaling():
	rider.is_pedaling = rider.stamina > 20.0

func _update_barrier_decisions():
	if rider.approaching_barrier and not hop_decision_made:
		hop_decision_made = true
		will_hop = randf() < hop_skill
		
		if not will_hop:
			rider.begin_dismount()
	
	if will_hop and rider.approaching_barrier:
		var barrier = rider.approaching_barrier
		var dist = rider.global_position.distance_to(barrier.global_position)
		if dist <= 25.0:
			rider.attempt_bunny_hop()
	
	if not rider.approaching_barrier:
		hop_decision_made = false
		will_hop = false

func _apply_rubber_banding():
	if not enable_rubber_band:
		return
	# Simplified rubber banding - would need course progress tracking
```

---

### src/course/obstacles/barrier.gd

```gdscript
# barrier.gd
class_name Barrier
extends Area2D

signal hop_attempted(rider: Node2D, result: String)

@export var detection_distance: float = 80.0
@export var hop_window_start: float = 50.0
@export var hop_window_end: float = 12.0
@export var perfect_window_start: float = 25.0
@export var perfect_window_end: float = 15.0

var approaching_riders: Dictionary = {}

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(_delta):
	for rider in approaching_riders:
		if is_instance_valid(rider):
			approaching_riders[rider] = _get_approach_distance(rider)

func _get_approach_distance(rider: Node2D) -> float:
	var to_rider = rider.global_position - global_position
	var forward = Vector2.RIGHT.rotated(rotation)
	return -to_rider.dot(forward)

func attempt_hop(rider: Node2D) -> String:
	var dist = approaching_riders.get(rider, 999.0)
	
	var result: String
	if dist > hop_window_start:
		result = "too_early"
	elif dist < hop_window_end:
		result = "too_late"
	elif dist >= perfect_window_end and dist <= perfect_window_start:
		result = "perfect"
	else:
		result = "good"
	
	hop_attempted.emit(rider, result)
	return result

func _on_body_entered(body: Node2D):
	if body is Rider:
		approaching_riders[body] = _get_approach_distance(body)
		body.approaching_barrier = self

func _on_body_exited(body: Node2D):
	if body is Rider:
		approaching_riders.erase(body)
		if body.approaching_barrier == self:
			body.approaching_barrier = null
```

---

### src/camera/race_camera.gd

```gdscript
# race_camera.gd
class_name RaceCamera
extends Camera2D

@export var target: Node2D
@export var smooth_speed: float = 5.0
@export var look_ahead_distance: float = 120.0
@export var look_ahead_smoothing: float = 3.0
@export var zoom_min: Vector2 = Vector2(0.7, 0.7)
@export var zoom_max: Vector2 = Vector2(1.0, 1.0)
@export var zoom_speed: float = 2.0
@export var shake_decay: float = 5.0

var current_look_ahead: Vector2 = Vector2.ZERO
var shake_intensity: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO
var target_zoom: Vector2 = Vector2.ONE

func _ready():
	make_current()
	if target:
		global_position = target.global_position

func _process(delta):
	if not target:
		return
	
	_update_position(delta)
	_update_zoom(delta)
	_update_shake(delta)

func _update_position(delta):
	var target_velocity = Vector2.ZERO
	if target is Rider:
		target_velocity = target.velocity
	
	var desired_look_ahead = target_velocity.normalized() * look_ahead_distance
	current_look_ahead = current_look_ahead.lerp(desired_look_ahead, look_ahead_smoothing * delta)
	
	var target_pos = target.global_position + current_look_ahead
	global_position = global_position.lerp(target_pos, smooth_speed * delta)
	offset = shake_offset

func _update_zoom(delta):
	if not target is Rider:
		return
	
	var rider = target as Rider
	var speed_ratio = clampf(rider.current_speed / rider.max_speed, 0.0, 1.0)
	target_zoom = zoom_max.lerp(zoom_min, speed_ratio)
	zoom = zoom.lerp(target_zoom, zoom_speed * delta)

func _update_shake(delta):
	if shake_intensity > 0:
		shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_intensity = maxf(0, shake_intensity - shake_decay * delta * shake_intensity)
	else:
		shake_offset = Vector2.ZERO

func shake(intensity: float = 5.0, _duration: float = 0.2):
	shake_intensity = maxf(shake_intensity, intensity)
```

---

### src/ui/hud.gd

```gdscript
# hud.gd
extends CanvasLayer

@onready var stamina_bar: ProgressBar = $Control/StaminaBar
@onready var position_label: Label = $Control/PositionLabel
@onready var lap_label: Label = $Control/LapLabel
@onready var countdown_label: Label = $Control/CountdownLabel

var player: Rider = null

func _ready():
	GameManager.race_countdown_tick.connect(_on_countdown_tick)
	GameManager.race_started.connect(_on_race_started)
	countdown_label.visible = false

func _process(_delta):
	if player:
		stamina_bar.value = player.stamina
		stamina_bar.max_value = player.max_stamina

func set_player(rider: Rider):
	player = rider
	if player:
		player.stamina_changed.connect(_on_stamina_changed)

func _on_stamina_changed(value: float):
	stamina_bar.value = value

func _on_countdown_tick(count: int):
	countdown_label.visible = true
	if count > 0:
		countdown_label.text = str(count)
	else:
		countdown_label.text = "GO!"

func _on_race_started():
	var tween = create_tween()
	tween.tween_property(countdown_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): countdown_label.visible = false)

func update_position(pos: int):
	position_label.text = _ordinal(pos)

func update_lap(current: int, total: int):
	lap_label.text = "Lap %d/%d" % [current, total]

func _ordinal(n: int) -> String:
	if n == 1: return "1st"
	if n == 2: return "2nd"
	if n == 3: return "3rd"
	return str(n) + "th"
```

---

### src/ui/title_screen.gd

```gdscript
# title_screen.gd
extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready():
	start_button.grab_focus()
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed():
	GameManager.start_race("course_01")

func _on_quit_pressed():
	get_tree().quit()
```

---

### src/ui/pause_menu.gd

```gdscript
# pause_menu.gd
extends CanvasLayer

@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Panel/VBoxContainer/RestartButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	resume_button.pressed.connect(_on_resume)
	restart_button.pressed.connect(_on_restart)
	quit_button.pressed.connect(_on_quit)
	
	GameManager.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: GameManager.GameState):
	visible = new_state == GameManager.GameState.RACE_PAUSED
	if visible:
		resume_button.grab_focus()

func _on_resume():
	GameManager.toggle_pause()

func _on_restart():
	GameManager.restart_race()

func _on_quit():
	GameManager.quit_to_menu()
```

---

### src/ui/results_screen.gd

```gdscript
# results_screen.gd
extends CanvasLayer

@onready var position_label: Label = $Panel/VBoxContainer/PositionLabel
@onready var time_label: Label = $Panel/VBoxContainer/TimeLabel
@onready var retry_button: Button = $Panel/VBoxContainer/HBoxContainer/RetryButton
@onready var quit_button: Button = $Panel/VBoxContainer/HBoxContainer/QuitButton

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	retry_button.pressed.connect(_on_retry)
	quit_button.pressed.connect(_on_quit)
	
	GameManager.race_finished.connect(_on_race_finished)

func _on_race_finished(results: Array):
	visible = true
	
	var player_result = null
	for r in results:
		if r.get("is_player", false):
			player_result = r
			break
	
	if player_result:
		position_label.text = _ordinal(player_result.position)
		time_label.text = _format_time(player_result.get("time", 0.0))
	
	retry_button.grab_focus()

func _on_retry():
	visible = false
	GameManager.restart_race()

func _on_quit():
	visible = false
	GameManager.quit_to_menu()

func _ordinal(n: int) -> String:
	if n == 1: return "1st"
	if n == 2: return "2nd"
	if n == 3: return "3rd"
	return str(n) + "th"

func _format_time(t: float) -> String:
	var mins = int(t / 60)
	var secs = fmod(t, 60)
	return "%d:%05.2f" % [mins, secs]
```

---

### src/ui/stamina_bar.gd

```gdscript
# stamina_bar.gd
extends ProgressBar

@export var low_stamina_color: Color = Color(0.8, 0.2, 0.2)
@export var normal_color: Color = Color(0.2, 0.7, 0.3)
@export var bonk_threshold: float = 20.0

var default_style: StyleBox = null

func _ready():
	default_style = get_theme_stylebox("fill")

func _process(_delta):
	if value < bonk_threshold:
		modulate = low_stamina_color
	else:
		modulate = normal_color
```

---

### src/ui/minimap.gd

```gdscript
# minimap.gd
extends Control

@export var map_size: Vector2 = Vector2(150, 150)
@export var background_color: Color = Color(0.1, 0.1, 0.1, 0.7)
@export var ground_color: Color = Color(0.3, 0.5, 0.3)
@export var player_color: Color = Color(1.0, 0.8, 0.0)
@export var ai_color: Color = Color(0.8, 0.2, 0.2)
@export var rider_radius: float = 4.0

var course_center: Vector2 = Vector2(640, 360)
var map_scale: float = 0.15

func _ready():
	custom_minimum_size = map_size

func _process(_delta):
	queue_redraw()

func _draw():
	draw_rect(Rect2(Vector2.ZERO, map_size), background_color)
	
	# Draw simple oval course outline
	var center = map_size * 0.5
	var radius = Vector2(60, 40)
	var points: PackedVector2Array = []
	for i in range(32):
		var angle = i * TAU / 32
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	points.append(points[0])
	
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], ground_color, 3.0)
	
	# Draw riders
	var riders = get_tree().get_nodes_in_group("riders")
	for rider in riders:
		var map_pos = _world_to_map(rider.global_position)
		var color = player_color if rider.is_in_group("player") else ai_color
		draw_circle(map_pos, rider_radius, color)
	
	draw_rect(Rect2(Vector2.ZERO, map_size), Color.WHITE, false, 1.0)

func _world_to_map(world_pos: Vector2) -> Vector2:
	var relative = world_pos - course_center
	var map_pos = relative * map_scale
	return map_pos + map_size * 0.5
```

---

## Scene Files

### scenes/title.tscn

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/title_screen.gd" id="1"]

[node name="TitleScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.15, 0.2, 0.15, 1)

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -100.0
offset_top = -80.0
offset_right = 100.0
offset_bottom = 80.0

[node name="Title" type="Label" parent="VBoxContainer"]
layout_mode = 2
theme_override_font_sizes/font_size = 48
text = "CYCLOCROSS"
horizontal_alignment = 1

[node name="Spacer" type="Control" parent="VBoxContainer"]
custom_minimum_size = Vector2(0, 40)
layout_mode = 2

[node name="StartButton" type="Button" parent="VBoxContainer"]
layout_mode = 2
text = "START RACE"

[node name="QuitButton" type="Button" parent="VBoxContainer"]
layout_mode = 2
text = "QUIT"
```

---

### scenes/race.tscn

```
[gd_scene load_steps=8 format=3]

[ext_resource type="Script" path="res://src/rider/rider.gd" id="1"]
[ext_resource type="Script" path="res://src/camera/race_camera.gd" id="2"]
[ext_resource type="Script" path="res://src/ui/hud.gd" id="3"]
[ext_resource type="Script" path="res://src/ui/pause_menu.gd" id="4"]
[ext_resource type="Script" path="res://src/ui/results_screen.gd" id="5"]
[ext_resource type="Script" path="res://src/ui/minimap.gd" id="6"]
[ext_resource type="Script" path="res://src/ui/stamina_bar.gd" id="7"]

[node name="Race" type="Node2D"]

[node name="Course" type="Node2D" parent="."]

[node name="Ground" type="ColorRect" parent="Course"]
offset_right = 1280.0
offset_bottom = 720.0
color = Color(0.3, 0.5, 0.25, 1)

[node name="Track" type="Polygon2D" parent="Course"]
color = Color(0.35, 0.55, 0.3, 1)
polygon = PackedVector2Array(340, 160, 940, 160, 1040, 260, 1040, 460, 940, 560, 340, 560, 240, 460, 240, 260)

[node name="Riders" type="Node2D" parent="."]

[node name="Player" type="CharacterBody2D" parent="Riders" groups=["player", "riders"]]
position = Vector2(640, 500)
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="Riders/Player"]
scale = Vector2(2, 1)
texture = PlaceholderTexture2D

[node name="CollisionShape2D" type="CollisionShape2D" parent="Riders/Player"]
shape = CircleShape2D

[node name="RaceCamera" type="Camera2D" parent="Riders/Player"]
script = ExtResource("2")
target = NodePath("..")

[node name="HUD" type="CanvasLayer" parent="."]
script = ExtResource("3")

[node name="Control" type="Control" parent="HUD"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="StaminaBar" type="ProgressBar" parent="HUD/Control"]
offset_left = 20.0
offset_top = 20.0
offset_right = 220.0
offset_bottom = 40.0
value = 100.0
script = ExtResource("7")

[node name="PositionLabel" type="Label" parent="HUD/Control"]
offset_left = 20.0
offset_top = 50.0
offset_right = 120.0
offset_bottom = 80.0
theme_override_font_sizes/font_size = 24
text = "1st"

[node name="LapLabel" type="Label" parent="HUD/Control"]
offset_left = 20.0
offset_top = 85.0
offset_right = 150.0
offset_bottom = 110.0
text = "Lap 1/3"

[node name="CountdownLabel" type="Label" parent="HUD/Control"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -50.0
offset_top = -40.0
offset_right = 50.0
offset_bottom = 40.0
theme_override_font_sizes/font_size = 72
text = "3"
horizontal_alignment = 1
vertical_alignment = 1

[node name="Minimap" type="Control" parent="HUD/Control"]
layout_mode = 1
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -170.0
offset_top = 20.0
offset_right = -20.0
offset_bottom = 170.0
script = ExtResource("6")

[node name="PauseMenu" type="CanvasLayer" parent="."]
script = ExtResource("4")

[node name="Panel" type="Panel" parent="PauseMenu"]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -100.0
offset_top = -80.0
offset_right = 100.0
offset_bottom = 80.0

[node name="VBoxContainer" type="VBoxContainer" parent="PauseMenu/Panel"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 10.0
offset_top = 10.0
offset_right = -10.0
offset_bottom = -10.0

[node name="Label" type="Label" parent="PauseMenu/Panel/VBoxContainer"]
layout_mode = 2
text = "PAUSED"
horizontal_alignment = 1

[node name="ResumeButton" type="Button" parent="PauseMenu/Panel/VBoxContainer"]
layout_mode = 2
text = "Resume"

[node name="RestartButton" type="Button" parent="PauseMenu/Panel/VBoxContainer"]
layout_mode = 2
text = "Restart"

[node name="QuitButton" type="Button" parent="PauseMenu/Panel/VBoxContainer"]
layout_mode = 2
text = "Quit"

[node name="ResultsScreen" type="CanvasLayer" parent="."]
script = ExtResource("5")

[node name="Panel" type="Panel" parent="ResultsScreen"]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -120.0
offset_top = -100.0
offset_right = 120.0
offset_bottom = 100.0

[node name="VBoxContainer" type="VBoxContainer" parent="ResultsScreen/Panel"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 10.0
offset_top = 10.0
offset_right = -10.0
offset_bottom = -10.0

[node name="FinishedLabel" type="Label" parent="ResultsScreen/Panel/VBoxContainer"]
layout_mode = 2
text = "FINISHED"
horizontal_alignment = 1

[node name="PositionLabel" type="Label" parent="ResultsScreen/Panel/VBoxContainer"]
layout_mode = 2
theme_override_font_sizes/font_size = 36
text = "1st"
horizontal_alignment = 1

[node name="TimeLabel" type="Label" parent="ResultsScreen/Panel/VBoxContainer"]
layout_mode = 2
text = "0:00.00"
horizontal_alignment = 1

[node name="Spacer" type="Control" parent="ResultsScreen/Panel/VBoxContainer"]
custom_minimum_size = Vector2(0, 20)
layout_mode = 2

[node name="HBoxContainer" type="HBoxContainer" parent="ResultsScreen/Panel/VBoxContainer"]
layout_mode = 2

[node name="RetryButton" type="Button" parent="ResultsScreen/Panel/VBoxContainer/HBoxContainer"]
layout_mode = 2
size_flags_horizontal = 3
text = "Retry"

[node name="QuitButton" type="Button" parent="ResultsScreen/Panel/VBoxContainer/HBoxContainer"]
layout_mode = 2
size_flags_horizontal = 3
text = "Quit"

[node name="RaceController" type="Node" parent="."]

[connection signal="ready" from="." to="RaceController" method="_on_race_ready"]
```

---

### scenes/test_arena.tscn

Create a simple test arena for early development:

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://src/rider/rider.gd" id="1"]
[ext_resource type="Script" path="res://src/camera/race_camera.gd" id="2"]
[ext_resource type="Script" path="res://src/course/obstacles/barrier.gd" id="3"]

[node name="TestArena" type="Node2D"]

[node name="Ground" type="ColorRect" parent="."]
offset_right = 1280.0
offset_bottom = 720.0
color = Color(0.3, 0.5, 0.25, 1)

[node name="MudPatch" type="ColorRect" parent="."]
offset_left = 500.0
offset_top = 300.0
offset_right = 700.0
offset_bottom = 420.0
color = Color(0.4, 0.25, 0.1, 1)

[node name="SandPatch" type="ColorRect" parent="."]
offset_left = 800.0
offset_top = 200.0
offset_right = 1000.0
offset_bottom = 350.0
color = Color(0.8, 0.7, 0.4, 1)

[node name="Barrier" type="Area2D" parent="." groups=["barriers"]]
position = Vector2(640, 250)
script = ExtResource("3")

[node name="Sprite2D" type="Sprite2D" parent="Barrier"]
scale = Vector2(4, 0.5)
texture = PlaceholderTexture2D

[node name="CollisionShape2D" type="CollisionShape2D" parent="Barrier"]
shape = RectangleShape2D

[node name="Player" type="CharacterBody2D" parent="." groups=["player", "riders"]]
position = Vector2(640, 500)
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="Player"]
scale = Vector2(2, 1)
texture = PlaceholderTexture2D

[node name="CollisionShape2D" type="CollisionShape2D" parent="Player"]
shape = CircleShape2D

[node name="Camera2D" type="Camera2D" parent="Player"]
script = ExtResource("2")
target = NodePath("..")

[node name="Instructions" type="Label" parent="."]
offset_left = 20.0
offset_top = 650.0
offset_right = 500.0
offset_bottom = 700.0
text = "WASD to move | SPACE to bunny hop | R to restart | ESC to pause"
```

---

## Placeholder Assets

Create the following placeholder files:

### icon.svg

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128">
  <rect width="128" height="128" fill="#3d5a3d"/>
  <circle cx="64" cy="64" r="40" fill="none" stroke="#7da87d" stroke-width="8"/>
  <circle cx="44" cy="64" r="12" fill="#7da87d"/>
  <circle cx="84" cy="64" r="12" fill="#7da87d"/>
</svg>
```

---

## Execution Steps

1. Create the directory structure as specified above
2. Create all `.gd` script files with the provided content
3. Create all `.tscn` scene files with the provided content
4. Create the `project.godot` configuration file
5. Create the `icon.svg` placeholder
6. Verify the project opens in Godot 4.3+ without errors
7. Run the title scene and verify navigation to race scene works
8. Test basic rider movement with WASD controls
9. Verify pause menu opens with ESC
10. Confirm debug restart works with R key

---

## Verification Checklist

After setup, verify:

- [ ] Project opens in Godot without errors
- [ ] Title screen displays with Start and Quit buttons
- [ ] Start button loads race scene
- [ ] Player rider responds to WASD input
- [ ] Camera follows player smoothly
- [ ] ESC opens pause menu
- [ ] Pause menu Resume/Restart/Quit work
- [ ] R key restarts the race
- [ ] Stamina bar displays and depletes when moving
- [ ] Minimap shows in top-right corner
- [ ] Space triggers bunny hop animation

---

## Notes

- All scripts use `class_name` for easy referencing
- Autoloads are prefixed with `*` in project.godot for singleton access
- Input map uses physical keycodes for consistent behavior
- Collision layers are predefined for ground/bridge separation
- Scene files use Godot 4.x format (format=3)
- PlaceholderTexture2D is used where sprites are needed
- Test arena scene is provided for isolated mechanic testing
