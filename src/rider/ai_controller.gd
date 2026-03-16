# ai_controller.gd
class_name AIController
extends Node

const TerrainTypes = preload("res://src/course/terrain_types.gd")

@export var rider: Node2D
@export var course: Node2D

@export_group("Skill")
@export var path_accuracy: float = 0.8
@export var hop_skill: float = 0.5
@export var mistake_chance: float = 0.1
@export var base_speed_mult: float = 1.0

@export_group("Rubber Banding")
@export var enable_rubber_band: bool = true
@export var rubber_band_strength: float = 0.1
@export var max_speed_boost: float = 1.15
@export var max_speed_penalty: float = 0.9

var target_point: Vector2 = Vector2.ZERO
var path_progress: float = 0.0
var look_ahead_distance: float = 100.0
var hop_decision_made: bool = false
var will_hop: bool = false

func _ready():
	if not rider:
		rider = get_parent() as Rider
	if rider:
		rider.is_player = false

func _physics_process(delta):
	if not rider or not course:
		return
	if GameManager.state != GameManager.GameState.RACING:
		rider.is_pedaling = false
		return

	_update_path_following()
	_update_steering(delta)
	_update_pedaling()
	_update_barrier_decisions()
	_apply_rubber_banding()

func _update_path_following():
	# Simple: head toward a point ahead on an oval path
	var center = Vector2(640, 360)
	var radius = 250.0
	var angle = rider.global_position.angle_to_point(center) + 0.3
	target_point = center + Vector2.RIGHT.rotated(angle) * radius

func _update_steering(delta):
	var to_target = target_point - rider.global_position
	var target_angle = to_target.angle()
	var angle_diff = wrapf(target_angle - rider.heading, -PI, PI)
	var steer_input = clampf(angle_diff * 2.0, -1.0, 1.0)

	var grip = 0.9
	if rider.course and rider.course.has_method("get_terrain_at"):
		var terrain = rider.course.get_terrain_at(rider.global_position)
		grip = TerrainTypes.PROPERTIES.get(terrain, {}).get("grip", 0.9)

	rider.heading += steer_input * rider.steering_speed * grip * delta

func _update_pedaling():
	rider.is_pedaling = rider.stamina > 20.0

func _update_barrier_decisions():
	if rider.approaching_barrier and not hop_decision_made:
		hop_decision_made = true
		will_hop = randf() < hop_skill

		if not will_hop:
			rider.begin_dismount()

	if will_hop and rider.approaching_barrier:
		var barrier = rider.approaching_barrier
		var dist = rider.global_position.distance_to(barrier.global_position)
		if dist <= 25.0:
			rider.attempt_bunny_hop()

	if not rider.approaching_barrier:
		hop_decision_made = false
		will_hop = false

func _apply_rubber_banding():
	if not enable_rubber_band:
		return
	# Simplified rubber banding - would need course progress tracking
