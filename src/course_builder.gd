# course_builder.gd
# Procedurally builds a cyclocross course with tight turns, sand/mud sections, a flyover bridge,
# and a long straight approach before the start/finish line.
extends Node2D

const TerrainTypes = preload("res://src/course/terrain_types.gd")
const BarrierScript = preload("res://src/course/obstacles/barrier.gd")

const HALF_TRACK           := 80.0
const BARRIER_W            := 12.0
const STRIPE_LEN           := 32.0
const BARRIER_PAIR_SPACING := 160.0   # 5 m at 32 px/m  (spec: 128–192 px)

const C_DIRT    := Color(0.48, 0.30, 0.15)
const C_INFIELD := Color(0.22, 0.42, 0.18)
const C_RED     := Color(0.88, 0.12, 0.10)
const C_WHITE   := Color(0.95, 0.95, 0.92)
const C_MUD     := Color(0.22, 0.14, 0.06)
const C_SAND    := Color(0.78, 0.68, 0.40)
const C_BRIDGE  := Color(0.50, 0.52, 0.56)   # concrete deck
const C_PILLAR  := Color(0.38, 0.40, 0.43)   # support posts

# Course tape
const TAPE_POLE_SPACING := 68.0   # px between poles along each edge
const TAPE_POLE_HEIGHT  := 26.0   # local-space height of each pole
const TAPE_WIDTH        := 2.5
const TAPE_POLE_WIDTH   := 3.5
const TAPE_ANIM_RADIUS  := 220.0  # px radius around hit to animate
const C_TAPE := Color(1.0, 0.88, 0.05)   # yellow
const C_POLE := Color(0.18, 0.18, 0.20)  # dark gray

# Flyover bridge — arches over the right-side straight (track pts 3 → 5).
# The arch peaks at TRACK_PTS[4] midway through the ramp.
const BRIDGE_A          := Vector2(1430, 830)   # = TRACK_PTS[3]  ramp start
const BRIDGE_B          := Vector2(1590, 545)   # = TRACK_PTS[5]  ramp end
const BRIDGE_HEIGHT     := 60.0    # px of elevation at the arch peak
const BRIDGE_VIS_SCALE  := 3.0    # must match rider sprite height scale
const BRIDGE_HALF_WIDTH := 90.0   # detection half-width (slightly > HALF_TRACK)

# 31-point course — clockwise from start/finish at bottom-center.
# All segment lengths ≥ 90 px (> HALF_TRACK=80) to prevent tape self-intersection.
# Hairpin widths ≥ 180 px (> 2×HALF_TRACK=160) to prevent polygon folding.
# Features: right bridge sweep, upper-right chicane, top mud, smooth left descent,
# far-left hairpin, tight U-hairpin at bottom, long straight with barriers.
const TRACK_PTS := [
	Vector2(900, 1080),   # 0  Start/finish
	Vector2(1100, 1030),  # 1  Right sweep →
	Vector2(1295,  945),  # 2
	Vector2(1430,  830),  # 3  Flyover bridge ramp start
	Vector2(1540,  690),  # 4
	Vector2(1590,  545),  # 5  Bridge ramp end
	Vector2(1555,  410),  # 6  Upper-right chicane – left
	Vector2(1615,  300),  # 7  right
	Vector2(1590,  195),  # 8
	Vector2(1470,  130),  # 9  Upper-right corner
	Vector2(1310,  105),  # 10
	Vector2(1120,   95),  # 11 Top mud
	Vector2(920,    90),  # 12
	Vector2(720,   100),  # 13
	Vector2(530,   130),  # 14 Mud exit
	Vector2(378,   208),  # 15 Upper-left sweep
	Vector2(235,   338),  # 16
	Vector2(175,   482),  # 17 Far-left descent
	Vector2(162,   638),  # 18
	Vector2(188,   782),  # 19
	Vector2(210,   875),  # 20 Smooth approach — outer polygon doesn't reverse x
	Vector2(205,   965),  # 21 Hairpin entry
	Vector2(178,  1042),  # 22 Far-left hairpin apex
	Vector2(260,  1082),  # 23 Hairpin exit
	Vector2(348,  1082),  # 24 Flat connector — keeps outer polygon horizontal here
	Vector2(440,  1040),  # 25 ── U-hairpin entry (up-right)
	Vector2(458,   942),  # 26
	Vector2(548,   908),  # 27 Hairpin top — gap = 638−458 = 180 px ✓
	Vector2(638,   942),  # 28 Right side going down
	Vector2(640,  1075),  # 29 Hairpin exit
	Vector2(665,  1082),  # 30 ── barrier straight starts here (level) ──
	Vector2(858,  1082),  # 31 Approaching finish
]

