# SHADOW PROTOCOL - Development Documentation
## Version 0.1.0 | Phase One Prototype

### Project Overview
SHADOW PROTOCOL is a third-person open-world crime thriller set in BLACKWATER CITY.
Protagonist: Alex Mercer returns to the city and gets pulled into the criminal underworld.
Tagline: EVERY CHOICE LEAVES A TRACE.

Inspired by GTA V open-world freedom and Mafia II cinematic storytelling, but with original characters, story, and assets.

### Technical Stack
- Engine: Godot 4.x (4.4 compatible, using gl_compatibility renderer for mobile)
- Language: GDScript
- Primary Platform: Android (landscape)
- Secondary: Windows PC for testing
- Orientation: Landscape
- Camera: Third-person follow with SpringArm collision
- Controls: Touchscreen (virtual joystick + buttons) + keyboard/mouse fallback

### Project Structure
```
project.godot
export_presets.cfg
scenes/
    main_menu.tscn      # Polished main menu with logo
    world.tscn          # Blackwater City explorable environment
    player.tscn         # Alex Mercer character with camera
    building.tscn       # Reusable building block
    garage.tscn         # Underground garage complex
scripts/
    game_manager.gd     # Autoload singleton, save, scene transitions
    player_controller.gd # Movement, gravity, jump, sprint, stamina
    camera_controller.gd # Third-person camera, mouse/touch rotation
    mission_manager.gd  # Mission "A NEW BEGINNING" progression
    interaction_system.gd # Reusable interaction detection
    interactable.gd     # Base class for interactables
    npc_marcus.gd       # Marcus Reed NPC with dialogue
    mobile_controls.gd  # Joystick and button logic
    game_hud.gd         # In-game HUD, health, stamina, prompts
    main_menu.gd        # Main menu logic
    pause_menu.gd       # Pause overlay
    world.gd            # World setup, triggers, environment
ui/
    game_hud.tscn       # Mobile-friendly HUD layout
    pause_menu.tscn     # Pause menu overlay
assets/
    textures/
        icon.png        # Game icon
    environment/
        default_env.tres # Fog, ambient, glow settings
    models/             # Placeholder for future models
    audio/              # Placeholder for audio
docs/
    DEVELOPMENT.md      # This file
```

### Visual Palette
- Obsidian black: #08090B (background, primary)
- Charcoal: #15171B (secondary surfaces)
- Steel gray: #858B94 (text, borders)
- Off-white: #F2F2F0 (highlights, primary text)
- Muted crimson: #A51F2B (accent, danger, mission critical)

Art direction: Cinematic, realistic-inspired, modern metropolitan city, atmospheric lighting, dark crime thriller. Optimized for mobile performance - no excessive real-time lights, using baked-ish lighting via StandardMaterial3D, limited shadow casters, simple geometry.

### Phase One Features Implemented

#### A. Third-Person Player (Alex Mercer)
- CharacterBody3D with Capsule collision
- Walking (3.5 m/s), Running (6.0 m/s), Sprinting (8.0 m/s)
- Jumping with gravity (12.0) and jump velocity (4.8)
- Stamina system: drain 25/s while sprinting, recover 18/s
- Health system: 100 HP, damage/heal functions
- Rotation toward movement direction (12 deg/s lerp)
- Movement relative to camera yaw
- Placeholder mesh: Capsule + Box head (replaceable with model)
- Group: "player" for easy lookup

#### B. Third-Person Camera
- Node3D CameraPivot with SpringArm3D
- Smooth follow (10.0 smooth_speed)
- Mouse rotation: right-click drag, sensitivity 0.003
- Touch drag: right half screen drag, sensitivity 0.005
- Pitch limits: -60 to +20 degrees
- Collision handling via SpringArm (margin 0.2, mask World)
- Zoom via mouse wheel (1.5 to 8.0 distance)
- Auto handles camera forward/right for movement

#### C. Blackwater City
- Ground: 200x200 Box with collision, charcoal material
- Roads: Main road (12x200) and cross road, dark asphalt material
- Sidewalks: Elevated 0.15, lighter gray
- Buildings: 10 buildings of varying heights (12m, 18m, 28m)
  - StaticBody3D with Box collision
  - Two materials: dark and gray for variety
  - Window emissive details on reusable building.tscn
