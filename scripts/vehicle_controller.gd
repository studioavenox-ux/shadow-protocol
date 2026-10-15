extends VehicleBody3D

# Vehicle Controller - NIGHTFALL Black Sports Sedan
# Drivable VehicleBody3D with 4 wheels, realistic physics, enter/exit

@export_group("Vehicle Setup")
@export var vehicle_name: String = "NIGHTFALL"
@export var max_engine_force: float = 900.0
@export var max_brake_force: float = 80.0
@export var max_steering_angle: float = 0.6 # radians ~34 degrees
@export var handbrake_force: float = 120.0
@export var mass_value: float = 1650.0

@export_group("Performance")
@export var acceleration_curve: float = 0.9
@export var brake_curve: float = 1.2
@export var steering_speed: float = 2.5
@export var auto_brake_when_no_input: bool = false

@export_group("Audio")
@export var engine_sound_enabled: bool = true

var is_player_in_vehicle: bool = false
var player: CharacterBody3D = null
var driver_seat_offset: Vector3 = Vector3(-0.4, 0.8, 0.0)
var exit_offset: Vector3 = Vector3(-2.5, 0.5, 0.0)

# Input
var throttle_input: float = 0.0 # -1 to 1 (negative = reverse)
var steering_input: float = 0.0 # -1 to 1
var brake_input: float = 0.0
var handbrake_input: bool = false

# Wheels
@onready var front_left_wheel: VehicleWheel3D = $FrontLeftWheel
@onready var front_right_wheel: VehicleWheel3D = $FrontRightWheel
@onready var rear_left_wheel: VehicleWheel3D = $RearLeftWheel
@onready var rear_right_wheel: VehicleWheel3D = $RearRightWheel

# Visuals
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var interaction_area: Area3D = $InteractionArea
@onready var exit_marker: Marker3D = $ExitMarker
@onready var camera_pivot: Node3D = $CameraPivot

# Lights
@onready var headlight_left: SpotLight3D = $Headlights/HeadlightLeft
@onready var headlight_right: SpotLight3D = $Headlights/HeadlightRight

# State
var current_speed: float = 0.0 # m/s
var current_speed_kmh: float = 0.0
var engine_rpm: float = 0.0
var vehicle_health: float = 100.0
var is_handbrake_active: bool = false

# Steering smoothing
var target_steering: float = 0.0
var current_steering: float = 0.0

signal player_entered_vehicle(vehicle: VehicleBody3D)
signal player_exited_vehicle(vehicle: VehicleBody3D)
signal vehicle_damaged(health: float)
signal speed_changed(speed_kmh: float)

func _ready():
	add_to_group("vehicle")
	add_to_group("interactable")
	
	mass = mass_value
	center_of_mass_mode = VehicleBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.8, 0.2)
	
	# Setup wheels if not configured
	_setup_wheels()
	
	# Setup interaction
	if interaction_area:
		interaction_area.monitoring = true
		interaction_area.monitorable = true
		interaction_area.collision_layer = 4
		interaction_area.collision_mask = 2
	
	# Ensure exit marker exists
	if not exit_marker:
		exit_marker = Marker3D.new()
		exit_marker.name = "ExitMarker"
		exit_marker.position = exit_offset
		add_child(exit_marker)
	
	print("[Vehicle] NIGHTFALL initialized - Mass: ", mass, " Engine: ", max_engine_force, " Steering: ", rad_to_deg(max_steering_angle), "°")
	print("[Vehicle] Wheels configured - FL:", front_left_wheel != null, " FR:", front_right_wheel != null, " RL:", rear_left_wheel != null, " RR:", rear_right_wheel != null)

