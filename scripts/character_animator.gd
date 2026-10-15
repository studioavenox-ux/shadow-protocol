extends Node

# Character Animator - Phase 5: Supports both legacy BoxMesh placeholder and new GLB Skeleton3D
# Alex Mercer - Dark urban outfit, humanoid rig
# Provides Idle, Walk, Run, Sprint, Jump, Fall, Land states
# Works with Skeleton3D from alex_mercer.glb and legacy procedural rig

@export var torso_path: NodePath
@export var head_path: NodePath
@export var left_arm_path: NodePath
@export var right_arm_path: NodePath
@export var left_leg_path: NodePath
@export var right_leg_path: NodePath
@export var character_root_path: NodePath
@export var skeleton_path: NodePath = NodePath("") # Auto-detect via recursive search for Godot 4 GLB compatibility

var torso: MeshInstance3D = null
var head: MeshInstance3D = null
var left_arm: MeshInstance3D = null
var right_arm: MeshInstance3D = null
var left_leg: MeshInstance3D = null
var right_leg: MeshInstance3D = null
var character_root: Node3D = null
var skeleton: Skeleton3D = null
var alex_model: Node3D = null

var animation_player: AnimationPlayer = null
var glb_animation_player: AnimationPlayer = null

# Animation state
var current_state: String = "idle"
var time: float = 0.0
var move_speed: float = 0.0
var is_grounded: bool = true
var vertical_velocity: float = 0.0

# Config
@export var walk_bob_amplitude: float = 0.05
@export var run_bob_amplitude: float = 0.08
@export var sprint_bob_amplitude: float = 0.12
@export var walk_frequency: float = 6.0
@export var run_frequency: float = 9.0
@export var sprint_frequency: float = 12.0

# Smoothing
var target_root_y: float = 0.0
var current_root_y: float = 0.0

# Skeleton bone indices cache
var bone_map: Dictionary = {}
var initial_bone_poses: Dictionary = {}
var has_skeleton: bool = false

func _ready():
	# Resolve nodes
	if character_root_path != NodePath(""):
		character_root = get_node_or_null(character_root_path)
	else:
		character_root = get_parent().get_node_or_null("CharacterRoot")
		if not character_root:
			character_root = get_parent() as Node3D
	
	torso = _resolve(torso_path, "Torso")
	head = _resolve(head_path, "Head")
	left_arm = _resolve(left_arm_path, "LeftArm")
	right_arm = _resolve(right_arm_path, "RightArm")
	left_leg = _resolve(left_leg_path, "LeftLeg")
	right_leg = _resolve(right_leg_path, "RightLeg")
	
	# Find Skeleton3D - try multiple paths for GLB import variations
	skeleton = _find_skeleton()
	
	if skeleton:
		has_skeleton = true
		_cache_bones()
		print("[CharacterAnimator] Skeleton3D found: ", skeleton.name, " bones: ", skeleton.get_bone_count())
		for i in range(skeleton.get_bone_count()):
			print("  Bone ", i, ": ", skeleton.get_bone_name(i))
	else:
		print("[CharacterAnimator] No Skeleton3D found - using legacy procedural rig")
	
	# Find AlexModel
	alex_model = get_node_or_null("../AlexModel")
	if not alex_model and character_root:
		alex_model = character_root.get_node_or_null("AlexModel")
	
	# Find AnimationPlayers
	animation_player = get_parent().get_node_or_null("AnimationPlayer")
	if not animation_player and character_root:
		animation_player = character_root.get_node_or_null("AnimationPlayer")
	
	if alex_model:
		# Search for AnimationPlayer inside GLB
		glb_animation_player = _find_animation_player(alex_model)
		if glb_animation_player:
			print("[CharacterAnimator] GLB AnimationPlayer found with ", glb_animation_player.get_animation_list().size(), " animations: ", glb_animation_player.get_animation_list())
	
	print("[CharacterAnimator] Initialized - Alex Mercer")
	print("[CharacterAnimator] Legacy Parts - Torso:", torso != null, " Head:", head != null, " Arms:", left_arm != null and right_arm != null, " Legs:", left_leg != null and right_leg != null)
	print("[CharacterAnimator] New Model - AlexModel:", alex_model != null, " Skeleton:", has_skeleton)
	
	if animation_player:
		print("[CharacterAnimator] Legacy AnimationPlayer found with ", animation_player.get_animation_list().size(), " animations")
		if animation_player.has_animation("idle"):
			animation_player.play("idle")

