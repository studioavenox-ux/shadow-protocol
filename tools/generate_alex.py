#!/usr/bin/env python3
"""
Generate alex_mercer.glb - game-ready humanoid with dark urban outfit
For SHADOW PROTOCOL - Godot 4 + Android optimized
No Blender required - uses pygltflib + numpy
"""

import numpy as np
from pygltflib import (
    GLTF2, Scene, Node, Mesh, Primitive, Material, PbrMetallicRoughness,
    Buffer, BufferView, Accessor, Skin,
    ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER,
    FLOAT, UNSIGNED_SHORT, UNSIGNED_INT,
    SCALAR, VEC2, VEC3, VEC4, MAT4
)
import struct
import os

# Ensure output dir
out_dir = "/home/user/shadow-protocol/assets/character"
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "alex_mercer.glb")

# Define bones: name, parent index, world position
bones_def = [
    ("Hips", -1, np.array([0.0, 0.9, 0.0])),
    ("Spine", 0, np.array([0.0, 1.05, 0.0])),
    ("Chest", 1, np.array([0.0, 1.25, 0.0])),
    ("Neck", 2, np.array([0.0, 1.50, 0.0])),
    ("Head", 3, np.array([0.0, 1.68, 0.0])),
    ("LeftShoulder", 2, np.array([-0.18, 1.42, 0.0])),
    ("LeftUpperArm", 5, np.array([-0.35, 1.42, 0.0])),
    ("LeftLowerArm", 6, np.array([-0.62, 1.42, 0.0])),
    ("LeftHand", 7, np.array([-0.85, 1.42, 0.0])),
    ("RightShoulder", 2, np.array([0.18, 1.42, 0.0])),
    ("RightUpperArm", 9, np.array([0.35, 1.42, 0.0])),
    ("RightLowerArm", 10, np.array([0.62, 1.42, 0.0])),
    ("RightHand", 11, np.array([0.85, 1.42, 0.0])),
    ("LeftUpperLeg", 0, np.array([-0.12, 0.55, 0.0])),
    ("LeftLowerLeg", 13, np.array([-0.12, 0.15, 0.0])),
    ("LeftFoot", 14, np.array([-0.12, 0.02, 0.10])),
    ("RightUpperLeg", 0, np.array([0.12, 0.55, 0.0])),
    ("RightLowerLeg", 16, np.array([0.12, 0.15, 0.0])),
    ("RightFoot", 17, np.array([0.12, 0.02, 0.10])),
]

num_joints = len(bones_def)

# Compute local translations
local_translations = []
for i, (name, parent, world_pos) in enumerate(bones_def):
    if parent == -1:
        local = world_pos
    else:
        parent_world = bones_def[parent][2]
        local = world_pos - parent_world
    local_translations.append(local)

# Inverse bind matrices: inverse of world matrix (translation only)
# World matrix = T(world_pos), inverse = T(-world_pos)
ibm = []
for i, (name, parent, world_pos) in enumerate(bones_def):
    mat = np.eye(4, dtype=np.float32)
    mat[0,3] = -world_pos[0]
    mat[1,3] = -world_pos[1]
    mat[2,3] = -world_pos[2]
    # glTF expects column-major, but pygltflib will handle? We store as column-major array
    # Actually accessor stores matrices in column-major, but we provide as flat list in column-major order
    # Our mat is row-major, need to transpose for column-major storage? pygltflib expects row-major? Let's store column-major
    # We'll transpose before flattening
    ibm.append(mat.T)  # Transpose to column-major for glTF

ibm_array = np.stack(ibm).astype(np.float32)  # shape (num_joints, 4,4) but already transposed
# Flatten to (num_joints *16)
ibm_flat = ibm_array.reshape(-1)