func _setup_wheels():
	# Configure wheels for realistic driving if not already set
	# Front wheels steer, rear wheels drive
	if front_left_wheel:
		front_left_wheel.use_as_steering = true
		front_left_wheel.use_as_traction = false
		front_left_wheel.wheel_friction_slip = 1.2
		front_left_wheel.wheel_roll_influence = 0.2
		front_left_wheel.suspension_stiffness = 35.0
		front_left_wheel.suspension_travel = 0.35
		front_left_wheel.damping_compression = 4.5
		front_left_wheel.damping_relaxation = 4.0
	
	if front_right_wheel:
		front_right_wheel.use_as_steering = true
		front_right_wheel.use_as_traction = false
		front_right_wheel.wheel_friction_slip = 1.2
		front_right_wheel.wheel_roll_influence = 0.2
		front_right_wheel.suspension_stiffness = 35.0
		front_right_wheel.suspension_travel = 0.35
		front_right_wheel.damping_compression = 4.5
		front_right_wheel.damping_relaxation = 4.0
	
	if rear_left_wheel:
		rear_left_wheel.use_as_steering = false
		rear_left_wheel.use_as_traction = true
		rear_left_wheel.wheel_friction_slip = 1.5
		rear_left_wheel.wheel_roll_influence = 0.1
		rear_left_wheel.suspension_stiffness = 40.0
		rear_left_wheel.suspension_travel = 0.4
		rear_left_wheel.damping_compression = 5.0
		rear_left_wheel.damping_relaxation = 4.5
	
	if rear_right_wheel:
		rear_right_wheel.use_as_steering = false
		rear_right_wheel.use_as_traction = true
		rear_right_wheel.wheel_friction_slip = 1.5
		rear_right_wheel.wheel_roll_influence = 0.1
		rear_right_wheel.suspension_stiffness = 40.0
		rear_right_wheel.suspension_travel = 0.4
		rear_right_wheel.damping_compression = 5.0
		rear_right_wheel.damping_relaxation = 4.5

func _physics_process(delta):
	if not is_player_in_vehicle:
		# Slow down when no driver
		if auto_brake_when_no_input:
			_apply_braking(0.3)
		_update_speed()
		return
	
	# Handle input
	_handle_input(delta)
	
	# Apply vehicle physics
	_apply_engine_force()
	_apply_steering(delta)
	_apply_braking()
	_apply_handbrake()
	
	# Update state
	_update_speed()
	_update_engine_rpm()
	_update_headlights()

func _handle_input(delta):
	# Keyboard input for PC testing
	var accel = 0.0
	var steer = 0.0
	var brake = 0.0
	
	# W / Up = accelerate
	if Input.is_action_pressed("move_forward") or Input.is_action_pressed("accelerate"):
		accel += 1.0
	# S / Down = brake/reverse
	if Input.is_action_pressed("move_back") or Input.is_action_pressed("brake"):
		# If moving forward, brake, else reverse
		if current_speed > 1.0:
			brake = 1.0
		else:
			accel -= 0.6 # Reverse slower
	
	# A/D steer
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("steer_left"):
		steer -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_action_pressed("steer_right"):
		steer += 1.0
	
	# Space handbrake
	if Input.is_action_pressed("handbrake") or Input.is_action_pressed("jump"):
		handbrake_input = true
	else:
		handbrake_input = false
	
	# Combine with mobile input (mobile overrides if present)
	if abs(throttle_input) > 0.1:
		accel = throttle_input
	if abs(steering_input) > 0.1:
		steer = steering_input
	if brake_input > 0.1:
		brake = brake_input
	
	# Store
	throttle_input = accel
	steering_input = steer
	brake_input = brake

func _apply_engine_force():
	var force = throttle_input * max_engine_force
	
	# Apply curve for better feel
	if force > 0:
		force = pow(force / max_engine_force, acceleration_curve) * max_engine_force
	else:
		force = -pow(abs(force) / max_engine_force, acceleration_curve) * max_engine_force * 0.6
	
	# Apply to rear wheels (RWD for sports sedan)
	if rear_left_wheel:
		rear_left_wheel.engine_force = force * 0.5
	if rear_right_wheel:
		rear_right_wheel.engine_force = force * 0.5
	
	# Front wheels no traction in this setup

func _apply_steering(delta):
	target_steering = steering_input * max_steering_angle
	
	# Smooth steering
	current_steering = lerp(current_steering, target_steering, steering_speed * delta)
	
	if front_left_wheel:
		front_left_wheel.steering = current_steering
	if front_right_wheel:
		front_right_wheel.steering = current_steering

func _apply_braking(b_override: float = -1.0):
	var brake_force = brake_input * max_brake_force
	if b_override >= 0:
		brake_force = b_override * max_brake_force
	
	# Apply to all wheels
	var wheels = [front_left_wheel, front_right_wheel, rear_left_wheel, rear_right_wheel]
	for wheel in wheels:
		if wheel:
			wheel.brake = brake_force

func _apply_handbrake():
	if handbrake_input:
		is_handbrake_active = true
		if rear_left_wheel:
			rear_left_wheel.brake = handbrake_force
		if rear_right_wheel:
			rear_right_wheel.brake = handbrake_force
	else:
		is_handbrake_active = false

func _update_speed():
	current_speed = linear_velocity.length()
	current_speed_kmh = current_speed * 3.6
	emit_signal("speed_changed", current_speed_kmh)

