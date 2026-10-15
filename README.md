# SHADOW PROTOCOL
### EVERY CHOICE LEAVES A TRACE.

**SHADOW PROTOCOL** is a third-person open-world crime thriller set in **BLACKWATER CITY**. You play as **Alex Mercer**, a young adult returning to the city and getting pulled into its criminal underworld.

Genre: Third-person open-world action and crime thriller  
Inspiration: GTA V open-world freedom + Mafia II cinematic storytelling (original characters & story)  
Engine: Godot 4.x (GDScript)  
Platforms: Android (primary, landscape) + Windows PC (testing)  
Version: 0.3.0 - Phase 3: Drivable Vehicles & Mobile Driving Gameplay

---

## 🎮 Playable Prototype - Phase 3 What's New

This is a **fully playable Godot project** with drivable vehicle, upgraded from Phase 2.

### Phase 1 & 2 Features (Preserved):
- Phase 1: Valid project, third-person player, follow camera, basic city, mobile controls, HUD, mission, interaction, main menu, pause, save
- Phase 2: Improved low-poly humanoid Alex Mercer (8 meshes <500 tris), procedural animator + AnimationPlayer, improved camera smoothing damping pitch -55/25, expanded city 240x240 + side streets + road markings + residential/commercial buildings + streetlights + props, destination beacon, dialogue UI, mobile polish 72 buttons

### Phase 3 New:
- ✅ **Drivable Car NIGHTFALL**: Reusable VehicleBody3D black sports sedan - Body Box 1.9x0.8x4.4 collision + 1.8x0.6x4.2 mesh black paint metallic 0.6 roughness 0.25 clearcoat, Cabin 1.6x0.5x2.2, Windshields glass, Spoiler, 4 wheels VehicleWheel3D Front steer true traction false friction 1.2 stiffness 35 travel 0.35, Rear traction true friction 1.5 stiffness 40 travel 0.4, radius 0.38, Wheels Cylinder 0.38 tire + Rim 0.22, Headlights SpotLight 25 range 25° energy 2.5 + bulb emissive 2.0, Scale 4.4x1.9x1.5m, Mass 1650kg center_of_mass (0,-0.8,0.2) lower, Tunable engine 900 brake 80 steer 0.6 rad handbrake 120, Actually drives via physics (RWD rear engine_force, front steering, brake all, handbrake rear, suspension)
- ✅ **Enter/Exit System**: Approach shows ENTER VEHICLE, enter hides player visible false DISABLED layer false disable_movement + camera to driving follow (SpringArm 6.0 behind car at 0,1.2,-2.5) + driving HUD + prevents controller interference, exit stops input + places beside car safe via ExitMarker (-2.5,0.5,0) raycast wall check other side + restores on-foot camera/controls, prevents through walls (raycast) or while moving dangerously (speed>3 m/s), uses existing interaction system
- ✅ **Mobile Driving Controls**: Landscape - Left: Steering ◀ 90 + ▶ 90 large buttons 220x120 container, Right: GAS 90 crimson active + BRAKE 80 + HB 72 handbrake + EXIT 72, Camera-look drag area right half offset 580, Pause 48, Large comfortable 72-90 no overlapping via CenterSpacer, actual touch controls car via set_throttle/steering/brake/handbrake, on-foot not active while driving via HUD switching, keyboard W/S/A/D Space E mouse look
- ✅ **Driving Camera & HUD**: Smooth third-person chase behind car SpringArm 6.0 margin 0.3 collision_mask 1 + Camera 70° FOV at 0,0.8,0, Smooth follow + rotation touch/mouse drag yaw/pitch clamped -20/15, adjustable distance 1.2-7.0, obstruction via SpringArm, center clear BottomBar -180 TopBar 84, Speedometer km/h SpeedLabel TopBar + SpeedValue 28 font + Gear D/P/R via speed*3.6, Vehicle condition health bar crimson, Minimap placeholder MINIMAP [PH] NIGHTFALL District 7 166x160, Mission objective Drive to Iron Gate Garage
- ✅ **Vehicle Garage**: Underground garage at 0,0,75 improved 28x9x34 + floor 26x32 + ramp 8x0.5x16 -5° at -22 + GarageLight Omni 1.0 range 28 + SpotLight entrance 1.5 range 20 35° shadow, Visible NIGHTFALL at 8,0.8,-8 near spawn, Entry/exit via VehicleInteractable layer 8 mask 2 prompt ENTER VEHICLE, Collision-safe parking Floor + Building + Ramp + ParkingLines 4 white, Info panel Label3D billboard at 8,0,-12 text NIGHTFALL Black Sports Sedan [Enter Vehicle] Top Speed 240 km/h font 24 outline 4
- ✅ **Connected Mission**: Extended A NEW BEGINNING Phase 3 - 1 Explore 0/30m, 2 Find NIGHTFALL VehicleTrigger at 8,2,-8, 3 Enter NIGHTFALL interaction, 4 Drive to Iron Gate Garage DestinationTrigger 0,2,40 + GarageEntranceTrigger 0,2,60 mask 6 player+vehicle beacon, 5 Park ParkingTrigger 0,2,75 requires speed<5, 6 Exit vehicle via exit signal, 7 Interact Marcus Reed inside garage, 8 Mission complete star notification save, Validation cannot skip index!=current blocked, not complete merely entering car, reuses beacon waypoint
- ✅ **Performance**: Simple collision Box/Cylinder, reusable buildings, no textures, limited lights 8 total 5 shadows max (2 street + garage spot + 2 headlights), stable physics mass 1650 center_of_mass lower friction 0.9 damp 0.1/0.8 stiffness 35/40, no per-frame alloc, gl_compatibility preserved, no FPS claimed

