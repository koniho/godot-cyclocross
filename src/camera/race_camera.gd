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
	if target.is_in_group("riders"):
		target_velocity = target.velocity

	var desired_look_ahead = target_velocity.normalized() * look_ahead_distance
	current_look_ahead = current_look_ahead.lerp(desired_look_ahead, look_ahead_smoothing * delta)

	var target_pos = target.global_position + current_look_ahead
	global_position = global_position.lerp(target_pos, smooth_speed * delta)
	offset = shake_offset

func _update_zoom(delta):
	if not target.is_in_group("riders"):
		return

	var speed_ratio = clampf(target.current_speed / target.max_speed, 0.0, 1.0)
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
