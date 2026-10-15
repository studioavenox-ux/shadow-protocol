#!/usr/bin/env python3
"""
Polished Alex Mercer - stylized protagonist for modern Android open-world
- Young adult male, dark urban jacket with folds, layered clothing
- Properly shaped trousers, rounded shoes
- Better head, neck, hands, facial proportions
- Dark hair, cohesive style
- Smooth rounded limbs
- Consistent dark materials with subtle detail
- Preserves skeleton, Android optimized, Godot 4 compatible
"""

import numpy as np
import math, os
from pygltflib import (
    GLTF2, Scene, Node, Mesh, Primitive, Material, PbrMetallicRoughness,
    Buffer, BufferView, Accessor, Skin, Animation, AnimationSampler, AnimationChannel,
    ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER,
    FLOAT, UNSIGNED_SHORT, UNSIGNED_INT,
    SCALAR, VEC2, VEC3, VEC4, MAT4
)

out_dir = "/home/user/shadow-protocol/assets/character"
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "alex_mercer.glb")

# Preserve skeleton - same 19 bones
bones_def = [
    ("Hips", -1, np.array([0.0, 0.92, 0.0])),
    ("Spine", 0, np.array([0.0, 1.06, 0.0])),
    ("Chest", 1, np.array([0.0, 1.30, 0.0])),
    ("Neck", 2, np.array([0.0, 1.54, 0.0])),
    ("Head", 3, np.array([0.0, 1.72, 0.0])),
    ("LeftShoulder", 2, np.array([-0.20, 1.47, 0.0])),
    ("LeftUpperArm", 5, np.array([-0.37, 1.47, 0.0])),
    ("LeftLowerArm", 6, np.array([-0.66, 1.47, 0.0])),
    ("LeftHand", 7, np.array([-0.89, 1.47, 0.0])),
    ("RightShoulder", 2, np.array([0.20, 1.47, 0.0])),
    ("RightUpperArm", 9, np.array([0.37, 1.47, 0.0])),
    ("RightLowerArm", 10, np.array([0.66, 1.47, 0.0])),
    ("RightHand", 11, np.array([0.89, 1.47, 0.0])),
    ("LeftUpperLeg", 0, np.array([-0.135, 0.60, 0.0])),
    ("LeftLowerLeg", 13, np.array([-0.135, 0.20, 0.0])),
    ("LeftFoot", 14, np.array([-0.135, 0.06, 0.09])),
    ("RightUpperLeg", 0, np.array([0.135, 0.60, 0.0])),
    ("RightLowerLeg", 16, np.array([0.135, 0.20, 0.0])),
    ("RightFoot", 17, np.array([0.135, 0.06, 0.09])),
]

num_joints = len(bones_def)
local_translations = []
for i, (name, parent, world_pos) in enumerate(bones_def):
    if parent == -1:
        local = world_pos
    else:
        parent_world = bones_def[parent][2]
        local = world_pos - parent_world
    local_translations.append(local)

ibm = []
for i, (name, parent, world_pos) in enumerate(bones_def):
    mat = np.eye(4, dtype=np.float32)
    mat[0,3] = -world_pos[0]
    mat[1,3] = -world_pos[1]
    mat[2,3] = -world_pos[2]
    ibm.append(mat.T)
ibm_array = np.stack(ibm).astype(np.float32)
ibm_flat = ibm_array.reshape(-1)

