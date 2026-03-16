# course.gd
# Main course controller - manages segments, terrain queries, obstacles
# Attach to Course node in race scene

class_name Course
extends Node2D

signal lap_completed(rider: Node2D, lap: int)
signal race_finished(rider: Node2D, position: int)

@export var course_data: CourseData  # Resource containing all segments
@export var lap_count: int = 3

# Runtime
var segments: Array[CourseSegment] = []
var total_length: float = 0.0
var rider_progress: Dictionary = {}  # rider -> {lap, progress, last_checkpoint}
var finish_order: Array = []

# Obstacle instances
var barriers: Array[Node2D] = []
var handups: Array[Node2D] = []
var ramp_triggers: Array[Area2D] = []

# Preloaded scenes
@export var barrier_scene: PackedScene
@export var handup_scene: PackedScene
@export var ramp_trigger_scene: PackedScene

func _ready():
	if course_data:
		load_course(course_data)

func load_course(data: CourseData):
	segments = data.segments.duplicate()
	_calculate_total_length()
	_spawn_obstacles()
	_spawn_triggers()

func _calculate_total_length():
	total_length = 0.0
	for segment in segments:
		total_length += segment.get_length()

# --- TERRAIN QUERIES ---

## Get terrain type at world position
func get_terrain_at(pos: Vector2) -> TerrainTypes.Type:
	var segment = _find_segment_at(pos)
	if segment:
		var progress = segment.get_progress_for_point(pos)
		return segment.get_terrain_at_progress(progress)
	return TerrainTypes.Type.GRASS

## Get height at world position
func get_height_at(pos: Vector2) -> float:
	var segment = _find_segment_at(pos)
	if segment:
		var progress = segment.get_progress_for_point(pos)
		return segment.get_height_at_progress(progress)
	return 0.0

## Get collision layer at world position
func get_layer_at(pos: Vector2) -> int:
	var segment = _find_segment_at(pos)
	if segment:
		var progress = segment.get_progress_for_point(pos)
		return segment.get_layer_at_progress(progress)
	return 0

## Get race progress (0 to lap_count) for a rider
func get_race_progress(rider: Node2D) -> float:
	if not rider in rider_progress:
		return 0.0
	var data = rider_progress[rider]
	return data.lap + data.progress

## Get position in race (1st, 2nd, etc.)
func get_race_position(rider: Node2D) -> int:
	var all_progress: Array = []
	for r in rider_progress:
		all_progress.append({"rider": r, "progress": get_race_progress(r)})
	all_progress.sort_custom(func(a, b): return a.progress > b.progress)
	
	for i in range(all_progress.size()):
		if all_progress[i].rider == rider:
			return i + 1
	return rider_progress.size()

# --- SEGMENT HELPERS ---

func _find_segment_at(pos: Vector2) -> CourseSegment:
	for segment in segments:
		if segment.contains_point(pos):
			return segment
	return null

func _get_segment_index_at(pos: Vector2) -> int:
	for i in range(segments.size()):
		if segments[i].contains_point(pos):
			return i
	return -1

# --- PROGRESS TRACKING ---

func register_rider(rider: Node2D):
	rider_progress[rider] = {
		"lap": 0,
		"progress": 0.0,
		"segment_index": 0,
		"last_checkpoint": 0.0
	}

func update_rider_progress(rider: Node2D):
	if not rider in rider_progress:
		register_rider(rider)
	
	var data = rider_progress[rider]
	var segment_index = _get_segment_index_at(rider.global_position)
	
	if segment_index < 0:
		return  # Off course
	
	var segment = segments[segment_index]
	var local_progress = segment.get_progress_for_point(rider.global_position)
	
	# Calculate overall progress
	var progress_before = 0.0
	for i in range(segment_index):
		progress_before += segments[i].get_length()
	progress_before += local_progress * segment.get_length()
	
	var overall_progress = progress_before / total_length
	
	# Detect lap completion (crossed from end to start)
	if data.progress > 0.9 and overall_progress < 0.1:
		data.lap += 1
		lap_completed.emit(rider, data.lap)
		
		if data.lap >= lap_count:
			_rider_finished(rider)
	
	data.progress = overall_progress
	data.segment_index = segment_index

func _rider_finished(rider: Node2D):
	if rider in finish_order:
		return
	
	finish_order.append(rider)
	var position = finish_order.size()
	race_finished.emit(rider, position)

# --- OBSTACLE SPAWNING ---

func _spawn_obstacles():
	# Clear existing
	for b in barriers:
		b.queue_free()
	barriers.clear()
	
	for h in handups:
		h.queue_free()
	handups.clear()
	
	# Spawn from segment data
	for segment in segments:
		_spawn_segment_barriers(segment)
		_spawn_segment_handups(segment)

func _spawn_segment_barriers(segment: CourseSegment):
	if not barrier_scene:
		return
	
	for t in segment.barrier_positions:
		var pos = segment.get_point_at_progress(t)
		var dir = segment.get_direction_at_progress(t)
		
		var barrier = barrier_scene.instantiate()
		barrier.global_position = pos
		barrier.rotation = dir.angle()
		$Obstacles/Barriers.add_child(barrier)
		barriers.append(barrier)

func _spawn_segment_handups(segment: CourseSegment):
	if not handup_scene:
		return
	
	for i in range(segment.handup_positions.size()):
		var t = segment.handup_positions[i]
		var side = segment.handup_sides[i] if i < segment.handup_sides.size() else 1
		var type = segment.handup_types[i] if i < segment.handup_types.size() else 0
		
		var pos = segment.get_point_at_progress(t)
		var dir = segment.get_direction_at_progress(t)
		var perpendicular = dir.rotated(PI * 0.5)
		
		var handup = handup_scene.instantiate()
		handup.global_position = pos + perpendicular * side * (segment.width * 0.5 + 20)
		handup.rotation = dir.angle()
		handup.handup_type = type
		$Obstacles/Handups.add_child(handup)
		handups.append(handup)

func _spawn_triggers():
	if not ramp_trigger_scene:
		return
	
	for trigger in ramp_triggers:
		trigger.queue_free()
	ramp_triggers.clear()
	
	# Find segments with layer transitions
	for segment in segments:
		if segment.transition_to_layer >= 0:
			var pos = segment.get_point_at_progress(0.5)  # Midpoint
			var dir = segment.get_direction_at_progress(0.5)
			
			var trigger = ramp_trigger_scene.instantiate()
			trigger.global_position = pos
			trigger.rotation = dir.angle()
			trigger.target_layer = segment.transition_to_layer
			$Obstacles/RampTriggers.add_child(trigger)
			ramp_triggers.append(trigger)

# --- MINIMAP DATA ---

func get_minimap_points() -> Array:
	var points: Array = []
	for segment in segments:
		points.append({
			"path": segment.path_points,
			"is_bridge": segment.is_bridge,
			"is_tunnel": segment.is_tunnel,
			"layer": segment.layer
		})
	return points

func get_rider_positions() -> Array:
	var positions: Array = []
	for rider in rider_progress:
		positions.append({
			"position": rider.global_position,
			"is_player": rider.is_in_group("player"),
			"race_position": get_race_position(rider)
		})
	return positions