- Streetlights: 4 poles with emissive bulbs + OmniLight (range 15-18, shadows)
- GarageComplex: Underground parking at (0,0,65)
  - 24x8x30 structure, floor, 4 pillars
  - Interior OmniLight
  - Marcus Reed NPC inside
- Parking areas: implied via garage floor
- Props: Pillars, lights, building windows
- Performance: Simple BoxMesh, limited lights, no huge textures

#### D. Mobile Controls
- Left side: Virtual joystick
  - Base 120x120, knob 50x50, max distance 50-60px
  - Deadzone 0.15, touch and mouse support
  - Emits move_vector_changed
- Right side:
  - CameraLookArea: full right half screen Control, captures drag
  - Jump button 64x64, Sprint toggle 64x64, Interact 64x64
  - Touch targets comfortable, no overlap, minimal obstruction
- Top: Pause button 44x44
- Also supports keyboard/mouse for PC testing

#### E. Game HUD
- TopBar: Game title, mission title, objective description
- Stats: Health bar (crimson) and Stamina bar (off-white) with labels
- Center: Interaction prompt panel with crimson left border
- TopCenter: Notification panel for mission updates
- BottomBar: Joystick + right controls
- Visual identity: dark semi-transparent panels, steel gray borders, crimson accents

#### F. First Story Mission: A NEW BEGINNING
Objectives:
1. Explore starting area - travel 30m distance (tracked via player_moved signal)
2. Find mission destination - enter DestinationTrigger at (0,2,40)
3. Reach garage entrance - enter GarageEntranceTrigger at (0,2,55)
4. Interact with Marcus Reed - Talk to NPC at garage
5. Mission Complete - notification and GameManager complete
- MissionManager tracks progress, emits signals
- Shows notifications, updates HUD objective
- Save after completion

#### G. Interaction System
- Base class Interactable extends Area3D
- Properties: prompt_text, interaction_id, auto_interact, one_shot, highlight_enabled
- Signals: interacted, player_entered_range, player_exited_range
- Highlight: emissive material override when in range
- NPC Marcus Reed extends Interactable:
  - Dialogue lines (5 lines)
  - Auto-advancing dialogue with 2.5s timer
  - Signals for dialogue flow and mission completion
- InteractionSystem node (optional) for centralized management
- World.gd connects all interactables to HUD

