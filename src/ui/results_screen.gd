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