def create_box(center, size):
    sx, sy, sz = size[0]/2, size[1]/2, size[2]/2
    cx, cy, cz = center
    positions = []
    normals = []
    uvs = []
    positions.extend([[cx+sx, cy-sy, cz-sz],[cx+sx, cy+sy, cz-sz],[cx+sx, cy+sy, cz+sz],[cx+sx, cy-sy, cz+sz]])
    normals.extend([[1,0,0]]*4)
    uvs.extend([[0,0],[0,1],[1,1],[1,0]])
    positions.extend([[cx-sx, cy-sy, cz+sz],[cx-sx, cy+sy, cz+sz],[cx-sx, cy+sy, cz-sz],[cx-sx, cy-sy, cz-sz]])
    normals.extend([[-1,0,0]]*4)
    uvs.extend([[0,0],[0,1],[1,1],[1,0]])
    positions.extend([[cx-sx, cy+sy, cz-sz],[cx-sx, cy+sy, cz+sz],[cx+sx, cy+sy, cz+sz],[cx+sx, cy+sy, cz-sz]])
    normals.extend([[0,1,0]]*4)
    uvs.extend([[0,0],[0,1],[1,1],[1,0]])
    positions.extend([[cx-sx, cy-sy, cz+sz],[cx-sx, cy-sy, cz-sz],[cx+sx, cy-sy, cz-sz],[cx+sx, cy-sy, cz+sz]])
    normals.extend([[0,-1,0]]*4)
    uvs.extend([[0,0],[0,1],[1,1],[1,0]])
    positions.extend([[cx-sx, cy-sy, cz+sz],[cx+sx, cy-sy, cz+sz],[cx+sx, cy+sy, cz+sz],[cx-sx, cy+sy, cz+sz]])
    normals.extend([[0,0,1]]*4)
    uvs.extend([[0,0],[1,0],[1,1],[0,1]])
    positions.extend([[cx+sx, cy-sy, cz-sz],[cx-sx, cy-sy, cz-sz],[cx-sx, cy+sy, cz-sz],[cx+sx, cy+sy, cz-sz]])
    normals.extend([[0,0,-1]]*4)
    uvs.extend([[0,0],[1,0],[1,1],[0,1]])
    indices = []
    for i in range(6):
        base = i*4
        indices.extend([base, base+1, base+2, base, base+2, base+3])
    return np.array(positions, dtype=np.float32), np.array(normals, dtype=np.float32), np.array(uvs, dtype=np.float32), np.array(indices, dtype=np.uint16)

def create_capsule(center, radius, height, segments=12):
    cx, cy, cz = center
    cyl_height = max(0, height - 2*radius)
    half_cyl = cyl_height / 2
    positions = []
    normals = []
    uvs = []
    indices = []
    for i in range(segments):
        angle = (i / segments) * 2 * math.pi
        x = math.cos(angle) * radius
        z = math.sin(angle) * radius
        positions.append([cx + x, cy - half_cyl, cz + z])
        normals.append([x/radius, 0, z/radius])
        uvs.append([i/segments, 0])
        positions.append([cx + x, cy + half_cyl, cz + z])
        normals.append([x/radius, 0, z/radius])
        uvs.append([i/segments, 1])
    for i in range(segments):
        i0 = i*2
        i1 = i*2+1
        j0 = ((i+1)%segments)*2
        j1 = ((i+1)%segments)*2+1
        indices.extend([i0, j0, j1, i0, j1, i1])
    base_idx = len(positions)
    top_center = [cx, cy + half_cyl + radius*0.6, cz]
    top_ring_start = base_idx
    for i in range(segments):
        angle = (i / segments) * 2 * math.pi
        x = math.cos(angle) * radius * 0.65
        z = math.sin(angle) * radius * 0.65
        positions.append([cx + x, cy + half_cyl + radius*0.5, cz + z])
        nx = x / radius
        nz = z / radius
        ny = 0.7
        length = math.sqrt(nx*nx + ny*ny + nz*nz)
        normals.append([nx/length, ny/length, nz/length])
        uvs.append([0.5 + x/radius*0.5, 0.5 + z/radius*0.5])
    positions.append(top_center)
    normals.append([0,1,0])
    uvs.append([0.5,0.5])
    top_center_idx = len(positions)-1
    for i in range(segments):
        j = (i+1)%segments
        indices.extend([top_ring_start + i, top_ring_start + j, top_center_idx])
    bottom_ring_start = len(positions)
    bottom_center = [cx, cy - half_cyl - radius*0.6, cz]
    for i in range(segments):
        angle = (i / segments) * 2 * math.pi
        x = math.cos(angle) * radius * 0.65
        z = math.sin(angle) * radius * 0.65
        positions.append([cx + x, cy - half_cyl - radius*0.5, cz + z])
        nx = x / radius
        nz = z / radius
        ny = -0.7
        length = math.sqrt(nx*nx + ny*ny + nz*nz)
        normals.append([nx/length, ny/length, nz/length])
        uvs.append([0.5 + x/radius*0.5, 0.5 + z/radius*0.5])
    positions.append(bottom_center)
    normals.append([0,-1,0])
    uvs.append([0.5,0.5])
    bottom_center_idx = len(positions)-1
    for i in range(segments):
        j = (i+1)%segments
        indices.extend([bottom_ring_start + i, bottom_center_idx, bottom_ring_start + j])
    return np.array(positions, dtype=np.float32), np.array(normals, dtype=np.float32), np.array(uvs, dtype=np.float32), np.array(indices, dtype=np.uint16)

