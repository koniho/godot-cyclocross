# course_segment.gd
# Resource class for course segment data
# Create instances in editor or via code, save as .tres files

class_name CourseSegment
extends Resource

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""

@export_group("Path")
## Points defining the centerline of this segment
@export var path_points: PackedVector2Array = []
## Width of rideable area in pixels
@export var width: float = 80.0
## Close the path into a loop (for complete courses)
@export var is_loop: bool = false

@export_group("Terrain")
@export var terrain_type: TerrainTypes.Type = TerrainTypes.Type.GRASS
## Optional: vary terrain along segment (0-1 mapped to path progress)
@export var terrain_variation: Array[TerrainTypes.Type] = []
@export var terrain_variation_positions: Array[float] = []  # 0.0-1.0

@export_group("Elevation")
## Base layer (0 = ground, 1 = bridge, etc.)
@export var layer: int = 0
## Base height offset
@export var base_height: float = 0.0
## Height profile curve (x: progress 0-1, y: height offset)
@export var height_curve: Curve = null
## Does this segment transition to a different layer?
@export var transition_to_layer: int = -1  # -1 = no transition

@export_group("Flags")
@export var is_bridge: bool = false
@export var is_tunnel: bool = false
@export var is_start_zone: bool = false
@export var is_finish_zone: bool = false
@export var is_sprint_zone: bool = false

@export_group("Obstacles")
## Positions along path (0-1) where barriers exist
@export var barrier_positions: Array[float] = []
## Positions along path for handup spectators
@export var handup_positions: Array[float] = []
## Which side handups are on (-1 = left, 1 = right)
@export var handup_sides: Array[int] = []
## Types of handups (indexes into handup type enum)
@export var handup_types: Array[int] = []

# --- RUNTIME HELPERS ---

## Get total path length in pixels
func get_length() -> float:
	var total = 0.0
	for i in range(path_points.size() - 1):
		total += path_points[i].distance_to(path_points[i + 1])
	if is_loop and path_points.size() > 1:
		total += path_points[-1].distance_to(path_points[0])
	return total

## Get position along path at progress t (0-1)
func get_point_at_progress(t: float) -> Vector2:
	if path_points.size() < 2:
		return path_points[0] if path_points.size() > 0 else Vector2.ZERO
	
	var total_length = get_length()
	var target_dist = t * total_length
	var current_dist = 0.0
	
	for i in range(path_points.size() - 1):
		var segment_length = path_points[i].distance_to(path_points[i + 1])
		if current_dist + segment_length >= target_dist:
			var segment_t = (target_dist - current_dist) / segment_length
			return path_points[i].lerp(path_points[i + 1], segment_t)
		current_dist += segment_length
	
	return path_points[-1]

## Get direction (normalized) at progress t
func get_direction_at_progress(t: float) -> Vector2:
	if path_points.size() < 2:
		return Vector2.RIGHT
	
	var total_length = get_length()
	var target_dist = t * total_length
	var current_dist = 0.0
	
	for i in range(path_points.size() - 1):
		var segment_length = path_points[i].distance_to(path_points[i + 1])
		if current_dist + segment_length >= target_dist:
			return (path_points[i + 1] - path_points[i]).normalized()
		current_dist += segment_length
	
	return (path_points[-1] - path_points[-2]).normalized()

## Get height at progress t
func get_height_at_progress(t: float) -> float:
	if height_curve:
		return base_height + height_curve.sample(clampf(t, 0.0, 1.0))
	return base_height

## Get layer at progress t (handles transitions)
func get_layer_at_progress(t: float) -> int:
	if transition_to_layer >= 0:
		# Linear transition across segment
		return transition_to_layer if t > 0.5 else layer
	return layer

## Get terrain type at progress t
func get_terrain_at_progress(t: float) -> TerrainTypes.Type:
	if terrain_variation.size() == 0:
		return terrain_type
	
	# Find which terrain zone we're in
	for i in range(terrain_variation_positions.size()):
		if t < terrain_variation_positions[i]:
			return terrain_variation[i - 1] if i > 0 else terrain_type
	
	return terrain_variation[-1] if terrain_variation.size() > 0 else terrain_type

## Check if a world position is within this segment's bounds
func contains_point(pos: Vector2) -> bool:
	# Simple distance-to-path check
	var min_dist = INF
	
	for i in range(path_points.size() - 1):
		var dist = _point_to_segment_distance(pos, path_points[i], path_points[i + 1])
		min_dist = minf(min_dist, dist)
	
	return min_dist <= width * 0.5

## Get progress (0-1) for a world position
func get_progress_for_point(pos: Vector2) -> float:
	var total_length = get_length()
	var min_dist = INF
	var best_progress = 0.0
	var current_dist = 0.0
	
	for i in range(path_points.size() - 1):
		var closest = _closest_point_on_segment(pos, path_points[i], path_points[i + 1])
		var dist = pos.distance_to(closest)
		
		if dist < min_dist:
			min_dist = dist
			var segment_progress = path_points[i].distance_to(closest)
			best_progress = (current_dist + segment_progress) / total_length
		
		current_dist += path_points[i].distance_to(path_points[i + 1])
	
	return clampf(best_progress, 0.0, 1.0)

# --- GEOMETRY HELPERS ---

func _point_to_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var closest = _closest_point_on_segment(p, a, b)
	return p.distance_to(closest)

func _closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab = b - a
	var ap = p - a
	var t = clampf(ap.dot(ab) / ab.dot(ab), 0.0, 1.0)
	return a + ab * t
