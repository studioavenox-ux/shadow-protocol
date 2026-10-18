extends VehicleBody3D

# Vehicle Controller - NIGHTFALL Black Sports Sedan - Phase 4 Fixed
# Drivable VehicleBody3D with improved stability, gradual steering, safe exit

@export_group("Vehicle Setup")
@export var vehicle_name: String = "NIGHTFALL"
@export var max_engine_force: float = 850.0
@export var max_brake_force: float = 90.0
@export var max_steering_angle: float = 0.55 # radians ~31.5 degrees - slightly reduced for stability
@export var handbrake_force: float = 100.0
@export var mass_value: float = 1850.0 # Increased from 1650 for stability

@export_group("Performance")
@export var acceleration_curve: float = 0.85
@export var brake_curve: float = 1.1
@export var steering_speed: float = 3.0 # How fast steering reaches target
@export var steering_return_speed: float = 4.5 # How fast steering returns to center
@export var gradual_steering_enabled: bool = true
@export var auto_brake_when_no_input: bool = false

@export_group("Stability")
@export var stability_enabled: bool = true
@export var angular_damping: float = 2.2 # Increased from 0.8
@export var linear_damping: float = 0.15
@export var center_of_mass_offset: Vector3 = Vector3(0, -1.1, 0.15) # Lower for anti-tip
@export var anti_roll_stiffness: float = 0.8

@export_group("Audio")
@export var engine_sound_enabled: bool = true
@export var engine_audio_path: String = "res://assets/audio/engine_loop.ogg" # Optional, documented
@export var tire_squeal_path: String = "res://assets/audio/tire_squeal.ogg" # Optional
@export var brake_sound_path: String = "res://assets/audio/brake.ogg" # Optional

var is_player_in_vehicle: bool = false
var player: CharacterBody3D = null
var driver_seat_offset: Vector3 = Vector3(-0.4, 0.8, 0.0)
var exit_offsets: Array[Vector3] = [
	Vector3(-2.8, 0.5, 0.2),
	Vector3(2.8, 0.5, 0.2),
	Vector3(0, 0.5, -2.8),
	Vector3(0, 0.5, 2.8),
	Vector3(-2.0, 0.5, 1.5),
	Vector3(2.0, 0.5, 1.5)
]

# Input - gradual
var throttle_input: float = 0.0
var steering_input: float = 0.0
var target_steering_input: float = 0.0 # For gradual steering
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

# Audio players - optional, created if assets exist
var engine_player: AudioStreamPlayer3D = null
var tire_player: AudioStreamPlayer3D = null
var brake_player: AudioStreamPlayer3D = null

# State
var current_speed: float = 0.0
var current_speed_kmh: float = 0.0
var engine_rpm: float = 0.0
var target_rpm: float = 800.0
var vehicle_health: float = 100.0
var is_handbrake_active: bool = false
var is_reversing: bool = false

# Steering smoothing
var target_steering: float = 0.0
var current_steering: float = 0.0

# Stability
var last_upright_check: float = 0.0

signal player_entered_vehicle(vehicle: VehicleBody3D)
signal player_exited_vehicle(vehicle: VehicleBody3D)
signal vehicle_damaged(health: float)
signal speed_changed(speed_kmh: float)

func _ready():
	add_to_group("vehicle")
	add_to_group("interactable")
	
	mass = mass_value
	center_of_mass_mode = VehicleBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = center_of_mass_offset
	linear_damp = linear_damping
	angular_damp = angular_damping
	
	_setup_wheels()
	_setup_audio()
	
	if interaction_area:
		interaction_area.monitoring = true
		interaction_area.monitorable = true
		interaction_area.collision_layer = 8
		interaction_area.collision_mask = 2
	
	if not exit_marker:
		exit_marker = Marker3D.new()
		exit_marker.name = "ExitMarker"
		exit_marker.position = exit_offsets[0]
		add_child(exit_marker)
	
	print("[Vehicle] NIGHTFALL Phase 4 - Mass: ", mass, " CoM: ", center_of_mass, " Engine: ", max_engine_force, " Steering: ", rad_to_deg(max_steering_angle), "°")
	print("[Vehicle] Stability: angular_damp ", angular_damping, " linear_damp ", linear_damping, " gradual steering ", gradual_steering_enabled)