def create_sphere(center, radius, lat_segments=6, lon_segments=10):
    cx, cy, cz = center
    positions = []
    normals = []
    uvs = []
    indices = []
    for lat in range(lat_segments+1):
        theta = lat * math.pi / lat_segments
        sin_theta = math.sin(theta)
        cos_theta = math.cos(theta)
        for lon in range(lon_segments+1):
            phi = lon * 2 * math.pi / lon_segments
            sin_phi = math.sin(phi)
            cos_phi = math.cos(phi)
            x = cos_phi * sin_theta
            y = cos_theta
            z = sin_phi * sin_theta
            positions.append([cx + x*radius, cy + y*radius, cz + z*radius])
            normals.append([x, y, z])
            uvs.append([lon/lon_segments, lat/lat_segments])
    for lat in range(lat_segments):
        for lon in range(lon_segments):
            first = lat * (lon_segments+1) + lon
            second = first + lon_segments + 1
            indices.extend([first, second, first+1])
            indices.extend([second, second+1, first+1])
    return np.array(positions, dtype=np.float32), np.array(normals, dtype=np.float32), np.array(uvs, dtype=np.float32), np.array(indices, dtype=np.uint16)

# Polished parts - young adult male, dark urban jacket with folds, layered
parts = []

# --- TORSO / JACKET ---
# Hips base - jacket bottom with slight flare
parts.append({"center": np.array([0.0, 0.88, 0.0]), "size": np.array([0.54, 0.20, 0.32]), "joint": 0, "mat": 0, "name": "HipsJacket", "type": "box"})
# Abdomen - tapered
parts.append({"center": np.array([0.0, 1.10, 0.0]), "size": np.array([0.50, 0.32, 0.29]), "joint": 2, "mat": 0, "name": "Abdomen", "type": "box"})
# Chest - broader shoulders, stylized
parts.append({"center": np.array([0.0, 1.34, 0.0]), "size": np.array([0.58, 0.36, 0.32]), "joint": 2, "mat": 0, "name": "Chest", "type": "box"})
# Jacket folds - left side fold (layered clothing)
parts.append({"center": np.array([-0.16, 1.18, -0.16]), "size": np.array([0.14, 0.45, 0.02]), "joint": 2, "mat": 0, "name": "FoldLeft", "type": "box"})
parts.append({"center": np.array([0.16, 1.18, -0.16]), "size": np.array([0.14, 0.45, 0.02]), "joint": 2, "mat": 0, "name": "FoldRight", "type": "box"})
# Zipper / front seam - crimson accent, facing -Z
parts.append({"center": np.array([0.0, 1.20, -0.17]), "size": np.array([0.04, 0.62, 0.02]), "joint": 2, "mat": 4, "name": "Zipper", "type": "box"})
# Pockets - subtle detail
parts.append({"center": np.array([-0.18, 1.02, -0.16]), "size": np.array([0.12, 0.10, 0.02]), "joint": 0, "mat": 0, "name": "PocketLeft", "type": "box"})
parts.append({"center": np.array([0.18, 1.02, -0.16]), "size": np.array([0.12, 0.10, 0.02]), "joint": 0, "mat": 0, "name": "PocketRight", "type": "box"})
# Collar - layered, around neck
parts.append({"center": np.array([0.0, 1.52, 0.0]), "size": np.array([0.42, 0.14, 0.36]), "joint": 3, "mat": 0, "name": "Collar", "type": "box"})
# Inner shirt visible at collar
parts.append({"center": np.array([0.0, 1.48, -0.14]), "size": np.array([0.18, 0.12, 0.02]), "joint": 3, "mat": 1, "name": "ShirtCollar", "type": "box"})

