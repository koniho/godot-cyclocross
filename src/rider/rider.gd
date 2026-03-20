# rider.gd
class_name Rider
extends CharacterBody2D

const TerrainTypes = preload("res://src/course/terrain_types.gd")

signal state_changed(new_state)
signal stamina_changed(new_value)
signal barrier_result(result: String)

@export_group("Movement")
@export var max_speed: float = 420.0       # pavement top speed px/s (~47 km/h)
@export var acceleration: float = 75.0    # px/s²
@export var drift_factor: float = 0.9

@export_group("Steering")
@export var turn_rate_accel: float = 8.0   # rad/s² — how fast angular velocity builds up
@export var turn_rate_decel: float = 14.0  # rad/s² — how fast it decays when releasing
@export var max_turn_rate: float = 2.8     # rad/s max angular velocity at zero speed
@export var turn_speed_damp: float = 150.0 # speed (px/s) at which max turn rate is halved
@export var slide_threshold: float = 480.0 # v*ω (px/s²) before sliding out and crashing

@export_group("Stamina")
@export var max_stamina: float = 300.0
@export var stamina_drain_rate: float = 3.0   # drains in ~100s of constant pedaling
@export var stamina_regen_rate: float = 12.0  # refills in ~25s of coasting
@export var bonk_threshold: float = 30.0      # below this = bonking (low accel)
@export var bonk_accel_floor: float = 0.1     # minimum acceleration multiplier at 0 stamina

@export_group("Bunny Hop")
@export var hop_force: float = 100.0       # gives ~12 px apex, ~0.5s airborne
@export var gravity: float = 400.0
@export var hop_speed_boost: float = 1.1

@export_group("Braking")
@export var brake_light_force: float = 110.0  # px/s² at the start of a tap
@export var brake_hard_force: float = 380.0   # px/s² when held
@export var brake_ramp_time: float = 0.35     # seconds to ramp from light to hard

@export_group("Dismount")
@export var run_speed_multiplier: float = 0.3   # 126 px/s — faster than sand/mud but not by much
@export var mount_dismount_time: float = 0.3

# Minimum height at which course-bounds check is suspended (bridge exempt)
const BRIDGE_EXEMPT_HEIGHT := 8.0

# Two-wheel collision model
const WHEEL_OFFSET := 14.0   # px from centre to each wheel along heading
const WHEEL_RADIUS :=  6.0   # collision circle radius per wheel

enum State { RIDING, DISMOUNTED, JUMPING, MOUNTING, DISMOUNTING, CRASHED }
var state: State = State.RIDING

var current_layer: int = 0
var height: float = 0.0
var vertical_velocity: float = 0.0

var stamina: float = max_stamina
var current_speed: float = 0.0
var heading: float = 0.0
var is_pedaling: bool = false
var is_bonking: bool = false
var current_terrain: int = 0

var steering_rate: float = 0.0  # current angular velocity rad/s (has inertia)
var is_braking: bool = false
var _brake_hold_time: float = 0.0
var approaching_barrier: Node2D = null
var hop_result: String = ""
var _jump_from_state: State = State.RIDING

var course: Node2D = null
var is_player: bool = true
var _squashing: bool = false

var _wheel_front: CollisionShape2D = null
var _wheel_rear:  CollisionShape2D = null
var _wheel_angle: float = 0.0   # visual rotation accumulator (radians)
var _slope: float = 0.0         # current terrain slope (positive = uphill)
var _wobble_timer: float = 0.0  # seconds remaining of steering wobble
var _stumble_flash: float = 0.0 # seconds remaining of red flash
var _stumble_cooldown: float = 0.0 # prevents re-triggering stumble every frame

@onready var sprite: Sprite2D = $Sprite2D
@onready var bike_sprite: Sprite2D = $BikeSprite
@onready var shadow: Sprite2D = $Shadow
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready():
	stamina = max_stamina
	add_to_group("riders")
	if is_player:
		add_to_group("player")

	# Prevent canvas culling — _draw() content must remain visible at any world position
	RenderingServer.canvas_item_set_custom_rect(get_canvas_item(), true, Rect2(-10000, -10000, 20000, 20000))

	course = get_tree().get_first_node_in_group("course")

	# Hide placeholder sprites — visuals handled by _draw()
	sprite.visible      = false
	bike_sprite.visible = false

	# Replace single collision circle with two wheel points
	collision.disabled = true
	for is_front in [true, false]:
		var col   := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = WHEEL_RADIUS
		col.shape = shape
		add_child(col)
		if is_front:
			_wheel_front = col
		else:
			_wheel_rear = col