func _find_skeleton() -> Skeleton3D:
	# Try explicit path if provided
	if skeleton_path != NodePath("") and skeleton_path != null:
		var node = get_node_or_null(skeleton_path)
		if node is Skeleton3D:
			print("[CharacterAnimator] Found skeleton via explicit path: ", skeleton_path)
			return node
	
	# Try common GLB import paths for Godot 4 - covers multiple importer variations
	var search_paths = [
		"../AlexModel/Armature_Root/Skeleton3D",
		"../AlexModel/Skeleton3D",
		"../AlexModel/Armature/Skeleton3D",
		"../../AlexModel/Armature_Root/Skeleton3D",
		"../CharacterRoot/AlexModel/Armature_Root/Skeleton3D",
		"../AlexModel/Armature_Root/Hips", # In some imports, Hips becomes Skeleton3D
		"../AlexModel/Hips",
		"../AlexModel/Armature_Root",
	]
	for p in search_paths:
		var node = get_node_or_null(p)
		if node is Skeleton3D:
			print("[CharacterAnimator] Found skeleton via search path: ", p)
			return node
		# Also check if node has Skeleton3D child
		if node:
			var child_skel = _recursive_find_skeleton(node)
			if child_skel:
				print("[CharacterAnimator] Found skeleton via child search of: ", p)
				return child_skel
	
	# Recursive search from CharacterRoot - most robust
	if character_root:
		var found = _recursive_find_skeleton(character_root)
		if found:
			print("[CharacterAnimator] Found skeleton via recursive search from CharacterRoot")
			return found
	
	# Search from parent (CharacterRoot's parent is Player)
	var parent = get_parent()
	if parent:
		var found = _recursive_find_skeleton(parent)
		if found:
			print("[CharacterAnimator] Found skeleton via recursive search from parent")
			return found
	
	# Search from Player root
	var player = get_node_or_null("../../Player")
	if player == null:
		player = get_node_or_null("../..")
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player:
		var found = _recursive_find_skeleton(player)
		if found:
			print("[CharacterAnimator] Found skeleton via recursive search from Player")
			return found
	
	return null

func _recursive_find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var result = _recursive_find_skeleton(child)
		if result:
			return result
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result
	return null

func _resolve(path: NodePath, fallback_name: String) -> MeshInstance3D:
	if path != NodePath(""):
		return get_node_or_null(path) as MeshInstance3D
	if character_root:
		var node = character_root.find_child(fallback_name, true, false)
		if node is MeshInstance3D:
			return node
	var parent = get_parent()
	if parent:
		var node = parent.find_child(fallback_name, true, false)
		if node is MeshInstance3D:
			return node
	return null

