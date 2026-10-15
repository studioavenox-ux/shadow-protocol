# SHADOW PROTOCOL - Godot 4.4 In-Game Visual Test Instructions

## Current State (Commit 684508d)

- **Updated GLB path**: `assets/character/alex_mercer.glb` (142,060 bytes, 1643 verts, 1488 tris, 6 PBR mats, 19 bones, 1 idle anim)
- **Copies**: `assets/character-assets/alex_mercer.glb` and `assets/models/alex_mercer.glb` (same file, 142KB)
- **Player scene**: `res://scenes/player.tscn` references `res://assets/character/alex_mercer.glb` as `CharacterRoot/AlexModel` instance=ExtResource(4) - **correct, not older duplicate**
- **Legacy**: BoxMesh/CapsuleMesh hidden visible=false under CharacterRoot, preserved as fallback
- **Skeleton**: 19 bones Hips->Spine->Chest->Neck->Head, shoulders, arms, hands, legs, feet - preserved
- **Animation**: idle chest bob in GLB + procedural walk/run/sprint/jump/fall/land via `character_animator.gd` with robust Skeleton3D auto-detect

## Automated Checks Passed (No Godot Binary)

- File existence: player.tscn, player_controller.gd, character_animator.gd, camera_controller.gd, 3 GLB paths - PASS
- GLB validity: pygltflib loads 21 nodes, 41 primitives, 6 mats, 19 joints, 1 anim, buffer 142KB - PASS
- Orientation: Y-up, height 1.97m, X 1.86 Y 1.97 Z 0.49 Y largest - PASS
- Scale: 1643 verts <5000, 1488 tris <5000, 142KB - PASS Android optimized
- Feet alignment: Min Y 0.0, Max Y 1.97, bottom at ground - PASS (was -0.02 in v1)
- Facing: Front -Z (Godot forward) - accent zipper at -0.17, face at -0.16, nose at -0.20 all -Z - PASS
- Materials: 6 PBR dark urban (Jacket_Dark 0.10/0.11/0.13, Skin 0.84/0.70/0.60, Trousers 0.14/0.15/0.17, Shoes 0.07, Accent Crimson 0.647, Hair Dark 0.08) - PASS
- Skeleton: 19 bones required present (Hips, Spine, Chest, Head, LeftUpperArm, RightUpperArm, LeftUpperLeg, RightUpperLeg) - PASS
- UVs, Normals present - PASS
- Topology: capsules 12 segments + spheres + boxes, clean quads->tris - PASS
- Integration: CharacterBody3D, CollisionShape3D capsule 0.35x1.4 at 0,0.9, CameraPivot SpringArm 4.2 FOV68, controller preserved - PASS
- Animation compatibility: skeleton_path auto-detect via recursive search, fuzzy animation name search, preserves movement controller - PASS (code fix)

## Fixes Applied in This Commit

- **character_animator.gd**: Changed skeleton_path from hardcoded "../AlexModel/Armature_Root/Skeleton3D" to auto-detect NodePath("") with recursive search fallback. Added 3 extra search paths (Hips as Skeleton3D, Armature_Root itself) and child search. Added search from Player root via group "player". Added `_find_animation_by_substring` for robust animation name matching (handles "idle" vs "Armature_Root|idle" vs "mixamo.com|idle"). Updated `update_animation` and `play_animation` to try exact then fuzzy match, with debug prints. Preserves movement controller, no rewrite.

## Exact Project Launch Steps in Godot 4.4