func _setup_wheels():
	# Phase 4 tuned for stability - higher stiffness, better damping, anti-roll
	if front_left_wheel:
		front_left_wheel.use_as_steering = true
		front_left_wheel.use_as_traction = false
		front_left_wheel.wheel_friction_slip = 1.4
		front_left_wheel.wheel_roll_influence = 0.15 # Reduced from 0.2 for stability
		front_left_wheel.suspension_stiffness = 42.0 # Increased from 35
		front_left_wheel.suspension_travel = 0.32
		front_left_wheel.damping_compression = 5.2
		front_left_wheel.damping_relaxation = 4.8
	
	if front_right_wheel:
		front_right_wheel.use_as_steering = true
		front_right_wheel.use_as_traction = false
		front_right_wheel.wheel_friction_slip = 1.4
		front_right_wheel.wheel_roll_influence = 0.15
		front_right_wheel.suspension_stiffness = 42.0
		front_right_wheel.suspension_travel = 0.32
		front_right_wheel.damping_compression = 5.2
		front_right_wheel.damping_relaxation = 4.8
	
	if rear_left_wheel:
		rear_left_wheel.use_as_steering = false
		rear_left_wheel.use_as_traction = true
		rear_left_wheel.wheel_friction_slip = 1.6
		rear_left_wheel.wheel_roll_influence = 0.08 # Reduced for stability
		rear_left_wheel.suspension_stiffness = 48.0 # Increased from 40
		rear_left_wheel.suspension_travel = 0.38
		rear_left_wheel.damping_compression = 5.8
		rear_left_wheel.damping_relaxation = 5.2
	
	if rear_right_wheel:
		rear_right_wheel.use_as_steering = false
		rear_right_wheel.use_as_traction = true
		rear_right_wheel.wheel_friction_slip = 1.6
		rear_right_wheel.wheel_roll_influence = 0.08
		rear_right_wheel.suspension_stiffness = 48.0
		rear_right_wheel.suspension_travel = 0.38
		rear_right_wheel.damping_compression = 5.8
		rear_right_wheel.damping_relaxation = 5.2

func _setup_audio():
	# Create audio players with optional asset paths - documented, not referencing missing files hard
	if engine_sound_enabled:
		engine_player = AudioStreamPlayer3D.new()
		engine_player.name = "EnginePlayer"
		engine_player.bus = "SFX"
		engine_player.max_distance = 40.0
		engine_player.unit_size = 8.0
		add_child(engine_player)
		
		# Try to load engine sound if exists, otherwise silent
		if ResourceLoader.exists(engine_audio_path):
			var stream = load(engine_audio_path)
			if stream:
				engine_player.stream = stream
				engine_player.autoplay = true
				print("[Vehicle] Engine audio loaded: ", engine_audio_path)
		else:
			print("[Vehicle] Engine audio not found (optional): ", engine_audio_path, " - system ready for asset")
	
	# Tire squeal player
	tire_player = AudioStreamPlayer3D.new()
	tire_player.name = "TirePlayer"
	tire_player.bus = "SFX"
	tire_player.max_distance = 30.0
	add_child(tire_player)
	if ResourceLoader.exists(tire_squeal_path):
		tire_player.stream = load(tire_squeal_path)
		print("[Vehicle] Tire squeal audio loaded")
	
	# Brake player
	brake_player = AudioStreamPlayer3D.new()
	brake_player.name = "BrakePlayer"
	brake_player.bus = "SFX"
	add_child(brake_player)
	if ResourceLoader.exists(brake_sound_path):
		brake_player.stream = load(brake_sound_path)

func _physics_process(delta):
	if not is_player_in_vehicle:
		if auto_brake_when_no_input:
			_apply_braking(0.3)
		_update_speed()
		_apply_stability(delta)
		return
	
	_handle_input(delta)
	_apply_engine_force()
	_apply_steering(delta)
	_apply_braking()
	_apply_handbrake()
	_apply_stability(delta)
	
	_update_speed()
	_update_engine_rpm(delta)
	_update_headlights()
	_update_audio(delta)
	_check_tire_squeal()

