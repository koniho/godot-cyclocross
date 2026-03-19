# course_builder.gd
# Builds a cyclocross course from a CourseData resource.
# If no course_data is assigned, uses built-in defaults.
extends Node2D

const TerrainTypes = preload("res://src/course/terrain_types.gd")
const BarrierScript = preload("res://src/course/obstacles/barrier.gd")

const HALF_TRACK           := 80.0
const BARRIER_W            := 12.0
const STRIPE_LEN           := 32.0
const BARRIER_PAIR_SPACING := 160.0

const C_DIRT    := Color(0.48, 0.30, 0.15)
const C_INFIELD := Color(0.22, 0.42, 0.18)
const C_RED     := Color(0.88, 0.12, 0.10)
const C_WHITE   := Color(0.95, 0.95, 0.92)
const C_MUD     := Color(0.22, 0.14, 0.06)
const C_SAND    := Color(0.78, 0.68, 0.40)
const C_BRIDGE  := Color(0.50, 0.52, 0.56)
const C_PILLAR  := Color(0.38, 0.40, 0.43)

const TAPE_POLE_SPACING := 68.0
const TAPE_POLE_HEIGHT  := 26.0
const TAPE_WIDTH        := 2.5
const TAPE_POLE_WIDTH   := 3.5
const TAPE_ANIM_RADIUS  := 220.0
const C_TAPE := Color(1.0, 0.88, 0.05)
const C_POLE := Color(0.18, 0.18, 0.20)

const BRIDGE_VIS_SCALE  := 3.0
const BRIDGE_HALF_WIDTH := 90.0
const VIS_SCALE         := 3.0  # visual height multiplier for ground elevation

@export var course_data: CourseData = null

signal lap_crossed(rider: Node2D)

var _outer := PackedVector2Array()
var _inner := PackedVector2Array()
var _lap_cooldowns: Dictionary = {}
var _tape_segments: Array = []

# Cached from course_data for fast access
var _track_pts: PackedVector2Array = PackedVector2Array()
var _track_widths: PackedFloat32Array = PackedFloat32Array()
var _track_heights: PackedFloat32Array = PackedFloat32Array()
var _track_cambers: PackedFloat32Array = PackedFloat32Array()
var _mud_zones: Array = []
var _sand_zones: Array = []
var _barrier_pairs: Array = []
var _bridge: Dictionary = {}

func _ready() -> void:
	add_to_group("course")
	if course_data == null:
		course_data = _make_default_data()
	_apply_data()
	_build_all()

func _process(delta: float) -> void:
	for rider in _lap_cooldowns.keys():
		_lap_cooldowns[rider] -= delta
		if _lap_cooldowns[rider] <= 0.0:
			_lap_cooldowns.erase(rider)

func rebuild() -> void:
	_clear_visuals()
	_apply_data()
	_build_all()

func _apply_data() -> void:
	_track_pts = course_data.track_points
	var n := _track_pts.size()
	# Ensure widths array matches track_points size
	if course_data.track_widths.size() != n:
		course_data.track_widths.resize(n)
		for i in n:
			if course_data.track_widths[i] <= 0.0:
				course_data.track_widths[i] = HALF_TRACK
	_track_widths = course_data.track_widths
	# Ensure heights array matches
	if course_data.track_heights.size() != n:
		course_data.track_heights.resize(n)
	_track_heights = course_data.track_heights
	# Ensure cambers array matches
	if course_data.track_cambers.size() != n:
		course_data.track_cambers.resize(n)
	_track_cambers = course_data.track_cambers
	_mud_zones = course_data.mud_zones
	_sand_zones = course_data.sand_zones
	_barrier_pairs = course_data.barrier_pairs
	_bridge = course_data.bridge

func _build_all() -> void:
	_compute_edges()
	_build_visuals()
	_build_course_tape()
	_build_barriers()
	_build_lap_trigger()

