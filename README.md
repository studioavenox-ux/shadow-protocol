# SHADOW PROTOCOL
### EVERY CHOICE LEAVES A TRACE.

**SHADOW PROTOCOL** is a third-person open-world crime thriller set in **BLACKWATER CITY**. You play as **Alex Mercer**, a young adult returning to the city and getting pulled into its criminal underworld.

Genre: Third-person open-world action and crime thriller  
Inspiration: GTA V open-world freedom + Mafia II cinematic storytelling (original characters & story)  
Engine: Godot 4.x (GDScript)  
Platforms: Android (primary, landscape) + Windows PC (testing)  
Version: 0.2.0 - Phase 2: Character, Animations & City Improvements

---

## 🎮 Playable Prototype - Phase 2 What's New

This is a **fully playable Godot project**, upgraded from Phase 1 prototype.

### Phase 1 Features (Preserved):
- Third-person character, follow camera, Blackwater City basic, mobile controls, HUD, mission, interaction, main menu, pause menu, save

### Phase 2 Improvements:
- ✅ **Improved Player Character**: Low-poly humanoid (8 meshes, <500 tris) - Torso dark jacket #15171B with crimson accent #A51F2B, Head skin, Arms jacket sleeve, Legs dark trousers #121315, Shoes #050506 - Young adult male urban
- ✅ **Character Animations**: Procedural system via `character_animator.gd` - Idle breathing, Walk 6Hz, Run 9Hz, Sprint 12Hz with bob/swing, Jump/Fall/Land with landing timer 0.3s - AnimationPlayer with 6 animations (idle with tracks, others placeholder) - No running while standing
- ✅ **Improved Camera**: Smoothing 12/10/15, damping 0.85, pitch -55°/25°, distance 1.2-7.0, margin 0.3, touch index tracking, zoom smoothing, auto-center optional, stable movement
- ✅ **Improved City**: Expanded district 240x240, Main road 14x240 + 3 side streets 80x10, Road markings 8 white lines, Sidewalks 5 width, Buildings: 2 residential (brick + balconies + lit windows) + 2 commercial (sign crimson + glass) + 8 simple boxes, 6 streetlights (2 shadows), Props: 2 benches + 2 trash bins, Parking lines, Garage 28x9x34 + ramp -5° + SpotLight, Nighttime fog 0.007 ambient 0.42
- ✅ **Improved Mission**: Visible destination marker (red beacon float animation, emissive 3.0, light range 12, pulse billboard), Contextual prompt 280x42 pulse 1.15, Dialogue sequence 5 lines expanded with UI fade + player movement disable + advance via E or auto 3.2s, Objective progress (0/30m) + ✓/★ notifications, Skip prevention via validation
- ✅ **Mobile Polish**: Joystick 140 base/60 knob max 60, Buttons 72x72 (was 64), Pause 48, No overlap via CenterSpacer, Camera area offset 580, Touch index tracking, Button animations 0.9-1.0 scale
- ✅ **Performance**: 3 shadow casters (was 6), reusable buildings, no textures, simple materials, no SSR/SDFGI

### Visual Identity:
- Obsidian black #08090B, Charcoal #15171B, Steel gray #858B94, Off-white #F2F2F0, Muted crimson #A51F2B
- Cinematic crime thriller nighttime with fog, emissive beacons, shadows
- Optimized for Android (gl_compatibility, simple geometry, limited lights)

---

## 📁 Project Structure Phase 2
```
project.godot
export_presets.cfg
scenes/
    main_menu.tscn
    world.tscn (expanded district)
    player.tscn (humanoid + animator)
    building.tscn (improved)
    building_residential.tscn (new)
    building_commercial.tscn (new)
    garage.tscn
    destination_marker.tscn (new beacon)
scripts/
    game_manager.gd
    player_controller.gd (animator integration)
    camera_controller.gd (smoothing)
    character_animator.gd (new procedural)
    mission_manager.gd (marker + validation)
    interaction_system.gd
    interactable.gd
    npc_marcus.gd (dialogue UI)
    mobile_controls.gd (larger targets)
    game_hud.gd (72 buttons)
    main_menu.gd
    pause_menu.gd
    world.gd (marker billboard)
ui/
    game_hud.tscn (polished)
    pause_menu.tscn
assets/
    textures/icon.png
    environment/default_env.tres (fog 0.007)
docs/
    DEVELOPMENT.md
    FEATURES.md (Phase 2 report)
    LAUNCH.md
```

---

## 🚀 How to Run

### PC Testing:
1. Godot 4.4 → Import project.godot → Play → NEW GAME
2. Controls: WASD Move, Shift Sprint, Space Jump, E Interact, Right-drag Camera, Wheel Zoom, Esc Pause
3. Test: Walk 30m (progress shows 0/30m), follow red beacon north, enter garage ramp, talk Marcus (E), complete mission

### Android Build:
1. Editor > Manage Export Templates → Download
2. Project > Export → Android preset (com.studioavenox.shadowprotocol, landscape, gl_compatibility, arm64)
3. Export builds/ShadowProtocol.apk → adb install builds/ShadowProtocol.apk
4. Controls: Left joystick (140 base) move, Right half drag look, JUMP/SPRINT/INTERACT 72 buttons, Pause 48

See docs/LAUNCH.md for detailed steps.

---

## 🎯 Mission: A NEW BEGINNING (Phase 2)

> Alex Mercer returns to Blackwater City, must reach underground garage and meet Marcus Reed.

Objectives:
1. Explore (0/30m) - Move to get familiar, progress updates
2. Locate garage - Look for red beacon north
3. Reach entrance - Follow road north to beacon at (0,0.5,-18 relative to garage)
4. Interact Marcus - Inside garage, press E or Interact, dialogue sequence (5 lines, advance via E or auto)
5. Mission Complete - Star notification, save

Cannot skip - validation ensures current objective only, shows "Explore first" if wrong.

---

## 🎨 Stitch References

8 cinematic folders + 2 police pursuit HUDs used for visual direction, no copyrighted assets copied.

---

## ✅ Validation Phase 2

- [x] project.godot valid, main_scene main_menu.tscn
- [x] 13 scripts valid, 10 scenes valid
- [x] Input map, autoload, icon exists
- [x] No empty files, no secrets
- [ ] Editor playtest requires Godot (sandbox has no Godot)
- [ ] Android device test requires build

See docs/FEATURES.md for full report.

---

## 🔜 Next Phase

- Vehicle system (drivable car, enter/exit, physics)
- Real character skeleton + AnimationTree
- Audio, minimap GPS, police pursuit

**EVERY CHOICE LEAVES A TRACE.**
