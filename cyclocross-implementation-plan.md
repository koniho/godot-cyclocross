# Cyclocross Arcade Racer - Implementation Plan

## Project Overview

An arcade cyclocross racing game inspired by Iron Man Off-Road Racing. Top-down/isometric view with simple controls, physics-based handling, and cyclocross-specific mechanics including bunny hops, barriers, dismounting, terrain variation, and handups.

**Target platforms:** Mobile (iOS/Android), PC (Windows/Mac/Linux)
**Engine:** Godot 4.x
**Art style:** Clean minimal pixel art (32x32 base tile)
**Target development time:** 12-16 weeks to playable beta

---

## Core Design Pillars

1. **Simple controls, deep skill expression** - Three inputs maximum, mastery through timing
2. **Readable chaos** - Busy races that remain visually parseable  
3. **Cyclocross authenticity** - Mechanics that capture the sport's unique character
4. **Satisfying feedback** - Every action has audio/visual/haptic response

---

## Control Scheme

### Mobile
| Input | Action |
|-------|--------|
| Tilt or touch zones | Steering |
| Hold right side | Pedal (accelerate) |
| Tap right side | Action (context-sensitive) |

### PC
| Input | Action |
|-------|--------|
| A/D or ←/→ | Steering |
| W or ↑ | Pedal |
| Space | Action |

### Action Button Context
- Approaching barrier → Bunny hop
- Near handup → Grab powerup
- Hold before barrier → Dismount
- While dismounted → Mount

---

## Game Mechanics

### 1. Movement Physics

**Base parameters (tuning required)**
```
max_speed: 400 px/s
acceleration: 800 px/s²
steering_speed: 3.5 rad/s
drag: 0.98 per frame
```

**Terrain modifiers**

| Terrain | Speed Mult | Grip | Friction |
|---------|-----------|------|----------|
| Grass | 1.0 | 0.9 | 0.85 |
| Pavement | 1.15 | 1.0 | 0.9 |
| Mud | 0.75 | 0.5 | 0.7 |
| Sand | 0.6 | 0.4 | 0.6 |
| Snow | 0.85 | 0.6 | 0.8 |
| Ice | 0.9 | 0.2 | 0.95 |

### 2. Stamina System

- **Max stamina:** 100 units
- **Drain rate:** 15/s while pedaling
- **Regen rate:** 8/s while coasting or drafting
- **Bonk state:** Below 10 stamina, max speed reduced 50%
- **Sprint boost:** Rapid tap increases speed 20% but drains 3x stamina

### 3. Barriers

Two approaches, player chooses in real-time:

**Bunny hop (risky, fast)**
- Detection zone: 60px before barrier
- Hop window: 40px to 10px before barrier
- Perfect window: 15px to 10px
- Perfect hop: Full speed maintained, small boost
- Good hop: 90% speed maintained
- Mistimed: Clip barrier, major speed loss
- Missed: Crash, 2 second recovery

**Dismount/run (safe, slow)**
- Hold action before detection zone
- Auto-dismount, run over barrier, auto-mount
- Consistent ~1.5s time cost
- No crash risk

### 4. Elevation System

**Layers**
- Layer 0: Ground level
- Layer 1: Bridge/flyover level
- Ramp triggers handle transitions

**Height**
- Continuous height value for jumps
- Gravity: 400 px/s²
- Bunny hop force: 150 px/s upward
- Visual: Sprite Y-offset = -height × 0.5

**Collision**
- Riders only collide if same layer
- Collision mask swaps on layer transition

**Draw order**
```
z_index = global_position.y + (layer × 10000) + height
```

### 5. Handups (Powerups)

Spectators along course offer items:

| Item | Effect | Duration |
|------|--------|----------|
| Beer | Speed boost +15% | 3 seconds |
| Cowbell | Invincibility to bumps | 4 seconds |
| Dollar bills | Points ×2 | 10 seconds |
| Hot dog | Stamina refill | Instant |

- Grab window: 0.5s as passing
- Must be within 20px of course edge
- Visual telegraph: Spectator arm extended

### 6. Race Structure

**Start sequence**
1. Grid placement (8-12 riders)
2. "30 seconds" callout
3. Countdown with power meter charge
4. Launch - mash pedal for hole shot

**Race flow**
- 3-5 laps depending on course length
- Position tracking with rubberband AI
- Terrain and obstacle variety per lap section

**Finish**
- Final 200m sprint zone
- Rapid pedal tap for burst
- Photo finish for close races

### 7. AI Behavior

**Path following**
- AI follows course centerline with variation
- Skill tiers: mistakes, speed, reaction time
- Rubberband: Slight speed boost when behind, penalty when far ahead

**Decision making**
- Barrier approach: Choose hop vs dismount based on skill + stamina
- Line choice: Prefer hard-packed lines in sand/mud
- Handup grab: Probabilistic based on need

---

## Technical Architecture

### Project Structure

