# rider.gd
# Core rider controller - handles movement, states, and elevation
# Attach to CharacterBody2D with Sprite2D and CollisionShape2D children

class_name Rider
extends CharacterBody2D

# Signals
signal state_changed(new_state)
signal stamina_changed(new_value)
signal crossed_finish_line(lap: int)
signal barrier_result(result: String)

# Movement tuning - tweak these until it feels right
@export_group("Movement")
@export var max_speed: float = 400.0
@export var acceleration: float = 800.0
@export var steering_speed: float = 3.5
@export var drag: float = 0.98
@export var drift_factor: float = 0.9  # 1.0 = no drift, 0.0 = ice

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 15.0
@export var stamina_regen_rate: float = 8.0
@export var bonk_threshold: float = 10.0
@export var bonk_speed_penalty: float = 0.5

@export_group("Bunny Hop")
@export var hop_force: float = 150.0
@export var gravity: float = 400.0
@export var hop_speed_boost: float = 1.1  # Perfect hop bonus

@export_group("Dismount")
@export var run_speed_multiplier: float = 0.6
@export var mount_dismount_time: float = 0.3

# State machine
enum State { RIDING, DISMOUNTED, JUMPING, MOUNTING, DISMOUNTING, CRASHED }
var state: State = State.RIDING

# Elevation
var current_layer: int = 0
var height: float = 0.0
var vertical_velocity: float = 0.0

# Runtime state
var stamina: float = max_stamina
var current_speed: float = 0.0
var heading: float = 0.0  # Radians, 0 = right
var is_pedaling: bool = false
var is_bonking: bool = false
var current_terrain: int = 0  # TerrainTypes.Type

# Barrier interaction
var approaching_barrier: Node2D = null
var hop_result: String = ""

# Components (assign in _ready or via @onready)
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

# External references
var course: Node2D = null  # Set by race scene
var is_player: bool = true  # False for AI

func _ready():
	# Find course in parent hierarchy
	var parent = get_parent()
	while parent and not parent.has_method("get_terrain_at"):
		parent = parent.get_parent()
	course = parent
	
	stamina = max_stamina
	add_to_group("riders")
	if is_player:
		add_to_group("player")

func _physics_process(delta):
	if is_player:
		_handle_input()
	
	match state:
		State.RIDING:
			_process_riding(delta)
		State.JUMPING:
			_process_jumping(delta)
		State.DISMOUNTED:
			_process_dismounted(delta)
		State.MOUNTING, State.DISMOUNTING:
			_process_transition(delta)
		State.CRASHED:
			_process_crashed(delta)
	
	_update_elevation(delta)
	_update_stamina(delta)
	_update_visuals()
	
	move_and_slide()

# --- INPUT ---

func _handle_input():
	# Steering
	var steer_input = Input.get_axis("steer_left", "steer_right")
	apply_steering(steer_input)
	
	# Pedaling
	is_pedaling = Input.is_action_pressed("pedal")
	
	# Action button (context-sensitive)
	if Input.is_action_just_pressed("action"):
		_handle_action_pressed()
	
	if Input.is_action_just_released("action"):
		_handle_action_released()

func _handle_action_pressed():
	match state:
		State.RIDING:
			if approaching_barrier:
				attempt_bunny_hop()
			# Could add handup grab here
		State.DISMOUNTED:
			begin_mount()

func _handle_action_released():
	pass  # Reserved for hold-to-dismount if implemented

# --- MOVEMENT STATES ---

func _process_riding(delta):
	var terrain_props = _get_terrain_properties()
	
	# Steering - grip affects turn rate
	var steer_input = Input.get_axis("steer_left", "steer_right") if is_player else 0.0
	var effective_steering = steering_speed * terrain_props.grip
	heading += steer_input * effective_steering * delta
	
	# Acceleration
	if is_pedaling and stamina > 0:
		var terrain_max = max_speed * terrain_props.max_speed_mult
		if is_bonking:
			terrain_max *= bonk_speed_penalty
		current_speed = minf(current_speed + acceleration * delta, terrain_max)
	
	# Apply drag and terrain friction
	current_speed *= drag * terrain_props.friction
	
	# Calculate velocity with drift
	var forward = Vector2.RIGHT.rotated(heading)
	var lateral_velocity = velocity - forward * velocity.dot(forward)
	var forward_velocity = forward * current_speed
	velocity = forward_velocity + lateral_velocity * drift_factor * terrain_props.grip

