#!/usr/bin/env python3
"""
Generate improved alex_mercer.glb - smoother rounded geometry, better proportions
Preserves skeleton, improves visual quality, Android optimized, Godot 4 compatible
"""

import numpy as np
from pygltflib import (
    GLTF2, Scene, Node, Mesh, Primitive, Material, PbrMetallicRoughness,
    Buffer, BufferView, Accessor, Skin, Animation, AnimationSampler, AnimationChannel,
    ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER,
    FLOAT, UNSIGNED_SHORT, UNSIGNED_INT,
    SCALAR, VEC2, VEC3, VEC4, MAT4
)
import os, math

out_dir = "/home/user/shadow-protocol/assets/character"
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "alex_mercer.glb")

# Skeleton - same as before to preserve compatibility
bones_def = [
    ("Hips", -1, np.array([0.0, 0.92, 0.0])),
    ("Spine", 0, np.array([0.0, 1.05, 0.0])),
    ("Chest", 1, np.array([0.0, 1.28, 0.0])),
    ("Neck", 2, np.array([0.0, 1.52, 0.0])),
    ("Head", 3, np.array([0.0, 1.70, 0.0])),
    ("LeftShoulder", 2, np.array([-0.19, 1.45, 0.0])),
    ("LeftUpperArm", 5, np.array([-0.36, 1.45, 0.0])),
    ("LeftLowerArm", 6, np.array([-0.64, 1.45, 0.0])),
    ("LeftHand", 7, np.array([-0.87, 1.45, 0.0])),
    ("RightShoulder", 2, np.array([0.19, 1.45, 0.0])),
    ("RightUpperArm", 9, np.array([0.36, 1.45, 0.0])),
    ("RightLowerArm", 10, np.array([0.64, 1.45, 0.0])),
    ("RightHand", 11, np.array([0.87, 1.45, 0.0])),
    ("LeftUpperLeg", 0, np.array([-0.13, 0.58, 0.0])),
    ("LeftLowerLeg", 13, np.array([-0.13, 0.18, 0.0])),
    ("LeftFoot", 14, np.array([-0.13, 0.05, 0.08])),
    ("RightUpperLeg", 0, np.array([0.13, 0.58, 0.0])),
    ("RightLowerLeg", 16, np.array([0.13, 0.18, 0.0])),
    ("RightFoot", 17, np.array([0.13, 0.05, 0.08])),
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

# Geometry helpers
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

def create_capsule(center, radius, height, segments=8, axis='y'):
    """
    Create capsule aligned along Y axis, centered at center
    height = total height (including caps)
    segments = radial segments
    """
    cx, cy, cz = center
    cyl_height = max(0, height - 2*radius)
    half_cyl = cyl_height / 2

    positions = []
    normals = []
    uvs = []
    indices = []

    # Cylinder side
    for i in range(segments):
        angle = (i / segments) * 2 * math.pi
        x = math.cos(angle) * radius
        z = math.sin(angle) * radius
        # bottom ring
        positions.append([cx + x, cy - half_cyl, cz + z])
        normals.append([x/radius, 0, z/radius])
        uvs.append([i/segments, 0])
        # top ring
        positions.append([cx + x, cy + half_cyl, cz + z])
        normals.append([x/radius, 0, z/radius])
        uvs.append([i/segments, 1])

    # Side indices
    for i in range(segments):
        i0 = i*2
        i1 = i*2+1
        j0 = ((i+1)%segments)*2
        j1 = ((i+1)%segments)*2+1
        # quad
        indices.extend([i0, j0, j1, i0, j1, i1])

    base_idx = len(positions)
    # Top cap - hemisphere approximation with triangle fan from top center
    top_center = [cx, cy + half_cyl + radius*0.5, cz]
    # For simplicity, use a single point for top cap center with averaged normal up
    # Create ring for top cap edge (same as top ring but with up normal blended)
    top_ring_start = base_idx
    for i in range(segments):
        angle = (i / segments) * 2 * math.pi
        x = math.cos(angle) * radius * 0.7
        z = math.sin(angle) * radius * 0.7
        positions.append([cx + x, cy + half_cyl + radius*0.5, cz + z])
        # normal up + radial
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

    # Bottom cap
    bottom_ring_start = len(positions)
    bottom_center = [cx, cy - half_cyl - radius*0.5, cz]
    for i in range(segments):
        angle = (i / segments) * 2 * math.pi
        x = math.cos(angle) * radius * 0.7
        z = math.sin(angle) * radius * 0.7
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

def create_rounded_box(center, size, bevel=0.02):
    # For now, just use box with slightly smaller size for bevel effect
    # Could add bevel later, but keep simple
    return create_box(center, size)

# Define improved parts with better proportions and rounded geometry
parts = []

# Torso - improved jacket with better silhouette
# Chest upper - slightly broader
parts.append({"center": np.array([0.0, 1.32, 0.0]), "size": np.array([0.54, 0.32, 0.30]), "joint": 2, "mat": 0, "name": "ChestUpper", "type": "box"})
# Chest lower / abdomen - tapered
parts.append({"center": np.array([0.0, 1.08, 0.0]), "size": np.array([0.50, 0.30, 0.28]), "joint": 2, "mat": 0, "name": "ChestLower", "type": "box"})
# Hips / jacket bottom
parts.append({"center": np.array([0.0, 0.88, 0.0]), "size": np.array([0.52, 0.18, 0.30]), "joint": 0, "mat": 0, "name": "HipsJacket", "type": "box"})
# Accent crimson - front zipper / stripe, now facing -Z (front is -Z in Godot)
parts.append({"center": np.array([0.0, 1.18, -0.16]), "size": np.array([0.08, 0.55, 0.02]), "joint": 2, "mat": 4, "name": "AccentZipper", "type": "box"})
# Collar - around neck, improved
parts.append({"center": np.array([0.0, 1.50, 0.0]), "size": np.array([0.38, 0.12, 0.32]), "joint": 3, "mat": 0, "name": "Collar", "type": "box"})

# Head - improved with face and hair
# Head base - more rounded proportions
parts.append({"center": np.array([0.0, 1.72, 0.0]), "size": np.array([0.28, 0.32, 0.30]), "joint": 4, "mat": 1, "name": "Head", "type": "box"})
# Face - slight forward protrusion for nose area, facing -Z
parts.append({"center": np.array([0.0, 1.70, -0.18]), "size": np.array([0.18, 0.18, 0.06]), "joint": 4, "mat": 1, "name": "Face", "type": "box"})
# Hair - dark, on top of head
parts.append({"center": np.array([0.0, 1.90, 0.0]), "size": np.array([0.30, 0.10, 0.32]), "joint": 4, "mat": 5, "name": "HairTop", "type": "box"})
parts.append({"center": np.array([0.0, 1.82, 0.12]), "size": np.array([0.30, 0.16, 0.08]), "joint": 4, "mat": 5, "name": "HairBack", "type": "box"})

# Arms - rounded capsules, better proportions
# Left upper arm - capsule
parts.append({"center": np.array([-0.36, 1.32, 0.0]), "size": np.array([0.11, 0.32, 0.11]), "joint": 6, "mat": 0, "name": "LeftUpperArm", "type": "capsule", "radius": 0.07, "height": 0.32})
# Right upper arm
parts.append({"center": np.array([0.36, 1.32, 0.0]), "size": np.array([0.11, 0.32, 0.11]), "joint": 10, "mat": 0, "name": "RightUpperArm", "type": "capsule", "radius": 0.07, "height": 0.32})
# Left lower arm
parts.append({"center": np.array([-0.64, 1.18, 0.0]), "size": np.array([0.09, 0.32, 0.09]), "joint": 7, "mat": 0, "name": "LeftLowerArm", "type": "capsule", "radius": 0.06, "height": 0.32})
# Right lower arm
parts.append({"center": np.array([0.64, 1.18, 0.0]), "size": np.array([0.09, 0.32, 0.09]), "joint": 11, "mat": 0, "name": "RightLowerArm", "type": "capsule", "radius": 0.06, "height": 0.32})
# Hands - skin, improved
parts.append({"center": np.array([-0.86, 1.02, 0.0]), "size": np.array([0.10, 0.12, 0.10]), "joint": 8, "mat": 1, "name": "LeftHand", "type": "box"})
parts.append({"center": np.array([0.86, 1.02, 0.0]), "size": np.array([0.10, 0.12, 0.10]), "joint": 12, "mat": 1, "name": "RightHand", "type": "box"})

# Legs - rounded capsules, better proportions, feet aligned to ground
# Left upper leg
parts.append({"center": np.array([-0.13, 0.62, 0.0]), "size": np.array([0.16, 0.40, 0.16]), "joint": 13, "mat": 2, "name": "LeftUpperLeg", "type": "capsule", "radius": 0.09, "height": 0.42})
# Right upper leg
parts.append({"center": np.array([0.13, 0.62, 0.0]), "size": np.array([0.16, 0.40, 0.16]), "joint": 16, "mat": 2, "name": "RightUpperLeg", "type": "capsule", "radius": 0.09, "height": 0.42})
# Left lower leg
parts.append({"center": np.array([-0.13, 0.24, 0.0]), "size": np.array([0.14, 0.38, 0.14]), "joint": 14, "mat": 2, "name": "LeftLowerLeg", "type": "capsule", "radius": 0.08, "height": 0.38})
# Right lower leg
parts.append({"center": np.array([0.13, 0.24, 0.0]), "size": np.array([0.14, 0.38, 0.14]), "joint": 17, "mat": 2, "name": "RightLowerLeg", "type": "capsule", "radius": 0.08, "height": 0.38})

# Shoes - improved silhouette, feet aligned to ground (bottom at 0)
# Shoe center y=0.06, height 0.12, bottom at 0
parts.append({"center": np.array([-0.13, 0.06, 0.08]), "size": np.array([0.16, 0.12, 0.32]), "joint": 15, "mat": 3, "name": "LeftShoe", "type": "box"})
parts.append({"center": np.array([0.13, 0.06, 0.08]), "size": np.array([0.16, 0.12, 0.32]), "joint": 18, "mat": 3, "name": "RightShoe", "type": "box"})
# Shoe soles - slightly larger, darker
parts.append({"center": np.array([-0.13, 0.02, 0.08]), "size": np.array([0.17, 0.04, 0.34]), "joint": 15, "mat": 3, "name": "LeftSole", "type": "box"})
parts.append({"center": np.array([0.13, 0.02, 0.08]), "size": np.array([0.17, 0.04, 0.34]), "joint": 18, "mat": 3, "name": "RightSole", "type": "box"})

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
    if part["type"] == "capsule":
        pos, norm, uv, idx = create_capsule(part["center"], part["radius"], part["height"], segments=10)
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

print(f"Improved model - Total vertices: {positions.shape[0]}, indices: {indices.shape[0]}, tris: {indices.shape[0]//3}")

# Animation data
anim_times = np.array([0.0, 1.0, 2.0], dtype=np.float32)
base_chest_local = local_translations[2]
anim_values = np.array([
    [base_chest_local[0], base_chest_local[1], base_chest_local[2]],
    [base_chest_local[0], base_chest_local[1]+0.015, base_chest_local[2]],
    [base_chest_local[0], base_chest_local[1], base_chest_local[2]],
], dtype=np.float32)

# Second animation - walk: legs swing
walk_times = np.array([0.0, 0.3, 0.6], dtype=np.float32)
# For simplicity, animate left upper leg rotation? But we can only animate translation/rotation/scale - we'll add translation for now
# Actually we need rotation animation - more complex, keep simple idle + walk as translation
# Walk will be procedural in Godot, so just idle is enough

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
gltf.asset.generator = "Shadow Protocol - Alex Mercer Improved v2 - rounded, better proportions"

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

# Materials - improved dark urban
mat_jacket = Material(name="Jacket_Dark", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.09, 0.10, 0.12, 1.0], metallicFactor=0.15, roughnessFactor=0.72))
mat_skin = Material(name="Skin", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.82, 0.68, 0.58, 1.0], metallicFactor=0.0, roughnessFactor=0.80))
mat_trousers = Material(name="Trousers_Dark", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.13, 0.14, 0.16, 1.0], metallicFactor=0.05, roughnessFactor=0.82))
mat_shoes = Material(name="Shoes", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.06, 0.06, 0.07, 1.0], metallicFactor=0.12, roughnessFactor=0.68))
mat_accent = Material(name="Accent_Crimson", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.647, 0.122, 0.169, 1.0], metallicFactor=0.1, roughnessFactor=0.55))
mat_hair = Material(name="Hair_Dark", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.07, 0.06, 0.06, 1.0], metallicFactor=0.05, roughnessFactor=0.85))

gltf.materials.extend([mat_jacket, mat_skin, mat_trousers, mat_shoes, mat_accent, mat_hair])

mesh = Mesh(name="AlexMercer_Body_Improved")
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
print(f"Saved improved GLB to {out_path}, size {os.path.getsize(out_path)} bytes, verts {positions.shape[0]}, tris {indices.shape[0]//3}")

import shutil
shutil.copy(out_path, "/home/user/shadow-protocol/assets/models/alex_mercer.glb")
shutil.copy(out_path, "/home/user/shadow-protocol/assets/character-assets/alex_mercer.glb")
print("Copied to models and character-assets")