# --- HEAD / NECK / FACE ---
# Neck - capsule, better shape
parts.append({"center": np.array([0.0, 1.60, 0.0]), "size": np.array([0.12, 0.20, 0.12]), "joint": 3, "mat": 1, "name": "Neck", "type": "capsule", "radius": 0.07, "height": 0.20})
# Head - rounded, better proportions young adult male
parts.append({"center": np.array([0.0, 1.76, 0.0]), "size": np.array([0.26, 0.30, 0.28]), "joint": 4, "mat": 1, "name": "Head", "type": "sphere", "radius": 0.16, "lat": 6, "lon": 10})
# Face - more defined, protruding at -Z (front)
parts.append({"center": np.array([0.0, 1.73, -0.16]), "size": np.array([0.16, 0.18, 0.06]), "joint": 4, "mat": 1, "name": "Face", "type": "box"})
# Nose - subtle
parts.append({"center": np.array([0.0, 1.74, -0.20]), "size": np.array([0.04, 0.06, 0.04]), "joint": 4, "mat": 1, "name": "Nose", "type": "box"})
# Ears - small
parts.append({"center": np.array([-0.15, 1.76, 0.0]), "size": np.array([0.04, 0.08, 0.04]), "joint": 4, "mat": 1, "name": "EarLeft", "type": "box"})
parts.append({"center": np.array([0.15, 1.76, 0.0]), "size": np.array([0.04, 0.08, 0.04]), "joint": 4, "mat": 1, "name": "EarRight", "type": "box"})
# Hair - dark, styled, cohesive
parts.append({"center": np.array([0.0, 1.92, 0.0]), "size": np.array([0.28, 0.10, 0.30]), "joint": 4, "mat": 5, "name": "HairTop", "type": "box"})
parts.append({"center": np.array([0.0, 1.85, 0.10]), "size": np.array([0.30, 0.14, 0.12]), "joint": 4, "mat": 5, "name": "HairBack", "type": "box"})
parts.append({"center": np.array([-0.14, 1.86, 0.0]), "size": np.array([0.06, 0.12, 0.20]), "joint": 4, "mat": 5, "name": "HairSideLeft", "type": "box"})
parts.append({"center": np.array([0.14, 1.86, 0.0]), "size": np.array([0.06, 0.12, 0.20]), "joint": 4, "mat": 5, "name": "HairSideRight", "type": "box"})

# --- ARMS - smooth rounded ---
# Shoulders - rounded
parts.append({"center": np.array([-0.22, 1.47, 0.0]), "size": np.array([0.12, 0.12, 0.12]), "joint": 5, "mat": 0, "name": "ShoulderLeft", "type": "sphere", "radius": 0.08, "lat": 5, "lon": 8})
parts.append({"center": np.array([0.22, 1.47, 0.0]), "size": np.array([0.12, 0.12, 0.12]), "joint": 9, "mat": 0, "name": "ShoulderRight", "type": "sphere", "radius": 0.08, "lat": 5, "lon": 8})
# Upper arms - capsule
parts.append({"center": np.array([-0.38, 1.34, 0.0]), "size": np.array([0.12, 0.34, 0.12]), "joint": 6, "mat": 0, "name": "UpperArmLeft", "type": "capsule", "radius": 0.075, "height": 0.34})
parts.append({"center": np.array([0.38, 1.34, 0.0]), "size": np.array([0.12, 0.34, 0.12]), "joint": 10, "mat": 0, "name": "UpperArmRight", "type": "capsule", "radius": 0.075, "height": 0.34})
# Elbows - small spheres for joint
parts.append({"center": np.array([-0.56, 1.18, 0.0]), "size": np.array([0.08, 0.08, 0.08]), "joint": 6, "mat": 0, "name": "ElbowLeft", "type": "sphere", "radius": 0.06, "lat": 4, "lon": 8})
parts.append({"center": np.array([0.56, 1.18, 0.0]), "size": np.array([0.08, 0.08, 0.08]), "joint": 10, "mat": 0, "name": "ElbowRight", "type": "sphere", "radius": 0.06, "lat": 4, "lon": 8})
# Lower arms
parts.append({"center": np.array([-0.68, 1.04, 0.0]), "size": np.array([0.10, 0.32, 0.10]), "joint": 7, "mat": 0, "name": "LowerArmLeft", "type": "capsule", "radius": 0.065, "height": 0.32})
parts.append({"center": np.array([0.68, 1.04, 0.0]), "size": np.array([0.10, 0.32, 0.10]), "joint": 11, "mat": 0, "name": "LowerArmRight", "type": "capsule", "radius": 0.065, "height": 0.32})
# Hands - improved with palm + fingers
parts.append({"center": np.array([-0.88, 0.88, 0.0]), "size": np.array([0.10, 0.12, 0.08]), "joint": 8, "mat": 1, "name": "HandLeft", "type": "box"})
parts.append({"center": np.array([0.88, 0.88, 0.0]), "size": np.array([0.10, 0.12, 0.08]), "joint": 12, "mat": 1, "name": "HandRight", "type": "box"})
# Fingers - small boxes for detail
for i, offset in enumerate([-0.03, 0.0, 0.03]):
    parts.append({"center": np.array([-0.88+offset, 0.80, -0.06]), "size": np.array([0.02, 0.06, 0.02]), "joint": 8, "mat": 1, "name": f"FingerL{i}", "type": "box"})
    parts.append({"center": np.array([0.88+offset, 0.80, -0.06]), "size": np.array([0.02, 0.06, 0.02]), "joint": 12, "mat": 1, "name": f"FingerR{i}", "type": "box"})

