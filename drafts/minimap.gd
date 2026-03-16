# minimap.gd
# Renders course overview and rider positions
# Attach to Control node in HUD

class_name Minimap
extends Control

@export var course: Course
@export var map_scale: float = 0.04  # World units to minimap pixels
@export var map_size: Vector2 = Vector2(150, 150)

@export_group("Colors")
@export var background_color: Color = Color(0.1, 0.1, 0.1, 0.7)
@export var ground_color: Color = Color(0.3, 0.5, 0.3)
@export var bridge_color: Color = Color(0.6, 0.6, 0.7)
@export var tunnel_color: Color = Color(0.2, 0.3, 0.2)
@export var player_color: Color = Color(1.0, 0.8, 0.0)
@export var ai_color: Color = Color(0.8, 0.2, 0.2)
@export var path_width: float = 3.0
@export var rider_radius: float = 4.0

# Runtime
var course_center: Vector2 = Vector2.ZERO
var course_bounds: Rect2 = Rect2()

func _ready():
	custom_minimum_size = map_size
	
	# Calculate course bounds for centering
	if course:
		_calculate_bounds()

func _process(_delta):
	queue_redraw()

func _draw():
	# Background
	draw_rect(Rect2(Vector2.ZERO, map_size), background_color)
	
	if not course:
		return
	
	# Draw course path
	_draw_course()
	
	# Draw riders
	_draw_riders()
	
	# Border
	draw_rect(Rect2(Vector2.ZERO, map_size), Color.WHITE, false, 1.0)

func _calculate_bounds():
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	var minimap_data = course.get_minimap_points()
	for segment_data in minimap_data:
		for point in segment_data.path:
			min_pos.x = minf(min_pos.x, point.x)
			min_pos.y = minf(min_pos.y, point.y)
			max_pos.x = maxf(max_pos.x, point.x)
			max_pos.y = maxf(max_pos.y, point.y)
	
	course_bounds = Rect2(min_pos, max_pos - min_pos)
	course_center = course_bounds.get_center()
	
	# Auto-calculate scale to fit
	var scale_x = (map_size.x - 20) / course_bounds.size.x
	var scale_y = (map_size.y - 20) / course_bounds.size.y
	map_scale = minf(scale_x, scale_y)

func _world_to_map(world_pos: Vector2) -> Vector2:
	var relative = world_pos - course_center
	var map_pos = relative * map_scale
	return map_pos + map_size * 0.5

func _draw_course():
	var minimap_data = course.get_minimap_points()
	
	# Draw ground level first, then bridges on top
	for layer in [0, 1]:
		for segment_data in minimap_data:
			if segment_data.layer != layer:
				continue
			
			var color = ground_color
			if segment_data.is_bridge:
				color = bridge_color
			elif segment_data.is_tunnel:
				color = tunnel_color
			
			var path: PackedVector2Array = segment_data.path
			if path.size() < 2:
				continue
			
			# Convert to map coordinates
			var map_points: PackedVector2Array = []
			for point in path:
				map_points.append(_world_to_map(point))
			
			# Draw path
			for i in range(map_points.size() - 1):
				draw_line(map_points[i], map_points[i + 1], color, path_width)

func _draw_riders():
	var rider_positions = course.get_rider_positions()
	
	# Sort so player draws on top
	rider_positions.sort_custom(func(a, b): return !a.is_player and b.is_player)
	
	for rider_data in rider_positions:
		var map_pos = _world_to_map(rider_data.position)
		
		# Clamp to minimap bounds
		map_pos.x = clampf(map_pos.x, rider_radius, map_size.x - rider_radius)
		map_pos.y = clampf(map_pos.y, rider_radius, map_size.y - rider_radius)
		
		var color = player_color if rider_data.is_player else ai_color
		
		# Draw rider dot
		draw_circle(map_pos, rider_radius, color)
		
		# Draw position number for non-player
		if not rider_data.is_player and rider_data.race_position <= 3:
			# Small position indicator
			var font = ThemeDB.fallback_font
			var pos_str = str(rider_data.race_position)
			draw_string(font, map_pos + Vector2(-3, 3), pos_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 8)

# --- PUBLIC INTERFACE ---

func set_course(new_course: Course):
	course = new_course
	if course:
		_calculate_bounds()

func highlight_segment(segment_index: int):
	# Could flash or highlight a specific segment
	pass

func show_upcoming_terrain(terrain_type: int):
	# Could show an indicator for what terrain is coming
	pass
