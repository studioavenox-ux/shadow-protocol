extends CharacterBody3D

# Player Controller - Alex Mercer
# Third-person movement, gravity, jumping, sprinting, stamina, health

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
var _mesh_instance: MeshInstance3D = null
var _collision_shape: CollisionShape3D = null
var _animation_state: String = "idle"

signal stamina_changed(current: float, max_val: float)
signal health_changed(current: float, max_val: float)
signal player_moved(distance: float)
signal player_jumped

var total_distance_traveled: float = 0.0
var last_position: Vector3 = Vector3.ZERO

func _ready():
	add_to_group("player")
	stamina = max_stamina
	health = max_health
	last_position = global_position
	
	# Get references
	if camera_pivot_path != NodePath(""):
		_camera_pivot = get_node_or_null(camera_pivot_path)
	else:
		_camera_pivot = get_node_or_null("CameraPivot")
	
	# Find mesh and collision
	for child in get_children():
		if child is MeshInstance3D:
			_mesh_instance = child
		if child is CollisionShape3D:
			_collision_shape = child
	
	# Setup collision layers
	collision_layer = 2 # Player
	collision_mask = 1 # World + Interactable
	
	print("[Player] Alex Mercer initialized at ", global_position)
	print("[Player] Walk: ", walk_speed, " Run: ", run_speed, " Sprint: ", sprint_speed)
	emit_signal("stamina_changed", stamina, max_stamina)
	emit_signal("health_changed", health, max_health)

func _physics_process(delta):
	if not can_move:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)
		_apply_gravity(delta)
		move_and_slide()
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
	
	# Track distance for mission
	var moved = global_position.distance_to(last_position)
	if moved > 0.01:
		total_distance_traveled += moved
		emit_signal("player_moved", total_distance_traveled)
	last_position = global_position
	
	# Update animation state (for future animation system)
	_update_movement_state()

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
		if _mesh_instance:
			var target_angle = atan2(direction.x, direction.z)
			_mesh_instance.rotation.y = lerp_angle(_mesh_instance.rotation.y, target_angle, rotation_speed * delta)
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
		_animation_state = new_state
		# Future: trigger animation

# Mobile controls interface
func set_move_input(input: Vector2):
	move_input = input.clamped(Vector2(-1, -1), Vector2(1, 1))
	# Deadzone
	if move_input.length() < 0.15:
		move_input = Vector2.ZERO

func set_sprinting(sprinting: bool):
	if sprinting and stamina > 5.0:
		is_sprinting = true
	else:
		is_sprinting = false

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

func disable_movement():
	can_move = false

func enable_movement():
	can_move = true