# --- LEGS - properly shaped trousers ---
# Upper legs - capsule with slight taper, trousers material
parts.append({"center": np.array([-0.135, 0.64, 0.0]), "size": np.array([0.17, 0.44, 0.17]), "joint": 13, "mat": 2, "name": "UpperLegLeft", "type": "capsule", "radius": 0.095, "height": 0.44})
parts.append({"center": np.array([0.135, 0.64, 0.0]), "size": np.array([0.17, 0.44, 0.17]), "joint": 16, "mat": 2, "name": "UpperLegRight", "type": "capsule", "radius": 0.095, "height": 0.44})
# Knee - subtle bulge
parts.append({"center": np.array([-0.135, 0.38, 0.0]), "size": np.array([0.11, 0.11, 0.11]), "joint": 13, "mat": 2, "name": "KneeLeft", "type": "sphere", "radius": 0.09, "lat": 5, "lon": 8})
parts.append({"center": np.array([0.135, 0.38, 0.0]), "size": np.array([0.11, 0.11, 0.11]), "joint": 16, "mat": 2, "name": "KneeRight", "type": "sphere", "radius": 0.09, "lat": 5, "lon": 8})
# Lower legs
parts.append({"center": np.array([-0.135, 0.22, 0.0]), "size": np.array([0.15, 0.36, 0.15]), "joint": 14, "mat": 2, "name": "LowerLegLeft", "type": "capsule", "radius": 0.085, "height": 0.36})
parts.append({"center": np.array([0.135, 0.22, 0.0]), "size": np.array([0.15, 0.36, 0.15]), "joint": 17, "mat": 2, "name": "LowerLegRight", "type": "capsule", "radius": 0.085, "height": 0.36})

# --- SHOES - rounded ---
# Shoe main - rounded box with toe cap
parts.append({"center": np.array([-0.135, 0.07, 0.10]), "size": np.array([0.15, 0.12, 0.30]), "joint": 15, "mat": 3, "name": "ShoeLeft", "type": "box"})
parts.append({"center": np.array([0.135, 0.07, 0.10]), "size": np.array([0.15, 0.12, 0.30]), "joint": 18, "mat": 3, "name": "ShoeRight", "type": "box"})
# Toe cap - rounded front
parts.append({"center": np.array([-0.135, 0.07, -0.06]), "size": np.array([0.14, 0.10, 0.10]), "joint": 15, "mat": 3, "name": "ToeLeft", "type": "sphere", "radius": 0.07, "lat": 4, "lon": 8})
parts.append({"center": np.array([0.135, 0.07, -0.06]), "size": np.array([0.14, 0.10, 0.10]), "joint": 18, "mat": 3, "name": "ToeRight", "type": "sphere", "radius": 0.07, "lat": 4, "lon": 8})
# Sole
parts.append({"center": np.array([-0.135, 0.02, 0.10]), "size": np.array([0.16, 0.04, 0.34]), "joint": 15, "mat": 3, "name": "SoleLeft", "type": "box"})
parts.append({"center": np.array([0.135, 0.02, 0.10]), "size": np.array([0.16, 0.04, 0.34]), "joint": 18, "mat": 3, "name": "SoleRight", "type": "box"})

