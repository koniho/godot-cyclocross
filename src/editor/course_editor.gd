# course_editor.gd
# Runtime course editor — click to place/drag track waypoints, terrain zones,
# barriers; live preview via CourseBuilder.rebuild().
extends Node2D

enum Tool { SELECT, ADD_POINT, INSERT_POINT, MUD_ZONE, SAND_ZONE, BARRIER, DELETE }

const GRAB_RADIUS := 40.0
const DEFAULT_MUD_HALF := Vector2(68, 34)
const DEFAULT_SAND_HALF := Vector2(65, 32)

var current_tool: Tool = Tool.SELECT
var course_data: CourseData = null

var _dragging := false
var _drag_idx := -1
var _drag_type := ""  # "track", "mud", "sand"
var _selected_pt := -1  # currently selected track point index
var _undo_stack: Array = []
var _undo_max := 50

@onready var course_builder: Node2D = $World/CourseBuilder
@onready var world: Node2D = $World
@onready var overlay: Node2D = $World/EditorOverlay
@onready var camera: Camera2D = $World/EditorCamera
@onready var status_label: Label = $UI/StatusBar
@onready var tool_label: Label = $UI/ToolBar/ToolLabel

func _input(event: InputEvent) -> void:
	# Always process drag motion and release — even if mouse is over UI
	if _dragging:
		if event is InputEventMouseMotion:
			_handle_drag(_screen_to_world(event))
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_dragging = false
			_drag_idx = -1
			_push_undo()
			course_builder.rebuild()
			get_viewport().set_input_as_handled()
			return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_handle_key(event)
		return

	if not (event is InputEventMouse):
		return

	var world_pos: Vector2 = _screen_to_world(event)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click(event, world_pos)

func _handle_key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_1: _set_tool(Tool.SELECT)
		KEY_2: _set_tool(Tool.ADD_POINT)
		KEY_3: _set_tool(Tool.INSERT_POINT)
		KEY_4: _set_tool(Tool.MUD_ZONE)
		KEY_5: _set_tool(Tool.SAND_ZONE)
		KEY_6: _set_tool(Tool.BARRIER)
		KEY_7: _set_tool(Tool.DELETE)
		KEY_Z:
			if event.ctrl_pressed or event.meta_pressed:
				_undo()
		KEY_S:
			if event.ctrl_pressed or event.meta_pressed:
				_save_course()
		KEY_T:
			if event.ctrl_pressed or event.meta_pressed:
				_test_course()
		KEY_BRACKETLEFT:
			_adjust_width(-10.0)
		KEY_BRACKETRIGHT:
			_adjust_width(10.0)
		KEY_E:
			_cycle_elevation()

func _handle_click(_event: InputEventMouseButton, pos: Vector2) -> void:
	match current_tool:
		Tool.SELECT:
			_try_grab(pos)
		Tool.ADD_POINT:
			_add_point(pos)
		Tool.INSERT_POINT:
			_insert_point(pos)
		Tool.MUD_ZONE:
			_add_zone("mud", pos)
		Tool.SAND_ZONE:
			_add_zone("sand", pos)
		Tool.BARRIER:
			_add_barrier_at(pos)
		Tool.DELETE:
			_delete_nearest(pos)

func _handle_drag(pos: Vector2) -> void:
	if _drag_type == "track" and _drag_idx >= 0:
		course_data.track_points[_drag_idx] = pos
	elif _drag_type == "mud" and _drag_idx >= 0:
		course_data.mud_zones[_drag_idx].center = pos
	elif _drag_type == "sand" and _drag_idx >= 0:
		course_data.sand_zones[_drag_idx].center = pos
	_update_status()

# ── Tool actions ──────────────────────────────────────────────────────────────

func _try_grab(pos: Vector2) -> void:
	# Check track points first
	for i in course_data.track_points.size():
		if pos.distance_to(course_data.track_points[i]) < GRAB_RADIUS:
			_dragging = true
			_drag_idx = i
			_drag_type = "track"
			_selected_pt = i
			_update_status()
			return
	# Check mud zones
	for i in course_data.mud_zones.size():
		if pos.distance_to(course_data.mud_zones[i].center) < GRAB_RADIUS * 2:
			_dragging = true
			_drag_idx = i
			_drag_type = "mud"
			return
	# Check sand zones
	for i in course_data.sand_zones.size():
		if pos.distance_to(course_data.sand_zones[i].center) < GRAB_RADIUS * 2:
			_dragging = true
			_drag_idx = i
			_drag_type = "sand"
			return

