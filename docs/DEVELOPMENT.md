# SHADOW PROTOCOL - Development Documentation
## Version 0.2.0 | Phase 2 - Character, Animations & City Improvements

### Project Overview
SHADOW PROTOCOL is a third-person open-world crime thriller set in BLACKWATER CITY.
Protagonist: Alex Mercer (young adult male, dark jacket, dark trousers, dark shoes) returns to the city and gets pulled into criminal underworld.
Tagline: EVERY CHOICE LEAVES A TRACE.

Inspired by GTA V open-world freedom and Mafia II cinematic storytelling, original characters/story/assets.

### Technical Stack Phase 2
- Engine: Godot 4.x (4.4 compatible, gl_compatibility renderer for mobile)
- Language: GDScript
- Primary Platform: Android landscape
- Secondary: Windows PC testing
- Camera: Third-person follow with SpringArm collision, improved smoothing
- Controls: Touchscreen (140 base joystick + 72 buttons) + keyboard/mouse
- Character: Low-poly humanoid procedural (8 meshes, <500 tris) + procedural animator + AnimationPlayer placeholder

### Project Structure Phase 2
```
project.godot
export_presets.cfg
scenes/
    main_menu.tscn
    world.tscn (Phase 2 expanded district)
    player.tscn (Phase 2 humanoid + animator)
    building.tscn (improved)
    building_residential.tscn (new - brick + balconies)
    building_commercial.tscn (new - commercial + sign)
    garage.tscn
    destination_marker.tscn (new - red beacon)
scripts/
    game_manager.gd
    player_controller.gd (Phase 2 - animator integration, landing)
    camera_controller.gd (Phase 2 - smoothing, damping, pitch -55/25)
    character_animator.gd (new - procedural anim system)
    mission_manager.gd (Phase 2 - marker, skip prevention, progress)
    interaction_system.gd
    interactable.gd
    npc_marcus.gd (Phase 2 - dialogue UI, movement disable)
    mobile_controls.gd (Phase 2 - larger targets)
    game_hud.gd (Phase 2 - 72 buttons, joystick 140/60, animations)
    main_menu.gd
    pause_menu.gd
    world.gd (Phase 2 - marker billboard, welcome sequence)
ui/
    game_hud.tscn (Phase 2 polished)
    pause_menu.tscn
assets/
    textures/icon.png, icon_512.png
    environment/default_env.tres (Phase 2 - ambient 0.42, fog 0.007)
    models/README.md
    audio/README.md
docs/
    DEVELOPMENT.md (this)
    FEATURES.md (completion report)
    LAUNCH.md (run instructions)
```

### Visual Palette (Unchanged)
- Obsidian black: #08090B
- Charcoal: #15171B
- Steel gray: #858B94
- Off-white: #F2F2F0
- Muted crimson: #A51F2B

Art direction: Cinematic realistic-inspired, modern metropolitan, atmospheric nighttime, dark crime thriller. Optimized for mobile.

### Phase 2 Improvements Detailed

#### Player Character - Alex Mercer
- Old: Capsule + Box head
- New: CharacterRoot with Torso (0.55x0.75x0.32) jacket #15171B, Collar, Crimson accent, Head 0.32x0.38x0.34 skin #826E58, Left/Right Arms Capsule 0.08x0.55 jacket sleeve, Left/Right Legs Capsule 0.11x0.75 trousers #121315, Shoes Box 0.18x0.12x0.32 #050506
- Lightweight <500 tris, 8 meshes, no skeleton, procedural
- Compatible with player_controller via CharacterRoot rotation
- Collision preserved Capsule 0.35x1.4