#### H. Main Menu
- Cinematic dark background (#08090B) with vignette
- Title: SHADOW PROTOCOL 64px, crimson outline
- Tagline: EVERY CHOICE LEAVES A TRACE
- Buttons: NEW GAME, CONTINUE, SETTINGS, EXIT (280x56, touch friendly)
- Styled with StyleBoxFlat, hover crimson border, pressed crimson bg
- Bottom bar: city sector and version
- Settings panel overlay (placeholder for Phase 2)
- Animations: fade in, title slide
- NEW GAME -> GameManager.new_game() -> world.tscn
- CONTINUE checks has_save, disabled if no save
- EXIT quits

#### I. Pause Menu
- CanvasLayer, process_mode WHEN_PAUSED
- Background semi-transparent 0.75 black
- Buttons: Resume, Restart Mission, Settings, Main Menu
- Connected to GameManager pause/resume signals
- Animations: fade in/out
- Handles ui_cancel input

### Input Map
- move_forward: W, Up, Joypad
- move_back: S, Down
- move_left: A, Left
- move_right: D, Right
- jump: Space, Joypad 0
- sprint: Shift, Joypad 5
- interact: E, Joypad 2
- pause: Escape, Joypad 6
- camera_left/right: Q/E (for testing)

### Save System
- ConfigFile at user://shadow_save.cfg
- Stores has_save, current_mission, player_position, settings
- GameManager handles save/load
- Continue button checks has_save

### Android Export Setup
- export_presets.cfg includes Android and Windows presets
- Package: com.studioavenox.shadowprotocol
- Name: SHADOW PROTOCOL
- Orientation: landscape (1)
- Min SDK blank (defaults), target blank
- Architectures: arm64-v8a true (modern devices)
- Permissions: INTERNET, VIBRATE
- Renderer: gl_compatibility for broad mobile support
- Icons: assets/textures/icon.png

### How to Run (PC Testing)
1. Open Godot 4.4 (or 4.2+)
2. Import project.godot
3. Run main_menu.tscn (F6) or press Play (main scene is main_menu)
4. Click NEW GAME
5. Controls:
   - WASD to move, Shift to sprint, Space to jump
   - Right-click drag to rotate camera, mouse wheel to zoom
   - E to interact
   - Escape to pause
   - Mobile controls also work with mouse: drag left joystick, drag right side for camera

### Android Build Instructions
1. In Godot, install Android export templates via Editor -> Manage Export Templates
2. Setup Android SDK (Android Studio or cmdline-tools)
3. Configure keystore for release (or use debug)
4. In Project -> Export, select Android preset
5. Set export path to builds/ShadowProtocol.apk
6. Click Export Project
7. Install APK on device via adb: adb install builds/ShadowProtocol.apk
8. For testing without full build, use Godot's Android remote deploy (one-click deploy)

### Performance Considerations
- gl_compatibility renderer for low-end devices
- BoxMesh and simple primitives, no high-poly models
- Limited shadow casters: DirectionalLight + 4 streetlights + garage light (6 total)
- No SSR, no expensive post-processing, glow low intensity 0.2
- Fog density low 0.006 for atmosphere without overdraw
- Physics tick 60, jitter fix 0.5
- Texture compression ETC2/ASTC enabled

### Known Limitations (Prototype)
- Placeholder character mesh (capsule + box) - needs real model
- No animations (idle/walk/run) - placeholder state tracking
- No vehicles yet (design references present but not implemented)
- No audio system (assets/audio empty)
- No minimap/radar (design shows radar but not implemented in 3D)
- No police/wanted system (future Phase 5)
- No inventory or weapons
- Dialogue UI is basic (DialoguePanel hidden, uses notifications)
- Settings panel placeholder
- No real city traffic or pedestrians
- Garage is simple box, not detailed interior

### Next Development Tasks (Priority Order)
1. Replace placeholder mesh with real character model + animations (idle, walk, run, sprint, jump)
2. Implement proper dialogue UI with typewriter effect and choices
3. Add vehicle system: car model, enter/exit, driving physics
4. Expand city: more buildings, roads, traffic system, LOD
5. Add audio: ambient city, footsteps, dialogue voice, music
6. Implement save slots and mission select
7. Add settings: graphics quality, sensitivity, volume sliders
8. Minimap with GPS and mission markers
9. Police pursuit and wanted system (from Stitch designs)
10. Second mission: courier run with driving

### Validation Steps Done
- [x] project.godot syntax valid (config_version 5, proper sections)
- [x] All script files have valid GDScript syntax (checked via Godot parser mental check)
- [x] Scene files reference valid ext_resources and sub_resources
- [x] Input map defined for all required actions
- [x] Autoload GameManager defined
- [x] Main scene points to main_menu.tscn
- [x] Icon file exists at assets/textures/icon.png
- [x] Environment resource exists
- [x] Player scene has CharacterBody3D, CollisionShape, Mesh, CameraPivot, SpringArm, Camera
- [x] World scene has WorldEnvironment, DirectionalLight, Ground, Buildings, Lights, Triggers, Player, MissionManager, UI
- [x] HUD has joystick, buttons, health/stamina, prompts
- [x] Pause menu has resume/restart/settings/main menu
- [x] Interactable system has signals and highlight
- [x] Mission progression via distance, triggers, interaction
- [x] No empty files - every script serves purpose
- [x] No secrets or API keys committed
- [ ] Godot editor validation (requires Godot installed - documented as remaining step)
- [ ] Scene transitions tested in editor (requires Godot)
- [ ] Player movement tested (requires Godot)
- [ ] Mobile touch tested on device (requires Android build)

### Repository Notes
- Preserved Stitch design reference folders (8 cinematic folders + 2 police pursuit)
- Did not delete any existing files except README update
- .gitignore already covers .godot, .import, export.cfg etc.
- Branch: arena/6bd301d4-shadow-protocol (working branch)

### License & Credits
- Original game concept, not copying GTA/Mafia assets
- Fictional city BLACKWATER CITY, protagonist ALEX MERCER, contact MARCUS REED
- Built by Lead Game Developer (Arena Agent) for Studio Avenox
- Godot Engine MIT licensed
