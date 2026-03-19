# course_data.gd
# Flat resource containing all data for a course layout.
# Save as .tres or export/import as JSON.

class_name CourseData
extends Resource

@export var id: String = ""
@export var display_name: String = "Unnamed Course"
@export var lap_count: int = 3

@export var track_points: PackedVector2Array = PackedVector2Array()

# Per-point half-track width (default 80.0). Must stay in sync with track_points.size().
@export var track_widths: PackedFloat32Array = PackedFloat32Array()

# Per-point elevation modifier: -1 (downhill), 0 (flat), +1 (uphill). Same size as track_points.
@export var track_elevations: PackedInt32Array = PackedInt32Array()

# Terrain zones: [{center: Vector2, half: Vector2}]
@export var mud_zones: Array = []
@export var sand_zones: Array = []

# Barrier pairs: [{idx_a: int, idx_b: int, t: float}]
@export var barrier_pairs: Array = []

# Bridge: {start_idx: int, end_idx: int, height: float} or empty
@export var bridge: Dictionary = {}


func to_dict() -> Dictionary:
	var pts: Array = []
	for p in track_points:
		pts.append([p.x, p.y])

	return {
		"id": id,
		"display_name": display_name,
		"lap_count": lap_count,
		"track_points": pts,
		"track_widths": Array(track_widths),
		"track_elevations": Array(track_elevations),
		"mud_zones": _zones_to_array(mud_zones),
		"sand_zones": _zones_to_array(sand_zones),
		"barrier_pairs": barrier_pairs.duplicate(true),
		"bridge": bridge.duplicate(true),
	}


static func from_dict(d: Dictionary) -> CourseData:
	var cd := CourseData.new()
	cd.id = d.get("id", "")
	cd.display_name = d.get("display_name", "Unnamed Course")
	cd.lap_count = d.get("lap_count", 3)

	var pts_raw: Array = d.get("track_points", [])
	var pts := PackedVector2Array()
	for p in pts_raw:
		pts.append(Vector2(p[0], p[1]))
	cd.track_points = pts

	var widths_raw: Array = d.get("track_widths", [])
	if widths_raw.size() == pts.size():
		cd.track_widths = PackedFloat32Array(widths_raw)
	else:
		cd.track_widths = PackedFloat32Array()
		cd.track_widths.resize(pts.size())
		cd.track_widths.fill(80.0)

	var elev_raw: Array = d.get("track_elevations", [])
	if elev_raw.size() == pts.size():
		cd.track_elevations = PackedInt32Array(elev_raw)
	else:
		cd.track_elevations = PackedInt32Array()
		cd.track_elevations.resize(pts.size())
		cd.track_elevations.fill(0)

	cd.mud_zones = _array_to_zones(d.get("mud_zones", []))
	cd.sand_zones = _array_to_zones(d.get("sand_zones", []))
	cd.barrier_pairs = d.get("barrier_pairs", [])
	cd.bridge = d.get("bridge", {})
	return cd


func save_json(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()


static func load_json(path: String) -> CourseData:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return null
	return from_dict(json.get_data())


static func _zones_to_array(zones: Array) -> Array:
	var out: Array = []
	for z in zones:
		out.append({
			"center": [z.center.x, z.center.y],
			"half": [z.half.x, z.half.y],
		})
	return out


static func _array_to_zones(arr: Array) -> Array:
	var out: Array = []
	for z in arr:
		var c: Array = z.get("center", [0, 0])
		var h: Array = z.get("half", [60, 30])
		out.append({
			"center": Vector2(c[0], c[1]),
			"half": Vector2(h[0], h[1]),
		})
	return out