# Define body parts: center, size, joint index, material index, name
# Materials: 0 jacket, 1 skin, 2 trousers, 3 shoe, 4 accent
parts = [
    # torso
    {"center": np.array([0.0, 1.15, 0.0]), "size": np.array([0.52, 0.70, 0.30]), "joint": 2, "mat": 0, "name": "Torso"},
    {"center": np.array([0.0, 1.15, 0.16]), "size": np.array([0.35, 0.12, 0.05]), "joint": 2, "mat": 4, "name": "Accent"},
    # head
    {"center": np.array([0.0, 1.68, 0.0]), "size": np.array([0.30, 0.36, 0.32]), "joint": 4, "mat": 1, "name": "Head"},
    # upper arms
    {"center": np.array([-0.38, 1.42, 0.0]), "size": np.array([0.32, 0.12, 0.12]), "joint": 6, "mat": 0, "name": "LeftUpperArm"},
    {"center": np.array([0.38, 1.42, 0.0]), "size": np.array([0.32, 0.12, 0.12]), "joint": 10, "mat": 0, "name": "RightUpperArm"},
    # lower arms
    {"center": np.array([-0.68, 1.42, 0.0]), "size": np.array([0.28, 0.10, 0.10]), "joint": 7, "mat": 0, "name": "LeftLowerArm"},
    {"center": np.array([0.68, 1.42, 0.0]), "size": np.array([0.28, 0.10, 0.10]), "joint": 11, "mat": 0, "name": "RightLowerArm"},
    # hands - skin
    {"center": np.array([-0.86, 1.42, 0.0]), "size": np.array([0.12, 0.10, 0.10]), "joint": 8, "mat": 1, "name": "LeftHand"},
    {"center": np.array([0.86, 1.42, 0.0]), "size": np.array([0.12, 0.10, 0.10]), "joint": 12, "mat": 1, "name": "RightHand"},
    # upper legs
    {"center": np.array([-0.12, 0.55, 0.0]), "size": np.array([0.16, 0.45, 0.18]), "joint": 13, "mat": 2, "name": "LeftUpperLeg"},
    {"center": np.array([0.12, 0.55, 0.0]), "size": np.array([0.16, 0.45, 0.18]), "joint": 16, "mat": 2, "name": "RightUpperLeg"},
    # lower legs
    {"center": np.array([-0.12, 0.18, 0.0]), "size": np.array([0.14, 0.40, 0.15]), "joint": 14, "mat": 2, "name": "LeftLowerLeg"},
    {"center": np.array([0.12, 0.18, 0.0]), "size": np.array([0.14, 0.40, 0.15]), "joint": 17, "mat": 2, "name": "RightLowerLeg"},
    # shoes
    {"center": np.array([-0.12, 0.04, 0.10]), "size": np.array([0.18, 0.12, 0.34]), "joint": 15, "mat": 3, "name": "LeftFoot"},
    {"center": np.array([0.12, 0.04, 0.10]), "size": np.array([0.18, 0.12, 0.34]), "joint": 18, "mat": 3, "name": "RightFoot"},
]

def create_box(center, size):
    """Create box with 24 vertices (4 per face) for proper normals and UVs"""
    sx, sy, sz = size[0]/2, size[1]/2, size[2]/2
    cx, cy, cz = center
    # 6 faces
    # Each face: 4 vertices, normal, uv
    # Order: +X, -X, +Y, -Y, +Z, -Z
    positions = []
    normals = []
    uvs = []
    # +X
    positions.extend([
        [cx+sx, cy-sy, cz-sz],
        [cx+sx, cy+sy, cz-sz],
        [cx+sx, cy+sy, cz+sz],
        [cx+sx, cy-sy, cz+sz],
    ])
    normals.extend([[1,0,0]]*4)
    uvs.extend([[0,0],[0,1],[1,1],[1,0]])
    # -X
    positions.extend([
        [cx-sx, cy-sy, cz+sz],
        [cx-sx, cy+sy, cz+sz],
        [cx-sx, cy+sy, cz-sz],
        [cx-sx, cy-sy, cz-sz],
    ])
    normals.extend([[-1,0,0]]*4)
    uvs.extend([[0,0],[0,1],[1,1],[1,0]])
    # +Y
    positions.extend([
        [cx-sx, cy+sy, cz-sz],
        [cx-sx, cy+sy, cz+sz],
        [cx+sx, cy+sy, cz+sz],
        [cx+sx, cy+sy, cz-sz],
    ])
    normals.extend([[0,1,0]]*4)
    uvs.extend([[0,0],[0,1],[1,1],[1,0]])
    # -Y
    positions.extend([
        [cx-sx, cy-sy, cz+sz],
        [cx-sx, cy-sy, cz-sz],
        [cx+sx, cy-sy, cz-sz],
        [cx+sx, cy-sy, cz+sz],
    ])
    normals.extend([[0,-1,0]]*4)
    uvs.extend([[0,0],[0,1],[1,1],[1,0]])
    # +Z
    positions.extend([
        [cx-sx, cy-sy, cz+sz],
        [cx+sx, cy-sy, cz+sz],
        [cx+sx, cy+sy, cz+sz],
        [cx-sx, cy+sy, cz+sz],
    ])
    normals.extend([[0,0,1]]*4)
    uvs.extend([[0,0],[1,0],[1,1],[0,1]])
    # -Z
    positions.extend([
        [cx+sx, cy-sy, cz-sz],
        [cx-sx, cy-sy, cz-sz],
        [cx-sx, cy+sy, cz-sz],
        [cx+sx, cy+sy, cz-sz],
    ])
    normals.extend([[0,0,-1]]*4)
    uvs.extend([[0,0],[1,0],[1,1],[0,1]])

    # Indices: 6 faces * 2 triangles *3 =36
    indices = []
    for i in range(6):
        base = i*4
        indices.extend([base, base+1, base+2, base, base+2, base+3])

    return np.array(positions, dtype=np.float32), np.array(normals, dtype=np.float32), np.array(uvs, dtype=np.float32), np.array(indices, dtype=np.uint16)