func _process(delta: float) -> void:
	if _stumble_flash > 0.0:
		_stumble_flash -= delta
	if _stumble_cooldown > 0.0:
		_stumble_cooldown -= delta
	queue_redraw()

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

	# Advance wheel rotation when on bike (not when running dismounted)
	if state != State.DISMOUNTED:
		_wheel_angle += current_speed * delta / 7.5

	# Keep wheel shapes aligned to heading direction
	var fwd := Vector2.RIGHT.rotated(heading)
	if _wheel_front:
		_wheel_front.position =  fwd * WHEEL_OFFSET
	if _wheel_rear:
		_wheel_rear.position  = -fwd * WHEEL_OFFSET

	_update_elevation(delta)
	_update_stamina(delta)
	_check_course_bounds()
	_update_visuals()

	move_and_slide()

func _handle_input():
	is_pedaling = Input.is_action_pressed("pedal")
	is_braking  = Input.is_action_pressed("brake")
	if Input.is_action_just_released("brake"):
		_brake_hold_time = 0.0

	if Input.is_action_just_pressed("action"):
		if state == State.RIDING or state == State.DISMOUNTED:
			attempt_bunny_hop()

	if Input.is_action_just_pressed("dismount"):
		if state == State.RIDING:
			begin_dismount()
		elif state == State.DISMOUNTED:
			begin_mount()

func _process_riding(delta):
	var terrain_props = _get_terrain_properties()

	var steer_input := Input.get_axis("steer_left", "steer_right") if is_player else 0.0

	# Speed-dependent max turn rate: high speed → tighter limit, like a real bicycle.
	var speed_factor := 1.0 + current_speed / turn_speed_damp
	var grip: float = terrain_props.grip
	var effective_max: float = max_turn_rate * grip / speed_factor

	# Steering angular velocity has inertia — it accelerates and decelerates smoothly.
	var target_rate := steer_input * effective_max
	var rate_change := turn_rate_accel if absf(target_rate) >= absf(steering_rate) else turn_rate_decel
	steering_rate = move_toward(steering_rate, target_rate, rate_change * delta)
	heading += steering_rate * delta

	# Stamina affects acceleration only — not max speed.
	var stamina_ratio := clampf(stamina / max_stamina, 0.0, 1.0)
	var accel_mult := lerpf(bonk_accel_floor, 1.0, stamina_ratio)

	var terrain_max: float = max_speed * terrain_props.max_speed_mult
	var terrain_decel: float = terrain_props.get("deceleration", 30.0)

	# Slope-based speed: compute height difference between front and rear wheel
	var fwd_slope := Vector2.RIGHT.rotated(heading)
	var front_pos := global_position + fwd_slope * WHEEL_OFFSET
	var rear_pos  := global_position - fwd_slope * WHEEL_OFFSET
	var h_front := _get_height_at_pos(front_pos)
	var h_rear  := _get_height_at_pos(rear_pos)
	var slope_val := (h_front - h_rear) / (WHEEL_OFFSET * 2.0)  # positive = uphill
	_slope = slope_val
	# Uphill: reduce speed; downhill: boost speed
	if slope_val > 0.01:
		var uphill_factor := clampf(slope_val * 4.0, 0.0, 0.6)  # up to 60% reduction
		terrain_max *= (1.0 - uphill_factor)
		accel_mult *= (1.0 - uphill_factor * 0.8)
	elif slope_val < -0.01:
		var downhill_factor := clampf(-slope_val * 3.0, 0.0, 0.4)  # up to 40% boost
		terrain_max *= (1.0 + downhill_factor)
		terrain_decel *= (1.0 - downhill_factor * 0.7)  # coasts longer downhill

	# Camber-based grip: off-camber reduces grip, on-camber increases it
	var camber := _get_camber()
	if camber < 0.0:
		grip *= (1.0 + camber * 0.3)  # off-camber: up to 30% grip reduction at -1.0
	elif camber > 0.0:
		grip *= (1.0 + camber * 0.15)  # on-camber: up to 15% grip increase at +1.0

	if is_braking:
		# Ramp from light to hard braking the longer the key is held
		_brake_hold_time += delta
		var brake_t := clampf(_brake_hold_time / brake_ramp_time, 0.0, 1.0)
		var brake_force := lerpf(brake_light_force, brake_hard_force, brake_t)
		current_speed = move_toward(current_speed, 0.0, brake_force * delta)
	elif is_pedaling:
		_brake_hold_time = 0.0
		current_speed = move_toward(current_speed, terrain_max, acceleration * accel_mult * delta)
	else:
		_brake_hold_time = 0.0
		current_speed = move_toward(current_speed, 0.0, terrain_decel * delta)

	var forward := Vector2.RIGHT.rotated(heading)
	var lateral_velocity := velocity - forward * velocity.dot(forward)

	# Slide-out check: centripetal acceleration v*ω — too tight at speed → stumble.
	var centripetal := current_speed * absf(steering_rate)
	if centripetal > slide_threshold * grip:
		_stumble(0.5, 0.8)
		steering_rate *= 0.3
		return

	# Apply wobble from recent stumble
	if _wobble_timer > 0.0:
		_wobble_timer -= delta
		steering_rate += randf_range(-3.0, 3.0) * delta * (_wobble_timer / 0.8)

	# Terrain wobble: low-grip surfaces cause continuous steering instability
	# Stronger at higher speeds, proportional to how slippery the surface is
	if grip < 0.8 and current_speed > 30.0:
		var wobble_strength := (1.0 - grip) * (current_speed / max_speed) * 4.0
		steering_rate += randf_range(-wobble_strength, wobble_strength) * delta

	velocity = forward * current_speed + lateral_velocity * (grip * drift_factor)

