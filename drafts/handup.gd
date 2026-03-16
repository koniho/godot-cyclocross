# handup.gd
# Spectator offering powerups at course edge
# Attach to Area2D with CollisionShape2D

class_name Handup
extends Area2D

signal grabbed(rider: Node2D, type: int)

enum Type {
	BEER,       # Speed boost
	COWBELL,    # Invincibility
	DOLLAR,     # Score multiplier
	HOTDOG      # Stamina refill
}

@export var handup_type: Type = Type.BEER
@export var grab_window: float = 0.5  # Seconds to grab while in range
@export var respawn_time: float = 10.0  # Time before handup reappears
@export var grab_distance: float = 25.0  # How close rider must be to edge

# Powerup effect values
const EFFECTS = {
	Type.BEER: {"duration": 3.0, "speed_boost": 1.15},
	Type.COWBELL: {"duration": 4.0},
	Type.DOLLAR: {"duration": 10.0, "score_mult": 2.0},
	Type.HOTDOG: {"stamina_restore": 100.0}
}

# Runtime
var is_available: bool = true
var riders_in_range: Dictionary = {}  # rider -> time_in_range

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var spectator_sprite: Sprite2D = $SpectatorSprite if has_node("SpectatorSprite") else null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_update_visual()

func _physics_process(delta):
	if not is_available:
		return
	
	# Update grab timers
	var to_remove: Array = []
	for rider in riders_in_range:
		if not is_instance_valid(rider):
			to_remove.append(rider)
			continue
		
		riders_in_range[rider] += delta
		
		# Check if rider is pressing action or close enough for auto-grab
		var should_grab = false
		
		if rider is Rider:
			# Auto-grab when very close to spectator
			var dist = rider.global_position.distance_to(global_position)
			if dist < grab_distance:
				should_grab = true
			# Or explicit grab with action button (if implemented)
		
		if should_grab and riders_in_range[rider] > 0.1:  # Small delay to prevent instant grab
			_grab(rider)
			break
	
	for rider in to_remove:
		riders_in_range.erase(rider)

func _on_body_entered(body: Node2D):
	if body is Rider and is_available:
		riders_in_range[body] = 0.0
		_show_grab_prompt(body)

func _on_body_exited(body: Node2D):
	if body in riders_in_range:
		riders_in_range.erase(body)
		_hide_grab_prompt(body)

func _grab(rider: Node2D):
	if not is_available:
		return
	
	is_available = false
	riders_in_range.clear()
	
	# Apply effect
	_apply_effect(rider)
	
	# Feedback
	grabbed.emit(rider, handup_type)
	if has_node("/root/AudioManager"):
		AudioManager.play("handup_grab")
	
	# Visual feedback
	_animate_grab()
	
	# Record stat
	if rider.is_in_group("player"):
		GameManager.record_handup_grab()
	
	# Schedule respawn
	get_tree().create_timer(respawn_time).timeout.connect(_respawn)

func _apply_effect(rider: Node2D):
	if not rider is Rider:
		return
	
	var effect = EFFECTS[handup_type]
	
	match handup_type:
		Type.BEER:
			_apply_speed_boost(rider, effect.speed_boost, effect.duration)
		Type.COWBELL:
			_apply_invincibility(rider, effect.duration)
		Type.DOLLAR:
			_apply_score_multiplier(rider, effect.score_mult, effect.duration)
		Type.HOTDOG:
			rider.stamina = rider.max_stamina

func _apply_speed_boost(rider: Rider, multiplier: float, duration: float):
	var original_max = rider.max_speed
	rider.max_speed *= multiplier
	
	# Visual indicator
	_add_effect_particles(rider, Color(1.0, 0.8, 0.3))  # Beer gold
	
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(rider):
			rider.max_speed = original_max
	)

func _apply_invincibility(rider: Rider, duration: float):
	# Add to invincibility group
	rider.add_to_group("invincible")
	
	# Visual indicator
	rider.modulate = Color(1.2, 1.2, 1.0)
	_add_effect_particles(rider, Color(0.8, 0.8, 0.2))  # Cowbell brass
	
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(rider):
			rider.remove_from_group("invincible")
			rider.modulate = Color.WHITE
	)

func _apply_score_multiplier(rider: Rider, multiplier: float, duration: float):
	# This would integrate with a scoring system
	# For now, just track it
	rider.set_meta("score_multiplier", multiplier)
	
	_add_effect_particles(rider, Color(0.2, 0.8, 0.2))  # Dollar green
	
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(rider):
			rider.remove_meta("score_multiplier")
	)

func _add_effect_particles(rider: Node2D, color: Color):
	# Placeholder - would create actual particle effect
	var tween = create_tween().set_loops(3)
	tween.tween_property(rider, "modulate", color, 0.2)
	tween.tween_property(rider, "modulate", Color.WHITE, 0.2)

# --- VISUALS ---

func _update_visual():
	if not sprite:
		return
	
	# Set color/frame based on type
	match handup_type:
		Type.BEER:
			sprite.modulate = Color(0.9, 0.7, 0.2)
		Type.COWBELL:
			sprite.modulate = Color(0.8, 0.7, 0.3)
		Type.DOLLAR:
			sprite.modulate = Color(0.3, 0.8, 0.3)
		Type.HOTDOG:
			sprite.modulate = Color(0.9, 0.6, 0.3)

func _animate_grab():
	if spectator_sprite:
		# Arm retract animation
		var tween = create_tween()
		tween.tween_property(spectator_sprite, "position:x", spectator_sprite.position.x - 10, 0.1)
	
	if sprite:
		# Item disappears
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.2)

func _respawn():
	is_available = true
	
	if sprite:
		sprite.modulate.a = 1.0
		sprite.scale = Vector2.ONE
	
	if spectator_sprite:
		spectator_sprite.position.x += 10  # Reset arm position

func _show_grab_prompt(rider: Node2D):
	# Could show UI indicator
	pass

func _hide_grab_prompt(rider: Node2D):
	pass

# --- DEBUG ---

func _draw():
	if not Engine.is_editor_hint() and not OS.is_debug_build():
		return
	
	# Draw grab range
	draw_circle(Vector2.ZERO, grab_distance, Color(0, 1, 0, 0.3))