# Collect all geometry
all_positions = []
all_normals = []
all_uvs = []
all_joints = []  # VEC4 uint16
all_weights = [] # VEC4 float
all_indices = []
index_offset = 0

# For per-primitive tracking
primitive_infos = []

for part in parts:
    pos, norm, uv, idx = create_box(part["center"], part["size"])
    n_verts = pos.shape[0]
    # Joints: all same joint
    joints = np.zeros((n_verts, 4), dtype=np.uint16)
    joints[:,0] = part["joint"]
    weights = np.zeros((n_verts, 4), dtype=np.float32)
    weights[:,0] = 1.0

    # Store
    all_positions.append(pos)
    all_normals.append(norm)
    all_uvs.append(uv)
    all_joints.append(joints)
    all_weights.append(weights)
    # Indices with offset
    all_indices.append(idx + index_offset)
    primitive_infos.append({
        "vertex_count": n_verts,
        "index_count": idx.shape[0],
        "index_offset": index_offset,
        "vertex_offset": sum([p["vertex_count"] for p in primitive_infos]),
        "mat": part["mat"],
        "name": part["name"],
        "joint": part["joint"]
    })
    index_offset += n_verts

# Concatenate
positions = np.concatenate(all_positions, axis=0)
normals = np.concatenate(all_normals, axis=0)
uvs = np.concatenate(all_uvs, axis=0)
joints = np.concatenate(all_joints, axis=0)
weights = np.concatenate(all_weights, axis=0)
indices = np.concatenate(all_indices, axis=0)

print(f"Total vertices: {positions.shape[0]}, indices: {indices.shape[0]}, tris: {indices.shape[0]//3}")

# Convert indices to uint16 or uint32 depending on count
if positions.shape[0] > 65535:
    indices = indices.astype(np.uint32)
    indices_component = UNSIGNED_INT
else:
    indices = indices.astype(np.uint16)
    indices_component = UNSIGNED_SHORT

# Build binary buffer
# Layout: positions, normals, uvs, joints, weights, indices, ibm
# Need to align to 4 bytes

def align_offset(offset):
    return (offset + 3) & ~3

buffer_data = bytearray()
offsets = {}

