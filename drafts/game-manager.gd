# game_manager.gd
# Central game state management
# Add as Autoload: Project Settings > Autoload > game_manager.gd as "GameManager"

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

# Current state
var state: GameState = GameState.TITLE
var previous_state: GameState = GameState.TITLE

# Race data
var current_course_id: String = ""
var race_results: Array = []
var player_stats: Dictionary = {}

# Session stats (reset on app close)
var session_stats: Dictionary = {
	"races_completed": 0,
	"total_wins": 0,
	"perfect_hops": 0,
	"total_crashes": 0,
	"total_play_time": 0.0
}

# Persistent data (save/load)
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
	process_mode = Node.PROCESS_MODE_ALWAYS  # Run even when paused

func _process(delta):
	if state == GameState.RACING:
		session_stats.total_play_time += delta

# --- STATE MANAGEMENT ---

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

# --- RACE FLOW ---

func start_race(course_id: String):
	current_course_id = course_id
	race_results.clear()
	player_stats = {
		"crashes": 0,
		"perfect_hops": 0,
		"good_hops": 0,
		"handups_grabbed": 0,
		"time_bonking": 0.0
	}
	
	# Load race scene
	get_tree().change_scene_to_file("res://scenes/race.tscn")
	
	# Race scene will call begin_countdown() when ready
	change_state(GameState.RACE_INTRO)

func begin_countdown():
	change_state(GameState.RACE_COUNTDOWN)
	
	# 3-2-1-GO countdown
	for i in range(3, 0, -1):
		race_countdown_tick.emit(i)
		if has_node("/root/AudioManager"):
			AudioManager.play("countdown_beep")
		await get_tree().create_timer(1.0).timeout
	
	# GO!
	race_countdown_tick.emit(0)
	if has_node("/root/AudioManager"):
		AudioManager.play("countdown_go")
	
	change_state(GameState.RACING)
	race_started.emit()

func finish_race(results: Array):
	race_results = results
	change_state(GameState.RACE_RESULTS)
	
	# Update stats
	session_stats.races_completed += 1
	save_data.total_races += 1
	
	# Check if player won
	if results.size() > 0 and results[0].is_player:
		session_stats.total_wins += 1
	
	# Update best time
	var player_result = results.filter(func(r): return r.is_player)
	if player_result.size() > 0:
		var time = player_result[0].time
		var best = save_data.best_times.get(current_course_id, INF)
		if time < best:
			save_data.best_times[current_course_id] = time
	
	session_stats.perfect_hops += player_stats.perfect_hops
	session_stats.total_crashes += player_stats.crashes
	
	race_finished.emit(results)
	save_game()

func restart_race():
	start_race(current_course_id)

func quit_to_menu():
	get_tree().change_scene_to_file("res://scenes/title.tscn")
	change_state(GameState.TITLE)

# --- PAUSE ---

func toggle_pause():
	if state == GameState.RACING:
		change_state(GameState.RACE_PAUSED)
	elif state == GameState.RACE_PAUSED:
		change_state(GameState.RACING)

func _input(event):
	if event.is_action_pressed("pause"):
		if state in [GameState.RACING, GameState.RACE_PAUSED]:
			toggle_pause()

# --- STAT TRACKING ---

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

# --- SAVE/LOAD ---

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
				# Merge with defaults (in case save is from older version)
				for key in data:
					save_data[key] = data[key]
			file.close()

func reset_save():
	save_data = {
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
	save_game()

# --- SETTINGS ---

func get_setting(key: String):
	return save_data.settings.get(key)

func set_setting(key: String, value):
	save_data.settings[key] = value
	_apply_setting(key, value)
	save_game()

func _apply_setting(key: String, value):
	match key:
		"master_volume":
			if has_node("/root/AudioManager"):
				AudioManager.set_master_volume(value)
		"sfx_volume":
			if has_node("/root/AudioManager"):
				AudioManager.set_sfx_volume(value)
		"music_volume":
			if has_node("/root/AudioManager"):
				AudioManager.set_music_volume(value)

func apply_all_settings():
	for key in save_data.settings:
		_apply_setting(key, save_data.settings[key])

# --- COURSE UNLOCKS ---

func is_course_unlocked(course_id: String) -> bool:
	return course_id in save_data.unlocked_courses

func unlock_course(course_id: String):
	if course_id not in save_data.unlocked_courses:
		save_data.unlocked_courses.append(course_id)
		save_game()

func get_best_time(course_id: String) -> float:
	return save_data.best_times.get(course_id, -1.0)

# --- DEBUG ---

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func debug_unlock_all():
	save_data.unlocked_courses = ["course_01", "course_02", "course_03", "course_04", "course_05"]
	save_game()

func debug_reset_times():
	save_data.best_times.clear()
	save_game()