func _handle_input(delta):
	var accel = 0.0
	var steer = 0.0
	var brake_amount = 0.0
	
	# Keyboard for PC testing - W/S
	if Input.is_action_pressed("move_forward") or Input.is_action_pressed("accelerate"):
		accel += 1.0
	if Input.is_action_pressed("move_back") or Input.is_action_pressed("brake"):
		if current_speed > 1.5:
			brake_amount = 1.0
		else:
			accel -= 0.65
			is_reversing = true
			if accel >= 0:
				is_reversing = false
	else:
		if accel >= 0:
			is_reversing = false
	
	# A/D steering - gradual
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("steer_left"):
		steer -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_action_pressed("steer_right"):
		steer += 1.0
	
	if Input.is_action_pressed("handbrake") or Input.is_action_pressed("jump"):
		handbrake_input = true
	else:
		handbrake_input = false
	
	# Mobile input - gradual steering handling
	if gradual_steering_enabled:
		# Mobile steering input is target, we gradually approach it
		if abs(steering_input) > 0.1 or abs(target_steering_input) > 0.1:
			# If mobile is providing input, use its target
			if abs(steering_input) > 0.05:
				target_steering_input = steering_input
			# Gradually move steering_input towards target
			steering_input = lerp(steering_input, target_steering_input, steering_speed * delta)
			# If no input, return to center faster
			if abs(target_steering_input) < 0.05:
				steering_input = lerp(steering_input, 0.0, steering_return_speed * delta)
		else:
			# Keyboard input gradual
			if abs(steer) > 0.1:
				target_steering_input = steer
				steering_input = lerp(steering_input, target_steering_input, steering_speed * delta)
			else:
				target_steering_input = 0.0
				steering_input = lerp(steering_input, 0.0, steering_return_speed * delta)
	else:
		# Old abrupt method (fallback)
		if abs(throttle_input) > 0.1:
			accel = throttle_input
		if abs(steering_input) > 0.1:
			steer = steering_input
		if brake_input > 0.1:
			brake_amount = brake_input
		throttle_input = accel
		steering_input = steer
		brake_input = brake_amount
		return
	
	# For gradual mode, combine
	if not gradual_steering_enabled:
		# Already handled
		pass
	else:
		# Throttle handling - if mobile throttle present, use it, else keyboard
		if abs(throttle_input) > 0.1 and abs(accel) < 0.1:
			# Keep mobile throttle
			pass
		else:
			throttle_input = accel
		
		# Brake
		if brake_input > 0.1 and brake_amount < 0.1:
			# Keep mobile brake
			pass
		else:
			brake_input = brake_amount

func _apply_engine_force():
	var force = throttle_input * max_engine_force
	
	if force > 0:
		force = pow(force / max_engine_force, acceleration_curve) * max_engine_force
	else:
		force = -pow(abs(force) / max_engine_force, acceleration_curve) * max_engine_force * 0.65
	
	if rear_left_wheel:
		rear_left_wheel.engine_force = force * 0.5
	if rear_right_wheel:
		rear_right_wheel.engine_force = force * 0.5

func _apply_steering(delta):
	target_steering = steering_input * max_steering_angle
	current_steering = lerp(current_steering, target_steering, steering_speed * delta)
	
	if front_left_wheel:
		front_left_wheel.steering = current_steering
	if front_right_wheel:
		front_right_wheel.steering = current_steering

func _apply_braking(b_override: float = -1.0):
	var brake_force = brake_input * max_brake_force
	if b_override >= 0:
		brake_force = b_override * max_brake_force
	
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

func _apply_stability(delta):
	if not stability_enabled:
		return
	
	# Anti-tip: if vehicle is tilting too much, apply corrective torque
	var up = global_transform.basis.y
	var dot = up.dot(Vector3.UP)
	
	# If dot < 0.5, vehicle is more than 60 degrees tilted
	if dot < 0.6 and current_speed < 5.0:
		# Apply torque to upright
		var torque = Vector3.UP.cross(up) * 15.0 * mass
		apply_torque(torque)
	
	# If vehicle is upside down and slow, auto-right after delay
	if dot < 0.0 and current_speed < 1.0:
		last_upright_check += delta
		if last_upright_check > 2.5:
			# Auto right
			var new_basis = Basis()
			new_basis = new_basis.rotated(Vector3.UP, global_rotation.y)
			global_transform.basis = new_basis
			angular_velocity = Vector3.ZERO
			last_upright_check = 0.0
			print("[Vehicle] Auto-uprighted")
	else:
		last_upright_check = 0.0

func _update_speed():
	current_speed = linear_velocity.length()
	current_speed_kmh = current_speed * 3.6
	emit_signal("speed_changed", current_speed_kmh)

func _update_engine_rpm(delta):
	var speed_factor = abs(current_speed_kmh) / 100.0
	var throttle_factor = abs(throttle_input)
	
	target_rpm = 800.0 + speed_factor * 2500.0 + throttle_factor * 2500.0
	target_rpm = clamp(target_rpm, 800.0, 6500.0)
	
	engine_rpm = lerp(engine_rpm, target_rpm, delta * 5.0)

func _update_headlights():
	if headlight_left:
		headlight_left.visible = true
	if headlight_right:
		headlight_right.visible = true

func _update_audio(delta):
	if engine_player and engine_player.stream:
		# Pitch based on RPM
		var pitch = 0.7 + (engine_rpm / 6500.0) * 1.3
		engine_player.pitch_scale = lerp(engine_player.pitch_scale, pitch, delta * 3.0)
		engine_player.volume_db = lerp(engine_player.volume_db, -10.0 + throttle_input * 5.0, delta * 2.0)
		if not engine_player.playing:
			engine_player.play()