func _update_engine_rpm():
	# Simple RPM based on speed and throttle
	var target_rpm = 800.0 + abs(current_speed_kmh) * 40.0 + abs(throttle_input) * 2000.0
	engine_rpm = lerp(engine_rpm, target_rpm, 0.1)

func _update_headlights():
	# Headlights on at night (always for now)
	if headlight_left:
		headlight_left.visible = true
	if headlight_right:
		headlight_right.visible = true

func _update_wheel_visuals():
	# Wheels are handled by VehicleWheel3D automatically if mesh assigned
	pass

# Enter/Exit system
func can_enter() -> bool:
	# Check if vehicle is not moving too fast
	if current_speed > 2.0:
		return false
	# Check if already occupied
	if is_player_in_vehicle:
		return false
	return true

func can_exit() -> bool:
	# Check if moving dangerously
	if current_speed > 3.0:
		return false
	# Check exit position is safe (no walls)
	if exit_marker:
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(global_position, exit_marker.global_position)
		query.collision_mask = 1
		var result = space_state.intersect_ray(query)
		if result:
			# Wall in the way, try other side
			var other_side = global_position + Vector3(2.5, 0.5, 0)
			query = PhysicsRayQueryParameters3D.create(global_position, other_side)
			result = space_state.intersect_ray(query)
			if result:
				return false
	return true

func enter_vehicle(p_player: CharacterBody3D):
	if not can_enter():
		print("[Vehicle] Cannot enter - moving too fast or occupied")
		return false
	
	player = p_player
	is_player_in_vehicle = true
	
	# Hide player
	if player:
		player.visible = false
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.set_collision_layer_value(2, false)
		player.set_collision_mask_value(1, false)
		if player.has_method("disable_movement"):
			player.disable_movement()
	
	# Enable vehicle camera
	if camera_pivot:
		camera_pivot.visible = true
		# Find camera and make current
		var cam = camera_pivot.find_child("Camera3D", true, false)
		if cam and cam is Camera3D:
			cam.current = true
	
	emit_signal("player_entered_vehicle", self)
	print("[Vehicle] Player entered NIGHTFALL")
	return true

func exit_vehicle():
	if not can_exit():
		print("[Vehicle] Cannot exit - moving too fast or unsafe")
		return false
	
	if not player:
		print("[Vehicle] No player to exit")
		return false
	
	# Find safe exit position
	var exit_pos = exit_marker.global_position if exit_marker else global_position + exit_offset
	# Ensure exit pos is not inside ground
	exit_pos.y = global_position.y + 0.5
	
	# Check if exit pos is safe
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, exit_pos)
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	if result:
		# Try other side
		exit_pos = global_position + Vector3(2.5, 0.5, 0)
		query = PhysicsRayQueryParameters3D.create(global_position, exit_pos)
		result = space_state.intersect_ray(query)
		if result:
			exit_pos = global_position + Vector3(0, 0.5, -2.5)
	
	# Place player
	player.global_position = exit_pos
	player.visible = true
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.set_collision_layer_value(2, true)
	player.set_collision_mask_value(1, true)
	player.set_collision_mask_value(4, true)
	player.set_collision_mask_value(8, true)
	if player.has_method("enable_movement"):
		player.enable_movement()
	
	# Reset vehicle inputs
	throttle_input = 0.0
	steering_input = 0.0
	brake_input = 0.0
	handbrake_input = false
	target_steering = 0.0
	current_steering = 0.0
	
	is_player_in_vehicle = false
	
	emit_signal("player_exited_vehicle", self)
	print("[Vehicle] Player exited NIGHTFALL at ", exit_pos)
	
	player = null
	return true

# Mobile input interface
func set_throttle_input(value: float):
	throttle_input = clamp(value, -1.0, 1.0)

func set_steering_input(value: float):
	steering_input = clamp(value, -1.0, 1.0)

func set_brake_input(value: float):
	brake_input = clamp(value, 0.0, 1.0)

func set_handbrake_input(active: bool):
	handbrake_input = active

func get_speed_kmh() -> float:
	return current_speed_kmh

func get_speed_mps() -> float:
	return current_speed

func get_health_percent() -> float:
	return vehicle_health

func take_damage(amount: float):
	vehicle_health -= amount
	vehicle_health = max(vehicle_health, 0)
	emit_signal("vehicle_damaged", vehicle_health)
	print("[Vehicle] Damage taken: ", amount, " Health: ", vehicle_health)

func repair(amount: float):
	vehicle_health += amount
	vehicle_health = min(vehicle_health, 100.0)
	emit_signal("vehicle_damaged", vehicle_health)
