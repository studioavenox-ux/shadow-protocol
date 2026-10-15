extends CharacterBody3D

# Player Controller - Alex Mercer (Phase 2 Improved)
# Third-person movement, gravity, jumping, sprinting, stamina, health
# Now with CharacterAnimator integration and improved humanoid rig support

@export_group("Movement")
@export var walk_speed: float = 3.5
@export var run_speed: float = 6.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.8
@export var gravity: float = 12.0
@export var acceleration: float = 12.0
@export var deceleration: float = 15.0
@export var air_control: float = 0.4
@export var rotation_speed: float = 12.0

@export_group("Stamina & Health")
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 25.0
@export var stamina_recover_rate: float = 18.0
@export var max_health: float = 100.0

@export_group("References")
@export var camera_pivot_path: NodePath = NodePath("CameraPivot")
@export var character_root_path: NodePath = NodePath("CharacterRoot")
@export var animator_path: NodePath = NodePath("CharacterAnimator")

var stamina: float = 100.0
var health: float = 100.0
var is_sprinting: bool = false
var is_moving: bool = false
var can_move: bool = true

# Input vectors
var move_input: Vector2 = Vector2.ZERO
var camera_input: Vector2 = Vector2.ZERO

# Internal
var _camera_pivot: Node3D = null
var _character_root: Node3D = null
var _animator = null
var _mesh_instance: MeshInstance3D = null
var _collision_shape: CollisionShape3D = null
var _animation_state: String = "idle"
var _prev_state: String = "idle"

signal stamina_changed(current: float, max_val: float)
signal health_changed(current: float, max_val: float)
signal player_moved(distance: float)
signal player_jumped
signal animation_state_changed(new_state: String)

var total_distance_traveled: float = 0.0
var last_position: Vector3 = Vector3.ZERO
var _was_on_floor: bool = true
var _landing_timer: float = 0.0

func _ready():
	add_to_group("player")
	stamina = max_stamina
	health = max_health
	last_position = global_position
	_was_on_floor = is_on_floor()
	
	# Get references
	if camera_pivot_path != NodePath(""):
		_camera_pivot = get_node_or_null(camera_pivot_path)
	else:
		_camera_pivot = get_node_or_null("CameraPivot")
	
	if character_root_path != NodePath(""):
		_character_root = get_node_or_null(character_root_path)
	else:
		_character_root = get_node_or_null("CharacterRoot")
		if not _character_root:
			# Fallback to old mesh instance name
			for child in get_children():
				if child.name == "CharacterRoot" or child.name == "MeshInstance3D":
					_character_root = child as Node3D
					break
	
	if animator_path != NodePath(""):
		_animator = get_node_or_null(animator_path)
	else:
		_animator = get_node_or_null("CharacterAnimator")
		if not _animator and _character_root:
			_animator = _character_root.get_node_or_null("CharacterAnimator")
	
	# Find mesh and collision (legacy support)
	for child in get_children():
		if child is MeshInstance3D and _mesh_instance == null:
			_mesh_instance = child
		if child is CollisionShape3D and _collision_shape == null:
			_collision_shape = child
	
	# Setup collision layers - Phase 3: Player layer 2 (bitmask 2), collides with World (1) + Vehicle (4)
	collision_layer = 2 # Player
	collision_mask = 1 | 4 # World + Vehicle - triggers and interactables are Areas, not physics
	
	print("[Player] Alex Mercer initialized at ", global_position)
	print("[Player] CharacterRoot: ", _character_root != null, " Animator: ", _animator != null)
	print("[Player] Walk: ", walk_speed, " Run: ", run_speed, " Sprint: ", sprint_speed)
	emit_signal("stamina_changed", stamina, max_stamina)
	emit_signal("health_changed", health, max_health)

func _physics_process(delta):
	if not can_move:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)
		_apply_gravity(delta)
		move_and_slide()
		_update_animation(delta)
		return
	
	# Handle gravity
	_apply_gravity(delta)
	
	# Handle jump
	_handle_jump()
	
	# Handle movement input
	_handle_movement(delta)
	
	# Handle stamina
	_handle_stamina(delta)
	
	# Apply movement
	move_and_slide()
	
	# Landing detection
	if not _was_on_floor and is_on_floor():
		# Just landed
		_landing_timer = 0.3
		_animation_state = "landing"
		if _animator and _animator.has_method("play_animation"):
			_animator.play_animation("landing")
		print("[Player] Landed")
	_was_on_floor = is_on_floor()
	
	if _landing_timer > 0:
		_landing_timer -= delta
	
	# Track distance for mission
	var moved = global_position.distance_to(last_position)
	if moved > 0.01:
		total_distance_traveled += moved
		emit_signal("player_moved", total_distance_traveled)
	last_position = global_position
	
	# Update animation state
	_update_movement_state()
	_update_animation(delta)

func _apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0:
			velocity.y = -0.1 # Small downward force to keep grounded

func _handle_jump():
	if Input.is_action_just_pressed("jump") or _mobile_jump_queued:
		_mobile_jump_queued = false
		if is_on_floor() and stamina > 10.0:
			velocity.y = jump_velocity
			stamina -= 10.0
			emit_signal("stamina_changed", stamina, max_stamina)
			emit_signal("player_jumped")
			_animation_state = "jumping"
			if _animator and _animator.has_method("play_animation"):
				_animator.play_animation("jumping")
			print("[Player] Jumped")

var _mobile_jump_queued: bool = false