func _process_jumping(delta):
	# Maintain momentum, reduced steering in air
	var forward = Vector2.RIGHT.rotated(heading)
	velocity = forward * current_speed
	current_speed *= 0.998  # Minimal air resistance

func _process_dismounted(delta):
	var terrain_props = _get_terrain_properties()
	
	# Running - simpler physics
	var steer_input = Input.get_axis("steer_left", "steer_right") if is_player else 0.0
	heading += steer_input * steering_speed * 1.5 * delta  # Faster turning on foot
	
	if is_pedaling:  # "Pedal" = run faster
		var run_max = max_speed * run_speed_multiplier * terrain_props.max_speed_mult
		current_speed = minf(current_speed + acceleration * 0.8 * delta, run_max)
	
	current_speed *= drag * terrain_props.friction
	velocity = Vector2.RIGHT.rotated(heading) * current_speed

func _process_transition(_delta):
	# Slow down during mount/dismount
	current_speed *= 0.95
	velocity = Vector2.RIGHT.rotated(heading) * current_speed

func _process_crashed(delta):
	# Slide to a stop
	current_speed *= 0.9
	velocity = Vector2.RIGHT.rotated(heading) * current_speed
	
	# Auto-recover after a delay (handled by timer or animation)

# --- ELEVATION ---

func _update_elevation(delta):
	var terrain_height = _get_terrain_height()
	var terrain_layer = _get_terrain_layer()
	
	# In air - apply gravity
	if state == State.JUMPING or height > terrain_height + 1.0:
		vertical_velocity -= gravity * delta
		height += vertical_velocity * delta
		
		# Landing
		if height <= terrain_height:
			_land(terrain_height, terrain_layer)
	else:
		# On ground - follow terrain
		height = terrain_height
		current_layer = terrain_layer
	
	# Update collision layers
	collision_layer = 1 << current_layer
	collision_mask = 1 << current_layer

func _land(terrain_height: float, terrain_layer: int):
	height = terrain_height
	vertical_velocity = 0.0
	current_layer = terrain_layer
	
	if state == State.JUMPING:
		_change_state(State.RIDING)
		_on_land()

func _on_land():
	# Feedback for landing
	_play_sound("land")
	_squash_sprite()
	
	# Apply hop result speed modifier
	match hop_result:
		"perfect":
			current_speed *= hop_speed_boost
		"good":
			pass  # Maintain speed
		"early", "late":
			current_speed *= 0.7
	
	hop_result = ""

# --- BUNNY HOP ---

func attempt_bunny_hop():
	if state != State.RIDING or height > 5.0:
		return
	
	if approaching_barrier and approaching_barrier.has_method("attempt_hop"):
		hop_result = approaching_barrier.attempt_hop(self)
		
		match hop_result:
			"perfect", "good":
				_execute_hop()
				barrier_result.emit(hop_result)
			"too_early":
				barrier_result.emit("too_early")
				# No hop, player can try again
			"too_late":
				_crash()
				barrier_result.emit("crash")
	else:
		# Free hop (no barrier)
		hop_result = "good"
		_execute_hop()

func _execute_hop():
	_change_state(State.JUMPING)
	vertical_velocity = hop_force
	_play_sound("hop_launch")
	_stretch_sprite()

# --- DISMOUNT/MOUNT ---

func begin_dismount():
	if state != State.RIDING:
		return
	_change_state(State.DISMOUNTING)
	_play_sound("dismount")
	
	# Transition timer
	get_tree().create_timer(mount_dismount_time).timeout.connect(_finish_dismount)