func _add_point(pos: Vector2) -> void:
	course_data.track_points.append(pos)
	_push_undo()
	course_builder.rebuild()
	queue_redraw()
	_update_status()

func _insert_point(pos: Vector2) -> void:
	var best_i := _nearest_segment(pos)
	if best_i < 0:
		return
	# Insert after best_i
	var pts := Array(course_data.track_points)
	pts.insert(best_i + 1, pos)
	course_data.track_points = PackedVector2Array(pts)
	# Adjust barrier indices
	for bp in course_data.barrier_pairs:
		if bp.idx_a > best_i:
			bp.idx_a += 1
		if bp.idx_b > best_i:
			bp.idx_b += 1
	# Adjust bridge indices
	if course_data.bridge.size() > 0:
		if course_data.bridge.start_idx > best_i:
			course_data.bridge.start_idx += 1
		if course_data.bridge.end_idx > best_i:
			course_data.bridge.end_idx += 1
	_push_undo()
	course_builder.rebuild()
	queue_redraw()
	_update_status()

func _add_zone(zone_type: String, pos: Vector2) -> void:
	var half := DEFAULT_MUD_HALF if zone_type == "mud" else DEFAULT_SAND_HALF
	var zone := {"center": pos, "half": half}
	if zone_type == "mud":
		course_data.mud_zones.append(zone)
	else:
		course_data.sand_zones.append(zone)
	_push_undo()
	course_builder.rebuild()
	_update_status()

func _add_barrier_at(pos: Vector2) -> void:
	var seg_i := _nearest_segment(pos)
	if seg_i < 0:
		return
	var n := course_data.track_points.size()
	var next_i := (seg_i + 1) % n
	# Project pos onto segment to get t
	var a: Vector2 = course_data.track_points[seg_i]
	var b: Vector2 = course_data.track_points[next_i]
	var seg: Vector2 = b - a
	var t := clampf((pos - a).dot(seg) / seg.length_squared(), 0.1, 0.9)
	course_data.barrier_pairs.append({"idx_a": seg_i, "idx_b": next_i, "t": t})
	_push_undo()
	course_builder.rebuild()
	_update_status()

func _delete_nearest(pos: Vector2) -> void:
	# Try track points
	for i in course_data.track_points.size():
		if pos.distance_to(course_data.track_points[i]) < GRAB_RADIUS:
			var pts := Array(course_data.track_points)
			pts.remove_at(i)
			course_data.track_points = PackedVector2Array(pts)
			# Adjust barrier indices: shift down, remove any that referenced deleted point
			var valid_pairs: Array = []
			for bp in course_data.barrier_pairs:
				var ia: int = bp.idx_a
				var ib: int = bp.idx_b
				if ia == i or ib == i:
					continue
				if ia > i:
					ia -= 1
				if ib > i:
					ib -= 1
				valid_pairs.append({"idx_a": ia, "idx_b": ib, "t": bp.t})
			course_data.barrier_pairs = valid_pairs
			# Adjust bridge indices
			if course_data.bridge.size() > 0:
				var si: int = course_data.bridge.start_idx
				var ei: int = course_data.bridge.end_idx
				if si == i or ei == i:
					course_data.bridge = {}
				else:
					if si > i:
						course_data.bridge.start_idx = si - 1
					if ei > i:
						course_data.bridge.end_idx = ei - 1
			_push_undo()
			course_builder.rebuild()
			queue_redraw()
			_update_status()
			return
	# Try mud zones
	for i in course_data.mud_zones.size():
		if pos.distance_to(course_data.mud_zones[i].center) < GRAB_RADIUS * 2:
			course_data.mud_zones.remove_at(i)
			_push_undo()
			course_builder.rebuild()
			_update_status()
			return
	# Try sand zones
	for i in course_data.sand_zones.size():
		if pos.distance_to(course_data.sand_zones[i].center) < GRAB_RADIUS * 2:
			course_data.sand_zones.remove_at(i)
			_push_undo()
			course_builder.rebuild()
			_update_status()
			return
	# Try barrier pairs — check midpoint
	for i in course_data.barrier_pairs.size():
		var bp: Dictionary = course_data.barrier_pairs[i]
		var a: Vector2 = course_data.track_points[bp.idx_a]
		var b: Vector2 = course_data.track_points[bp.idx_b]
		var mid: Vector2 = a.lerp(b, bp.t)
		if pos.distance_to(mid) < GRAB_RADIUS * 3:
			course_data.barrier_pairs.remove_at(i)
			_push_undo()
			course_builder.rebuild()
			_update_status()
			return

