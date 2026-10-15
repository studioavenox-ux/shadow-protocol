extends Node

# Character Animator - Procedural low-poly animation system for Alex Mercer
# Since we use primitive meshes without skeleton, we animate via code
# Provides Idle, Walk, Run, Sprint, Jump, Fall, Land states
# Also hosts AnimationPlayer for future skeletal support

@export var torso_path: NodePath
@export var head_path: NodePath
@export var left_arm_path: NodePath
@export var right_arm_path: NodePath
@export var left_leg_path: NodePath
@export var right_leg_path: NodePath
@export var character_root_path: NodePath

var torso: MeshInstance3D = null
var head: MeshInstance3D = null
var left_arm: MeshInstance3D = null
var right_arm: MeshInstance3D = null
var left_leg: MeshInstance3D = null
var right_leg: MeshInstance3D = null
var character_root: Node3D = null

var animation_player: AnimationPlayer = null

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
	
	# Find AnimationPlayer if exists
	animation_player = get_parent().get_node_or_null("AnimationPlayer")
	if not animation_player and character_root:
		animation_player = character_root.get_node_or_null("AnimationPlayer")
	
	print("[CharacterAnimator] Initialized - Alex Mercer low-poly rig")
	print("[CharacterAnimator] Parts - Torso:", torso != null, " Head:", head != null, " Arms:", left_arm != null and right_arm != null, " Legs:", left_leg != null and right_leg != null)
	
	if animation_player:
		print("[CharacterAnimator] AnimationPlayer found with ", animation_player.get_animation_list().size(), " animations")
		# Play idle by default
		if animation_player.has_animation("idle"):
			animation_player.play("idle")

func _resolve(path: NodePath, fallback_name: String) -> MeshInstance3D:
	if path != NodePath(""):
		return get_node_or_null(path) as MeshInstance3D
	# Try to find via character_root
	if character_root:
		var node = character_root.find_child(fallback_name, true, false)
		if node is MeshInstance3D:
			return node
	# Try parent
	var parent = get_parent()
	if parent:
		var node = parent.find_child(fallback_name, true, false)
		if node is MeshInstance3D:
			return node
	return null

func update_animation(delta: float, state: String, speed: float, grounded: bool, v_vel: float):
	current_state = state
	move_speed = speed
	is_grounded = grounded
	vertical_velocity = v_vel
	time += delta
	
	# If we have AnimationPlayer with real animations, use it
	if animation_player and animation_player.has_animation(state):
		if animation_player.current_animation != state:
			animation_player.play(state, 0.2)
		return
	
	# Otherwise procedural animation
	_procedural_animate(delta)

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
	# Subtle breathing and weight shift
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
		# Slight knee bend
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

func _animate_land(delta: float):
	var t = clamp(time * 3.0, 0.0, 1.0)
	var crouch = sin(t * PI) * 0.15
	
	if character_root:
		character_root.position.y = -crouch
	
	if left_leg and right_leg:
		left_leg.rotation.x = crouch * 2.0
		right_leg.rotation.x = crouch * 2.0
	
	if torso:
		torso.rotation.x = crouch * 1.5

func play_animation(name: String, blend: float = 0.2):
	if animation_player and animation_player.has_animation(name):
		animation_player.play(name, blend)
		current_state = name
		print("[CharacterAnimator] Playing animation: ", name)

func get_current_animation() -> String:
	if animation_player:
		return animation_player.current_animation
	return current_state