func _process_jumping(_delta):
	velocity = Vector2.RIGHT.rotated(heading) * current_speed

func _process_dismounted(delta):
	# Running on foot: terrain doesn't affect run speed — this is the sand advantage.
	# Sand ride max = 109 px/s; run max = 252 px/s. Dismount is ~2.3× faster in sand.
	var steer_input := Input.get_axis("steer_left", "steer_right") if is_player else 0.0
	# More responsive turning on foot than on bike
	var target_rate := steer_input * max_turn_rate * 1.5
	var rate_change := turn_rate_accel * 2.5 if absf(target_rate) >= absf(steering_rate) else turn_rate_decel * 2.5
	steering_rate = move_toward(steering_rate, target_rate, rate_change * delta)
	heading += steering_rate * delta

	var run_max := max_speed * run_speed_multiplier
	if is_braking:
		_brake_hold_time = 0.0
		current_speed = move_toward(current_speed, 0.0, 2000.0 * delta)  # near-instant stop on foot
	elif is_pedaling:
		_brake_hold_time = 0.0
		current_speed = move_toward(current_speed, run_max, acceleration * 6.0 * delta)
	else:
		_brake_hold_time = 0.0
		current_speed = move_toward(current_speed, 0.0, acceleration * 8.0 * delta)

	velocity = Vector2.RIGHT.rotated(heading) * current_speed

func _process_transition(delta):
	steering_rate = move_toward(steering_rate, 0.0, turn_rate_decel * delta)
	current_speed = move_toward(current_speed, 0.0, acceleration * delta)
	velocity = Vector2.RIGHT.rotated(heading) * current_speed

func _process_crashed(delta):
	steering_rate = move_toward(steering_rate, 0.0, turn_rate_decel * 2.0 * delta)
	current_speed = move_toward(current_speed, 0.0, acceleration * 2.0 * delta)
	velocity = Vector2.RIGHT.rotated(heading) * current_speed

func _update_elevation(delta):
	var terrain_height = _get_terrain_height()
	var terrain_layer = _get_terrain_layer()

	if state == State.JUMPING or height > terrain_height + 1.0:
		vertical_velocity -= gravity * delta
		height += vertical_velocity * delta

		if height <= terrain_height:
			height = terrain_height
			vertical_velocity = 0.0
			current_layer = terrain_layer
			if state == State.JUMPING:
				_land()
	else:
		height = terrain_height
		current_layer = terrain_layer

	collision_layer = 1 << current_layer
	collision_mask = (1 << current_layer) | 4

