# hud.gd
extends CanvasLayer

@onready var stamina_bar: ProgressBar = $Control/StaminaBar
@onready var position_label: Label = $Control/PositionLabel
@onready var lap_label: Label = $Control/LapLabel
@onready var countdown_label: Label = $Control/CountdownLabel

var player: Node2D = null

func _ready():
	GameManager.race_countdown_tick.connect(_on_countdown_tick)
	GameManager.race_started.connect(_on_race_started)
	countdown_label.visible = false

func _process(_delta):
	if player:
		stamina_bar.value = player.stamina
		stamina_bar.max_value = player.max_stamina

func set_player(rider: Node2D):
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
