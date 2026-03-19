# editor_camera.gd
# Pan/zoom camera for the course editor.
# Arrow keys to pan, +/- to zoom, middle-mouse drag + scroll wheel also supported.
extends Camera2D

const ZOOM_MIN := 0.1
const ZOOM_MAX := 4.0
const ZOOM_STEP := 0.1
const PAN_SPEED := 600.0

var _panning := false

func _ready() -> void:
	zoom = Vector2(0.6, 0.6)
	position = Vector2(800, 600)

func _process(delta: float) -> void:
	# Arrow key panning
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		pan.y += 1.0
	if pan != Vector2.ZERO:
		position += pan.normalized() * PAN_SPEED * delta / zoom.x

	# +/- zoom
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):
		_apply_zoom(ZOOM_STEP * delta * 3.0)
	if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
		_apply_zoom(-ZOOM_STEP * delta * 3.0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				_panning = event.pressed
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_apply_zoom(ZOOM_STEP)
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_apply_zoom(-ZOOM_STEP)
					get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and _panning:
		position -= event.relative / zoom
		get_viewport().set_input_as_handled()

func _apply_zoom(step: float) -> void:
	var new_z := clampf(zoom.x + step, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(new_z, new_z)