# Mud ovals on the top straight (pts 11–13)
const MUD_CENTERS := [
	Vector2(1120, 95),
	Vector2(920,  90),
	Vector2(720,  100),
]
const MUD_HALF := Vector2(68, 34)

# Sand pits on the far-left descent (midpoints of pts 17→18 and 18→19)
const SAND_CENTERS := [
	Vector2(168, 560),   # midpoint pts 17→18
	Vector2(175, 710),   # midpoint pts 18→19
]
const SAND_HALF := Vector2(65, 32)

# One barrier pair on the long straight before the start line (pts 29→30).
# Two bars placed BARRIER_PAIR_SPACING px apart, centred at lerp(a,b,t).
const BARRIER_PAIR_SEGMENTS := [
	[30, 31, 0.45],  # Pair 1 — flat straight, before start line
]

signal lap_crossed(rider: Node2D)

var _outer := PackedVector2Array()
var _inner := PackedVector2Array()
var _lap_cooldowns: Dictionary = {}   # rider -> seconds remaining
var _tape_segments: Array = []        # { tape, poles, center, mid_rest, tween }

func _ready() -> void:
	add_to_group("course")
	_compute_edges()
	_build_visuals()
	_build_course_tape()
	_build_barriers()
	_build_lap_trigger()

func _process(delta: float) -> void:
	for rider in _lap_cooldowns.keys():
		_lap_cooldowns[rider] -= delta
		if _lap_cooldowns[rider] <= 0.0:
			_lap_cooldowns.erase(rider)

func _compute_edges() -> void:
	var pts := PackedVector2Array(TRACK_PTS)
	var n := pts.size()
	_outer.resize(n)
	_inner.resize(n)
	for i in n:
		var prev := pts[(i - 1 + n) % n]
		var nxt  := pts[(i + 1) % n]
		var dir  := (nxt - prev).normalized()
		var perp := Vector2(-dir.y, dir.x)
		_outer[i] = pts[i] + perp * HALF_TRACK
		_inner[i] = pts[i] - perp * HALF_TRACK

func _build_visuals() -> void:
	var n := _outer.size()

	# Track surface polygon (dirt)
	var track_poly := PackedVector2Array()
	for p in _outer:
		track_poly.append(p)
	for i in range(n - 1, -1, -1):
		track_poly.append(_inner[i])
	var track := Polygon2D.new()
	track.name = "TrackSurface"
	track.color = C_DIRT
	track.polygon = track_poly
	add_child(track)

	# Infield grass
	var infield := Polygon2D.new()
	infield.name = "Infield"
	infield.color = C_INFIELD
	infield.polygon = _inner
	add_child(infield)

	# Mud ovals
	for mc in MUD_CENTERS:
		_add_mud_oval(mc)

	# Sand pits
	for sc in SAND_CENTERS:
		_add_sand_oval(sc)

	# Flyover bridge (drawn last so it appears above the track surface)
	_build_bridge_visual()

	# Checkered start/finish line
	_add_start_finish()