# Build geometry
all_positions = []
all_normals = []
all_uvs = []
all_joints = []
all_weights = []
all_indices = []
index_offset = 0
primitive_infos = []

for part in parts:
    t = part["type"]
    if t == "capsule":
        pos, norm, uv, idx = create_capsule(part["center"], part["radius"], part["height"], segments=12)
    elif t == "sphere":
        pos, norm, uv, idx = create_sphere(part["center"], part["radius"], lat_segments=part.get("lat",6), lon_segments=part.get("lon",10))
    else:
        pos, norm, uv, idx = create_box(part["center"], part["size"])
    
    n_verts = pos.shape[0]
    joints = np.zeros((n_verts, 4), dtype=np.uint16)
    joints[:,0] = part["joint"]
    weights = np.zeros((n_verts, 4), dtype=np.float32)
    weights[:,0] = 1.0

    all_positions.append(pos)
    all_normals.append(norm)
    all_uvs.append(uv)
    all_joints.append(joints)
    all_weights.append(weights)
    all_indices.append(idx + index_offset)
    primitive_infos.append({
        "vertex_count": n_verts,
        "index_count": idx.shape[0],
        "vertex_offset": sum([p["vertex_count"] for p in primitive_infos]),
        "mat": part["mat"],
        "name": part["name"],
        "joint": part["joint"]
    })
    index_offset += n_verts

positions = np.concatenate(all_positions, axis=0)
normals = np.concatenate(all_normals, axis=0)
uvs = np.concatenate(all_uvs, axis=0)
joints = np.concatenate(all_joints, axis=0)
weights = np.concatenate(all_weights, axis=0)
indices = np.concatenate(all_indices, axis=0)

if positions.shape[0] > 65535:
    indices = indices.astype(np.uint32)
    indices_component = UNSIGNED_INT
else:
    indices = indices.astype(np.uint16)
    indices_component = UNSIGNED_SHORT

print(f"Polished model - Verts: {positions.shape[0]}, Indices: {indices.shape[0]}, Tris: {indices.shape[0]//3}")

# Animations
anim_times = np.array([0.0, 1.0, 2.0], dtype=np.float32)
base_chest_local = local_translations[2]
anim_values = np.array([
    [base_chest_local[0], base_chest_local[1], base_chest_local[2]],
    [base_chest_local[0], base_chest_local[1]+0.012, base_chest_local[2]],
    [base_chest_local[0], base_chest_local[1], base_chest_local[2]],
], dtype=np.float32)

def align_offset(offset):
    return (offset + 3) & ~3

buffer_data = bytearray()
offsets = {}
offsets['positions'] = len(buffer_data)
buffer_data.extend(positions.tobytes())
offsets['normals'] = align_offset(len(buffer_data))
buffer_data.extend(b'\x00' * (offsets['normals'] - len(buffer_data)))
buffer_data.extend(normals.tobytes())
offsets['uvs'] = align_offset(len(buffer_data))
buffer_data.extend(b'\x00' * (offsets['uvs'] - len(buffer_data)))
buffer_data.extend(uvs.tobytes())
offsets['joints'] = align_offset(len(buffer_data))
buffer_data.extend(b'\x00' * (offsets['joints'] - len(buffer_data)))
buffer_data.extend(joints.tobytes())
offsets['weights'] = align_offset(len(buffer_data))
buffer_data.extend(b'\x00' * (offsets['weights'] - len(buffer_data)))
buffer_data.extend(weights.tobytes())
offsets['indices'] = align_offset(len(buffer_data))
buffer_data.extend(b'\x00' * (offsets['indices'] - len(buffer_data)))
buffer_data.extend(indices.tobytes())
offsets['ibm'] = align_offset(len(buffer_data))
buffer_data.extend(b'\x00' * (offsets['ibm'] - len(buffer_data)))
buffer_data.extend(ibm_flat.tobytes())
offsets['anim_times'] = align_offset(len(buffer_data))
buffer_data.extend(b'\x00' * (offsets['anim_times'] - len(buffer_data)))
buffer_data.extend(anim_times.tobytes())
offsets['anim_values'] = align_offset(len(buffer_data))
buffer_data.extend(b'\x00' * (offsets['anim_values'] - len(buffer_data)))
buffer_data.extend(anim_values.tobytes())