# ── Helpers ───────────────────────────────────────────────────────────────────

func _nearest_segment(pos: Vector2) -> int:
	var pts := course_data.track_points
	var n := pts.size()
	if n < 2:
		return -1
	var best_i := 0
	var best_d := INF
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var d := _point_to_segment_dist(pos, a, b)
		if d < best_d:
			best_d = d
			best_i = i
	return best_i

func _point_to_segment_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var seg: Vector2 = b - a
	var len_sq := seg.length_squared()
	if len_sq < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(seg) / len_sq, 0.0, 1.0)
	return p.distance_to(a + seg * t)

func _screen_to_world(_event: InputEvent) -> Vector2:
	# CourseBuilder is a direct child of World at (0,0) — its local space IS course space.
	# get_local_mouse_position() handles camera, zoom, and World's isometric scale.
	return course_builder.get_local_mouse_position()

# ── Per-point properties ──────────────────────────────────────────────────────

func _adjust_width(delta_w: float) -> void:
	if _selected_pt < 0 or _selected_pt >= course_data.track_points.size():
		return
	var w: float = course_data.track_widths[_selected_pt] + delta_w
	course_data.track_widths[_selected_pt] = clampf(w, 20.0, 200.0)
	_push_undo()
	course_builder.rebuild()
	_update_status()

func _cycle_elevation() -> void:
	if _selected_pt < 0 or _selected_pt >= course_data.track_points.size():
		return
	var e: int = course_data.track_elevations[_selected_pt]
	# Cycle: 0 → 1 → -1 → 0
	if e == 0:
		e = 1
	elif e == 1:
		e = -1
	else:
		e = 0
	course_data.track_elevations[_selected_pt] = e
	_push_undo()
	course_builder.rebuild()
	_update_status()

# ── Undo ──────────────────────────────────────────────────────────────────────

func _push_undo() -> void:
	_undo_stack.append(course_data.to_dict())
	if _undo_stack.size() > _undo_max:
		_undo_stack.pop_front()

func _undo() -> void:
	if _undo_stack.size() < 2:
		return
	_undo_stack.pop_back()  # current state
	var prev: Dictionary = _undo_stack.back()
	course_data = CourseData.from_dict(prev)
	course_builder.course_data = course_data
	course_builder.rebuild()
	queue_redraw()
	_update_status()

# ── Save / Test ───────────────────────────────────────────────────────────────

func _save_course() -> void:
	DirAccess.make_dir_recursive_absolute("user://courses")
	var filename := course_data.id if course_data.id != "" else "untitled"
	var path := "user://courses/%s.json" % filename
	course_data.save_json(path)
	status_label.text = "Saved: %s" % path

func _test_course() -> void:
	GameManager.editor_course_data = course_data
	get_tree().change_scene_to_file("res://scenes/test_arena.tscn")

# ── Drawing (editor overlay) ─────────────────────────────────────────────────

func _ready() -> void:
	if course_data == null:
		course_data = course_builder._make_default_data()
	course_builder.course_data = course_data
	course_builder.rebuild()
	_push_undo()
	_update_status()
	# Connect overlay drawing
	overlay.draw.connect(_draw_overlay)

func _process(_delta: float) -> void:
	overlay.queue_redraw()