```
cyclocross/
├── project.godot
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
│   │   ├── game_manager.gd
│   │   ├── audio_manager.gd
│   │   └── input_manager.gd
│   ├── rider/
│   │   ├── rider.gd
│   │   ├── rider.tscn
│   │   ├── rider_states.gd
│   │   └── ai_controller.gd
│   ├── course/
│   │   ├── course.gd
│   │   ├── course_segment.gd
│   │   ├── terrain_types.gd
│   │   └── obstacles/
│   │       ├── barrier.gd
│   │       ├── handup.gd
│   │       └── ramp_trigger.gd
│   ├── camera/
│   │   └── race_camera.gd
│   ├── ui/
│   │   ├── hud.gd
│   │   ├── minimap.gd
│   │   └── stamina_bar.gd
│   └── effects/
│       ├── screen_shake.gd
│       └── particles.gd
├── courses/
│   └── course_data/
└── scenes/
    ├── title.tscn
    ├── race.tscn
    └── results.tscn
```

### Scene Tree (Race)

```
Race
├── Course
│   ├── TerrainLayer0 (TileMapLayer)
│   ├── TerrainLayer1 (TileMapLayer)
│   ├── Obstacles
│   │   ├── Barriers
│   │   ├── Handups
│   │   └── RampTriggers
│   └── Decorations
├── Riders (Y-sort enabled)
│   ├── Player
│   └── AI_Riders
├── RaceCamera
└── UI (CanvasLayer)
    └── HUD
        ├── Minimap
        ├── StaminaBar
        ├── PositionDisplay
        └── LapCounter
```

### Collision Layers

| Layer | Name | Purpose |
|-------|------|---------|
| 1 | ground_riders | Riders on layer 0 |
| 2 | bridge_riders | Riders on layer 1 |
| 3 | course_bounds | Course tape/edges |
| 4 | obstacles | Barriers, trees |
| 5 | triggers | Ramps, handups, finish |

### Input Map

```
steer_left: A, Left Arrow, Joypad Axis 0-
steer_right: D, Right Arrow, Joypad Axis 0+
pedal: W, Up Arrow, Joypad Button 0
action: Space, Joypad Button 1
pause: Escape, Joypad Button 6
```

---

## Development Phases

### Phase 1: Core Loop (Weeks 1-3)

**Week 1: Movement foundation**
- [ ] Project setup with folder structure
- [ ] Rider CharacterBody2D with placeholder sprite
- [ ] Basic acceleration, steering, drag
- [ ] Single terrain type (grass)
- [ ] Placeholder pedal sound
- [ ] Test on PC

**Week 2: Terrain and feel**
- [ ] TileMap with grass, mud, sand, pavement
- [ ] Terrain detection and physics modification
- [ ] Terrain transition sounds
- [ ] Camera follow with look-ahead
- [ ] Screen shake utility
- [ ] Basic stamina bar UI

**Week 3: Barriers and skill**
- [ ] Barrier obstacle with detection zones
- [ ] Bunny hop mechanic with timing windows
- [ ] Dismount/mount state machine
- [ ] Hop success/fail feedback (sound, visual)
- [ ] Running animation state
- [ ] First playable single-screen loop

**Milestone: Playable bike with one terrain loop and barriers**

### Phase 2: Racing (Weeks 4-6)

**Week 4: Course system**
- [ ] CourseSegment resource structure
- [ ] Path2D based course definition
- [ ] Multi-screen scrolling course
- [ ] Course boundaries (tape)
- [ ] Finish line detection

**Week 5: Competition**
- [ ] AI rider with path following
- [ ] Basic rubber banding
- [ ] Rider-rider collision
- [ ] Position tracking
- [ ] Lap counting
- [ ] 3-4 AI opponents

**Week 6: Race flow**
- [ ] Start grid and countdown
- [ ] Hole shot mechanic
- [ ] Sprint finish zone
- [ ] Results screen (minimal)
- [ ] Retry/quit flow
- [ ] First external playtest

**Milestone: Complete single race against AI**

### Phase 3: Depth (Weeks 7-9)

**Week 7: Elevation**
- [ ] Height system for jumps
- [ ] Layer-based collision masking
- [ ] Ramp triggers for layer transition
- [ ] Bridge segment support
- [ ] Draw order with layers
- [ ] Minimap layer indication

**Week 8: Handups and variety**
- [ ] Handup spectators with grab zones
- [ ] Four powerup types
- [ ] Powerup effects and timers
- [ ] Snow and ice terrain
- [ ] Off-camber sections
- [ ] Weather variation (visual only initially)

**Week 9: Course content**
- [ ] Second complete course
- [ ] Course select screen
- [ ] Course data format finalized
- [ ] Third course (flyover heavy)
- [ ] Second external playtest

**Milestone: Three varied courses, full mechanic set**

### Phase 4: Polish (Weeks 10-12)

**Week 10: Feedback pass**
- [ ] Replace all placeholder sounds
- [ ] Particle effects (mud spray, dust, snow)
- [ ] Hit pause on impacts
- [ ] Squash/stretch animations
- [ ] Haptics for mobile
- [ ] Audio mix pass

