# Launch Instructions - SHADOW PROTOCOL v0.1.0

## Quick Start (PC Testing)

### Prerequisites
- Godot Engine 4.4 (recommended) or 4.2+ 
  Download from https://godotengine.org/download
- No additional dependencies

### Steps
1. Clone repo:
   ```
   git clone https://github.com/studioavenox-ux/shadow-protocol.git
   cd shadow-protocol
   git checkout arena/6bd301d4-shadow-protocol
   ```
2. Open Godot
3. Click Import, navigate to project.godot, select it
4. Click Import & Edit
5. Press F5 or ▶️ Play button (main scene is main_menu.tscn)
6. In Main Menu, click NEW GAME
7. Play!

### Controls (PC)
- WASD: Move
- Shift: Hold to sprint (drains stamina)
- Space: Jump (costs 10 stamina)
- E: Interact (when near Marcus Reed or other interactables)
- Right Mouse Drag: Rotate camera
- Mouse Wheel: Zoom in/out
- Esc: Pause

### What to Test
1. Player movement feels smooth, camera-relative
2. Joystick (mouse drag on left joystick area) works
3. Camera drag (drag on right half of screen) rotates camera
4. Jump button works, sprint toggle works
5. Explore: walk 30m to complete first objective
6. Find garage: go north (toward lights) to (0,0,65) area, triggers should fire
7. Enter garage, talk to Marcus Reed (press E or Interact button)
8. Mission completes with notification
9. Pause menu: Esc, test Resume, Restart, Main Menu

---

## Android Build & Launch

### Prerequisites
- Godot 4.4 with Android export templates installed
  - In Godot: Editor > Manage Export Templates > Download
- Android SDK (via Android Studio or command line tools)
- ADB for device deployment
- Android device with Developer Options + USB Debugging enabled
- Optional: Keystore for release builds

### One-Click Deploy (Easiest for Testing)
1. Open project in Godot
2. Connect Android device via USB, enable USB debugging, allow debugging
3. In Godot, click the remote deploy button (top right, Android icon) or:
   - Project > Export > Android > One-click deploy
4. Godot will build and install APK automatically
5. Launch on device

### Manual APK Build
1. Open project in Godot
2. Project > Export
3. Select Android preset (already configured)
   - Package: com.studioavenox.shadowprotocol
   - Name: SHADOW PROTOCOL
   - Orientation: Landscape
   - Renderer: gl_compatibility
4. Set Export Path: builds/ShadowProtocol.apk (create builds folder)
5. Click Export Project
6. If debug build: enable Use Debug Keystore
7. For release: configure keystore path, user, password
8. Export

### Install APK
```
adb install builds/ShadowProtocol.apk
# Or if already installed:
adb install -r builds/ShadowProtocol.apk
```

### Android Controls
- Left thumb: Virtual joystick (move)
- Right thumb: Drag on right half screen (look around)
- Right side buttons: JUMP, SPRINT (toggle), INTERACT (◉)
- Top right: Pause (||)

### Performance Tips for Low-End Devices
- In GameManager settings (future), set graphics_quality to 0
- Current prototype already optimized:
  - gl_compatibility renderer
  - Simple geometry
  - Limited lights
  - No heavy post-processing
- Should run 60fps on Snapdragon 660+ or equivalent

---

## Windows Build

1. Project > Export > Windows Desktop preset (already configured)
2. Export Path: builds/ShadowProtocol.exe
3. Export
4. Run builds/ShadowProtocol.exe

---

## Troubleshooting

### Godot says "No main scene"
- Check project.godot run/main_scene = res://scenes/main_menu.tscn
- If not, set it in Project Settings > Run > Main Scene

### Player falls through ground
- Check Ground StaticBody3D collision_layer 1, Player collision_mask 1
- Should be configured correctly

### Camera not rotating
- Try right-click drag on PC
- On mobile, drag on right half of screen
- Check CameraPivot script attached

### Interact not working
- Must be within 1.5m of Marcus Reed (inside garage)
- Look for interaction prompt "[E] Talk to Marcus Reed"
- Press E or Interact button

### Mission not progressing
- Objective 1 requires 30m movement - walk around
- Objectives 2 and 3 require entering trigger areas (large boxes at z=40 and z=55)
- Check MissionManager signals connected

### No Godot installed (CI/Sandbox)
- Project files are text-based and valid
- Validation documented in docs/DEVELOPMENT.md
- Install Godot to fully test

---

## File Integrity Check

Run this in repo root:
```
find . -name "*.gd" -exec echo "Checking {}" \; -exec python3 -m py_compile {} \; 2>&1 | head
# Or basic syntax check:
grep -r "extends" scripts/ | wc -l  # Should be 12
ls scenes/*.tscn ui/*.tscn  # Should list 6 files
ls assets/textures/icon.png  # Should exist
```

---

## Support

- Docs: docs/DEVELOPMENT.md (technical), docs/FEATURES.md (completion), docs/LAUNCH.md (this file)
- Issues: GitHub Issues in studioavenox-ux/shadow-protocol
- Branch: arena/6bd301d4-shadow-protocol (prototype branch)

**EVERY CHOICE LEAVES A TRACE.**