gltf = GLTF2()
gltf.asset.version = "2.0"
gltf.asset.generator = "Shadow Protocol - Alex Mercer Polished - stylized protagonist"

gltf.buffers.append(Buffer(byteLength=len(buffer_data)))

bv_positions = BufferView(buffer=0, byteOffset=offsets['positions'], byteLength=len(positions.tobytes()), target=ARRAY_BUFFER)
bv_normals = BufferView(buffer=0, byteOffset=offsets['normals'], byteLength=len(normals.tobytes()), target=ARRAY_BUFFER)
bv_uvs = BufferView(buffer=0, byteOffset=offsets['uvs'], byteLength=len(uvs.tobytes()), target=ARRAY_BUFFER)
bv_joints = BufferView(buffer=0, byteOffset=offsets['joints'], byteLength=len(joints.tobytes()), target=ARRAY_BUFFER)
bv_weights = BufferView(buffer=0, byteOffset=offsets['weights'], byteLength=len(weights.tobytes()), target=ARRAY_BUFFER)
bv_indices = BufferView(buffer=0, byteOffset=offsets['indices'], byteLength=len(indices.tobytes()), target=ELEMENT_ARRAY_BUFFER)
bv_ibm = BufferView(buffer=0, byteOffset=offsets['ibm'], byteLength=len(ibm_flat.tobytes()))
bv_anim_times = BufferView(buffer=0, byteOffset=offsets['anim_times'], byteLength=len(anim_times.tobytes()))
bv_anim_values = BufferView(buffer=0, byteOffset=offsets['anim_values'], byteLength=len(anim_values.tobytes()))

gltf.bufferViews.extend([bv_positions, bv_normals, bv_uvs, bv_joints, bv_weights, bv_indices, bv_ibm, bv_anim_times, bv_anim_values])

acc_pos = Accessor(bufferView=0, byteOffset=0, componentType=FLOAT, count=positions.shape[0], type=VEC3, max=positions.max(axis=0).tolist(), min=positions.min(axis=0).tolist())
acc_norm = Accessor(bufferView=1, byteOffset=0, componentType=FLOAT, count=normals.shape[0], type=VEC3)
acc_uv = Accessor(bufferView=2, byteOffset=0, componentType=FLOAT, count=uvs.shape[0], type=VEC2)
acc_joints = Accessor(bufferView=3, byteOffset=0, componentType=UNSIGNED_SHORT, count=joints.shape[0], type=VEC4)
acc_weights = Accessor(bufferView=4, byteOffset=0, componentType=FLOAT, count=weights.shape[0], type=VEC4)
acc_indices = Accessor(bufferView=5, byteOffset=0, componentType=indices_component, count=indices.shape[0], type=SCALAR)
acc_ibm = Accessor(bufferView=6, byteOffset=0, componentType=FLOAT, count=num_joints, type=MAT4)
acc_anim_times = Accessor(bufferView=7, byteOffset=0, componentType=FLOAT, count=anim_times.shape[0], type=SCALAR, min=[float(anim_times.min())], max=[float(anim_times.max())])
acc_anim_values = Accessor(bufferView=8, byteOffset=0, componentType=FLOAT, count=anim_values.shape[0], type=VEC3)

gltf.accessors.extend([acc_pos, acc_norm, acc_uv, acc_joints, acc_weights, acc_indices, acc_ibm, acc_anim_times, acc_anim_values])