func _clear_visuals() -> void:
	_tape_segments.clear()
	_lap_cooldowns.clear()
	for child in get_children():
		child.queue_free()

# ── Geometry ──────────────────────────────────────────────────────────────────

func _compute_edges() -> void:
	var pts := _track_pts
	var n := pts.size()
	_outer.resize(n)
	_inner.resize(n)
	for i in n:
		var prev := pts[(i - 1 + n) % n]
		var nxt  := pts[(i + 1) % n]
		var dir  := (nxt - prev).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var hw: float = _track_widths[i] if i < _track_widths.size() else HALF_TRACK
		_outer[i] = pts[i] + perp * hw
		_inner[i] = pts[i] - perp * hw

# ── Visuals ───────────────────────────────────────────────────────────────────

func _get_height_at_index(i: int) -> float:
	if i < _track_heights.size():
		return _track_heights[i]
	return 0.0

func _height_visual_offset(h: float) -> Vector2:
	return Vector2(0.0, -h * VIS_SCALE)

func _build_visuals() -> void:
	var n := _outer.size()

	# Build track as individual quad segments with height offset and tinting
	for i in n:
		var j := (i + 1) % n
		var h_i := _get_height_at_index(i)
		var h_j := _get_height_at_index(j)
		var avg_h := (h_i + h_j) * 0.5

		# Tint: higher = slightly lighter, lower = normal dirt
		var col := C_DIRT
		if avg_h > 1.0:
			col = C_DIRT.lightened(clampf(avg_h / 120.0 * 0.3, 0.0, 0.3))
		elif avg_h < -1.0:
			col = C_DIRT.darkened(clampf(-avg_h / 120.0 * 0.2, 0.0, 0.2))

		# Compute visual vertices with height offset
		var off_i := _height_visual_offset(h_i)
		var off_j := _height_visual_offset(h_j)
		var quad := Polygon2D.new()
		quad.color = col
		quad.polygon = PackedVector2Array([
			_outer[i] + off_i, _outer[j] + off_j,
			_inner[j] + off_j, _inner[i] + off_i
		])
		add_child(quad)

	# Elevation markers: chevrons for uphill, arrows for downhill
	for i in n:
		var j := (i + 1) % n
		var h_i := _get_height_at_index(i)
		var h_j := _get_height_at_index(j)
		var slope := h_j - h_i
		if absf(slope) < 2.0:
			continue
		var center := (_track_pts[i] + _track_pts[j]) * 0.5
		var avg_h := (h_i + h_j) * 0.5
		var vis_center := center + _height_visual_offset(avg_h)
		var dir := (_track_pts[j] - _track_pts[i]).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var marker := Line2D.new()
		marker.width = 2.0
		marker.z_index = 1
		if slope > 0:
			# Uphill chevron pointing in travel direction
			marker.default_color = Color(1.0, 0.6, 0.2, 0.35)
			var tip := vis_center + dir * 8.0
			marker.add_point(vis_center - dir * 6.0 + perp * 12.0)
			marker.add_point(tip)
			marker.add_point(vis_center - dir * 6.0 - perp * 12.0)
		else:
			# Downhill arrow
			marker.default_color = Color(0.3, 0.7, 1.0, 0.35)
			var tip := vis_center + dir * 8.0
			marker.add_point(vis_center + dir * 6.0 + perp * 12.0)
			marker.add_point(tip)
			marker.add_point(vis_center + dir * 6.0 - perp * 12.0)
		add_child(marker)

	var infield := Polygon2D.new()
	infield.name = "Infield"
	infield.color = C_INFIELD
	infield.polygon = _inner
	add_child(infield)

	for zone in _mud_zones:
		_add_terrain_oval(zone.center, zone.half, C_MUD)
	for zone in _sand_zones:
		_add_terrain_oval(zone.center, zone.half, C_SAND)

	if _bridge.size() > 0:
		_build_bridge_visual()

	_add_start_finish()

