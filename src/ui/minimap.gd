# minimap.gd
# Draws the actual course shape from TRACK_PTS and shows rider positions.
extends Control

const WORLD_MIN := Vector2(60.0,   60.0)
const WORLD_MAX := Vector2(1710.0, 1170.0)
const MAP_PAD   := 6.0

var _course: Node2D = null
var _track_pts: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	_course = get_tree().get_first_node_in_group("course")
	if _course and _course.has_method("get_track_points"):
		_track_pts = _course.get_track_points()

func _process(_delta: float) -> void:
	queue_redraw()

func _world_to_map(wp: Vector2) -> Vector2:
	var draw_w := size.x - MAP_PAD * 2.0
	var draw_h := size.y - MAP_PAD * 2.0
	var s := minf(draw_w / (WORLD_MAX.x - WORLD_MIN.x),
	              draw_h / (WORLD_MAX.y - WORLD_MIN.y))
	var ox := MAP_PAD + (draw_w - (WORLD_MAX.x - WORLD_MIN.x) * s) * 0.5
	var oy := MAP_PAD + (draw_h - (WORLD_MAX.y - WORLD_MIN.y) * s) * 0.5
	return Vector2(ox + (wp.x - WORLD_MIN.x) * s,
	               oy + (wp.y - WORLD_MIN.y) * s)

func _draw() -> void:
	# Background + border
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.6), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.7, 0.7, 0.7, 0.5), false)

	if _track_pts.is_empty():
		return

	var n := _track_pts.size()

	# Track centre-line
	for i in n:
		var a := _world_to_map(_track_pts[i])
		var b := _world_to_map(_track_pts[(i + 1) % n])
		draw_line(a, b, Color(0.65, 0.50, 0.28), 3.0)

	# Start/finish marker
	draw_circle(_world_to_map(_track_pts[0]), 3.0, Color(1.0, 1.0, 1.0))

	# Riders (player = cyan, AI = red)
	var riders := get_tree().get_nodes_in_group("riders")
	for rider in riders:
		if not _course:
			continue
		var lp: Vector2 = _course.to_local(rider.global_position)
		var mp := _world_to_map(lp)
		var col := Color(0.2, 0.9, 1.0) if rider.is_in_group("player") else Color(1.0, 0.3, 0.3)
		draw_circle(mp, 4.0, col)