func _finish_dismount():
	if state == State.DISMOUNTING:
		_change_state(State.DISMOUNTED)

func begin_mount():
	if state != State.DISMOUNTED:
		return
	_change_state(State.MOUNTING)
	_play_sound("mount")
	
	get_tree().create_timer(mount_dismount_time).timeout.connect(_finish_mount)

func _finish_mount():
	if state == State.MOUNTING:
		_change_state(State.RIDING)

# --- CRASH ---

func _crash():
	_change_state(State.CRASHED)
	current_speed *= 0.3
	_play_sound("crash")
	_screen_shake(10.0, 0.3)
	
	# Auto-recover
	get_tree().create_timer(2.0).timeout.connect(_recover_from_crash)

func _recover_from_crash():
	if state == State.CRASHED:
		_change_state(State.RIDING)

# --- STAMINA ---

func _update_stamina(delta):
	if state in [State.CRASHED, State.MOUNTING, State.DISMOUNTING]:
		return
	
	if is_pedaling and state != State.JUMPING:
		stamina -= stamina_drain_rate * delta
		stamina = maxf(stamina, 0.0)
	else:
		stamina += stamina_regen_rate * delta
		stamina = minf(stamina, max_stamina)
	
	# Bonk check
	var was_bonking = is_bonking
	is_bonking = stamina < bonk_threshold
	
	if is_bonking and not was_bonking:
		_play_sound("bonk_start")
	
	stamina_changed.emit(stamina)

# --- TERRAIN HELPERS ---

func _get_terrain_properties() -> Dictionary:
	if course and course.has_method("get_terrain_at"):
		current_terrain = course.get_terrain_at(global_position)
		return TerrainTypes.PROPERTIES.get(current_terrain, TerrainTypes.PROPERTIES[0])
	return TerrainTypes.PROPERTIES[0]  # Default to grass

func _get_terrain_height() -> float:
	if course and course.has_method("get_height_at"):
		return course.get_height_at(global_position)
	return 0.0

func _get_terrain_layer() -> int:
	if course and course.has_method("get_layer_at"):
		return course.get_layer_at(global_position)
	return 0

# --- VISUALS ---

func _update_visuals():
	# Rotation
	sprite.rotation = heading
	
	# Height offset (parallax)
	sprite.position.y = -height * 0.5
	
	# Z-index for draw order
	z_index = int(global_position.y) + (current_layer * 10000) + int(height)
	
	# Animation state (if using AnimationPlayer)
	if animation_player:
		match state:
			State.RIDING:
				if is_pedaling:
					animation_player.play("pedaling")
				else:
					animation_player.play("coasting")
			State.DISMOUNTED:
				animation_player.play("running")
			State.CRASHED:
				animation_player.play("crashed")

func _squash_sprite():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.05)
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.08)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)

func _stretch_sprite():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.08)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)

# --- STATE MANAGEMENT ---

func _change_state(new_state: State):
	var old_state = state
	state = new_state
	state_changed.emit(new_state)

# --- EXTERNAL INTERFACE ---

func apply_steering(input: float):
	# Called by AI controller or input
	# Actual steering happens in _process_riding
	pass

func set_pedaling(value: bool):
	is_pedaling = value

func apply_powerup(type: String):
	match type:
		"beer":
			# Speed boost handled elsewhere
			pass
		"hotdog":
			stamina = max_stamina
		"cowbell":
			# Invincibility flag
			pass
		"dollar":
			# Score multiplier
			pass

# --- FEEDBACK (override or connect to AudioManager) ---

func _play_sound(sound_name: String):
	# Placeholder - connect to AudioManager autoload
	if Engine.has_singleton("AudioManager"):
		Engine.get_singleton("AudioManager").play(sound_name)
	else:
		print("SFX: ", sound_name)

func _screen_shake(intensity: float, duration: float):
	# Placeholder - connect to camera or effects manager
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(intensity, duration)
