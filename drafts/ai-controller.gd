# ai_controller.gd
# AI controller for non-player riders
# Attach alongside rider.gd on AI rider nodes

class_name AIController
extends Node

@export var rider: Rider
@export var course: Course

@export_group("Skill Settings")
## How well AI follows racing line (0-1)
@export var path_accuracy: float = 0.8
## Reaction time for obstacles (seconds)
@export var reaction_time: float = 0.2
## Chance of perfect bunny hop (0-1)  
@export var hop_skill: float = 0.5
## How often AI makes mistakes (0-1)
@export var mistake_chance: float = 0.1
## Speed multiplier (rubber banding base)
@export var base_speed_mult: float = 1.0

@export_group("Rubber Banding")
@export var enable_rubber_band: bool = true
@export var rubber_band_strength: float = 0.1
@export var max_speed_boost: float = 1.15
@export var max_speed_penalty: float = 0.9

# Runtime
var target_point: Vector2 = Vector2.ZERO
var path_progress: float = 0.0
var current_segment_index: int = 0
var look_ahead_distance: float = 100.0

var next_mistake_time: float = 0.0
var is_making_mistake: bool = false
var mistake_steering: float = 0.0

var approaching_barrier: bool = false
var hop_decision_made: bool = false
var will_hop: bool = false

func _ready():
	if not rider:
		rider = get_parent() as Rider
	
	if rider:
		rider.is_player = false
		rider.barrier_result.connect(_on_barrier_result)
	
	_schedule_next_mistake()

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
	_update_mistakes(delta)
	_apply_rubber_banding()

# --- PATH FOLLOWING ---

func _update_path_following():
	# Find current position on course
	var segments = course.segments
	if segments.size() == 0:
		return
	
	# Get current segment
	var segment = segments[current_segment_index]
	path_progress = segment.get_progress_for_point(rider.global_position)
	
	# Check if we've moved to next segment
	if path_progress > 0.95 and current_segment_index < segments.size() - 1:
		current_segment_index += 1
		path_progress = 0.0
	elif path_progress > 0.95 and current_segment_index == segments.size() - 1:
		# Loop back to start
		current_segment_index = 0
		path_progress = 0.0
	
	# Calculate look-ahead target
	var look_ahead_progress = path_progress + (look_ahead_distance / segment.get_length())
	
	if look_ahead_progress > 1.0:
		# Look ahead into next segment
		var next_index = (current_segment_index + 1) % segments.size()
		var overflow = look_ahead_progress - 1.0
		target_point = segments[next_index].get_point_at_progress(overflow)
	else:
		target_point = segment.get_point_at_progress(look_ahead_progress)
	
	# Add some variance based on skill (less skilled = wobblier line)
	var variance = (1.0 - path_accuracy) * 30.0
	target_point += Vector2(randf_range(-variance, variance), randf_range(-variance, variance))

func _update_steering(delta):
	var to_target = target_point - rider.global_position
	var target_angle = to_target.angle()
	
	# Calculate steering input (-1 to 1)
	var angle_diff = wrapf(target_angle - rider.heading, -PI, PI)
	var steer_input = clampf(angle_diff * 2.0, -1.0, 1.0)
	
	# Apply mistake steering if active
	if is_making_mistake:
		steer_input = mistake_steering
	
	# Apply steering to rider
	rider.heading += steer_input * rider.steering_speed * _get_terrain_grip() * delta

func _get_terrain_grip() -> float:
	var terrain = course.get_terrain_at(rider.global_position)
	var props = TerrainTypes.PROPERTIES.get(terrain, {})
	return props.get("grip", 1.0)

# --- PEDALING ---

func _update_pedaling():
	# Always pedal unless low stamina
	rider.is_pedaling = rider.stamina > 20.0
	
	# Ease off in corners
	var to_target = target_point - rider.global_position
	var angle_diff = abs(wrapf(to_target.angle() - rider.heading, -PI, PI))
	
	if angle_diff > 0.5:  # Sharp turn
		rider.is_pedaling = rider.is_pedaling and rider.stamina > 40.0

# --- BARRIER DECISIONS ---