func _check_course_bounds() -> void:
	if state == State.CRASHED:
		return
	# Exempt when elevated above ground (bridge/jump)
	var terrain_h := _get_terrain_height()
	if height - terrain_h > BRIDGE_EXEMPT_HEIGHT:
		return
	if not course or not course.has_method("is_on_course"):
		return
	var fwd := Vector2.RIGHT.rotated(heading)
	var front_g := to_global( fwd * WHEEL_OFFSET)
	var rear_g  := to_global(-fwd * WHEEL_OFFSET)
	if not course.is_on_course(front_g) or not course.is_on_course(rear_g):
		if course.has_method("animate_tape_at"):
			course.animate_tape_at(course.to_local(global_position))
		_crash_off_course()

func _land():
	state = _jump_from_state  # return to riding or dismounted depending on jump origin
	state_changed.emit(state)
	_squash_sprite()

	match hop_result:
		"perfect":
			current_speed *= hop_speed_boost
		"early", "late":
			current_speed *= 0.7
	hop_result = ""

func _update_stamina(delta):
	if state in [State.CRASHED, State.MOUNTING, State.DISMOUNTING]:
		return

	if is_pedaling and state != State.JUMPING:
		stamina -= stamina_drain_rate * delta
		stamina = maxf(stamina, 0.0)
	else:
		stamina += stamina_regen_rate * delta
		stamina = minf(stamina, max_stamina)

	is_bonking = stamina < bonk_threshold
	stamina_changed.emit(stamina)

func _update_visuals():
	z_index = clampi(int(global_position.y) + current_layer * 3000 + int(height), -4096, 4096)

func _draw() -> void:
	var fwd  := Vector2.RIGHT.rotated(heading)
	var side := fwd.rotated(PI * 0.5)
	var lift := Vector2(0.0, -height * 3.0)   # match sprite elevation scale

	# Pitch: slope tilts the bike so front is higher/lower than rear visually.
	# _slope is height_change / distance — multiply by VIS_SCALE * wheel_spread
	# to get pixel offset between front and rear draw positions.
	var pitch_px := _slope * 3.0 * WHEEL_OFFSET  # visual pitch in pixels

	# Hide placeholder shadow sprite — we draw our own
	if shadow:
		shadow.visible = false

	# Draw shadow on the visual ground surface, oriented along heading with pitch
	# Ground height = height from terrain (excludes jump/bridge arch above ground)
	var ground_h := _get_terrain_height_only()
	var ground_lift := Vector2(0.0, -ground_h * 3.0)  # visual ground position
	var air_gap := height - ground_h                    # how far above ground (jump/bridge)
	var sh_alpha := 0.3 - clampf(air_gap / 60.0, 0.0, 1.0) * 0.2
	if sh_alpha > 0.01:
		var sh_col := Color(0.0, 0.0, 0.0, sh_alpha)
		var sh_spread := 1.0 + air_gap / 40.0   # shadow grows when airborne
		var sh_rear  := ground_lift - fwd * 14.0 * sh_spread + Vector2(0.0, pitch_px * 0.3)
		var sh_front := ground_lift + fwd * 14.0 * sh_spread + Vector2(0.0, -pitch_px * 0.3)
		var sh_side  := side * 5.0 * sh_spread
		draw_polygon(
			PackedVector2Array([
				sh_front + sh_side, sh_front - sh_side,
				sh_rear - sh_side, sh_rear + sh_side
			]),
			PackedColorArray([sh_col, sh_col, sh_col, sh_col])
		)

	# Stumble flash: tint red briefly on hit
	var flash := _stumble_flash > 0.0 and fmod(_stumble_flash, 0.15) < 0.075
	var rider_col := Color(1.0, 0.3, 0.3) if flash else Color(0.25, 0.55, 0.90)
	var frame_col := Color(0.9, 0.3, 0.2) if flash else Color(0.55, 0.42, 0.22)

	match state:
		State.RIDING, State.MOUNTING, State.DISMOUNTING:
			_draw_bike(fwd, side, lift, frame_col, Color(0.2, 0.2, 0.22), pitch_px)
			_draw_rider_body(fwd * 3.0 + lift + Vector2(0.0, -pitch_px * 0.3), rider_col)

		State.JUMPING:
			_draw_bike(fwd, side, lift, Color(0.70, 0.60, 0.18), Color(0.25, 0.25, 0.25), 0.0)
			_draw_rider_body(fwd * 3.0 + lift, Color(1.0, 0.85, 0.15))

		State.DISMOUNTED:
			var bike_offset := fwd * -20.0 + lift
			_draw_bike(fwd, side, bike_offset, Color(0.45, 0.45, 0.48), Color(0.2, 0.2, 0.22), 0.0)
			_draw_runner(fwd, side, lift)

		State.CRASHED:
			var crash_fwd  := Vector2.RIGHT.rotated(heading + PI * 0.5)
			var crash_side := crash_fwd.rotated(PI * 0.5)
			_draw_bike(crash_fwd, crash_side, lift, Color(0.7, 0.2, 0.2), Color(0.3, 0.1, 0.1), 0.0)
			_draw_rider_body(side * 20.0 + lift, Color(1.0, 0.3, 0.3))