func queue_jump():
	_mobile_jump_queued = true

func _handle_movement(delta):
	# Get keyboard input
	var input_dir = Vector2.ZERO
	
	# Keyboard / gamepad input
	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Mobile joystick input overrides or adds to keyboard
	if move_input.length() > 0.1:
		input_dir = move_input
	
	# Determine speed based on sprint
	var target_speed = walk_speed
	is_moving = input_dir.length() > 0.1
	
	if is_moving:
		if is_sprinting and stamina > 0.0 and input_dir.length() > 0.5:
			target_speed = sprint_speed
		elif input_dir.length() > 0.8:
			target_speed = run_speed
		else:
			target_speed = walk_speed
	
	# Camera-relative movement
	var cam_basis = Basis()
	if _camera_pivot:
		cam_basis = _camera_pivot.global_transform.basis
		# Only use yaw, ignore pitch for movement
		cam_basis = Basis.from_euler(Vector3(0, _camera_pivot.rotation.y, 0))
	
	var forward = -cam_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right = cam_basis.x
	right.y = 0
	right = right.normalized()
	
	var direction = (right * input_dir.x + forward * -input_dir.y).normalized()
	
	# Apply movement
	if direction.length() > 0.1:
		var accel = acceleration
		if not is_on_floor():
			accel *= air_control
		
		velocity.x = lerp(velocity.x, direction.x * target_speed, accel * delta)
		velocity.z = lerp(velocity.z, direction.z * target_speed, accel * delta)
		
		# Rotate character to face movement direction
		var target_root = _character_root if _character_root else _mesh_instance
		if target_root:
			var target_angle = atan2(direction.x, direction.z)
			target_root.rotation.y = lerp_angle(target_root.rotation.y, target_angle, rotation_speed * delta)
	else:
		# Decelerate
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)

func _handle_stamina(delta):
	if is_sprinting and is_moving and is_on_floor():
		if stamina > 0:
			stamina -= stamina_drain_rate * delta
			stamina = max(stamina, 0)
			if stamina <= 0:
				is_sprinting = false
				print("[Player] Out of stamina")
		emit_signal("stamina_changed", stamina, max_stamina)
	else:
		# Recover stamina
		if stamina < max_stamina:
			stamina += stamina_recover_rate * delta
			stamina = min(stamina, max_stamina)
			emit_signal("stamina_changed", stamina, max_stamina)

func _update_movement_state():
	if _landing_timer > 0:
		return # Keep landing state for short duration
	
	var new_state = "idle"
	if not is_on_floor():
		if velocity.y > 0:
			new_state = "jumping"
		else:
			new_state = "falling"
	elif is_moving:
		if is_sprinting:
			new_state = "sprinting"
		elif velocity.length() > run_speed * 0.9:
			new_state = "running"
		else:
			new_state = "walking"
	
	if new_state != _animation_state:
		_prev_state = _animation_state
		_animation_state = new_state
		emit_signal("animation_state_changed", _animation_state)

func _update_animation(delta: float):
	if _animator == null:
		return
	
	var speed = Vector2(velocity.x, velocity.z).length()
	var grounded = is_on_floor()
	
	if _animator.has_method("update_animation"):
		_animator.update_animation(delta, _animation_state, speed, grounded, velocity.y)
	elif _animator.has_method("play_animation"):
		# Fallback
		if _animation_state != _prev_state:
			_animator.play_animation(_animation_state)

# Mobile controls interface
func set_move_input(input: Vector2):
	move_input = input.clamped(Vector2(-1, -1), Vector2(1, 1))
	# Deadzone
	if move_input.length() < 0.15:
		move_input = Vector2.ZERO
	
	# Audio footstep hook - Phase 4
	var audio_mgr = get_tree().get_first_node_in_group("audio_manager")
	if audio_mgr and audio_mgr.has_method("set_walking"):
		var moving = move_input.length() > 0.1 and can_move and is_on_floor()
		audio_mgr.set_walking(moving, is_sprinting, global_position)

func set_sprinting(sprinting: bool):
	if sprinting and stamina > 5.0:
		is_sprinting = true
	else:
		is_sprinting = false
	
	# Update audio
	var audio_mgr = get_tree().get_first_node_in_group("audio_manager")
	if audio_mgr and audio_mgr.has_method("set_walking"):
		var moving = move_input.length() > 0.1 or Input.get_vector(\"move_left\", \"move_right\", \"move_forward\", \"move_back\").length() > 0.1
		if moving and can_move:
			audio_mgr.set_walking(true, is_sprinting, global_position)

func set_camera_input(input: Vector2):
	camera_input = input

# Health system
func take_damage(amount: float):
	health -= amount
	health = max(health, 0)
	emit_signal("health_changed", health, max_health)
	print("[Player] Took damage: ", amount, " Health: ", health)
	if health <= 0:
		_die()

func heal(amount: float):
	health += amount
	health = min(health, max_health)
	emit_signal("health_changed", health, max_health)

func _die():
	print("[Player] Player died")
	can_move = false
	# For prototype, restart mission after delay
	await get_tree().create_timer(2.0).timeout
	if GameManager:
		GameManager.restart_mission()
	else:
		get_tree().reload_current_scene()

func get_stamina_percent() -> float:
	return stamina / max_stamina

func get_health_percent() -> float:
	return health / max_health

func get_animation_state() -> String:
	return _animation_state

func disable_movement():
	can_move = false

func enable_movement():
	can_move = true