func _update_barrier_decisions():
	# Check if approaching a barrier
	if rider.approaching_barrier and not hop_decision_made:
		hop_decision_made = true
		
		# Decide: hop or dismount?
		# Factors: skill, stamina, speed
		var hop_chance = hop_skill
		
		# Low stamina = prefer dismount
		if rider.stamina < 30.0:
			hop_chance *= 0.5
		
		# High speed = prefer hop (momentum)
		if rider.current_speed > rider.max_speed * 0.8:
			hop_chance *= 1.3
		
		will_hop = randf() < clampf(hop_chance, 0.1, 0.95)
		
		if not will_hop:
			# Start dismount early
			rider.begin_dismount()
	
	# Execute hop with timing based on skill
	if will_hop and rider.approaching_barrier:
		var barrier = rider.approaching_barrier
		if barrier.has_method("attempt_hop"):
			# Calculate ideal hop timing (skilled AI waits for perfect window)
			var dist = rider.global_position.distance_to(barrier.global_position)
			var ideal_dist = (barrier.perfect_window_start + barrier.perfect_window_end) / 2.0
			
			# Add some variance based on skill
			var timing_variance = (1.0 - hop_skill) * 15.0
			var trigger_dist = ideal_dist + randf_range(-timing_variance, timing_variance)
			
			if dist <= trigger_dist:
				rider.attempt_bunny_hop()
	
	# Reset when no longer approaching barrier
	if not rider.approaching_barrier:
		hop_decision_made = false
		will_hop = false

func _on_barrier_result(result: String):
	# Could use this for AI learning/adaptation
	pass

# --- MISTAKES ---

func _schedule_next_mistake():
	# Random time until next mistake (lower skill = more frequent)
	var base_interval = 10.0 / (mistake_chance + 0.1)
	next_mistake_time = randf_range(base_interval * 0.5, base_interval * 1.5)

func _update_mistakes(delta):
	if is_making_mistake:
		return
	
	next_mistake_time -= delta
	
	if next_mistake_time <= 0:
		_trigger_mistake()
		_schedule_next_mistake()

func _trigger_mistake():
	# Random mistake type
	var mistake_type = randi() % 3
	
	match mistake_type:
		0:  # Oversteer
			is_making_mistake = true
			mistake_steering = [-1.0, 1.0][randi() % 2] * randf_range(0.5, 1.0)
			get_tree().create_timer(randf_range(0.2, 0.5)).timeout.connect(_end_mistake)
		1:  # Brake/hesitate
			rider.is_pedaling = false
			get_tree().create_timer(randf_range(0.3, 0.8)).timeout.connect(func(): rider.is_pedaling = true)
		2:  # Line wobble (minor)
			look_ahead_distance *= 0.5
			get_tree().create_timer(0.5).timeout.connect(func(): look_ahead_distance = 100.0)

func _end_mistake():
	is_making_mistake = false
	mistake_steering = 0.0

# --- RUBBER BANDING ---

func _apply_rubber_banding():
	if not enable_rubber_band:
		rider.max_speed = rider.max_speed  # Use base
		return
	
	var player_progress = _get_player_progress()
	var ai_progress = course.get_race_progress(rider)
	var diff = player_progress - ai_progress
	
	# diff > 0 means AI is behind player
	var speed_mult = base_speed_mult
	
	if diff > 0.1:  # AI behind
		speed_mult = lerpf(base_speed_mult, max_speed_boost, minf(diff * rubber_band_strength, 1.0))
	elif diff < -0.1:  # AI ahead
		speed_mult = lerpf(base_speed_mult, max_speed_penalty, minf(-diff * rubber_band_strength, 1.0))
	
	# Apply (this affects max_speed indirectly through acceleration)
	# Actually modify the base parameters would be cleaner, but this works
	rider.current_speed = minf(rider.current_speed, rider.max_speed * speed_mult)

func _get_player_progress() -> float:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return course.get_race_progress(players[0])
	return 0.0

# --- DEBUG ---

func _draw():
	if not Engine.is_editor_hint() and not OS.is_debug_build():
		return
	
	# Draw target point
	var local_target = target_point - rider.global_position
	draw_circle(local_target, 5.0, Color.YELLOW)
	draw_line(Vector2.ZERO, local_target, Color.YELLOW, 1.0)
