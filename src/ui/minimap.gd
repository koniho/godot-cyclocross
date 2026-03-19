# minimap.gd
# Draws the actual course shape from track points and shows rider positions.
extends Control

const MAP_PAD := 6.0

var _course: Node2D = null
var _track_pts: PackedVector2Array = PackedVector2Array()
var _world_min := Vector2.ZERO
var _world_max := Vector2(1, 1)

func _ready() -> void:
	_course = get_tree().get_first_node_in_group("course")
	if _course and _course.has_method("get_track_points"):
		_track_pts = _course.get_track_points()
		_compute_bounds()

func _compute_bounds() -> void:
	if _track_pts.is_empty():
		return
	var mn := _track_pts[0]
	var mx := _track_pts[0]
	for p in _track_pts:
		mn.x = minf(mn.x, p.x)
		mn.y = minf(mn.y, p.y)
		mx.x = maxf(mx.x, p.x)
		mx.y = maxf(mx.y, p.y)
	# Add margin so track doesn't touch minimap edges
	var margin := (mx - mn) * 0.08
	_world_min = mn - margin
	_world_max = mx + margin

func _process(_delta: float) -> void:
	# Re-fetch track points in case course was rebuilt (editor testing)
	if _course and _course.has_method("get_track_points"):
		var pts: PackedVector2Array = _course.get_track_points()
		if pts.size() != _track_pts.size():
			_track_pts = pts
			_compute_bounds()
	queue_redraw()

func _world_to_map(wp: Vector2) -> Vector2:
	var draw_w := size.x - MAP_PAD * 2.0
	var draw_h := size.y - MAP_PAD * 2.0
	var world_size := _world_max - _world_min
	if world_size.x < 1.0 or world_size.y < 1.0:
		return Vector2.ZERO
	var s := minf(draw_w / world_size.x, draw_h / world_size.y)
	var ox := MAP_PAD + (draw_w - world_size.x * s) * 0.5
	var oy := MAP_PAD + (draw_h - world_size.y * s) * 0.5
	return Vector2(ox + (wp.x - _world_min.x) * s,
				   oy + (wp.y - _world_min.y) * s)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.6), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.7, 0.7, 0.7, 0.5), false)

	if _track_pts.is_empty():
		return

	var n := _track_pts.size()

	for i in n:
		var a := _world_to_map(_track_pts[i])
		var b := _world_to_map(_track_pts[(i + 1) % n])
		draw_line(a, b, Color(0.65, 0.50, 0.28), 3.0)

	draw_circle(_world_to_map(_track_pts[0]), 3.0, Color(1.0, 1.0, 1.0))

	var riders := get_tree().get_nodes_in_group("riders")
	for rider in riders:
		if not _course:
			continue
		var lp: Vector2 = _course.to_local(rider.global_position)
		var mp := _world_to_map(lp)
		var col := Color(0.2, 0.9, 1.0) if rider.is_in_group("player") else Color(1.0, 0.3, 0.3)
		draw_circle(mp, 4.0, col)
