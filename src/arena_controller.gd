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

var player: Node2D = null
var course: Node2D = null

var elapsed_time: float = 0.0
var lap_count: int = 0
var bell_lap_active: bool = false
var race_finished: bool = false
var _bell_flash_timer: float = 0.0

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if player:
		stamina_bar.max_value = player.max_stamina

	course = get_tree().get_first_node_in_group("course")

	# Apply editor course data if testing from the editor
	if GameManager.editor_course_data and course and course.has_method("rebuild"):
		course.course_data = GameManager.editor_course_data
		course.rebuild()

	if course:
		course.lap_crossed.connect(_on_lap_crossed)

	bell_label.visible = false

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

	# Bell label flash
	if bell_lap_active and not race_finished:
		_bell_flash_timer += delta
		bell_label.visible = fmod(_bell_flash_timer, 0.6) < 0.35

func _on_lap_crossed(_rider: Node2D) -> void:
	if race_finished:
		return

	if bell_lap_active:
		# Completing the bell lap — race over
		race_finished = true
		bell_label.text = "FINISHED!  Laps: %d" % lap_count
		bell_label.modulate = Color(0.2, 1.0, 0.4)
		bell_label.visible = true
		return

	lap_count += 1

	if elapsed_time >= RACE_DURATION:
		# This crossing triggers the bell lap
		bell_lap_active = true
		bell_label.text = "BELL LAP!"
		bell_label.modulate = Color(1.0, 0.9, 0.1)
		bell_label.visible = true
		_bell_flash_timer = 0.0
		AudioManager.play("bell")