# Positions
offsets['positions'] = len(buffer_data)
buffer_data.extend(positions.tobytes())
# Normals
offsets['normals'] = align_offset(len(buffer_data))
buffer_data.extend(b'\x00' * (offsets['normals'] - len(buffer_data)))
buffer_data.extend(normals.tobytes())
# UVs
offsets['uvs'] = align_offset(len(buffer_data))
buffer_data.extend(b'\x00' * (offsets['uvs'] - len(buffer_data)))
buffer_data.extend(uvs.tobytes())
# Joints
offsets['joints'] = align_offset(len(buffer_data))
buffer_data.extend(b'\x00' * (offsets['joints'] - len(buffer_data)))
buffer_data.extend(joints.tobytes())
# Weights
offsets['weights'] = align_offset(len(buffer_data))
buffer_data.extend(b'\x00' * (offsets['weights'] - len(buffer_data)))
buffer_data.extend(weights.tobytes())
# Indices
offsets['indices'] = align_offset(len(buffer_data))
buffer_data.extend(b'\x00' * (offsets['indices'] - len(buffer_data)))
buffer_data.extend(indices.tobytes())
# IBM
offsets['ibm'] = align_offset(len(buffer_data))
buffer_data.extend(b'\x00' * (offsets['ibm'] - len(buffer_data)))
buffer_data.extend(ibm_flat.tobytes())

print(f"Buffer size: {len(buffer_data)} bytes")
for k,v in offsets.items():
    print(f"  {k}: offset {v}")

# Create glTF
gltf = GLTF2()
gltf.asset.version = "2.0"
gltf.asset.generator = "Shadow Protocol - Alex Mercer Generator"

# Buffer
gltf.buffers.append(Buffer(byteLength=len(buffer_data)))

# BufferViews
# 0: positions
bv_positions = BufferView(buffer=0, byteOffset=offsets['positions'], byteLength=len(positions.tobytes()), target=ARRAY_BUFFER)
# 1: normals
bv_normals = BufferView(buffer=0, byteOffset=offsets['normals'], byteLength=len(normals.tobytes()), target=ARRAY_BUFFER)
# 2: uvs
bv_uvs = BufferView(buffer=0, byteOffset=offsets['uvs'], byteLength=len(uvs.tobytes()), target=ARRAY_BUFFER)
# 3: joints
bv_joints = BufferView(buffer=0, byteOffset=offsets['joints'], byteLength=len(joints.tobytes()), target=ARRAY_BUFFER)
# 4: weights
bv_weights = BufferView(buffer=0, byteOffset=offsets['weights'], byteLength=len(weights.tobytes()), target=ARRAY_BUFFER)
# 5: indices
bv_indices = BufferView(buffer=0, byteOffset=offsets['indices'], byteLength=len(indices.tobytes()), target=ELEMENT_ARRAY_BUFFER)
# 6: ibm
bv_ibm = BufferView(buffer=0, byteOffset=offsets['ibm'], byteLength=len(ibm_flat.tobytes()))

gltf.bufferViews.extend([bv_positions, bv_normals, bv_uvs, bv_joints, bv_weights, bv_indices, bv_ibm])

# Accessors
# Positions
acc_pos = Accessor(bufferView=0, byteOffset=0, componentType=FLOAT, count=positions.shape[0], type=VEC3, max=positions.max(axis=0).tolist(), min=positions.min(axis=0).tolist())
# Normals
acc_norm = Accessor(bufferView=1, byteOffset=0, componentType=FLOAT, count=normals.shape[0], type=VEC3)
# UVs
acc_uv = Accessor(bufferView=2, byteOffset=0, componentType=FLOAT, count=uvs.shape[0], type=VEC2)
# Joints
acc_joints = Accessor(bufferView=3, byteOffset=0, componentType=UNSIGNED_SHORT, count=joints.shape[0], type=VEC4)
# Weights
acc_weights = Accessor(bufferView=4, byteOffset=0, componentType=FLOAT, count=weights.shape[0], type=VEC4)
# Indices
acc_indices = Accessor(bufferView=5, byteOffset=0, componentType=indices_component, count=indices.shape[0], type=SCALAR)
# IBM
acc_ibm = Accessor(bufferView=6, byteOffset=0, componentType=FLOAT, count=num_joints, type=MAT4)

gltf.accessors.extend([acc_pos, acc_norm, acc_uv, acc_joints, acc_weights, acc_indices, acc_ibm])