#### Character Animations
- character_animator.gd: Procedural system, update_animation(delta, state, speed, grounded, v_vel)
  - Idle: breathing sin 1.2Hz 0.02, sway 0.7Hz 0.02, head nod
  - Walk: freq 6Hz amp 0.05, leg swing sin 0.6, arm swing 0.8, torso yaw 0.15, bob
  - Run: 9Hz 0.08, Sprint: 12Hz 0.12
  - Jump: legs -0.8, arms -1.2, torso -0.2, root 0.1
  - Fall: legs 0.3, arms 0.5, torso 0.1
  - Land: crouch sin PI 0.15, root -crouch
- AnimationPlayer: 6 animations (idle with actual tracks for torso pos and head rot, others placeholder 0.35-0.6s loop), library, autoplay idle, blend 0.2
- State machine in player_controller: idle, walking, running, sprinting, jumping, falling, landing with landing timer 0.3s, emits animation_state_changed
- No running while standing - validated via is_moving check

#### Third-Person Camera
- Old: smooth 10, min/max -60/20, distance 4.5
- New: smooth 12, rotation_smooth 10, follow_smooth 15, damping 0.85, pitch -55/25, distance 1.2-7.0, margin 0.3, collision_mask 1
- Mouse: right-drag, sens 0.003 * setting, capture mode
- Touch: right half x>45%, index tracking, sens 0.005*2.2, add_camera_rotation() with 1.8 scale
- Smoothing: lerp_angle for yaw, clamp pitch rad, lerp spring length
- Stable: Basis.from_euler only yaw for movement, no abrupt snapping
- Features: zoom -0.4/+0.4, auto-center optional, is_colliding(), get_camera_basis()