func _draw_bike(fwd: Vector2, side: Vector2, offset: Vector2,
		frame_col: Color, wheel_col: Color, pitch: float = 0.0) -> void:
	# Pitch offsets front up and rear down (negative y = higher on screen)
	var rear  := -fwd * 14.0 + offset + Vector2(0.0, pitch * 0.5)
	var front :=  fwd * 14.0 + offset + Vector2(0.0, -pitch * 0.5)
	# Frame
	draw_line(rear, front, frame_col, 3.5)
	# Seat stay / top tube hint
	draw_line(rear + side * 2.0, front - fwd * 4.0 + offset, frame_col.darkened(0.2), 2.0)
	# Wheels with spinning quadrant coloring and orientation shape
	_draw_wheel(rear,  7.5, wheel_col, frame_col, _wheel_angle, fwd)
	_draw_wheel(front, 7.5, wheel_col, frame_col, _wheel_angle, fwd)
	# Handlebar
	draw_line(front - side * 5.0, front + side * 5.0, frame_col.lightened(0.2), 2.0)
	# Collision radius indicator (faint ring — shows actual hitbox)
	draw_arc(offset, 12.0, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.18), 1.0)

func _draw_wheel(center: Vector2, r: float, col_a: Color, col_b: Color, angle: float, fwd: Vector2) -> void:
	# Squash wheel along heading: thin when going sideways (profile view),
	# rounder when going toward/away from camera (tread view).
	var fwd_scale := maxf(0.15, absf(fwd.x))
	draw_set_transform(center, fwd.angle(), Vector2(fwd_scale, 1.0))
	# Flip spin direction when facing left so the wheel rolls the correct way.
	var spin := angle if fwd.x >= 0.0 else -angle
	var qa := col_a
	var qb := col_b.lightened(0.25)
	for q in 4:
		var a0 := spin + q * (TAU / 4.0)
		var a1 := a0 + TAU / 4.0
		var col := qa if q % 2 == 0 else qb
		draw_arc(Vector2.ZERO, r, a0, a1, 8, col, r)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, col_b.lightened(0.4), 1.5)
	draw_set_transform(Vector2.ZERO)

func _draw_rider_body(center: Vector2, col: Color) -> void:
	# Torso
	draw_circle(center, 6.0, col)
	# Helmet highlight
	draw_circle(center + Vector2(0.0, -2.0), 3.0, col.lightened(0.4))

func _draw_runner(fwd: Vector2, _side: Vector2, offset: Vector2) -> void:
	# Upright body — tall and narrow (running silhouette)
	var feet  := offset + Vector2(0.0,  5.0)
	var head  := offset + Vector2(0.0, -12.0)
	var torso := (feet + head) * 0.5
	draw_line(feet, head, Color(0.3, 0.65, 1.0), 4.0)
	draw_circle(head, 5.0, Color(0.3, 0.65, 1.0))
	# Arms swinging
	draw_line(torso - fwd * 6.0, torso + fwd * 6.0, Color(0.3, 0.65, 1.0).lightened(0.2), 2.5)
	draw_arc(offset, 12.0, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.18), 1.0)