# Materials - PBR dark urban
# 0: Jacket dark
mat_jacket = Material(
    name="Jacket_Dark",
    pbrMetallicRoughness=PbrMetallicRoughness(
        baseColorFactor=[0.08, 0.09, 0.105, 1.0],
        metallicFactor=0.15,
        roughnessFactor=0.75
    ),
    doubleSided=False
)
# 1: Skin
mat_skin = Material(
    name="Skin",
    pbrMetallicRoughness=PbrMetallicRoughness(
        baseColorFactor=[0.82, 0.68, 0.58, 1.0],
        metallicFactor=0.0,
        roughnessFactor=0.85
    )
)
# 2: Trousers
mat_trousers = Material(
    name="Trousers_Dark",
    pbrMetallicRoughness=PbrMetallicRoughness(
        baseColorFactor=[0.12, 0.13, 0.15, 1.0],
        metallicFactor=0.05,
        roughnessFactor=0.85
    )
)
# 3: Shoes
mat_shoes = Material(
    name="Shoes",
    pbrMetallicRoughness=PbrMetallicRoughness(
        baseColorFactor=[0.05, 0.05, 0.06, 1.0],
        metallicFactor=0.1,
        roughnessFactor=0.7
    )
)
# 4: Accent crimson
mat_accent = Material(
    name="Accent_Crimson",
    pbrMetallicRoughness=PbrMetallicRoughness(
        baseColorFactor=[0.647, 0.122, 0.169, 1.0],
        metallicFactor=0.1,
        roughnessFactor=0.6
    )
)

gltf.materials.extend([mat_jacket, mat_skin, mat_trousers, mat_shoes, mat_accent])

# Mesh - one mesh with multiple primitives grouped by material
# We have 15 parts, but we need to split by material and keep joints/weights
# Simpler: create 5 primitives, each covering all vertices of that material, with own indices
# Let's group

# Build groups by material
from collections import defaultdict
groups = defaultdict(list)
for info in primitive_infos:
    groups[info["mat"]].append(info)

# For each material group, create combined indices and accessors? But we already have single buffer for all vertices.
# To keep simple, we'll create one primitive per original part (15 primitives) - Godot supports multiple primitives
# Each primitive will have its own indices accessor pointing to subset of indices buffer

# Need to create additional accessors for per-part indices
# We'll create bufferViews and accessors for each part's indices slice

# Already have all indices in one bufferView, but we need per-part accessors with byteOffset

# Create per-part index accessors
# We'll reuse the same bufferView (5) but with different byteOffset and count

# For positions etc, we need per-part accessors too that point to subset of vertex attributes

# Let's create per-part accessors

# First, we need to create additional bufferViews? Actually we can use same bufferViews with byteOffset in accessor

# Accessor byteOffset is relative to bufferView byteOffset

# So for each part, we need accessors for pos, norm, uv, joints, weights, indices

# Let's create them

# We'll keep the first 7 accessors as whole, but for primitives we need sliced

# Create new accessors list for sliced

# Helper to create sliced accessor
def create_sliced_accessor(bufferView_idx, base_accessor, vertex_offset, count, byte_stride=None):
    # base_accessor has componentType, type
    # byteOffset = vertex_offset * componentSize
    # For VEC3 float: 12 bytes per vertex
    # For VEC2 float: 8
    # For VEC4 ushort: 8
    # For VEC4 float: 16
    component_size = 0
    if base_accessor.componentType == FLOAT:
        component_size = 4
    elif base_accessor.componentType == UNSIGNED_SHORT:
        component_size = 2
    elif base_accessor.componentType == UNSIGNED_INT:
        component_size = 4

    type_num_components = {"SCALAR":1, "VEC2":2, "VEC3":3, "VEC4":4, "MAT4":16}
    # Actually Accessor.type is enum, but we have string? pygltflib uses string?
    # We'll compute byte offset
    num_comp = {"VEC2":2, "VEC3":3, "VEC4":4, "SCALAR":1}[base_accessor.type] if isinstance(base_accessor.type, str) else 3
    # Simpler: use known
    if base_accessor.type == VEC3:
        num_comp = 3
    elif base_accessor.type == VEC2:
        num_comp = 2
    elif base_accessor.type == VEC4:
        num_comp = 4
    elif base_accessor.type == SCALAR:
        num_comp = 1
    else:
        num_comp = 3

    byte_offset = vertex_offset * num_comp * component_size
    acc = Accessor(
        bufferView=bufferView_idx,
        byteOffset=byte_offset,
        componentType=base_accessor.componentType,
        count=count,
        type=base_accessor.type
    )
    return acc

