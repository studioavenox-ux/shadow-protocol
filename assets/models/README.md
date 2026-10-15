# Models - Phase 5 Character Update

## Current Assets
- **Alex Mercer** - `alex_mercer.glb` (37KB, 360 verts, 180 tris, 19 bones, 5 PBR materials, 1 idle animation)
  - Location: `assets/character/alex_mercer.glb`, `assets/character-assets/alex_mercer.glb`, `assets/models/alex_mercer.glb`
  - Generated via Python pygltflib (no Blender required, original geometry)
  - Dark urban outfit: jacket #14161A, trousers #1E2126, skin #D1A990, shoes #0D0D0E, accent crimson #A51F2B
  - Humanoid rig: Hips->Spine->Chest->Neck->Head, Left/Right shoulders, upper/lower arms, hands, upper/lower legs, feet (19 bones)
  - PBR metallicRoughness, UVs, normals, skin weights (single bone per part)
  - Android optimized: low-poly, no textures, 5 materials
  - Integrated into `scenes/player.tscn` as `CharacterRoot/AlexModel` instance, legacy BoxMesh hidden

## Future Models
- Marcus Reed NPC model
- Vehicle models (sedan, SUV, police car) - currently procedural
- Building modular kit (facades, windows, doors)
- Street props (bench, trash bin, hydrant)

## Standards
- Optimized for mobile (low poly, efficient UVs)
- Use shared materials where possible
- LOD support for buildings
- Embedded in .glb format for Godot 4
- Y-up, scale 1 unit = 1 meter, height ~1.8m
- PBR materials, no heavy textures for Android