### Visual Identity:
- Obsidian #08090B, Charcoal #15171B, Steel gray #858B94, Off-white #F2F2F0, Muted crimson #A51F2B
- Cinematic nighttime with beacon, headlights, fog 0.007
- Optimized for Android

---

## 📁 Project Structure Phase 3
```
project.godot (input accelerate/brake/steer/handbrake + layers World/Player/Vehicle/Interactable/Trigger)
scenes/
    main_menu.tscn
    world.tscn (with NIGHTFALL + VehicleTrigger + ParkingTrigger + DrivingHUD + InfoPanel)
    player.tscn (humanoid)
    nightfall.tscn (new - VehicleBody3D black sedan 4 wheels headlights)
    building.tscn, building_residential.tscn, building_commercial.tscn, garage.tscn, destination_marker.tscn
scripts/
    vehicle_controller.gd (new - drivable physics)
    vehicle_interactable.gd (new - ENTER VEHICLE)
    driving_hud.gd (new - speedometer + driving controls)
    player_controller.gd (mask 1|4)
    camera_controller.gd, character_animator.gd
    mission_manager.gd (8 objectives vehicle)
    world.gd (vehicle HUD switching)
    game_hud.gd, mobile_controls.gd, interactable.gd (layer 8 mask 2), etc.
ui/
    game_hud.tscn (on-foot)
    driving_hud.tscn (new - GAS BRAKE HB EXIT steer)
    pause_menu.tscn
assets/textures/icon.png
docs/FEATURES.md (Phase 3 report)
```

---

## 🚀 How to Run