func _cache_bones():
	if not skeleton:
		return
	# Cache bone indices by name for quick access
	var bone_names = ["Hips", "Spine", "Chest", "Neck", "Head", "LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]
	for bone_name in bone_names:
		var idx = skeleton.find_bone(bone_name)
		if idx != -1:
			bone_map[bone_name] = idx
			# Cache initial pose
			initial_bone_poses[bone_name] = skeleton.get_bone_pose(idx)
	
	print("[CharacterAnimator] Cached bones: ", bone_map.keys())

func _find_animation_by_substring(player: AnimationPlayer, substr: String) -> String:
	if not player:
		return ""
	for anim_name in player.get_animation_list():
		if substr.to_lower() in anim_name.to_lower():
			return anim_name
	return ""

func update_animation(delta: float, state: String, speed: float, grounded: bool, v_vel: float):
	current_state = state
	move_speed = speed
	is_grounded = grounded
	vertical_velocity = v_vel
	time += delta
	
	# If we have GLB AnimationPlayer with real animations, use it - robust substring search
	if glb_animation_player:
		var exact = glb_animation_player.has_animation(state)
		var fuzzy = _find_animation_by_substring(glb_animation_player, state)
		var anim_to_play = ""
		if exact:
			anim_to_play = state
		elif fuzzy != "":
			anim_to_play = fuzzy
		
		if anim_to_play != "":
			if glb_animation_player.current_animation != anim_to_play:
				glb_animation_player.play(anim_to_play, 0.2)
				print("[CharacterAnimator] Playing GLB anim: ", anim_to_play, " for state ", state)
			return
	
	if animation_player:
		var exact = animation_player.has_animation(state)
		var fuzzy = _find_animation_by_substring(animation_player, state)
		var anim_to_play = ""
		if exact:
			anim_to_play = state
		elif fuzzy != "":
			anim_to_play = fuzzy
		
		if anim_to_play != "":
			if animation_player.current_animation != anim_to_play:
				animation_player.play(anim_to_play, 0.2)
			return
	
	# Otherwise procedural animation - preserves skeleton compatibility
	if has_skeleton:
		_procedural_skeleton_animate(delta)
	else:
		_procedural_animate(delta)

func _procedural_skeleton_animate(delta: float):
	if not skeleton:
		return
	
	match current_state:
		"idle":
			_animate_skeleton_idle(delta)
		"walking":
			_animate_skeleton_walk(delta, walk_frequency, walk_bob_amplitude)
		"running":
			_animate_skeleton_walk(delta, run_frequency, run_bob_amplitude)
		"sprinting":
			_animate_skeleton_walk(delta, sprint_frequency, sprint_bob_amplitude)
		"jumping":
			_animate_skeleton_jump(delta)
		"falling":
			_animate_skeleton_fall(delta)
		"landing":
			_animate_skeleton_land(delta)
		_:
			_animate_skeleton_idle(delta)

func _animate_skeleton_idle(_delta: float):
	var breath = sin(time * 1.2) * 0.02
	var sway = sin(time * 0.7) * 0.02
	
	# Chest breathing
	if bone_map.has("Chest"):
		var idx = bone_map["Chest"]
		var base = initial_bone_poses.get("Chest", Transform3D())
		var t = base
		t.origin.y = breath * 0.5
		t.basis = t.basis.rotated(Vector3.FORWARD, sway * 0.05)
		skeleton.set_bone_pose(idx, t)
	
	# Head subtle movement
	if bone_map.has("Head"):
		var idx = bone_map["Head"]
		var base = initial_bone_poses.get("Head", Transform3D())
		var t = base
		t.basis = t.basis.rotated(Vector3.RIGHT, sin(time * 0.5) * 0.05)
		skeleton.set_bone_pose(idx, t)

func _animate_skeleton_walk(_delta: float, freq: float, amp: float):
	var cycle = time * freq
	var swing = sin(cycle) * 0.6
	var arm_swing = sin(cycle) * 0.8
	
	# Legs
	if bone_map.has("LeftUpperLeg"):
		var idx = bone_map["LeftUpperLeg"]
		var base = initial_bone_poses.get("LeftUpperLeg", Transform3D())
		var t = base
		t.basis = t.basis.rotated(Vector3.RIGHT, swing)
		skeleton.set_bone_pose(idx, t)
	
	if bone_map.has("RightUpperLeg"):
		var idx = bone_map["RightUpperLeg"]
		var base = initial_bone_poses.get("RightUpperLeg", Transform3D())
		var t = base
		t.basis = t.basis.rotated(Vector3.RIGHT, -swing)
		skeleton.set_bone_pose(idx, t)
	
	if bone_map.has("LeftLowerLeg"):
		var idx = bone_map["LeftLowerLeg"]
		var base = initial_bone_poses.get("LeftLowerLeg", Transform3D())
		var t = base
		# Knee bend when leg forward
		var knee_bend = max(0, sin(cycle)) * 0.5
		t.basis = t.basis.rotated(Vector3.RIGHT, knee_bend)
		skeleton.set_bone_pose(idx, t)
	
	if bone_map.has("RightLowerLeg"):
		var idx = bone_map["RightLowerLeg"]
		var base = initial_bone_poses.get("RightLowerLeg", Transform3D())
		var t = base
		var knee_bend = max(0, -sin(cycle)) * 0.5
		t.basis = t.basis.rotated(Vector3.RIGHT, knee_bend)
		skeleton.set_bone_pose(idx, t)
	
	# Arms
	if bone_map.has("LeftUpperArm"):
		var idx = bone_map["LeftUpperArm"]
		var base = initial_bone_poses.get("LeftUpperArm", Transform3D())
		var t = base
		t.basis = t.basis.rotated(Vector3.RIGHT, -arm_swing)
		skeleton.set_bone_pose(idx, t)
	
	if bone_map.has("RightUpperArm"):
		var idx = bone_map["RightUpperArm"]
		var base = initial_bone_poses.get("RightUpperArm", Transform3D())
		var t = base
		t.basis = t.basis.rotated(Vector3.RIGHT, arm_swing)
		skeleton.set_bone_pose(idx, t)
	
	# Chest rotation
	if bone_map.has("Chest"):
		var idx = bone_map["Chest"]
		var base = initial_bone_poses.get("Chest", Transform3D())
		var t = base
		t.basis = t.basis.rotated(Vector3.UP, sin(cycle * 0.5) * 0.15)
		t.basis = t.basis.rotated(Vector3.FORWARD, sin(cycle) * 0.05)
		skeleton.set_bone_pose(idx, t)

func _animate_skeleton_jump(_delta: float):
	if bone_map.has("LeftUpperLeg"):
		var idx = bone_map["LeftUpperLeg"]
		var base = initial_bone_poses.get("LeftUpperLeg", Transform3D())
		var t = base
		t.basis = t.basis.rotated(Vector3.RIGHT, -0.8)
		skeleton.set_bone_pose(idx, t)
	if bone_map.has("RightUpperLeg"):
		var idx = bone_map["RightUpperLeg"]
		var base = initial_bone_poses.get("RightUpperLeg", Transform3D())
		var t = base
		t.basis = t.basis.rotated(Vector3.RIGHT, -0.8)
		skeleton.set_bone_pose(idx, t)
	if bone_map.has("LeftUpperArm"):
		var idx = bone_map["LeftUpperArm"]
		var base = initial_bone_poses.get("LeftUpperArm", Transform3D())
		var t = base
		t.basis = t.basis.rotated(Vector3.RIGHT, -1.2)
		skeleton.set_bone_pose(idx, t)
	if bone_map.has("RightUpperArm"):
		var idx = bone_map["RightUpperArm"]
		var base = initial_bone_poses.get("RightUpperArm", Transform3D())
		var t = base
		t.basis = t.basis.rotated(Vector3.RIGHT, -1.2)
		skeleton.set_bone_pose(idx, t)

func _animate_skeleton_fall(_delta: float):
	if bone_map.has("LeftUpperLeg"):
		var idx = bone_map["LeftUpperLeg"]
		var base = initial_bone_poses.get("LeftUpperLeg", Transform3D())
		var t = base
		t.basis = t.basis.rotated(Vector3.RIGHT, 0.3)
		skeleton.set_bone_pose(idx, t)
	if bone_map.has("RightUpperLeg"):
		var idx = bone_map["RightUpperLeg"]
		var base = initial_bone_poses.get("RightUpperLeg", Transform3D())
		var t = base
		t.basis = t.basis.rotated(Vector3.RIGHT, 0.3)
		skeleton.set_bone_pose(idx, t)

func _animate_skeleton_land(_delta: float):
	var t_val = clamp(time * 3.0, 0.0, 1.0)
	var crouch = sin(t_val * PI) * 0.3
	if bone_map.has("LeftUpperLeg"):
		var idx = bone_map["LeftUpperLeg"]
		var base = initial_bone_poses.get("LeftUpperLeg", Transform3D())
		var trans = base
		trans.basis = trans.basis.rotated(Vector3.RIGHT, crouch * 2.0)
		skeleton.set_bone_pose(idx, trans)
	if bone_map.has("RightUpperLeg"):
		var idx = bone_map["RightUpperLeg"]
		var base = initial_bone_poses.get("RightUpperLeg", Transform3D())
		var trans = base
		trans.basis = trans.basis.rotated(Vector3.RIGHT, crouch * 2.0)
		skeleton.set_bone_pose(idx, trans)

# Legacy procedural for BoxMesh placeholder
func _procedural_animate(delta: float):
	match current_state:
		"idle":
			_animate_idle(delta)
		"walking":
			_animate_walk(delta, walk_frequency, walk_bob_amplitude)
		"running":
			_animate_walk(delta, run_frequency, run_bob_amplitude)
		"sprinting":
			_animate_walk(delta, sprint_frequency, sprint_bob_amplitude)
		"jumping":
			_animate_jump(delta)
		"falling":
			_animate_fall(delta)
		"landing":
			_animate_land(delta)
		_:
			_animate_idle(delta)

func _animate_idle(delta: float):
	var breath = sin(time * 1.2) * 0.02
	var sway = sin(time * 0.7) * 0.02
	if torso:
		torso.position.y = 0.8 + breath
		torso.rotation.z = sway * 0.1
	if head:
		head.position.y = 0.55 + breath * 0.5
		head.rotation.x = sin(time * 0.5) * 0.05
	if left_arm and right_arm:
		left_arm.rotation.x = sin(time * 0.8) * 0.05
		right_arm.rotation.x = -sin(time * 0.8) * 0.05
		left_arm.rotation.z = 0.1 + sway
		right_arm.rotation.z = -0.1 - sway
	if left_leg and right_leg:
		left_leg.rotation.x = 0
		right_leg.rotation.x = 0
		left_leg.position.y = -0.5
		right_leg.position.y = -0.5
	if character_root:
		character_root.position.y = lerp(character_root.position.y, 0.0, delta * 5.0)

func _animate_walk(delta: float, freq: float, amp: float):
	var cycle = time * freq
	var bob = abs(sin(cycle)) * amp
	var swing = sin(cycle) * 0.6
	var arm_swing = sin(cycle) * 0.8
	if character_root:
		character_root.position.y = lerp(character_root.position.y, bob, delta * 10.0)
	if left_leg and right_leg:
		left_leg.rotation.x = swing
		right_leg.rotation.x = -swing
		left_leg.position.y = -0.5 + bob * 0.3
		right_leg.position.y = -0.5 + bob * 0.3
	if left_arm and right_arm:
		left_arm.rotation.x = -arm_swing
		right_arm.rotation.x = arm_swing
	if torso:
		torso.rotation.y = sin(cycle * 0.5) * 0.15
		torso.rotation.z = sin(cycle) * 0.05
		torso.position.y = 0.8 + bob * 0.5
	if head:
		head.rotation.y = sin(cycle * 0.5) * 0.1
		head.position.y = 0.55 + bob * 0.2

func _animate_jump(delta: float):
	if left_leg and right_leg:
		left_leg.rotation.x = -0.8
		right_leg.rotation.x = -0.8
		left_leg.position.y = -0.4
		right_leg.position.y = -0.4
	if left_arm and right_arm:
		left_arm.rotation.x = -1.2
		right_arm.rotation.x = -1.2
		left_arm.rotation.z = 0.3
		right_arm.rotation.z = -0.3
	if torso:
		torso.rotation.x = -0.2
		torso.position.y = 0.85
	if character_root:
		character_root.position.y = lerp(character_root.position.y, 0.1, delta * 8.0)

func _animate_fall(delta: float):
	if left_leg and right_leg:
		left_leg.rotation.x = 0.3
		right_leg.rotation.x = 0.3
	if left_arm and right_arm:
		left_arm.rotation.x = 0.2
		right_arm.rotation.x = 0.2
		left_arm.rotation.z = 0.5
		right_arm.rotation.z = -0.5
	if torso:
		torso.rotation.x = 0.1
	if character_root:
		character_root.position.y = lerp(character_root.position.y, 0.0, delta * 5.0)

func _animate_land(_delta: float):
	var t = clamp(time * 3.0, 0.0, 1.0)
	var crouch = sin(t * PI) * 0.15
	if character_root:
		character_root.position.y = -crouch
	if left_leg and right_leg:
		left_leg.rotation.x = crouch * 2.0
		right_leg.rotation.x = crouch * 2.0
	if torso:
		torso.rotation.x = crouch * 1.5

func play_animation(anim_name: String, blend: float = 0.2):
	if glb_animation_player:
		if glb_animation_player.has_animation(anim_name):
			glb_animation_player.play(anim_name, blend)
			current_state = anim_name
			print("[CharacterAnimator] Playing GLB animation: ", anim_name)
			return
		var fuzzy = _find_animation_by_substring(glb_animation_player, anim_name)
		if fuzzy != "" and glb_animation_player.has_animation(fuzzy):
			glb_animation_player.play(fuzzy, blend)
			current_state = fuzzy
			print("[CharacterAnimator] Playing GLB animation (fuzzy): ", fuzzy, " for ", anim_name)
			return
	if animation_player:
		if animation_player.has_animation(anim_name):
			animation_player.play(anim_name, blend)
			current_state = anim_name
			print("[CharacterAnimator] Playing legacy animation: ", anim_name)
			return
		var fuzzy = _find_animation_by_substring(animation_player, anim_name)
		if fuzzy != "" and animation_player.has_animation(fuzzy):
			animation_player.play(fuzzy, blend)
			current_state = fuzzy
			print("[CharacterAnimator] Playing legacy animation (fuzzy): ", fuzzy)

func get_current_animation() -> String:
	if glb_animation_player:
		return glb_animation_player.current_animation
	if animation_player:
		return animation_player.current_animation
	return current_state

func has_skeleton_rig() -> bool:
	return has_skeleton