func _draw_overlay() -> void:
	var pts := course_data.track_points
	var n := pts.size()
	if n < 2:
		return

	# Draw track centerline
	for i in n:
		overlay.draw_line(pts[i], pts[(i + 1) % n], Color(1.0, 1.0, 1.0, 0.4), 2.0)

	# Draw point handles with elevation indicators
	for i in n:
		var p: Vector2 = pts[i]
		var is_sel := (_selected_pt == i)
		var col := Color.YELLOW if is_sel else Color.WHITE
		overlay.draw_circle(p, 8.0, col)
		# Elevation indicator
		var elev: int = course_data.track_elevations[i] if i < course_data.track_elevations.size() else 0
		var label := str(i)
		if elev > 0:
			label += "^"   # uphill
			overlay.draw_circle(p, 12.0, Color(0.8, 0.3, 0.2, 0.5))
		elif elev < 0:
			label += "v"   # downhill
			overlay.draw_circle(p, 12.0, Color(0.2, 0.5, 0.8, 0.5))
		overlay.draw_string(ThemeDB.fallback_font, p + Vector2(10, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	# Draw mud/sand zone centers
	for i in course_data.mud_zones.size():
		var c: Vector2 = course_data.mud_zones[i].center
		overlay.draw_circle(c, 14.0, Color(0.4, 0.25, 0.1, 0.7))
		overlay.draw_string(ThemeDB.fallback_font, c + Vector2(16, 5), "M", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.5, 0.2))

	for i in course_data.sand_zones.size():
		var c: Vector2 = course_data.sand_zones[i].center
		overlay.draw_circle(c, 14.0, Color(0.7, 0.6, 0.3, 0.7))
		overlay.draw_string(ThemeDB.fallback_font, c + Vector2(16, 5), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.8, 0.4))

	# Draw barrier pair indicators
	for bp in course_data.barrier_pairs:
		if bp.idx_a < n and bp.idx_b < n:
			var mid: Vector2 = pts[bp.idx_a].lerp(pts[bp.idx_b], bp.t)
			overlay.draw_circle(mid, 12.0, Color(1.0, 0.3, 0.3, 0.8))
			overlay.draw_string(ThemeDB.fallback_font, mid + Vector2(14, 5), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.RED)

# ── UI ────────────────────────────────────────────────────────────────────────

func _set_tool(t: int) -> void:
	current_tool = t as Tool
	var names := ["Select [1]", "Add Point [2]", "Insert Point [3]",
		"Mud Zone [4]", "Sand Zone [5]", "Barrier [6]", "Delete [7]"]
	tool_label.text = names[t]
	_update_status()

func _update_status() -> void:
	var pts := course_data.track_points.size()
	var mud := course_data.mud_zones.size()
	var sand := course_data.sand_zones.size()
	var bp := course_data.barrier_pairs.size()
	var info := "%d pts | %d mud | %d sand | %d barriers" % [pts, mud, sand, bp]
	if _selected_pt >= 0 and _selected_pt < pts:
		var w: float = course_data.track_widths[_selected_pt]
		var e: int = course_data.track_elevations[_selected_pt]
		var elev_name := "flat"
		if e > 0:
			elev_name = "uphill"
		elif e < 0:
			elev_name = "downhill"
		info += "  |  pt %d: width=%.0f [/]  elev=%s [E]" % [_selected_pt, w, elev_name]
	status_label.text = info

# ── Button callbacks (connected from scene) ───────────────────────────────────

func _on_new_pressed() -> void:
	course_data = CourseData.new()
	course_data.id = "new_course"
	course_data.display_name = "New Course"
	course_data.track_points = PackedVector2Array()
	course_builder.course_data = course_data
	course_builder.rebuild()
	_undo_stack.clear()
	_push_undo()
	_update_status()

func _on_save_pressed() -> void:
	_save_course()

func _on_test_pressed() -> void:
	_test_course()

func _on_load_pressed() -> void:
	var dir := DirAccess.open("user://courses")
	if not dir:
		status_label.text = "No saved courses found"
		return
	# Load the most recently modified JSON file
	var latest_path := ""
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			latest_path = "user://courses/" + file_name
		file_name = dir.get_next()
	dir.list_dir_end()

	if latest_path == "":
		status_label.text = "No .json courses found"
		return

	var loaded := CourseData.load_json(latest_path)
	if loaded == null:
		status_label.text = "Failed to load: %s" % latest_path
		return

	course_data = loaded
	course_builder.course_data = course_data
	course_builder.rebuild()
	_undo_stack.clear()
	_push_undo()
	_update_status()
	status_label.text = "Loaded: %s" % latest_path

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")
