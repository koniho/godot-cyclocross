# race_camera.gd
# Dynamic camera with look-ahead, zoom, and screen shake
# Attach to Camera2D node

class_name RaceCamera
extends Camera2D

@export_group("Follow")
@export var target: Node2D
@export var smooth_speed: float = 5.0
@export var look_ahead_distance: float = 120.0
@export var look_ahead_smoothing: float = 3.0

@export_group("Zoom")
@export var zoom_min: Vector2 = Vector2(0.7, 0.7)  # Zoomed out (high speed)
@export var zoom_max: Vector2 = Vector2(1.0, 1.0)  # Zoomed in (low speed)
@export var zoom_speed: float = 2.0

@export_group("Shake")
@export var shake_decay: float = 5.0

# Runtime
var current_look_ahead: Vector2 = Vector2.ZERO
var shake_intensity: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO
var target_zoom: Vector2 = Vector2.ONE

func _ready():
	# Ensure camera is current
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
	# Calculate look-ahead based on target velocity
	var target_velocity = Vector2.ZERO
	if target is Rider:
		target_velocity = target.velocity
	elif target.has_method("get_velocity"):
		target_velocity = target.get_velocity()
	
	# Smooth look-ahead
	var desired_look_ahead = target_velocity.normalized() * look_ahead_distance
	current_look_ahead = current_look_ahead.lerp(desired_look_ahead, look_ahead_smoothing * delta)
	
	# Target position with look-ahead
	var target_pos = target.global_position + current_look_ahead
	
	# Smooth follow
	global_position = global_position.lerp(target_pos, smooth_speed * delta)
	
	# Apply shake offset
	offset = shake_offset

func _update_zoom(delta):
	if not target is Rider:
		return
	
	var rider = target as Rider
	var speed_ratio = rider.current_speed / rider.max_speed
	speed_ratio = clampf(speed_ratio, 0.0, 1.0)
	
	# Zoom out at high speed for better visibility
	target_zoom = zoom_max.lerp(zoom_min, speed_ratio)
	
	# Smooth zoom transition
	zoom = zoom.lerp(target_zoom, zoom_speed * delta)

func _update_shake(delta):
	if shake_intensity > 0:
		# Generate random offset
		shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		
		# Decay shake
		shake_intensity = maxf(0, shake_intensity - shake_decay * delta * shake_intensity)
	else:
		shake_offset = Vector2.ZERO

## Trigger screen shake
func shake(intensity: float = 5.0, _duration: float = 0.2):
	# Duration is implicit via decay rate
	shake_intensity = maxf(shake_intensity, intensity)

## Instant camera snap (for respawns, etc.)
func snap_to_target():
	if target:
		global_position = target.global_position
		current_look_ahead = Vector2.ZERO

## Focus on a specific point temporarily
func focus_point(point: Vector2, duration: float = 1.0):
	var original_target = target
	target = null
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", point, 0.3)
	tween.tween_interval(duration)
	tween.tween_callback(func(): target = original_target)

## Zoom to specific level temporarily
func zoom_to(new_zoom: Vector2, duration: float = 0.5):
	var tween = create_tween()
	tween.tween_property(self, "zoom", new_zoom, duration * 0.5)
	tween.tween_interval(duration)
	tween.tween_property(self, "zoom", target_zoom, duration * 0.5)

# --- RACE EVENTS ---

## Called at race start - dramatic zoom
func race_start_sequence():
	zoom = Vector2(1.5, 1.5)  # Start zoomed in
	var tween = create_tween()
	tween.tween_property(self, "zoom", Vector2.ONE, 1.5).set_ease(Tween.EASE_OUT)

## Called at finish - follow winner
func race_finish_sequence(winner: Node2D):
	target = winner
	zoom_to(Vector2(1.3, 1.3), 2.0)

## Sprint zone - pull back for drama
func enter_sprint_zone():
	var tween = create_tween()
	tween.tween_property(self, "zoom", zoom_min * 0.9, 0.5)

func exit_sprint_zone():
	# Return to normal zoom behavior
	pass  # _update_zoom will handle it