# We'll create primitives with sliced accessors
mesh = Mesh(name="AlexMercer_Body")

# For each part, create sliced accessors and primitive
for info in primitive_infos:
    v_off = info["vertex_offset"]
    v_count = info["vertex_count"]
    i_off = 0
    # Find index offset in indices array: need to compute cumulative index count
    # Our all_indices is concatenated in order, so index buffer offset for this part is sum of previous index counts * size of index
    # For accessor, byteOffset in indices bufferView
    # Compute index byte offset
    prev_idx_count = sum([p["index_count"] for p in primitive_infos if p["vertex_offset"] < v_off])
    idx_byte_offset = prev_idx_count * (2 if indices_component==UNSIGNED_SHORT else 4)
    # Create accessors
    acc_p = Accessor(bufferView=0, byteOffset=v_off*12, componentType=FLOAT, count=v_count, type=VEC3)
    acc_n = Accessor(bufferView=1, byteOffset=v_off*12, componentType=FLOAT, count=v_count, type=VEC3)
    acc_t = Accessor(bufferView=2, byteOffset=v_off*8, componentType=FLOAT, count=v_count, type=VEC2)
    acc_j = Accessor(bufferView=3, byteOffset=v_off*8, componentType=UNSIGNED_SHORT, count=v_count, type=VEC4)
    acc_w = Accessor(bufferView=4, byteOffset=v_off*16, componentType=FLOAT, count=v_count, type=VEC4)
    acc_i = Accessor(bufferView=5, byteOffset=idx_byte_offset, componentType=indices_component, count=info["index_count"], type=SCALAR)

    # Add to gltf accessors
    base_idx = len(gltf.accessors)
    gltf.accessors.extend([acc_p, acc_n, acc_t, acc_j, acc_w, acc_i])

    prim = Primitive(
        attributes={
            "POSITION": base_idx,
            "NORMAL": base_idx+1,
            "TEXCOORD_0": base_idx+2,
            "JOINTS_0": base_idx+3,
            "WEIGHTS_0": base_idx+4,
        },
        indices=base_idx+5,
        material=info["mat"]
    )
    mesh.primitives.append(prim)

gltf.meshes.append(mesh)

# Nodes for bones
bone_nodes = []
for i, (name, parent, world_pos) in enumerate(bones_def):
    local = local_translations[i]
    node = Node(
        name=name,
        translation=local.tolist(),
        # No rotation/scale for T-pose
    )
    bone_nodes.append(node)

# Set children for bone nodes
for i, (name, parent, world_pos) in enumerate(bones_def):
    if parent != -1:
        if bone_nodes[parent].children is None:
            bone_nodes[parent].children = []
        bone_nodes[parent].children.append(i)

# Mesh node
mesh_node = Node(
    name="AlexMercer_Mesh",
    mesh=0,
    skin=0
)

# Root node for scene: contains hips and mesh
root_node = Node(
    name="Armature_Root",
    children=[0, len(bone_nodes)]  # hips is 0, mesh node will be last
)

# Add bone nodes to gltf.nodes
gltf.nodes.extend(bone_nodes)
# Mesh node index
mesh_node_idx = len(gltf.nodes)
gltf.nodes.append(mesh_node)
# Root node index
root_node_idx = len(gltf.nodes)
gltf.nodes.append(root_node)

# Skin
skin = Skin(
    inverseBindMatrices=6,  # accessor index for IBM (we created earlier as index 6)
    joints=list(range(num_joints)),  # joints are node indices 0..18
    skeleton=0  # hips node
)
gltf.skins.append(skin)

# Scene
scene = Scene(nodes=[root_node_idx])
gltf.scenes.append(scene)
gltf.scene = 0

# Set binary blob
gltf.set_binary_blob(bytes(buffer_data))

# Save
gltf.save(out_path)
print(f"Saved GLB to {out_path}, size {os.path.getsize(out_path)} bytes")

# Also create a copy in assets/models for compatibility
import shutil
shutil.copy(out_path, "/home/user/shadow-protocol/assets/models/alex_mercer.glb")
print("Also copied to assets/models/alex_mercer.glb")
