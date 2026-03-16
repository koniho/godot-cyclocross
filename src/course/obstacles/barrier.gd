# barrier.gd
class_name Barrier
extends Area2D

signal hop_attempted(rider: Node2D, result: String)

@export var detection_distance: float = 80.0
@export var hop_window_start: float = 50.0
@export var hop_window_end: float = 12.0
@export var perfect_window_start: float = 25.0
@export var perfect_window_end: float = 15.0

var approaching_riders: Dictionary = {}

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(_delta):
	for rider in approaching_riders:
		if is_instance_valid(rider):
			approaching_riders[rider] = _get_approach_distance(rider)

func _get_approach_distance(rider: Node2D) -> float:
	var to_rider = rider.global_position - global_position
	var forward = Vector2.RIGHT.rotated(rotation)
	return -to_rider.dot(forward)

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
	return result

func _on_body_entered(body: Node2D):
	if body.is_in_group("riders"):
		approaching_riders[body] = _get_approach_distance(body)
		body.approaching_barrier = self

func _on_body_exited(body: Node2D):
	if body.is_in_group("riders"):
		approaching_riders.erase(body)
		if body.approaching_barrier == self:
			body.approaching_barrier = null
