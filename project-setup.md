# Cyclocross Project Setup Checklist

## Initial Godot Setup

### 1. Create Project
```
1. Open Godot 4.x
2. New Project → "cyclocross"
3. Renderer: Forward+ (or Compatibility for mobile focus)
4. Create & Edit
```

### 2. Project Settings

**Input Map** (Project → Project Settings → Input Map)
```
steer_left    → A, Left Arrow
steer_right   → D, Right Arrow
pedal         → W, Up Arrow
action        → Space
pause         → Escape
debug_restart → R (for development)
```

**Display** (Project → Project Settings → Display → Window)
```
Viewport Width: 1280
Viewport Height: 720
Stretch Mode: canvas_items
Stretch Aspect: expand
```

**Audio Buses** (Bottom panel → Audio)
```
Create buses:
- Master (default)
- SFX (output to Master)
- Music (output to Master)
```

**Autoloads** (Project → Project Settings → Autoload)
```
res://src/autoload/game_manager.gd    → GameManager
res://src/autoload/audio_manager.gd   → AudioManager
```

### 3. Create Folder Structure
```
res://
├── assets/
│   ├── sprites/
│   │   ├── rider/
│   │   ├── terrain/
│   │   └── objects/
│   ├── audio/
│   │   ├── sfx/
│   │   └── music/
│   └── ui/
├── src/
│   ├── autoload/
│   ├── rider/
│   ├── course/
│   │   └── obstacles/
│   ├── camera/
│   ├── ui/
│   └── effects/
├── courses/
└── scenes/
```

### 4. Create Placeholder Assets

**Rider placeholder** (32x32 PNG)
- Green rectangle or simple bike shape
- Save as `res://assets/sprites/rider/rider_placeholder.png`

**Terrain tiles** (32x32 each)
- Grass: #4a7c3f solid
- Mud: #5c4033 solid
- Sand: #c2a366 solid  
- Pavement: #555555 solid
- Save in `res://assets/sprites/terrain/`

**Barrier placeholder**
- Red horizontal line/rectangle
- Save as `res://assets/sprites/objects/barrier.png`

---

## Scene Creation Order

### Phase 1: Core Rider

**1. Create rider.tscn**
```
Rider (CharacterBody2D)
├── Sprite2D
│   └── texture: rider_placeholder.png
├── CollisionShape2D
│   └── shape: CircleShape2D (radius: 12)
└── Camera2D (temporary, for testing)
```

**2. Attach rider.gd**
- Copy from artifact
- Test with arrow keys / WASD

**3. Create test_arena.tscn**
```
TestArena (Node2D)
├── TileMapLayer
│   └── Add grass tiles for ground
├── Rider (instance rider.tscn)
└── Camera2D (attached to Rider)
```

### Phase 2: Terrain

**1. Create TileSet**
- New TileSet resource
- Add terrain tile textures
- Set up physics layers

**2. Implement terrain detection**
- Add terrain_types.gd to project
- Test rider speed changes on different tiles

### Phase 3: Barriers

**1. Create barrier.tscn**
```
Barrier (Area2D)
├── Sprite2D
│   └── barrier texture
├── CollisionShape2D (detection zone)
│   └── RectangleShape2D (80x20)
└── CollisionShape2D (actual barrier)
    └── RectangleShape2D (60x8)
```

**2. Attach barrier.gd**
- Copy from artifact
- Test bunny hop timing

### Phase 4: Course System

**1. Create course resources**
- course_segment.gd → Resource class
- Create test course .tres file

**2. Create course.tscn**
```
Course (Node2D) [course.gd]
├── TerrainLayer0 (TileMapLayer)
├── Obstacles (Node2D)
│   ├── Barriers (Node2D)
│   ├── Handups (Node2D)
│   └── RampTriggers (Node2D)
└── Decorations (Node2D)
```

---

## First Playable Checklist

Before first external playtest, verify:

- [ ] Rider moves with WASD/arrows
- [ ] Terrain affects speed (mud slower than grass)
- [ ] Bunny hop works with timing feedback
- [ ] Dismount/mount cycles work
- [ ] Stamina depletes and regenerates
- [ ] At least one complete loop course
- [ ] Basic sound effects (can be jsfxr placeholders)
- [ ] Screen shake on impacts
- [ ] Restart hotkey works (R)
- [ ] Builds run on target platform

---

## File Checklist

Copy these files from artifacts:

### Autoloads
- [ ] `src/autoload/game_manager.gd`
- [ ] `src/autoload/audio_manager.gd`

### Rider
- [ ] `src/rider/rider.gd`
- [ ] `src/rider/ai_controller.gd`

### Course
- [ ] `src/course/terrain_types.gd`
- [ ] `src/course/course_segment.gd`
- [ ] `src/course/course.gd`
- [ ] `src/course/obstacles/barrier.gd`
- [ ] `src/course/obstacles/handup.gd`

### Camera & UI
- [ ] `src/camera/race_camera.gd`
- [ ] `src/ui/minimap.gd`

---

## Quick Reference: Tuning Values

**Rider feel (start here)**
```gdscript
max_speed = 400.0        # Increase for faster pace
acceleration = 800.0     # Higher = snappier response
steering_speed = 3.5     # Higher = twitchier
drag = 0.98              # Lower = more slide
```

**Barrier timing**
```gdscript
detection_distance = 80.0
hop_window_start = 50.0      # Easier = larger number
hop_window_end = 12.0        # Harder = larger number
perfect_window_start = 25.0
perfect_window_end = 15.0
```

**Stamina pacing**
```gdscript
max_stamina = 100.0
stamina_drain_rate = 15.0    # Higher = more strategic
stamina_regen_rate = 8.0
bonk_threshold = 10.0
```

---

## Sound Effect Generation (jsfxr)

Quick settings to get started:

| Sound | jsfxr Preset | Adjustments |
|-------|-------------|-------------|
| hop_launch | Jump | Shorter, pitch up |
| land_good | Hit | Lower pitch, short |
| land_perfect | Powerup | Quick, satisfying |
| crash | Explosion | Small, noisy |
| pedal_tick | Blip | Very short, quiet |
| terrain_mud | Random | Filter down, loopable |
| handup_grab | Coin | As-is |
| countdown_beep | Blip | Clean tone |
| countdown_go | Powerup | Longer, exciting |

Export as .wav, place in `res://assets/audio/sfx/`

---

## Next Steps After Setup

1. **Get the bike feeling good** (most important!)
   - Spend time just driving around
   - Tune until it's satisfying before anything else

2. **Add one barrier**
   - Test bunny hop feel
   - Adjust timing windows

3. **Build a simple loop course**
   - Just grass, maybe one mud patch
   - Finish line detection

4. **Add one AI opponent**
   - Verify collision
   - Basic rubber banding

5. **First playtest!**
   - Watch someone else play
   - Don't explain controls
   - Take notes
