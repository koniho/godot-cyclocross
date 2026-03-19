# title_screen.gd
extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var editor_button: Button = $VBoxContainer/EditorButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready():
	start_button.grab_focus()
	start_button.pressed.connect(_on_start_pressed)
	editor_button.pressed.connect(_on_editor_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed():
	GameManager.start_race("course_01")

func _on_editor_pressed():
	GameManager.open_editor()

func _on_quit_pressed():
	get_tree().quit()
