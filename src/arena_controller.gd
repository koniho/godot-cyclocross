# arena_controller.gd
extends Node

const TerrainTypes = preload("res://src/course/terrain_types.gd")

const RACE_DURATION := 180.0   # seconds until bell lap triggers
const DISMOUNT_BENEFICIAL_TERRAINS := [TerrainTypes.Type.SAND, TerrainTypes.Type.MUD]

@onready var state_label: Label       = $"../HUD/Control/StateLabel"
@onready var speed_label: Label       = $"../HUD/Control/SpeedLabel"
@onready var terrain_label: Label     = $"../HUD/Control/TerrainLabel"
@onready var stamina_bar: ProgressBar = $"../HUD/Control/StaminaBar"
@onready var hop_prompt: Label        = $"../HUD/Control/HopPrompt"
@onready var dismount_hint: Label     = $"../HUD/Control/DismountHint"
@onready var lap_label: Label         = $"../HUD/Control/LapLabel"
@onready var timer_label: Label       = $"../HUD/Control/TimerLabel"
@onready var bell_label: Label        = $"../HUD/Control/BellLabel"
@onready var lap_banner: Label        = $"../HUD/Control/LapBanner"
@onready var lap_time_label: Label    = $"../HUD/Control/LapTimeLabel"

var player: Node2D = null
var course: Node2D = null

var elapsed_time: float = 0.0
var lap_count: int = 0
var bell_lap_active: bool = false
var race_finished: bool = false
var _bell_flash_timer: float = 0.0
var _lap_start_time: float = 0.0
var _lap_times: Array = []
var _banner_timer: float = 0.0

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if player:
		stamina_bar.max_value = player.max_stamina

	course = get_tree().get_first_node_in_group("course")

	# Load course: editor data first, then saved default, then built-in fallback
	if GameManager.editor_course_data and course and course.has_method("rebuild"):
		course.course_data = GameManager.editor_course_data
		course.rebuild()
	elif course and course.has_method("rebuild"):
		var saved := CourseData.load_json("user://courses/default.json")
		if saved:
			course.course_data = saved
			course.rebuild()

	if course:
		course.lap_crossed.connect(_on_lap_crossed)

	bell_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		GameManager.quit_to_menu()

func _process(delta: float):
	if not player or race_finished:
		return

	# Race timer
	elapsed_time += delta
	var total_secs := int(elapsed_time)
	var mins: int = floori(total_secs / 60.0)
	var secs: int = total_secs - mins * 60
	timer_label.text = "%d:%02d" % [mins, secs]

	# Lap display
	lap_label.text = "Lap %d" % lap_count

	# HUD updates
	stamina_bar.value = player.stamina
	speed_label.text  = "Speed: %d px/s" % int(player.current_speed)
	state_label.text  = "State: %s" % player.State.keys()[player.state]

	var terrain_name: String = TerrainTypes.PROPERTIES.get(
		player.current_terrain, TerrainTypes.PROPERTIES[0]
	).get("name", "?")
	terrain_label.text = "Terrain: %s" % terrain_name

	hop_prompt.visible = (player.approaching_barrier != null
		and player.state == player.State.RIDING)

	var on_slow_terrain: bool = player.current_terrain in DISMOUNT_BENEFICIAL_TERRAINS
	dismount_hint.visible = (on_slow_terrain and player.state == player.State.RIDING)

	# Lap banner fade-out
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			lap_banner.visible = false
			lap_time_label.visible = false
		else:
			var alpha := clampf(_banner_timer / 0.5, 0.0, 1.0)
			lap_banner.modulate.a = alpha
			lap_time_label.modulate.a = alpha

	# Bell label flash
	if bell_lap_active and not race_finished:
		_bell_flash_timer += delta
		bell_label.visible = fmod(_bell_flash_timer, 0.6) < 0.35

func _format_time(t: float) -> String:
	var mins: int = floori(t / 60.0)
	var secs: float = t - mins * 60.0
	return "%d:%05.2f" % [mins, secs]

func _on_lap_crossed(_rider: Node2D) -> void:
	if race_finished:
		return

	# Record lap time
	var lap_time := elapsed_time - _lap_start_time
	_lap_times.append(lap_time)
	_lap_start_time = elapsed_time

	if bell_lap_active:
		# Completing the bell lap — race over
		race_finished = true
		bell_label.text = "FINISHED!  Laps: %d" % (lap_count + 1)
		bell_label.modulate = Color(0.2, 1.0, 0.4)
		bell_label.visible = true
		_show_lap_banner(lap_count + 1, lap_time)
		return

	lap_count += 1
	_show_lap_banner(lap_count, lap_time)

	if elapsed_time >= RACE_DURATION:
		# This crossing triggers the bell lap
		bell_lap_active = true
		bell_label.text = "BELL LAP!"
		bell_label.modulate = Color(1.0, 0.9, 0.1)
		bell_label.visible = true
		_bell_flash_timer = 0.0
		AudioManager.play("bell")

func _show_lap_banner(lap_num: int, lap_time: float) -> void:
	lap_banner.text = "LAP %d" % lap_num
	lap_banner.modulate = Color(1.0, 1.0, 1.0, 1.0)
	lap_banner.visible = true

	var time_text := _format_time(lap_time)
	if _lap_times.size() >= 2:
		var prev_time: float = _lap_times[-2]
		var diff := lap_time - prev_time
		var diff_str := _format_time(absf(diff))
		if diff < -0.01:
			time_text += "  -%s" % diff_str
			lap_time_label.modulate = Color(0.3, 1.0, 0.4)
		elif diff > 0.01:
			time_text += "  +%s" % diff_str
			lap_time_label.modulate = Color(1.0, 0.4, 0.3)
		else:
			lap_time_label.modulate = Color(1.0, 1.0, 1.0)
	else:
		lap_time_label.modulate = Color(1.0, 1.0, 1.0)

	lap_time_label.text = time_text
	lap_time_label.visible = true
	_banner_timer = 3.0  # visible for 3s, fades out in last 0.5s