#### Blackwater City - Polished Compact District
- Ground: 240x240 (was 200)
- Roads: Main 14x240, 3 side streets 80x10 at z=-35,5,35, asphalt #111113
- Road markings: 8 white lines 0.25x0.02x3 at z=-20,-14,-8,8,14,20,40,50, white #858582
- Sidewalks: 5 width 0.35 height both sides concrete #19191A
- Buildings: 12 buildings - 2 residential instance (10x14x10 brick #181615 + balconies + lit windows emission 0.25), 2 commercial instance (14x20x12 #121315 metallic 0.3 + awning + sign crimson emission 0.6 + glass 2.5x2.0 transparency 0.85), plus 4 simple boxes tall/mid/small with dark/gray materials, 2 north back row
- Streetlights: 6 (was 4) at x=±9.5 z=-50,-20,15, poles 6m, emissive bulbs, Omni 1.2-1.4 energy range 16-20, only 2 with shadows for performance
- Props: 2 benches 2.0x0.5x0.6 wood #201816 at (-11,0.25,-10) and (11,0.25,10), 2 trash bins cylinder 0.35x0.9 dark #151516
- Parking: Garage floor 26x32, 4 parking lines 2.5x0.02x0.15 white
- Garage: 28x9x34 (was 24x8x30), floor, ramp 8x0.5x16 at -22 with -5° incline, GarageLight Omni 1.0 range 28 no shadow, Entrance SpotLight 1.5 energy 20 range 35° shadow
- Destination marker: Beacon pole 0.1x8 semi-transparent, top sphere 0.4 crimson emission 3.0, ring 1.2 emission 1.5, Omni 2.0 range 12, float anim 2s bob 4-4.5m ring rotate 360°, billboard pulse
- Collisions: All buildings StaticBody layer 1, ground, roads, sidewalks, props, ramp
- Atmosphere: WorldEnvironment fog 0.007 (was 0.006), ambient 0.42 (was 0.35), glow 0.22/0.85, tonemap 1.05, directional -50/35° energy 0.85 shadow blur 1.2 bias 0.04
- Optimized: Reusable scenes, BoxMesh, 3 shadow casters, no SSR/SDFGI/SSIL, simple materials

#### Garage Mission - A NEW BEGINNING
- Objectives same 5 but improved: explore shows (0/30m) progress, find garage with beacon hint, reach entrance, interact with Marcus, complete
- Destination marker: Visible only objectives 1-3 via marker_visible flag, hidden after, faces player with pulse
- Interaction prompt: 280x42 (was 240x36), font 13, crimson border 3, pulse 1.15
- Dialogue: 5 lines expanded, DialogueUI CanvasLayer with SpeakerLabel and DialogueLabel, fade in/out 0.25/0.3, player movement disabled during, advance via E or auto 3.2s, signals
- Objective updates: Notifications with ✓ and ★, 2.8-4.5s, flash animation, progress text
- Validation: Cannot skip - complete_objective checks current_objective, triggers check current, show "Explore first" if wrong, can_interact_with_marcus()
- Mission-complete: Star notification, save via GameManager

#### Mobile Gameplay Polish
- Joystick: 140 base (was 120) 60 knob (was 50), max dist 60 (was 50), deadzone 0.15, active flag, touch index, allows drag outside, center calculation via global_rect
- Camera-look: Offset 580 (was 640), index tracking, last pos, delta, mouse fallback 0.6
- Jump: 72x72 (was 64) 13 font, animation 0.9-1.0 scale 0.08/0.12, Input action press
- Sprint: 72 toggle 11 font, modulate green when sprinting
- Interact: 72 22 font disabled 0.5 alpha pulse 1.15
- Pause: 48 (was 44) 14 radius
- No overlap: BottomBar HBox CenterSpacer, joystick left 160 container, right controls right, camera area full right but buttons higher
- Landscape: handheld orientation 1, TopBar 84, BottomBar -180
- Keyboard/mouse preserved

#### Performance
- Simple collision: Box, Capsule, Cylinder
- Reusable: 3 building types instanced
- Textures: No textures, only materials, icon 128/512
- Lights: 8 total, 3 shadows (directional + 2 street + spot = 4? Actually 1 directional + 2 street + 1 spot = 4 shadows, but we set 2 street no shadow, so 1 directional + 1 spot + 2 street with shadow? We have 6 street: 2 with shadow true, 4 false, plus garage no shadow, spot true = 3 shadows)
- Materials: StandardMaterial3D only
- Shadows: Directional blur 1.2 bias 0.04 split 0.1/0.2/0.5, conservative
- No expensive: SSR false, SDFGI false, SSIL false, glow 0.22, fog 0.007
- No FPS claimed

### Input Map (Unchanged)
- move_forward W/Up, move_back S/Down, move_left A/Left, move_right D/Right, jump Space/Joy0, sprint Shift/Joy5, interact E/Joy2, pause Esc/Joy6, camera_left Q, camera_right E

### Save System (Unchanged)
- ConfigFile user://shadow_save.cfg, has_save, mission, pos, settings

### Android Export (Unchanged)
- Package com.studioavenox.shadowprotocol, landscape, gl_compatibility, arm64, INTERNET VIBRATE

### How to Run Phase 2
Same as Phase 1 but with improved character and city - see LAUNCH.md
- PC: Godot 4.4 Import project.godot Play NEW GAME WASD Shift Space E Right-drag Wheel Esc
- Android: Export Android builds/ShadowProtocol.apk adb install
- Test: Walk 30m (progress), follow red beacon north, ramp, talk Marcus (E)

### Validation Phase 2
- [x] project.godot valid
- [x] 13 scripts OK
- [x] 10 scenes valid ext_resources
- [x] Input map, autoload
- [x] Icon exists
- [x] No empty files
- [ ] Godot editor playtest requires Godot - not in sandbox
- [ ] Android device test requires build

### Known Issues Phase 2
- Low-poly procedural not skeletal, placeholder documented
- Procedural anim not motion-captured, functional but not realistic
- No audio, no particles, marker visible through buildings, dialogue UI basic, no LOD, no haptic

### Next Tasks
1. Vehicle system (car model, physics, enter/exit, driving camera)
2. Real character model skeleton + AnimationTree
3. Audio, minimap GPS, police pursuit from Stitch designs