# Materials - polished dark urban with subtle detail
mat_jacket = Material(name="Jacket_Dark", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.10, 0.11, 0.13, 1.0], metallicFactor=0.18, roughnessFactor=0.68))
mat_skin = Material(name="Skin", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.84, 0.70, 0.60, 1.0], metallicFactor=0.0, roughnessFactor=0.78))
mat_trousers = Material(name="Trousers_Dark", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.14, 0.15, 0.17, 1.0], metallicFactor=0.06, roughnessFactor=0.80))
mat_shoes = Material(name="Shoes", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.07, 0.07, 0.08, 1.0], metallicFactor=0.15, roughnessFactor=0.65))
mat_accent = Material(name="Accent_Crimson", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.647, 0.122, 0.169, 1.0], metallicFactor=0.12, roughnessFactor=0.52))
mat_hair = Material(name="Hair_Dark", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.08, 0.07, 0.07, 1.0], metallicFactor=0.06, roughnessFactor=0.82))

gltf.materials.extend([mat_jacket, mat_skin, mat_trousers, mat_shoes, mat_accent, mat_hair])

mesh = Mesh(name="AlexMercer_Polished")
for info in primitive_infos:
    v_off = info["vertex_offset"]
    v_count = info["vertex_count"]
    prev_idx_count = sum([p["index_count"] for p in primitive_infos if p["vertex_offset"] < v_off])
    idx_byte_offset = prev_idx_count * (2 if indices_component==UNSIGNED_SHORT else 4)
    acc_p = Accessor(bufferView=0, byteOffset=v_off*12, componentType=FLOAT, count=v_count, type=VEC3)
    acc_n = Accessor(bufferView=1, byteOffset=v_off*12, componentType=FLOAT, count=v_count, type=VEC3)
    acc_t = Accessor(bufferView=2, byteOffset=v_off*8, componentType=FLOAT, count=v_count, type=VEC2)
    acc_j = Accessor(bufferView=3, byteOffset=v_off*8, componentType=UNSIGNED_SHORT, count=v_count, type=VEC4)
    acc_w = Accessor(bufferView=4, byteOffset=v_off*16, componentType=FLOAT, count=v_count, type=VEC4)
    acc_i = Accessor(bufferView=5, byteOffset=idx_byte_offset, componentType=indices_component, count=info["index_count"], type=SCALAR)
    base_idx = len(gltf.accessors)
    gltf.accessors.extend([acc_p, acc_n, acc_t, acc_j, acc_w, acc_i])
    prim = Primitive(attributes={"POSITION": base_idx, "NORMAL": base_idx+1, "TEXCOORD_0": base_idx+2, "JOINTS_0": base_idx+3, "WEIGHTS_0": base_idx+4}, indices=base_idx+5, material=info["mat"])
    mesh.primitives.append(prim)

gltf.meshes.append(mesh)

bone_nodes = []
for i, (name, parent, world_pos) in enumerate(bones_def):
    local = local_translations[i]
    node = Node(name=name, translation=local.tolist())
    bone_nodes.append(node)

for i, (name, parent, world_pos) in enumerate(bones_def):
    if parent != -1:
        if bone_nodes[parent].children is None:
            bone_nodes[parent].children = []
        bone_nodes[parent].children.append(i)

mesh_node = Node(name="AlexMercer_Mesh", mesh=0, skin=0)
root_node = Node(name="Armature_Root", children=[0, len(bone_nodes)])

gltf.nodes.extend(bone_nodes)
mesh_node_idx = len(gltf.nodes)
gltf.nodes.append(mesh_node)
root_node_idx = len(gltf.nodes)
gltf.nodes.append(root_node)

skin = Skin(inverseBindMatrices=6, joints=list(range(num_joints)), skeleton=0)
gltf.skins.append(skin)

anim_sampler = AnimationSampler(input=7, output=8, interpolation="LINEAR")
anim_channel = AnimationChannel(sampler=0, target={"node": 2, "path": "translation"})
animation = Animation(name="idle", samplers=[anim_sampler], channels=[anim_channel])
gltf.animations.append(animation)

scene = Scene(nodes=[root_node_idx])
gltf.scenes.append(scene)
gltf.scene = 0

gltf.set_binary_blob(bytes(buffer_data))
gltf.save(out_path)
print(f"Saved polished GLB to {out_path}, size {os.path.getsize(out_path)} bytes, verts {positions.shape[0]}, tris {indices.shape[0]//3}")

import shutil
shutil.copy(out_path, "/home/user/shadow-protocol/assets/models/alex_mercer.glb")
shutil.copy(out_path, "/home/user/shadow-protocol/assets/character-assets/alex_mercer.glb")
print("Copied to models and character-assets")
