#!/usr/bin/env python3
"""
Generate alex_mercer.glb v2 - with idle animation
"""

import numpy as np
from pygltflib import (
    GLTF2, Scene, Node, Mesh, Primitive, Material, PbrMetallicRoughness,
    Buffer, BufferView, Accessor, Skin, Animation, AnimationSampler, AnimationChannel,
    ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER,
    FLOAT, UNSIGNED_SHORT, UNSIGNED_INT,
    SCALAR, VEC2, VEC3, VEC4, MAT4, LINEAR
)
import os

out_dir = "/home/user/shadow-protocol/assets/character"
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "alex_mercer.glb")

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

parts = [
    {"center": np.array([0.0, 1.15, 0.0]), "size": np.array([0.52, 0.70, 0.30]), "joint": 2, "mat": 0, "name": "Torso"},
    {"center": np.array([0.0, 1.15, 0.16]), "size": np.array([0.35, 0.12, 0.05]), "joint": 2, "mat": 4, "name": "Accent"},
    {"center": np.array([0.0, 1.68, 0.0]), "size": np.array([0.30, 0.36, 0.32]), "joint": 4, "mat": 1, "name": "Head"},
    {"center": np.array([-0.38, 1.42, 0.0]), "size": np.array([0.32, 0.12, 0.12]), "joint": 6, "mat": 0, "name": "LeftUpperArm"},
    {"center": np.array([0.38, 1.42, 0.0]), "size": np.array([0.32, 0.12, 0.12]), "joint": 10, "mat": 0, "name": "RightUpperArm"},
    {"center": np.array([-0.68, 1.42, 0.0]), "size": np.array([0.28, 0.10, 0.10]), "joint": 7, "mat": 0, "name": "LeftLowerArm"},
    {"center": np.array([0.68, 1.42, 0.0]), "size": np.array([0.28, 0.10, 0.10]), "joint": 11, "mat": 0, "name": "RightLowerArm"},
    {"center": np.array([-0.86, 1.42, 0.0]), "size": np.array([0.12, 0.10, 0.10]), "joint": 8, "mat": 1, "name": "LeftHand"},
    {"center": np.array([0.86, 1.42, 0.0]), "size": np.array([0.12, 0.10, 0.10]), "joint": 12, "mat": 1, "name": "RightHand"},
    {"center": np.array([-0.12, 0.55, 0.0]), "size": np.array([0.16, 0.45, 0.18]), "joint": 13, "mat": 2, "name": "LeftUpperLeg"},
    {"center": np.array([0.12, 0.55, 0.0]), "size": np.array([0.16, 0.45, 0.18]), "joint": 16, "mat": 2, "name": "RightUpperLeg"},
    {"center": np.array([-0.12, 0.18, 0.0]), "size": np.array([0.14, 0.40, 0.15]), "joint": 14, "mat": 2, "name": "LeftLowerLeg"},
    {"center": np.array([0.12, 0.18, 0.0]), "size": np.array([0.14, 0.40, 0.15]), "joint": 17, "mat": 2, "name": "RightLowerLeg"},
    {"center": np.array([-0.12, 0.04, 0.10]), "size": np.array([0.18, 0.12, 0.34]), "joint": 15, "mat": 3, "name": "LeftFoot"},
    {"center": np.array([0.12, 0.04, 0.10]), "size": np.array([0.18, 0.12, 0.34]), "joint": 18, "mat": 3, "name": "RightFoot"},
]

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

all_positions = []
all_normals = []
all_uvs = []
all_joints = []
all_weights = []
all_indices = []
index_offset = 0
primitive_infos = []
for part in parts:
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

# Animation data: idle breathing for Chest (node 2)
# Time: 0,1,2 seconds
anim_times = np.array([0.0, 1.0, 2.0], dtype=np.float32)
# Values: translation for Chest - base local [0,0.2,0] plus bob
base_chest_local = local_translations[2]  # Chest local
# Bob Y: 0, 0.02, 0
anim_values = np.array([
    [base_chest_local[0], base_chest_local[1], base_chest_local[2]],
    [base_chest_local[0], base_chest_local[1]+0.02, base_chest_local[2]],
    [base_chest_local[0], base_chest_local[1], base_chest_local[2]],
], dtype=np.float32)

# Build binary buffer
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
gltf.asset.generator = "Shadow Protocol - Alex Mercer Generator v2 with anim"

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

mat_jacket = Material(name="Jacket_Dark", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.08, 0.09, 0.105, 1.0], metallicFactor=0.15, roughnessFactor=0.75))
mat_skin = Material(name="Skin", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.82, 0.68, 0.58, 1.0], metallicFactor=0.0, roughnessFactor=0.85))
mat_trousers = Material(name="Trousers_Dark", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.12, 0.13, 0.15, 1.0], metallicFactor=0.05, roughnessFactor=0.85))
mat_shoes = Material(name="Shoes", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.05, 0.05, 0.06, 1.0], metallicFactor=0.1, roughnessFactor=0.7))
mat_accent = Material(name="Accent_Crimson", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.647, 0.122, 0.169, 1.0], metallicFactor=0.1, roughnessFactor=0.6))
gltf.materials.extend([mat_jacket, mat_skin, mat_trousers, mat_shoes, mat_accent])

mesh = Mesh(name="AlexMercer_Body")
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

# Animation: idle breathing for Chest node (index 2)
# Sampler 0: time -> translation
anim_sampler = AnimationSampler(input=7, output=8, interpolation="LINEAR")
anim_channel = AnimationChannel(sampler=0, target={"node": 2, "path": "translation"})
animation = Animation(name="idle", samplers=[anim_sampler], channels=[anim_channel])
gltf.animations.append(animation)

scene = Scene(nodes=[root_node_idx])
gltf.scenes.append(scene)
gltf.scene = 0

gltf.set_binary_blob(bytes(buffer_data))
gltf.save(out_path)
print(f"Saved GLB to {out_path}, size {os.path.getsize(out_path)} bytes")

import shutil
shutil.copy(out_path, "/home/user/shadow-protocol/assets/models/alex_mercer.glb")
shutil.copy(out_path, "/home/user/shadow-protocol/assets/character-assets/alex_mercer.glb")
print("Copied to models and character-assets")