func _squash_sprite():
	_squashing = true
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(2.6, 0.5), 0.06)
	tween.tween_property(sprite, "scale", Vector2(1.6, 1.3), 0.1)
	tween.tween_property(sprite, "scale", Vector2(2.0, 1.0), 0.12)
	tween.tween_callback(func(): _squashing = false)

func attempt_bunny_hop():
	if state != State.RIDING and state != State.DISMOUNTED:
		return
	# Only allow hop if close to the ground (not already airborne)
	var terrain_h := _get_terrain_height()
	if height - terrain_h > 5.0:
		return

	if approaching_barrier and approaching_barrier.has_method("attempt_hop"):
		hop_result = approaching_barrier.attempt_hop(self)

		match hop_result:
			"perfect", "good":
				_execute_hop()
				barrier_result.emit(hop_result)
			"too_late":
				_crash()
				barrier_result.emit("crash")
			# "too_early": ignore — rider can try again
	else:
		hop_result = "good"
		_execute_hop()

func _execute_hop():
	_jump_from_state = state  # remember whether we jumped from riding or running
	state = State.JUMPING
	state_changed.emit(state)
	vertical_velocity = hop_force
	AudioManager.play("hop_launch")

func begin_dismount():
	if state != State.RIDING:
		return
	state = State.DISMOUNTING
	state_changed.emit(state)
	get_tree().create_timer(mount_dismount_time).timeout.connect(_finish_dismount)

func _finish_dismount():
	if state == State.DISMOUNTING:
		state = State.DISMOUNTED
		state_changed.emit(state)

func begin_mount():
	if state != State.DISMOUNTED:
		return
	state = State.MOUNTING
	state_changed.emit(state)
	get_tree().create_timer(mount_dismount_time).timeout.connect(_finish_mount)

func _finish_mount():
	if state == State.MOUNTING:
		state = State.RIDING
		state_changed.emit(state)

## Stumble: speed penalty + wobble + stamina drain. No state change — keeps riding.
## speed_mult: how much speed to keep (0.5 = lose half)
## wobble_time: seconds of steering instability
func _stumble(speed_mult: float, wobble_time: float) -> void:
	if _stumble_cooldown > 0.0:
		return
	current_speed *= speed_mult
	_wobble_timer = maxf(_wobble_timer, wobble_time)
	_stumble_flash = 0.5
	_stumble_cooldown = 1.0   # can't re-stumble for 1 second
	stamina = maxf(stamina - max_stamina * 0.15, 0.0)
	stamina_changed.emit(stamina)
	AudioManager.play("crash")

func _crash():
	# Slide-out / general crash → stumble with moderate penalty
	_stumble(0.5, 0.8)

func crash_into_tape() -> void:
	# Tape collision: light stumble — speed cut + brief wobble
	if state == State.CRASHED or state == State.DISMOUNTED:
		return
	_stumble(0.7, 0.5)

func _crash_off_course():
	# Off-course: heavier stumble
	_stumble(0.4, 1.0)

func _get_terrain_properties() -> Dictionary:
	if course and course.has_method("get_terrain_at"):
		current_terrain = course.get_terrain_at(global_position)
		return TerrainTypes.PROPERTIES.get(current_terrain, TerrainTypes.PROPERTIES[0])
	return TerrainTypes.PROPERTIES[0]

func _get_terrain_height() -> float:
	if course and course.has_method("get_height_at"):
		return course.get_height_at(global_position)
	return 0.0

func _get_terrain_layer() -> int:
	if course and course.has_method("get_layer_at"):
		return course.get_layer_at(global_position)
	return 0

func _get_height_at_pos(pos: Vector2) -> float:
	if course and course.has_method("get_height_at"):
		return course.get_height_at(pos)
	return 0.0

func _get_camber() -> float:
	if course and course.has_method("get_camber_at"):
		return course.get_camber_at(global_position)
	return 0.0

func _get_terrain_height_only() -> float:
	# Ground height only (no bridge arch, no jump) — for shadow placement
	if course and course.has_method("get_ground_height_at"):
		return course.get_ground_height_at(course.to_local(global_position))
	return 0.0