func _check_tire_squeal():
	if not tire_player:
		return
	
	var lateral_speed = abs(linear_velocity.dot(global_transform.basis.x))
	var should_squeal = (abs(current_steering) > 0.4 and current_speed > 8.0) or (handbrake_input and current_speed > 5.0) or lateral_speed > 3.0
	
	if should_squeal:
		if tire_player.stream and not tire_player.playing:
			tire_player.play()
		tire_player.volume_db = lerp(tire_player.volume_db, -5.0, 0.2)
	else:
		if tire_player.playing:
			tire_player.volume_db = lerp(tire_player.volume_db, -80.0, 0.1)
			if tire_player.volume_db < -70.0:
				tire_player.stop()

func can_enter() -> bool:
	if current_speed > 2.5:
		return false
	if is_player_in_vehicle:
		return false
	return true

func can_exit() -> bool:
	if current_speed > 3.5:
		return false
	return _find_safe_exit_position() != null

func _find_safe_exit_position() -> Variant:
	# Try multiple exit offsets to find collision-safe position
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return exit_marker.global_position if exit_marker else global_position + exit_offsets[0]
	
	for offset in exit_offsets:
		var exit_pos = global_position + offset
		exit_pos.y = global_position.y + 0.5
		
		# Raycast from vehicle center to exit pos for walls
		var query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.5, 0), exit_pos)
		query.collision_mask = 1 # World
		query.exclude = [self]
		var result = space_state.intersect_ray(query)
		if result:
			continue # Wall blocked
		
		# Check ground below exit pos - ensure not falling
		var ground_query = PhysicsRayQueryParameters3D.create(exit_pos + Vector3(0, 2, 0), exit_pos + Vector3(0, -3, 0))
		ground_query.collision_mask = 1
		ground_query.exclude = [self]
		var ground_result = space_state.intersect_ray(ground_query)
		if not ground_result:
			continue # No ground
		
		# Check if position is inside building via sphere check
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = 0.5
		var params = PhysicsShapeQueryParameters3D.new()
		params.shape = sphere_shape
		params.transform = Transform3D(Basis(), exit_pos)
		params.collision_mask = 1
		params.exclude = [self]
		var collisions = space_state.intersect_shape(params, 4)
		if collisions.size() > 0:
			continue # Inside something
		
		return exit_pos
	
	return null

func enter_vehicle(p_player: CharacterBody3D):
	if not can_enter():
		print("[Vehicle] Cannot enter - moving too fast or occupied")
		return false
	
	player = p_player
	is_player_in_vehicle = true
	
	if player:
		player.visible = false
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.set_collision_layer_value(2, false)
		player.set_collision_mask_value(1, false)
		if player.has_method("disable_movement"):
			player.disable_movement()
	
	if camera_pivot:
		camera_pivot.visible = true
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
	
	var exit_pos = _find_safe_exit_position()
	if exit_pos == null:
		print("[Vehicle] No safe exit position found")
		return false
	
	player.global_position = exit_pos
	player.visible = true
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.set_collision_layer_value(2, true)
	player.set_collision_mask_value(1, true)
	player.set_collision_mask_value(2, false)
	player.set_collision_mask_value(3, true) # Vehicle layer 3 = bitmask 4
	player.set_collision_mask_value(4, true) # Interactable layer 4 = bitmask 8
	player.set_collision_mask_value(5, true) # Trigger layer 5 = bitmask 16
	if player.has_method("enable_movement"):
		player.enable_movement()
	
	throttle_input = 0.0
	steering_input = 0.0
	target_steering_input = 0.0
	brake_input = 0.0
	handbrake_input = false
	target_steering = 0.0
	current_steering = 0.0
	
	is_player_in_vehicle = false
	
	emit_signal("player_exited_vehicle", self)
	print("[Vehicle] Player exited NIGHTFALL at ", exit_pos)
	
	player = null
	return true

# Mobile input interface - Phase 4 gradual
func set_throttle_input(value: float):
	throttle_input = clamp(value, -1.0, 1.0)

func set_steering_input(value: float):
	# Gradual steering: set target, actual steering lerps in _handle_input
	target_steering_input = clamp(value, -1.0, 1.0)
	if not gradual_steering_enabled:
		steering_input = target_steering_input

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
	print("[Vehicle] Damage: ", amount, " Health: ", vehicle_health)

func repair(amount: float):
	vehicle_health += amount
	vehicle_health = min(vehicle_health, 100.0)
	emit_signal("vehicle_damaged", vehicle_health)
