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
