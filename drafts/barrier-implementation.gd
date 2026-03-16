# barrier.gd
# Barrier obstacle with timing windows for bunny hops
# Attach to Area2D with detection and collision zones

class_name Barrier
extends Area2D

signal hop_attempted(rider: Node2D, result: String)

@export_group("Timing Windows (pixels from barrier)")
## Distance at which rider can start attempting hop
@export var detection_distance: float = 80.0
## Earliest point a hop will succeed
@export var hop_window_start: float = 50.0
## Latest point a hop will succeed (too close = crash)
@export var hop_window_end: float = 12.0
## Window for "perfect" timing bonus
@export var perfect_window_start: float = 25.0
@export var perfect_window_end: float = 15.0

@export_group("Visuals")
@export var barrier_height: float = 40.0  # For collision/visual reference

# Track approaching riders
var approaching_riders: Dictionary = {}  # rider -> distance

@onready var detection_zone: CollisionShape2D = $DetectionZone
@onready var collision_zone: CollisionShape2D = $CollisionZone

func _ready():
	# Set up detection zone size based on detection_distance
	if detection_zone and detection_zone.shape is RectangleShape2D:
		var shape = detection_zone.shape as RectangleShape2D
		shape.size.x = detection_distance * 2
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(_delta):
	# Update distances for all approaching riders
	for rider in approaching_riders:
		if is_instance_valid(rider):
			approaching_riders[rider] = _get_approach_distance(rider)

func _get_approach_distance(rider: Node2D) -> float:
	# Calculate distance along approach vector (not just raw distance)
	# This accounts for angle of approach
	var to_rider = rider.global_position - global_position
	var forward = Vector2.RIGHT.rotated(rotation)
	
	# Distance along the approach axis (negative = past barrier)
	var approach_dist = -to_rider.dot(forward)
	return approach_dist

## Called by rider when they press action button
func attempt_hop(rider: Node2D) -> String:
	var dist = approaching_riders.get(rider, 999.0)
	
	var result: String
	
	if dist > hop_window_start:
		result = "too_early"
	elif dist < hop_window_end:
		result = "too_late"
	elif dist >= perfect_window_end and dist <= perfect_window_start:
		result = "perfect"
	else:
		result = "good"
	
	hop_attempted.emit(rider, result)
	
	# Visual/audio feedback based on result
	match result:
		"perfect":
			_flash_perfect()
		"good":
			_flash_good()
		"too_late":
			_shake_barrier()
	
	return result

func _on_body_entered(body: Node2D):
	if body is Rider:
		approaching_riders[body] = _get_approach_distance(body)
		body.approaching_barrier = self

func _on_body_exited(body: Node2D):
	if body is Rider:
		approaching_riders.erase(body)
		if body.approaching_barrier == self:
			body.approaching_barrier = null

# --- VISUAL FEEDBACK ---

func _flash_perfect():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.5, 1.0, 0.5), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)

func _flash_good():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.8, 1.0, 0.8), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func _shake_barrier():
	var original_pos = position
	var tween = create_tween()
	for i in range(4):
		var offset = Vector2(randf_range(-3, 3), randf_range(-2, 2))
		tween.tween_property(self, "position", original_pos + offset, 0.03)
	tween.tween_property(self, "position", original_pos, 0.03)

# --- DEBUG ---

func _draw():
	if not Engine.is_editor_hint() and not OS.is_debug_build():
		return
	
	# Draw timing windows for debugging
	var forward = Vector2.RIGHT
	
	# Detection zone
	draw_line(forward * detection_distance, forward * detection_distance + Vector2(0, 30), Color.BLUE, 2)
	
	# Hop window
	draw_line(forward * hop_window_start, forward * hop_window_start + Vector2(0, 25), Color.GREEN, 2)
	draw_line(forward * hop_window_end, forward * hop_window_end + Vector2(0, 25), Color.RED, 2)
	
	# Perfect window
	draw_line(forward * perfect_window_start, forward * perfect_window_start + Vector2(0, 20), Color.YELLOW, 3)
	draw_line(forward * perfect_window_end, forward * perfect_window_end + Vector2(0, 20), Color.YELLOW, 3)
