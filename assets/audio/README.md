# Shadow Protocol - Audio Assets - Phase 4

All audio assets are **optional**. The game systems are designed to work without them, logging a message if not found.

## Optional Asset Paths

Place audio files at these paths to enable immersion. No code references missing files hard.

### Vehicle Audio
- `res://assets/audio/engine_loop.ogg` - Engine loop, pitch scaled by RPM (800-6500). Format: OGG Vorbis, loopable, ~2-3 sec seamless loop. Bus: SFX.
- `res://assets/audio/engine_start.ogg` - Engine start one-shot.
- `res://assets/audio/tire_squeal.ogg` - Tire squeal during hard turns, handbrake, lateral slip. Triggered when steering >0.4 rad and speed >8 m/s.
- `res://assets/audio/brake.ogg` - Brake squeal.

### Ambience
- `res://assets/audio/city_ambience.ogg` - City nighttime ambience, subtle wind, distant traffic, loopable. Volume -18dB, Bus: Ambience/Master.
- `res://assets/audio/wind.ogg` - Wind loop for driving.

### Footsteps
- `res://assets/audio/footstep_walk.ogg` - Walk footstep, interval 0.5s, pitch randomized 0.9-1.1.
- `res://assets/audio/footstep_run.ogg` - Run footstep, interval 0.32s, faster pitch.
- Both triggered via AudioManager.set_walking(walking, running, position)

### Interaction
- `res://assets/audio/interaction_click.ogg` - Interaction feedback (E key / mobile button), UI bus, -4dB.
- `res://assets/audio/door_open.ogg` - Door open.
- `res://assets/audio/door_close.ogg` - Door close.

### Mission
- `res://assets/audio/mission_complete.ogg` - Mission objective complete, SFX bus -2dB.
- `res://assets/audio/objective_update.ogg` - Objective update notification.

### Police
- `res://assets/audio/police_siren.ogg` - Police siren loop, 3D positioned, max distance 80m.
- `res://assets/audio/wanted_alert.ogg` - Wanted level increase alert.
- `res://assets/audio/police_radio.ogg` - Police radio chatter.

## Implementation Notes

- **No missing file refs**: All loads check ResourceLoader.exists() before load().
- **AudioManager** (scripts/audio_manager.gd) preloads optional assets, caches them, provides play methods with fallbacks.
- **VehicleController** creates AudioStreamPlayer3D for engine/tire, checks existence before assigning stream.
- **Bus layout**: Master, SFX, Music, Ambience - falls back to Master if bus missing.
- **Android optimized**: OGG Vorbis preferred, max 3 simultaneous 3D voices, distance culling, low-pass not used.

## How to Add

1. Import OGG file into Godot (ensure Loop enabled for loops).
2. Place at exact path listed above.
3. AudioManager auto-detects on _ready() and starts ambience if found.
4. No code change needed.

## Phase 4 Audio Features Implemented (even without assets)

- Engine pitch based on RPM (0.7 + rpm/6500*1.3)
- Tire squeal logic: lateral speed >3m/s or steering >0.4 rad + speed >8 m/s or handbrake + speed >5 m/s
- City ambience system ready
- Footstep system with walk/run intervals
- Interaction feedback hook
- Mission completion audio hook
- Police siren 3D positioning ready

## Streetlight Variation & Fog (Visual Immersion)

See `scripts/environment_manager.gd` - handles:
- Streetlight flicker variation
- Night fog density subtle
- Time-of-day nighttime ambience
- Optimized for Android: no realtime shadows from streetlights, baked lightmaps, fog with low steps.

## Performance

- All audio players created once, reused.
- 3D players max_distance 30-40m for culling.
- No audio processing in _physics_process heavy loops.
- OGG streaming disabled for short SFX, enabled for ambience loops.