**Week 11: AI and balance**
- [ ] AI skill tiers
- [ ] AI barrier decisions
- [ ] AI line choice in terrain
- [ ] Difficulty settings
- [ ] Stamina balance tuning
- [ ] Bunny hop window tuning

**Week 12: UI and flow**
- [ ] Title screen with art
- [ ] Transitions between screens
- [ ] Settings (audio, controls)
- [ ] Mobile touch controls polish
- [ ] PC/mobile build verification
- [ ] Third external playtest

**Milestone: Feature complete beta**

### Phase 5: Release Prep (Weeks 13-16)

**Week 13-14: Content**
- [ ] 5-6 total courses
- [ ] Unlockable progression
- [ ] Rider customization (colors)
- [ ] Stats tracking
- [ ] Achievements/challenges

**Week 15: Platform prep**
- [ ] Mobile performance optimization
- [ ] Touch control refinement
- [ ] App store assets
- [ ] Privacy policy, etc.

**Week 16: Launch**
- [ ] Final bug fixes
- [ ] Wider beta if needed
- [ ] Release builds
- [ ] Submit to stores

---

## Asset Requirements

### Sprites

**Rider/Bike**
- 8 rotation angles
- 3 states per angle: pedaling (2 frames), coasting, running
- ~40 frames total
- Start with 4 angles, interpolate

**Terrain tiles (32×32)**
- Grass (base + 2 variants)
- Mud (3 variants)
- Sand (2 variants)
- Snow (2 variants)
- Ice (2 variants)
- Pavement (2 variants)
- Transitions (auto-tile)

**Objects**
- Barrier (tape on stakes)
- Course tape (left/right)
- Trees (3 variants)
- Spectators (3 types)
- Handup items (4 types)
- Start/finish banner
- Bridge deck tiles
- Ramp tiles

**UI**
- Stamina bar (fill + frame)
- Position indicator
- Lap counter
- Minimap frame
- Countdown numbers
- Button prompts

### Audio

**SFX (placeholder via jsfxr, replace later)**
- Pedal tick (chain sound)
- Terrain: grass, mud, sand, snow, ice, pavement
- Bunny hop: launch, land (good), land (perfect)
- Barrier: clip, crash
- Dismount/mount footsteps
- Stamina: low warning (breathing)
- Handup: grab chime
- Position: up/down tones
- Countdown: beeps
- Finish: crowd cheer

**Music**
- Title theme
- Race music (loopable, builds tension)
- Results sting (win/lose variants)

---

## Playtesting Checkpoints

### Playtest 1 (Week 3)
**Focus:** Does the bike feel good?
- Solo play, just movement
- Barrier timing readable?
- Terrain differences noticeable?

### Playtest 2 (Week 6)
**Focus:** Is racing fun?
- 3-5 external testers
- Full race loop
- AI competitive?
- Controls intuitive?

### Playtest 3 (Week 9)
**Focus:** Depth and variety
- 5-10 testers
- Multiple courses
- Handups useful?
- Elevation readable?

### Playtest 4 (Week 12)
**Focus:** Polish and feel
- 10-15 testers
- All feedback systems in
- Mobile testing begins
- Session length and retention

### Beta (Week 15+)
**Focus:** Balance and bugs
- 50+ testers
- Analytics enabled
- Difficulty curve
- Edge cases

---

## Key Metrics to Track

**Gameplay**
- Bunny hop success rate (perfect/good/fail/crash)
- Dismount vs hop ratio
- Average stamina at finish
- Crashes per race
- Handup grab rate

**Engagement**
- Races per session
- Session length
- Retry rate after loss
- Course completion rate
- Quit points (when/where)

**Balance**
- Win rate per difficulty
- Position distribution
- Speed by terrain type
- Powerup usage rates

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Mobile performance | Test weekly on low-end device |
| Touch controls feel bad | Prototype touch early (week 2) |
| AI too hard/easy | Implement difficulty slider early |
| Bunny hop timing frustrating | Track success rate, adjust window |
| Scope creep | Defer features past week 12 |
| Art bottleneck | Commit to placeholder-friendly style |

---

## Tools

**Development**
- Godot 4.x
- Git + GitHub/GitLab
- VS Code with Godot extension

**Art**
- Aseprite (sprites)
- Tiled (level design, optional)

**Audio**
- jsfxr (placeholder SFX)
- Audacity (editing)
- Freesound.org (samples)

**Testing**
- OBS (screen recording)
- Google Forms (feedback)
- GameAnalytics (metrics, optional)

---

## Next Actions

1. Create Godot 4.x project with folder structure
2. Build Rider scene with CharacterBody2D
3. Implement basic movement (30 lines)
4. Add placeholder pedal sound
5. Play for 30 minutes, tune numbers
6. Add single terrain tile and test surface
7. Build first barrier with hop detection

Start simple. Get the bike feeling right before anything else. Everything builds on that foundation.