func _add_terrain_oval(center: Vector2, half: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := float(i) / 24.0 * TAU
		pts.append(center + Vector2(cos(a) * half.x, sin(a) * half.y))
	var poly := Polygon2D.new()
	poly.color = col
	poly.polygon = pts
	add_child(poly)

func _add_start_finish() -> void:
	var h0 := _get_height_at_index(0)
	var off := _height_visual_offset(h0)
	var a := _outer[0] + off
	var b := _inner[0] + off
	var dir  := (b - a).normalized()
	var perp := Vector2(-dir.y, dir.x) * 8.0
	var black := true
	for i in 10:
		var t0 := float(i) / 10.0
		var t1 := float(i + 1) / 10.0
		var pa := a.lerp(b, t0)
		var pb := a.lerp(b, t1)
		var poly := Polygon2D.new()
		poly.color = Color.BLACK if black else Color.WHITE
		poly.polygon = PackedVector2Array([pa - perp, pa + perp, pb + perp, pb - perp])
		add_child(poly)
		black = not black

# ── Course tape ───────────────────────────────────────────────────────────────

func _build_course_tape() -> void:
	_add_tape_boundary(_outer)
	_add_tape_boundary(_inner)

func _add_tape_boundary(edge_pts: PackedVector2Array) -> void:
	var n := edge_pts.size()
	var pole_pos: PackedVector2Array = PackedVector2Array()
	for i in n:
		var a: Vector2 = edge_pts[i]
		var b: Vector2 = edge_pts[(i + 1) % n]
		var seg_len := a.distance_to(b)
		var traveled := 0.0
		while traveled < seg_len - 0.1:
			pole_pos.append(a.lerp(b, traveled / seg_len))
			traveled += TAPE_POLE_SPACING

	var m := pole_pos.size()
	if m < 2:
		return

	var pole_nodes: Array = []
	for i in m:
		var base: Vector2 = pole_pos[i]
		var pole := Line2D.new()
		pole.width         = TAPE_POLE_WIDTH
		pole.default_color = C_POLE
		pole.add_point(base)
		pole.add_point(base + Vector2(0.0, -TAPE_POLE_HEIGHT))
		pole.z_index = 2
		add_child(pole)
		pole_nodes.append(pole)

	for i in m:
		var pa: Vector2 = pole_pos[i]
		var pb: Vector2 = pole_pos[(i + 1) % m]
		var top_a := pa + Vector2(0.0, -TAPE_POLE_HEIGHT)
		var top_b := pb + Vector2(0.0, -TAPE_POLE_HEIGHT)
		var mid   := (top_a + top_b) * 0.5

		var tape := Line2D.new()
		tape.width         = TAPE_WIDTH
		tape.default_color = C_TAPE
		tape.add_point(top_a)
		tape.add_point(mid)
		tape.add_point(top_b)
		tape.z_index = 2
		add_child(tape)

		var seg_center := (pa + pb) * 0.5
		var seg_dir: Vector2 = (pb - pa).normalized()
		var seg_len  := pa.distance_to(pb)

		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask  = 1
		area.position = seg_center
		area.rotation = atan2(seg_dir.y, seg_dir.x)

		var col  := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(seg_len * 1.05, 10.0)
		col.shape = rect
		area.add_child(col)

		var strip := Line2D.new()
		strip.width         = 3.0
		strip.default_color = Color(1.0, 1.0, 0.35, 0.45)
		strip.add_point(pa)
		strip.add_point(pb)
		strip.z_index = 1
		add_child(strip)

		_tape_segments.append({
			"tape":     tape,
			"poles":    [pole_nodes[i], pole_nodes[(i + 1) % m]],
			"center":   seg_center,
			"mid_rest": mid,
			"tween":    null,
		})

		area.body_entered.connect(func(_body: Node2D) -> void:
			animate_tape_at(seg_center))
		add_child(area)

func animate_tape_at(local_pos: Vector2) -> void:
	for seg in _tape_segments:
		var d: float = (seg.center as Vector2).distance_to(local_pos)
		if d <= TAPE_ANIM_RADIUS:
			_animate_tape_segment(seg, 1.0 - d / TAPE_ANIM_RADIUS)

func _animate_tape_segment(seg: Dictionary, strength: float) -> void:
	var tape: Line2D    = seg.tape
	var mid_rest: Vector2 = seg.mid_rest

	if seg.tween != null and (seg.tween as Tween).is_running():
		(seg.tween as Tween).kill()

	var tw := create_tween()
	seg.tween = tw
	var droop := mid_rest + Vector2(0.0, 28.0 * strength)

	tw.tween_method(func(p: Vector2): tape.set_point_position(1, p),
		mid_rest, droop, 0.10)
	tw.tween_method(func(p: Vector2): tape.set_point_position(1, p),
		droop, mid_rest, 0.45)

	for pole: Line2D in seg.poles:
		var tilt := randf_range(-0.25, 0.25) * strength
		var ptw := create_tween()
		ptw.tween_property(pole, "rotation", tilt, 0.08)
		ptw.tween_property(pole, "rotation", 0.0,  0.40)

# ── Bridge ────────────────────────────────────────────────────────────────────

func _get_bridge_endpoints() -> Array:
	if _bridge.size() == 0:
		return []
	var si: int = _bridge.get("start_idx", -1)
	var ei: int = _bridge.get("end_idx", -1)
	if si < 0 or ei < 0 or si >= _track_pts.size() or ei >= _track_pts.size():
		return []
	return [_track_pts[si], _track_pts[ei], _bridge.get("height", 60.0)]

func _build_bridge_visual() -> void:
	var ep := _get_bridge_endpoints()
	if ep.size() == 0:
		return
	var bridge_a: Vector2 = ep[0]
	var bridge_b: Vector2 = ep[1]
	var bridge_height: float = ep[2]

	# Ground heights at bridge start/end for combining
	var si: int = _bridge.get("start_idx", 0)
	var ei: int = _bridge.get("end_idx", 0)
	var gh_start := _get_height_at_index(si)
	var gh_end := _get_height_at_index(ei)

	const N := 14
	var dir: Vector2  = (bridge_b - bridge_a).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	var deck_left  := PackedVector2Array()
	var deck_right := PackedVector2Array()

	for i in N:
		var t    := float(i) / float(N - 1)
		var gp   := bridge_a.lerp(bridge_b, t)
		# Bridge arch on top of interpolated ground height
		var ground_h := lerpf(gh_start, gh_end, t)
		var arch_h := sin(t * PI) * bridge_height
		var total_lift := -(ground_h + arch_h) * BRIDGE_VIS_SCALE
		var ep2  := gp + Vector2(0.0, total_lift)
		deck_left.append(ep2  + perp * HALF_TRACK * 0.92)
		deck_right.append(ep2 - perp * HALF_TRACK * 0.92)

	var deck_poly := PackedVector2Array()
	for p in deck_left:
		deck_poly.append(p)
	for i in range(deck_right.size() - 1, -1, -1):
		deck_poly.append(deck_right[i])
	var deck := Polygon2D.new()
	deck.color   = C_BRIDGE
	deck.polygon = deck_poly
	deck.z_index = 5
	add_child(deck)

	for t: float in [0.15, 0.35, 0.50, 0.65, 0.85]:
		var gp   := bridge_a.lerp(bridge_b, t)
		var ground_h := lerpf(gh_start, gh_end, t)
		var arch_h := sin(t * PI) * bridge_height
		var total_lift := -(ground_h + arch_h) * BRIDGE_VIS_SCALE
		var ep2  := gp + Vector2(0.0, total_lift)
		for sx: float in [-0.5, 0.5]:
			var top := ep2 + perp * (HALF_TRACK * sx)
			var bot := gp  + perp * (HALF_TRACK * sx)
			var post := Line2D.new()
			post.width         = 5.0
			post.default_color = C_PILLAR
			post.add_point(top)
			post.add_point(bot)
			post.z_index = 4
			add_child(post)

	for edge_pts: PackedVector2Array in [deck_left, deck_right]:
		var rail := Line2D.new()
		rail.width         = 4.0
		rail.default_color = C_PILLAR
		for p in edge_pts:
			rail.add_point(p)
		rail.z_index = 6
		add_child(rail)

func _bridge_t(lp: Vector2) -> float:
	var ep := _get_bridge_endpoints()
	if ep.size() == 0:
		return -1.0
	var bridge_a: Vector2 = ep[0]
	var bridge_b: Vector2 = ep[1]
	var seg: Vector2 = bridge_b - bridge_a
	var seg_len := seg.length()
	var seg_dir := seg / seg_len
	var local: Vector2 = lp - bridge_a
	var proj := local.dot(seg_dir)
	if proj < 0.0 or proj > seg_len:
		return -1.0
	if absf(local.cross(seg_dir)) > BRIDGE_HALF_WIDTH:
		return -1.0
	return proj / seg_len

# ── Barriers ──────────────────────────────────────────────────────────────────

func _build_barriers() -> void:
	for pair_data in _barrier_pairs:
		var idx_a: int  = pair_data.get("idx_a", pair_data[0] if pair_data is Array else 0)
		var idx_b: int  = pair_data.get("idx_b", pair_data[1] if pair_data is Array else 0)
		var t: float    = pair_data.get("t", pair_data[2] if pair_data is Array else 0.5)
		if idx_a >= _track_pts.size() or idx_b >= _track_pts.size():
			continue
		var a: Vector2  = _track_pts[idx_a]
		var b: Vector2  = _track_pts[idx_b]
		var mid: Vector2 = a.lerp(b, t)
		var dir: Vector2 = (b - a).normalized()
		_add_barrier(mid - dir * (BARRIER_PAIR_SPACING * 0.5), dir)
		_add_barrier(mid + dir * (BARRIER_PAIR_SPACING * 0.5), dir)

func _add_barrier(center: Vector2, track_dir: Vector2) -> void:
	var barrier := Area2D.new()
	barrier.set_script(BarrierScript)
	barrier.collision_layer = 16
	barrier.collision_mask  = 1
	barrier.position = center
	barrier.rotation = atan2(track_dir.y, track_dir.x)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(HALF_TRACK * 2.2, 80.0)
	col.shape = rect
	barrier.add_child(col)

	var bar := Line2D.new()
	bar.width = 6.0
	bar.default_color = Color.WHITE
	bar.add_point(Vector2(0.0, -HALF_TRACK * 1.05))
	bar.add_point(Vector2(0.0,  HALF_TRACK * 1.05))
	barrier.add_child(bar)

	for sign_y in [-1.0, 1.0]:
		var cap := Line2D.new()
		cap.width = 8.0
		cap.default_color = C_RED
		cap.add_point(Vector2(-6.0, sign_y * HALF_TRACK * 0.9))
		cap.add_point(Vector2( 6.0, sign_y * HALF_TRACK * 0.9))
		barrier.add_child(cap)

	add_child(barrier)

# ── Lap trigger ───────────────────────────────────────────────────────────────

func _build_lap_trigger() -> void:
	var n := _track_pts.size()
	if n < 2:
		return
	var crossing_dir: Vector2 = (_track_pts[0] - _track_pts[n - 1]).normalized()

	var trigger := Area2D.new()
	trigger.name = "LapTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	trigger.position = _track_pts[0]
	trigger.rotation = atan2(crossing_dir.y, crossing_dir.x)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(HALF_TRACK * 2.2, 28.0)
	col.shape = rect
	trigger.add_child(col)

	trigger.body_entered.connect(func(body: Node2D) -> void:
		if not body.is_in_group("riders"):
			return
		if _lap_cooldowns.get(body, 0.0) > 0.0:
			return
		if body.velocity.normalized().dot(crossing_dir) > 0.25:
			_lap_cooldowns[body] = 4.0
			lap_crossed.emit(body))

	add_child(trigger)

# ── Course interface (called by rider) ────────────────────────────────────────

func get_terrain_at(pos: Vector2) -> int:
	var lp := to_local(pos)
	var dist_to_start := lp.distance_to(_track_pts[0])
	if dist_to_start < 60.0:
		return TerrainTypes.Type.PAVEMENT
	for zone in _mud_zones:
		var d: Vector2 = lp - (zone.center as Vector2)
		var half: Vector2 = zone.half
		var nx: float = d.x / half.x
		var ny: float = d.y / half.y
		if nx * nx + ny * ny <= 1.0:
			return TerrainTypes.Type.MUD
	for zone in _sand_zones:
		var d: Vector2 = lp - (zone.center as Vector2)
		var half: Vector2 = zone.half
		var nx: float = d.x / half.x
		var ny: float = d.y / half.y
		if nx * nx + ny * ny <= 1.0:
			return TerrainTypes.Type.SAND
	return TerrainTypes.Type.GRASS

func get_track_points() -> PackedVector2Array:
	return PackedVector2Array(_track_pts)

## Returns the combined ground height + bridge arch height at the given global position.
## Ground height is interpolated from per-point track_heights.
## Bridge arch is added on top if the position is within the bridge zone.
func get_height_at(pos: Vector2) -> float:
	var lp := to_local(pos)
	var ground_h := get_ground_height_at(lp)

	# Add bridge arch on top
	var ep := _get_bridge_endpoints()
	if ep.size() > 0:
		var t: float = _bridge_t(lp)
		if t >= 0.0:
			ground_h += sin(t * PI) * ep[2]

	return ground_h

## Returns interpolated ground height at a position in LOCAL course space.
## Finds the nearest track segment and interpolates the height along it.
func get_ground_height_at(pos: Vector2) -> float:
	var n := _track_pts.size()
	if n < 2:
		return 0.0

	var best_d := INF
	var best_i := 0
	var best_t := 0.0

	for i in n:
		var j := (i + 1) % n
		var a: Vector2 = _track_pts[i]
		var b: Vector2 = _track_pts[j]
		var seg: Vector2 = b - a
		var len_sq := seg.length_squared()
		var t := 0.0
		if len_sq > 0.001:
			t = clampf((pos - a).dot(seg) / len_sq, 0.0, 1.0)
		var closest := a + seg * t
		var d := pos.distance_to(closest)
		if d < best_d:
			best_d = d
			best_i = i
			best_t = t

	var h_i := _get_height_at_index(best_i)
	var h_j := _get_height_at_index((best_i + 1) % n)
	return lerpf(h_i, h_j, best_t)

## Returns interpolated camber at a position in GLOBAL space.
func get_camber_at(pos: Vector2) -> float:
	var lp := to_local(pos)
	var n := _track_pts.size()
	if n < 2:
		return 0.0

	var best_d := INF
	var best_i := 0
	var best_t := 0.0

	for i in n:
		var j := (i + 1) % n
		var a: Vector2 = _track_pts[i]
		var b: Vector2 = _track_pts[j]
		var seg: Vector2 = b - a
		var len_sq := seg.length_squared()
		var t := 0.0
		if len_sq > 0.001:
			t = clampf((lp - a).dot(seg) / len_sq, 0.0, 1.0)
		var closest := a + seg * t
		var d := lp.distance_to(closest)
		if d < best_d:
			best_d = d
			best_i = i
			best_t = t

	var c_i: float = _track_cambers[best_i] if best_i < _track_cambers.size() else 0.0
	var c_j: float = _track_cambers[(best_i + 1) % n] if (best_i + 1) % n < _track_cambers.size() else 0.0
	return lerpf(c_i, c_j, best_t)

func get_layer_at(pos: Vector2) -> int:
	var ep := _get_bridge_endpoints()
	if ep.size() == 0:
		return 0
	var t: float = _bridge_t(to_local(pos))
	if t >= 0.0 and sin(t * PI) * ep[2] > ep[2] * 0.3:
		return 1
	return 0

func is_on_course(pos: Vector2) -> bool:
	var lp := to_local(pos)
	return (Geometry2D.is_point_in_polygon(lp, _outer)
		and not Geometry2D.is_point_in_polygon(lp, _inner))

# ── Default course data (migration from hardcoded constants) ──────────────────

func _make_default_data() -> CourseData:
	var cd := CourseData.new()
	cd.id = "test_arena"
	cd.display_name = "Test Arena"
	cd.lap_count = 3
	cd.track_points = PackedVector2Array([
		Vector2(900, 1080), Vector2(1100, 1030), Vector2(1295, 945),
		Vector2(1430, 830), Vector2(1540, 690), Vector2(1590, 545),
		Vector2(1555, 410), Vector2(1615, 300), Vector2(1590, 195),
		Vector2(1470, 130), Vector2(1310, 105), Vector2(1120, 95),
		Vector2(920, 90), Vector2(720, 100), Vector2(530, 130),
		Vector2(378, 208), Vector2(235, 338), Vector2(175, 482),
		Vector2(162, 638), Vector2(188, 782), Vector2(210, 875),
		Vector2(205, 965), Vector2(178, 1042), Vector2(260, 1082),
		Vector2(348, 1082), Vector2(440, 1040), Vector2(458, 942),
		Vector2(548, 908), Vector2(638, 942), Vector2(640, 1075),
		Vector2(665, 1082), Vector2(858, 1082),
	])
	var n := cd.track_points.size()
	cd.track_widths = PackedFloat32Array()
	cd.track_widths.resize(n)
	cd.track_widths.fill(80.0)

	# Height map (0-120 px)
	cd.track_heights = PackedFloat32Array()
	cd.track_heights.resize(n)
	cd.track_heights.fill(0.0)
	# Bridge approach points — bridge arch handles their visual elevation
	cd.track_heights[3] = 0.0
	cd.track_heights[4] = 0.0
	cd.track_heights[5] = 0.0
	# Gentle hill at upper right (pts 9-10)
	cd.track_heights[9] = 25.0
	cd.track_heights[10] = 25.0
	# Gentle rise on far-left descent (pts 17-19)
	cd.track_heights[17] = 15.0
	cd.track_heights[18] = 15.0
	cd.track_heights[19] = 15.0

	# Camber map (-1.0 to +1.0)
	cd.track_cambers = PackedFloat32Array()
	cd.track_cambers.resize(n)
	cd.track_cambers.fill(0.0)
	# Far-left hairpin: off-camber
	cd.track_cambers[21] = -0.3
	cd.track_cambers[22] = -0.3
	cd.track_cambers[23] = -0.3
	# U-hairpin: on-camber (banked)
	cd.track_cambers[25] = 0.2
	cd.track_cambers[26] = 0.2
	cd.track_cambers[27] = 0.2
	cd.track_cambers[28] = 0.2
	cd.track_cambers[29] = 0.2

	cd.mud_zones = [
		{"center": Vector2(1120, 95), "half": Vector2(68, 34)},
		{"center": Vector2(920, 90),  "half": Vector2(68, 34)},
		{"center": Vector2(720, 100), "half": Vector2(68, 34)},
	]
	cd.sand_zones = [
		{"center": Vector2(168, 560), "half": Vector2(65, 32)},
		{"center": Vector2(175, 710), "half": Vector2(65, 32)},
	]
	cd.barrier_pairs = [
		{"idx_a": 30, "idx_b": 31, "t": 0.45},
	]
	cd.bridge = {"start_idx": 3, "end_idx": 5, "height": 60.0}
	return cd