func _add_mud_oval(center: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := float(i) / 24.0 * TAU
		pts.append(center + Vector2(cos(a) * MUD_HALF.x, sin(a) * MUD_HALF.y))
	var poly := Polygon2D.new()
	poly.color = C_MUD
	poly.polygon = pts
	add_child(poly)

func _add_sand_oval(center: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := float(i) / 24.0 * TAU
		pts.append(center + Vector2(cos(a) * SAND_HALF.x, sin(a) * SAND_HALF.y))
	var poly := Polygon2D.new()
	poly.color = C_SAND
	poly.polygon = pts
	add_child(poly)

func _add_start_finish() -> void:
	var a := _outer[0]
	var b := _inner[0]
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

func _build_course_tape() -> void:
	_add_tape_boundary(_outer)
	_add_tape_boundary(_inner)

func _add_tape_boundary(edge_pts: PackedVector2Array) -> void:
	var n := edge_pts.size()

	# Collect pole base positions along this edge at regular intervals
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

	# Build pole Line2D visuals
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

	# Build tape spans between consecutive poles (closed loop)
	for i in m:
		var pa: Vector2 = pole_pos[i]
		var pb: Vector2 = pole_pos[(i + 1) % m]
		var top_a := pa + Vector2(0.0, -TAPE_POLE_HEIGHT)
		var top_b := pb + Vector2(0.0, -TAPE_POLE_HEIGHT)
		var mid   := (top_a + top_b) * 0.5

		# 3-point Line2D so the centre point can be tweened to droop
		var tape := Line2D.new()
		tape.width         = TAPE_WIDTH
		tape.default_color = C_TAPE
		tape.add_point(top_a)
		tape.add_point(mid)
		tape.add_point(top_b)
		tape.z_index = 2
		add_child(tape)

		# Thin Area2D trigger aligned to this span
		var seg_center := (pa + pb) * 0.5
		var seg_dir: Vector2 = (pb - pa).normalized()
		var seg_len  := pa.distance_to(pb)

		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask  = 1   # ground_riders — bridge riders (layer 2) auto-exempt
		# Ground-level strip joining the pole bases — wheels are at ground level
		area.position = seg_center
		area.rotation = atan2(seg_dir.y, seg_dir.x)

		var col  := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(seg_len * 1.05, 10.0)
		col.shape = rect
		area.add_child(col)

		# Ground-level collision strip visual (shows the actual detection line)
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

		# Area2D is animation-only — crash is driven by _check_course_bounds()
		area.body_entered.connect(func(_body: Node2D) -> void:
			animate_tape_at(seg_center))

		add_child(area)

# Called by rider._check_course_bounds() when a wheel exits the course polygon.
func animate_tape_at(local_pos: Vector2) -> void:
	for seg in _tape_segments:
		var d: float = (seg.center as Vector2).distance_to(local_pos)
		if d <= TAPE_ANIM_RADIUS:
			_animate_tape_segment(seg, 1.0 - d / TAPE_ANIM_RADIUS)

func _animate_tape_segment(seg: Dictionary, strength: float) -> void:
	var tape: Line2D    = seg.tape
	var mid_rest: Vector2 = seg.mid_rest

	# Kill any in-flight tween so animations don't stack
	if seg.tween != null and (seg.tween as Tween).is_running():
		(seg.tween as Tween).kill()

	var tw := create_tween()
	seg.tween = tw
	var droop := mid_rest + Vector2(0.0, 28.0 * strength)

	# Droop down quickly, spring back slowly
	tw.tween_method(func(p: Vector2): tape.set_point_position(1, p),
		mid_rest, droop, 0.10)
	tw.tween_method(func(p: Vector2): tape.set_point_position(1, p),
		droop, mid_rest, 0.45)

	# Tilt nearby poles
	for pole: Line2D in seg.poles:
		var tilt := randf_range(-0.25, 0.25) * strength
		var ptw := create_tween()
		ptw.tween_property(pole, "rotation", tilt, 0.08)
		ptw.tween_property(pole, "rotation", 0.0,  0.40)

func _build_bridge_visual() -> void:
	const N := 14   # sample count along the arch
	var dir: Vector2  = (BRIDGE_B - BRIDGE_A).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	var deck_left  := PackedVector2Array()
	var deck_right := PackedVector2Array()

	for i in N:
		var t    := float(i) / float(N - 1)
		var gp   := BRIDGE_A.lerp(BRIDGE_B, t)
		var lift := -sin(t * PI) * BRIDGE_HEIGHT * BRIDGE_VIS_SCALE
		var ep   := gp + Vector2(0.0, lift)
		deck_left.append(ep  + perp * HALF_TRACK * 0.92)
		deck_right.append(ep - perp * HALF_TRACK * 0.92)

	# Deck polygon (left edge forward + right edge reversed)
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

	# Support pillars at t = 0.15, 0.35, 0.50, 0.65, 0.85
	for t: float in [0.15, 0.35, 0.50, 0.65, 0.85]:
		var gp   := BRIDGE_A.lerp(BRIDGE_B, t)
		var lift := -sin(t * PI) * BRIDGE_HEIGHT * BRIDGE_VIS_SCALE
		var ep   := gp + Vector2(0.0, lift)
		for sx: float in [-0.5, 0.5]:
			var top := ep  + perp * (HALF_TRACK * sx)
			var bot := gp  + perp * (HALF_TRACK * sx)
			var post := Line2D.new()
			post.width         = 5.0
			post.default_color = C_PILLAR
			post.add_point(top)
			post.add_point(bot)
			post.z_index = 4
			add_child(post)

	# Rail lines along both edges of the deck
	for edge_pts: PackedVector2Array in [deck_left, deck_right]:
		var rail := Line2D.new()
		rail.width         = 4.0
		rail.default_color = C_PILLAR
		for p in edge_pts:
			rail.add_point(p)
		rail.z_index = 6
		add_child(rail)

# Returns t (0–1) if `lp` is within the bridge arch zone, otherwise -1.
func _bridge_t(lp: Vector2) -> float:
	var seg: Vector2 = BRIDGE_B - BRIDGE_A
	var seg_len := seg.length()
	var seg_dir := seg / seg_len
	var local: Vector2 = lp - BRIDGE_A
	var proj := local.dot(seg_dir)
	if proj < 0.0 or proj > seg_len:
		return -1.0
	if absf(local.cross(seg_dir)) > BRIDGE_HALF_WIDTH:
		return -1.0
	return proj / seg_len

func _build_barriers() -> void:
	for pair_data in BARRIER_PAIR_SEGMENTS:
		var idx_a: int  = pair_data[0]
		var idx_b: int  = pair_data[1]
		var t: float    = pair_data[2]
		var a: Vector2  = TRACK_PTS[idx_a]
		var b: Vector2  = TRACK_PTS[idx_b]
		var mid: Vector2 = a.lerp(b, t)
		var dir: Vector2 = (b - a).normalized()
		_add_barrier(mid - dir * (BARRIER_PAIR_SPACING * 0.5), dir)
		_add_barrier(mid + dir * (BARRIER_PAIR_SPACING * 0.5), dir)

func _add_barrier(center: Vector2, track_dir: Vector2) -> void:
	var barrier := Area2D.new()
	barrier.set_script(BarrierScript)
	barrier.collision_layer = 16  # triggers (layer 5)
	barrier.collision_mask  = 1   # detect ground_riders
	barrier.position = center
	barrier.rotation = atan2(track_dir.y, track_dir.x)

	# Detection zone — spans track width, deep enough for hop timing
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(HALF_TRACK * 2.2, 80.0)
	col.shape = rect
	barrier.add_child(col)

	# Visual — white bar with red end-caps (local y = across track)
	var bar := Line2D.new()
	bar.width = 6.0
	bar.default_color = Color.WHITE
	bar.add_point(Vector2(0.0, -HALF_TRACK * 1.05))
	bar.add_point(Vector2(0.0,  HALF_TRACK * 1.05))
	barrier.add_child(bar)

	var cap_color := C_RED
	for sign_y in [-1.0, 1.0]:
		var cap := Line2D.new()
		cap.width = 8.0
		cap.default_color = cap_color
		cap.add_point(Vector2(-6.0, sign_y * HALF_TRACK * 0.9))
		cap.add_point(Vector2( 6.0, sign_y * HALF_TRACK * 0.9))
		barrier.add_child(cap)

	add_child(barrier)

func _build_lap_trigger() -> void:
	var n := TRACK_PTS.size()
	# Direction the rider travels when correctly crossing the line (last pt → pt 0)
	var crossing_dir: Vector2 = (TRACK_PTS[0] - TRACK_PTS[n - 1]).normalized()

	var trigger := Area2D.new()
	trigger.name = "LapTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	trigger.position = TRACK_PTS[0]
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
		# Only count if rider is travelling in the correct direction
		if body.velocity.normalized().dot(crossing_dir) > 0.25:
			_lap_cooldowns[body] = 4.0
			lap_crossed.emit(body))

	add_child(trigger)

# ── Course interface (called by rider) ─────────────────────────────────────────

func get_terrain_at(pos: Vector2) -> int:
	var lp := to_local(pos)
	# Start/finish zone — slight pavement bonus
	var dist_to_start := lp.distance_to(TRACK_PTS[0])
	if dist_to_start < 60.0:
		return TerrainTypes.Type.PAVEMENT
	for mc: Vector2 in MUD_CENTERS:
		var d: Vector2 = lp - mc
		var nx := d.x / MUD_HALF.x
		var ny := d.y / MUD_HALF.y
		if nx * nx + ny * ny <= 1.0:
			return TerrainTypes.Type.MUD
	for sc: Vector2 in SAND_CENTERS:
		var d: Vector2 = lp - sc
		var nx := d.x / SAND_HALF.x
		var ny := d.y / SAND_HALF.y
		if nx * nx + ny * ny <= 1.0:
			return TerrainTypes.Type.SAND
	return TerrainTypes.Type.GRASS

func get_track_points() -> PackedVector2Array:
	return PackedVector2Array(TRACK_PTS)

func get_height_at(pos: Vector2) -> float:
	var t: float = _bridge_t(to_local(pos))
	if t < 0.0:
		return 0.0
	return sin(t * PI) * BRIDGE_HEIGHT

func get_layer_at(pos: Vector2) -> int:
	var t: float = _bridge_t(to_local(pos))
	# Layer 1 (bridge) once past the lower 30 % of the arch on either side
	if t >= 0.0 and sin(t * PI) * BRIDGE_HEIGHT > BRIDGE_HEIGHT * 0.3:
		return 1
	return 0

func is_on_course(pos: Vector2) -> bool:
	var lp := to_local(pos)
	return (Geometry2D.is_point_in_polygon(lp, _outer)
		and not Geometry2D.is_point_in_polygon(lp, _inner))