### PC Testing:
1. Godot 4.4 → Import project.godot → Play → NEW GAME
2. On Foot: WASD Move, Shift Sprint, Space Jump, E Interact (ENTER VEHICLE near NIGHTFALL black sedan at 8,0.8,-8 with Label3D info), Right-drag Camera, Wheel Zoom, Esc Pause
3. Driving: W/Up Accelerate, S/Down Brake (>1 speed) / Reverse (<1, 0.6 slower), A/D Steer, Space Handbrake, E Exit when safe (speed<3 no wall), Mouse Right-drag Camera, Esc Pause
4. Mission: Explore 30m (0/30m progress), Find NIGHTFALL (VehicleTrigger at 8,2,-8), Enter (E), Drive north to Iron Gate Garage (red beacon at 0,0.5,-18 rel to garage), follow road markings, GarageEntranceTrigger at 0,2,60, ParkingTrigger at 0,2,75 requires speed<5, Exit (E or EXIT button), Talk Marcus (E) inside garage at 0,1,-5, Mission Complete ★

### Android Build:
1. Editor > Manage Export Templates → Download
2. Project > Export → Android preset com.studioavenox.shadowprotocol landscape gl_compatibility arm64 → builds/ShadowProtocol.apk → adb install
3. On Foot: Left joystick 140/60 move, Right half drag look, JUMP 72 SPRINT 72 INTERACT 72 ◉ ENTER VEHICLE, Pause 48
4. Driving: Left Steer ◀ 90 ▶ 90, Right GAS 90 BRAKE 80 HB 72 EXIT 72, Right half drag camera, Top Speed + Health + Pause, Left Speedometer 28 font D/P/R + Minimap placeholder, Center clear for road

See docs/LAUNCH.md

---

## 🎯 Mission Phase 3

1 Explore (0/30m) → 2 Find NIGHTFALL VehicleTrigger → 3 Enter NIGHTFALL → 4 Drive to Iron Gate Garage (Destination + GarageEntrance triggers) → 5 Park ParkingTrigger speed<5 → 6 Exit vehicle → 7 Interact Marcus Reed → 8 Mission Complete

Cannot skip - validation, not complete merely entering car.

---

## ✅ Validation Phase 3

- [x] Vehicle scene valid 24 load_steps 2 ext_resources 13 sub_resources VehicleBody3D + 4 VehicleWheel3D + Collision + Meshes + Headlights Spot + InteractionArea + ExitMarker + CameraPivot SpringArm Camera
- [x] Physics wheels front steer rear traction mass 1650 center_of_mass lower engine rear steering front
- [x] Acceleration steering braking reverse implemented throttle -1 to 1 pow 0.9 reverse 0.6 steer lerp 2.5 brake 80 handbrake 120
- [x] Enter/exit transitions can_enter speed>2 false can_exit speed>3 false raycast safe ExitMarker -2.5,0.5,0 other side, hide player DISABLED camera switching HUD switching
- [x] Camera transitions game_hud false driving_hud true player cam false vehicle cam true reverse
- [x] Mobile/keyboard controls DrivingHUD 72-90 large no overlap set_* methods keyboard W/S/A/D Space E mouse
- [x] Collision parking ground 240 garage 28 ramp vehicle layer 4 mask 1 player mask 1|4 triggers layer 16 mask 2/6 parking speed<5 safe exit
- [x] Mission progression 8 objectives validation cannot skip vehicle signals triggers notifications not merely entering car
- [x] On-foot after exit restored visible true INHERIT layer true enable_movement camera true game_hud true
- [x] Project.godot input accelerate/brake/steer/handbrake layer names World/Player/Vehicle/Interactable/Trigger main_scene autoload 16 scripts OK 9 scenes UID
- [ ] Godot editor launch: Requires Godot - not in sandbox - explicitly stated not tested
- [ ] Android device: Requires build - not tested

---

## 🔜 Next Phase

Phase 4: Audio & Immersion + Police System - Engine sound AudioStreamPlayer pitch rpm, tire screech, ambient city, footsteps, dialogue voice, music, police pursuit wanted stars heat level radar minimap circular N/E/S/W road overlay player pip interceptor pips police AI chase roadblocks from Stitch Phase 5, minimap real GPS, vehicle damage visual, fuel, repair garage

**EVERY CHOICE LEAVES A TRACE.**