### Prerequisites
- Godot 4.4 stable (https://godotengine.org/download)
- Project cloned: `git clone https://github.com/studioavenox-ux/shadow-protocol.git` and checkout branch `arena/6bd301d4-shadow-protocol` or use current working directory
- No additional dependencies needed (pygltflib only for generation, not runtime)

### Steps

1. **Open Project:**
   ```
   - Launch Godot 4.4
   - Click "Import" -> Browse to `/path/to/shadow-protocol/project.godot`
   - Click "Import & Edit"
   - Wait for import (should import alex_mercer.glb automatically, creates .import files)
   ```

2. **Inspect Player Scene:**
   ```
   - In FileSystem dock: res://scenes/player.tscn double-click
   - In Scene tree: Player (CharacterBody3D) -> CharacterRoot -> AlexModel (should be instance of alex_mercer.glb)
   - Select AlexModel -> In Inspector, check if it has child Armature_Root -> Skeleton3D
   - Select Skeleton3D -> Check Bone count: should be 19, names: Hips, Spine, Chest, Neck, Head, LeftShoulder, LeftUpperArm, LeftLowerArm, LeftHand, RightShoulder, RightUpperArm, RightLowerArm, RightHand, LeftUpperLeg, LeftLowerLeg, LeftFoot, RightUpperLeg, RightLowerLeg, RightFoot
   - If Skeleton3D not found, check Console for "[CharacterAnimator] Found skeleton via..." prints
   - Select CharacterRoot -> Check Transform: Position 0,0,0, Rotation 0,0,0, Scale 1,1,1
   - Select AlexModel -> Transform 0,0,0 - feet should be at y=0 (ground)
   - Check legacy meshes under CharacterRoot: Torso, Head, LeftArm etc - should have visible=false (hidden)
   ```

3. **Check Materials:**
   ```
   - Select AlexModel -> Find MeshInstance3D (AlexMercer_Mesh) -> Surface Material Override should be empty (materials from GLB)
   - In FileSystem: res://assets/character/alex_mercer.glb -> Click -> Import tab -> Check Materials: should show 6 materials with base colors dark urban
   - If materials look wrong (pink), reimport: Select glb -> Import tab -> Reimport
   ```

4. **Check Animation:**
   ```
   - In player.tscn, find AnimationPlayer under CharacterRoot (legacy) and under AlexModel/Armature_Root (GLB)
   - GLB AnimationPlayer should have animation "idle" (or "Armature_Root|idle") - 3 keys, 2 seconds, chest Y bob 0->0.012->0
   - Select AnimationPlayer -> Play "idle" -> Check Output console for "[CharacterAnimator] Playing GLB anim: idle"
   - If animation not found, check _find_animation_by_substring should handle fuzzy match
   ```

5. **Check Orientation and Ground Alignment:**
   ```
   - In 3D viewport, select Player, set Position y=0, x=0, z=0
   - Check feet bottom touches grid y=0 - should be Min Y 0.0, not floating or sinking
   - Check facing: Front is -Z (Godot forward) - Face and zipper at -Z (towards -Z axis, blue arrow in Godot). When you look from +Z towards origin, you should see face and crimson zipper
   - If facing +Z (backwards), select AlexModel and rotate y=180 deg, then save scene
   ```

6. **Run Game - Main Menu:**
   ```
   - Press F5 or Click Play button (top right)
   - Main scene is res://scenes/main_menu.tscn (project.godot run/main_scene)
   - In main menu, click Play or Start
   - Should load res://scenes/world.tscn
   ```

7. **In-Game Visual Test - On Foot:**
   ```
   - Player spawns at PlayerSpawn (0,1,-10)
   - Check character visible: polished jacket with folds, rounded arms/legs capsules 12 seg, hair dark, face with nose, shoes with toe caps, dark urban cohesive
   - Check idle: chest breathing subtle Y bob
   - Move with WASD or joystick: walk, run, sprint (Shift) - check procedural animation legs swing, arms swing, chest rotation, no T-pose
   - Jump with Space: check jump anim legs -0.8, arms -1.2
   - Fall: check fall anim
   - Sprint: check stamina drain
   - Interaction: approach NIGHTFALL sedan (black sports car at 8,0.8,-8), press E or Interact button - should show prompt
   ```

8. **In-Game Visual Test - Vehicle:**
   ```
   - Enter NIGHTFALL: check HUD switches to DrivingHUD, player hidden, vehicle camera active
   - Drive with W/S and A/D or mobile steering: check gradual steering, stability (mass 1850, CoM -1.1, angular damp 2.2), no tipping
   - Check tire squeal logic, engine pitch
   - Exit vehicle: check safe exit placement (6 offsets raycast)
   - Drive to Iron Gate Garage at 0,0,75: check parking requires proper bounds x[-16,16] z[58,94] dist<20
   ```

9. **Police and Audio (Phase 4):**
   ```
   - Test wanted system: speed >100 triggers wanted, vehicle theft (if not tutorial)
   - Check HUD wanted stars, police alert, minimap direction
   - Check audio manager optional paths (no missing refs)
   ```

10. **Android Export (Optional):**
    ```
    - Project -> Export -> Add Android preset
    - Check Min SDK, permissions, orientation landscape
    - Export APK, install on device, check performance 1488 tris fine, 142KB model, materials correct
    ```

## Remaining Manual Checks (Do NOT Claim Passed Until Tested in Godot)

Since Godot binary NOT AVAILABLE in sandbox, following require manual testing and cannot be claimed passed:

- [ ] Visual in editor: polished jacket folds, rounded limbs 12 seg, hair, face, shoes toe caps, dark cohesive, no import warnings
- [ ] Skeleton: 19 bones visible in Skeleton3D inspector, bone names correct
- [ ] Materials: 6 PBR dark urban look correct, not pink, roughness variation visible
- [ ] Orientation: faces -Z when rotation.y=0, front -Z with zipper and face at -Z
- [ ] Ground alignment: feet bottom at y=0 touching ground plane, not floating/sinking
- [ ] Animation: idle chest bob plays, procedural walk/run/sprint/jump/fall/land animates skeleton without T-pose
- [ ] In-game movement: WASD/joystick moves player, camera follows, collision works, stamina/health HUD updates
- [ ] Vehicle: enter/exit NIGHTFALL, gradual steering, stability, camera driving/reversing, safe exit, parking bounds
- [ ] Missions: 8 objectives complete, Marcus Reed dialogue, mission complete
- [ ] Police: wanted levels 0-3, pursuit, search, escape, HUD indicators
- [ ] Audio: optional paths no errors, engine pitch, tire squeal, footsteps, interaction, mission complete
- [ ] Android: APK exports, runs on device, performance OK, no crashes

## Known Limitations

- Blender NOT AVAILABLE in sandbox, so used Python pygltflib best alternative - capsules/spheres/boxes with 12 segments, folds via extra boxes, hair, face details. For sculpted folds, normal maps, blend shapes, need Blender.
- No Godot binary, so runtime testing not performed - instructions provided for manual testing.
- Model is stylized low-poly (1643 verts, 1488 tris) suitable for Android but not high-poly sculpted - for AAA quality need Blender sculpt + texture atlas 512x512.

## Commit

- Branch: `arena/6bd301d4-shadow-protocol`
- Latest GLB: `assets/character/alex_mercer.glb` 142,060 bytes, verified via pygltflib
- Fixes: `scripts/character_animator.gd` skeleton auto-detect + fuzzy anim search
- Docs: `docs/TESTING_INSTRUCTIONS.md` this file
