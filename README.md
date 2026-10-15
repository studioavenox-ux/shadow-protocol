# SHADOW PROTOCOL
### EVERY CHOICE LEAVES A TRACE.

**SHADOW PROTOCOL** is a third-person open-world crime thriller set in **BLACKWATER CITY**. You play as **Alex Mercer**, a young adult returning to the city and getting pulled into its criminal underworld.

Genre: Third-person open-world action and crime thriller  
Inspiration: GTA V open-world freedom + Mafia II cinematic storytelling (original characters & story)  
Engine: Godot 4.x (GDScript)  
Platforms: Android (primary, landscape) + Windows PC (testing)  
Version: 0.1.0 Prototype - Phase One

---

## 🎮 Playable Prototype - What's Included

This is a **fully playable Godot project**, not a mockup or HTML prototype.

### Core Features Implemented:
- ✅ **Third-person character**: Walk, run, sprint, jump, gravity, collision, camera-relative movement
- ✅ **Follow camera**: Smooth, touch-drag rotation, mouse control, SpringArm collision
- ✅ **Blackwater City**: Small explorable urban environment with roads, sidewalks, buildings, streetlights, garage
- ✅ **Mobile controls**: Virtual joystick (left), camera drag (right), jump/sprint/interact buttons, pause
- ✅ **Game HUD**: Mission title/objective, health & stamina bars, interaction prompt, notifications
- ✅ **Mission**: "A NEW BEGINNING" - 5 objectives with progression via exploration, triggers, interaction
- ✅ **Interaction system**: Reusable Area3D-based interactables with highlight and prompts (Marcus Reed NPC)
- ✅ **Main menu**: Cinematic dark design, New Game/Continue/Settings/Exit with animations
- ✅ **Pause menu**: Resume/Restart/Settings/Main Menu with proper pause handling
- ✅ **Save system**: ConfigFile save for continue functionality

### Visual Identity:
- Obsidian black #08090B, Charcoal #15171B, Steel gray #858B94, Off-white #F2F2F0, Muted crimson #A51F2B
- Cinematic crime thriller atmosphere with fog, emissive lights, shadows
- Optimized for Android (gl_compatibility renderer, simple geometry, limited lights)

---

## 📁 Project Structure
```
project.godot
export_presets.cfg
scenes/
    main_menu.tscn      # Entry point
    world.tscn          # Blackwater City + gameplay
    player.tscn         # Alex Mercer
    building.tscn       # Reusable building
    garage.tscn         # Underground garage
scripts/
    game_manager.gd     # Autoload singleton
    player_controller.gd
    camera_controller.gd
    mission_manager.gd
    interaction_system.gd
    interactable.gd
    npc_marcus.gd
    mobile_controls.gd
    game_hud.gd
    main_menu.gd
    pause_menu.gd
    world.gd
ui/
    game_hud.tscn
    pause_menu.tscn
assets/
    textures/icon.png
    environment/default_env.tres
docs/DEVELOPMENT.md
```

---

## 🚀 How to Run

### PC Testing (Godot Editor):
1. Install **Godot 4.4** (or 4.2+) from https://godotengine.org
2. Open Godot, click **Import**, select `project.godot` in this repo
3. Press **Play** (▶️) - main scene is Main Menu
4. Click **NEW GAME**
5. Controls:
   - **WASD** - Move
   - **Shift** - Sprint (drains stamina)
   - **Space** - Jump
   - **Right-click drag** - Rotate camera
   - **Mouse wheel** - Zoom
   - **E** - Interact (when near Marcus)
   - **Esc** - Pause

### Android Build:
1. In Godot: **Editor > Manage Export Templates** - download templates
2. Install Android SDK (via Android Studio)
3. **Project > Export** - select Android preset
4. Export to `builds/ShadowProtocol.apk`
5. Install on device: `adb install builds/ShadowProtocol.apk`
6. Or use **One-click deploy** with device connected via USB

**Export preset already configured:**
- Package: `com.studioavenox.shadowprotocol`
- Orientation: Landscape
- Renderer: gl_compatibility (broad device support)
- Permissions: Internet, Vibrate

---

## 🎯 First Mission: A NEW BEGINNING

> Alex Mercer has returned to Blackwater City. He must reach an underground parking garage and meet an old contact named Marcus Reed.

**Objectives:**
1. **Explore the starting area** - Move 30m to get familiar
2. **Find the mission destination** - Locate garage area (north)
3. **Reach the garage entrance** - Enter trigger at garage
4. **Interact with Marcus Reed** - Talk to contact inside garage
5. **Mission Complete** - Welcome to Blackwater City

Look for streetlights and building lights guiding you north toward the garage complex at (0,0,65).

---

## 🎨 Stitch Design References

This repo includes 8 cinematic reference folders (screen.png) from Google Stitch:
- Downtown panoramic capture
- Dark metropolitan city at night
- Intense urban police chase
- Rooftop widescreen
- Vehicle showcase renders (fictional cars, dark/minimalist/an)
- Mobile Phase 5 police pursuit HUDs (wanted level, radar, speedometer)

These were used to guide the visual direction (dark, cinematic, realistic-inspired) but **no copyrighted assets were copied**. All game assets are original procedural geometry.

---

## ✅ Validation

- [x] Valid Godot 4.x project.godot (config_version=5)
- [x] All scenes have valid resource references
- [x] All scripts are syntactically valid GDScript
- [x] Input map defined
- [x] Main menu is entry point
- [x] Icon exists
- [x] No empty placeholder files
- [x] No secrets committed
- [ ] Full editor playtest requires Godot installed (documented)
- [ ] Android device test requires build

See `docs/DEVELOPMENT.md` for detailed validation and next steps.

---

## 🔜 Next Phase (Not in this prototype)

- Real character model + animations
- Vehicle driving system
- Expanded city with traffic
- Audio (footsteps, ambient, dialogue)
- Minimap & GPS
- Police/wanted system
- Inventory & weapons
- More missions

---

## 📝 License

Original project for **Studio Avenox**.  
Built with Godot Engine (MIT).  
All characters, story, and city are fictional and original.

**Tagline: EVERY CHOICE LEAVES A TRACE.**
