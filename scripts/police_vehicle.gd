extends VehicleBody3D

# Police Vehicle - Blackwater City PD - Phase 4
# Lightweight AI pursuit: approach last known position, search, avoid spawning on player

@export_group("Police Setup")
@export var police_id: String = "BCPD-01"
@export var max_engine_force: float = 750.0
@export var max_brake_force: float = 85.0
@export var max_steering_angle: float = 0.55
@export var mass_value: float = 1750.0

@export_group("AI")
@export var detection_range: float = 60.0
@export var pursuit_speed: float = 18.0
@export var search_speed: float = 8.0
@export var arrival_distance: float = 4.0
@export var stuck_timeout: float = 4.0
@export var siren_enabled: bool = true

var target_position: Vector3 = Vector3.ZERO
var last_known_player_position: Vector3 = Vector3.ZERO
var is_pursuing: bool = false
var is_searching: bool = false
var is_patrolling: bool = false

var stuck_timer: float = 0.0
var last_position: Vector3 = Vector3.ZERO
var search_timer: float = 0.0

# Wheels
@onready var front_left_wheel: VehicleWheel3D = $FrontLeftWheel
@onready var front_right_wheel: VehicleWheel3D = $FrontRightWheel
@onready var rear_left_wheel: VehicleWheel3D = $RearLeftWheel
@onready var rear_right_wheel: VehicleWheel3D = $RearRightWheel

@onready var siren_light_left: OmniLight3D = $SirenLights/SirenLeft
@onready var siren_light_right: OmniLight3D = $SirenLights/SirenRight
@onready var siren_mesh_left: MeshInstance3D = $SirenLights/SirenMeshLeft
@onready var siren_mesh_right: MeshInstance3D = $SirenLights/SirenMeshRight

var current_speed: float = 0.0
var steering_target: float = 0.0
var current_steering: float = 0.0
var siren_timer: float = 0.0
var is_siren_on: bool = false

signal police_lost_target
signal police_reached_target

func _ready():
	add_to_group("police")
	
	mass = mass_value
	center_of_mass_mode = VehicleBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -1.0, 0.1)
	linear_damp = 0.12
	angular_damp = 2.0
	
	_setup_wheels()
	
	# Start with siren off, will turn on when pursuit starts
	if siren_light_left:
		siren_light_left.visible = false
	if siren_light_right:
		siren_light_right.visible = false
	
	last_position = global_position
	
	print("[Police] BCPD vehicle ", police_id, " initialized at ", global_position)

func _setup_wheels():
	if front_left_wheel:
		front_left_wheel.use_as_steering = true
		front_left_wheel.use_as_traction = false
		front_left_wheel.wheel_friction_slip = 1.3
		front_left_wheel.suspension_stiffness = 38.0
		front_left_wheel.suspension_travel = 0.3
	if front_right_wheel:
		front_right_wheel.use_as_steering = true
		front_right_wheel.use_as_traction = false
		front_right_wheel.wheel_friction_slip = 1.3
		front_right_wheel.suspension_stiffness = 38.0
		front_right_wheel.suspension_travel = 0.3
	if rear_left_wheel:
		rear_left_wheel.use_as_steering = false
		rear_left_wheel.use_as_traction = true
		rear_left_wheel.wheel_friction_slip = 1.5
		rear_left_wheel.suspension_stiffness = 42.0
	if rear_right_wheel:
		rear_right_wheel.use_as_steering = false
		rear_right_wheel.use_as_traction = true
		rear_right_wheel.wheel_friction_slip = 1.5
		rear_right_wheel.suspension_stiffness = 42.0

func _physics_process(delta):
	_update_speed()
	_handle_ai(delta)
	_apply_physics(delta)
	_update_siren(delta)
	_check_stuck(delta)

func _handle_ai(delta):
	if target_position == Vector3.ZERO:
		# No target, idle
		steering_target = 0.0
		if rear_left_wheel:
			rear_left_wheel.engine_force = 0.0
			rear_left_wheel.brake = 20.0
		if rear_right_wheel:
			rear_right_wheel.brake = 20.0
		return
	
	var distance_to_target = global_position.distance_to(target_position)
	
	if distance_to_target < arrival_distance:
		# Reached target
		if is_searching:
			search_timer -= delta
			if search_timer <= 0:
				# Search ended
				emit_signal("police_lost_target")
				is_searching = false
				target_position = Vector3.ZERO
				print("[Police] ", police_id, " search ended at ", global_position)
		else:
			# Reached last known, start search
			emit_signal("police_reached_target")
			if not is_searching:
				start_search()
		return
	
	# Pursuit logic - simple steering towards target
	var local_target = to_local(target_position)
	var angle_to_target = atan2(local_target.x, local_target.z)
	
	# Steering - proportional to angle
	steering_target = clamp(angle_to_target * 1.2, -max_steering_angle, max_steering_angle)
	
	# Throttle based on distance and angle
	var throttle = 1.0
	if abs(angle_to_target) > 0.8:
		throttle = 0.4 # Slow down for sharp turns
	elif distance_to_target < 10.0:
		throttle = 0.5
	
	if is_searching:
		throttle *= 0.5 # Search slower
	
	# Apply
	if rear_left_wheel:
		rear_left_wheel.engine_force = throttle * max_engine_force * 0.5
	if rear_right_wheel:
		rear_right_wheel.engine_force = throttle * max_engine_force * 0.5
	
	# Brake if very close
	if distance_to_target < 6.0:
		var brake_force = (1.0 - distance_to_target / 6.0) * max_brake_force
		if front_left_wheel:
			front_left_wheel.brake = brake_force
		if front_right_wheel:
			front_right_wheel.brake = brake_force

func _apply_physics(delta):
	current_steering = lerp(current_steering, steering_target, delta * 3.0)
	
	if front_left_wheel:
		front_left_wheel.steering = current_steering
	if front_right_wheel:
		front_right_wheel.steering = current_steering

func _update_speed():
	current_speed = linear_velocity.length()

func _check_stuck(delta):
	var moved = global_position.distance_to(last_position)
	if moved < 0.2 and current_speed < 1.0 and target_position != Vector3.ZERO:
		stuck_timer += delta
		if stuck_timer > stuck_timeout:
			# Try to unstuck - reverse and turn
			if rear_left_wheel:
				rear_left_wheel.engine_force = -max_engine_force * 0.4
			if rear_right_wheel:
				rear_right_wheel.engine_force = -max_engine_force * 0.4
			steering_target = randf_range(-max_steering_angle, max_steering_angle)
			stuck_timer = 0.0
			print("[Police] ", police_id, " stuck, attempting unstuck")
	else:
		stuck_timer = 0.0
	
	last_position = global_position

func _update_siren(delta):
	if not siren_enabled:
		return
	
	if not is_pursuing and not is_searching:
		# Siren off when not active
		if siren_light_left:
			siren_light_left.visible = false
		if siren_light_right:
			siren_light_right.visible = false
		return
	
	siren_timer += delta * 8.0 # Flash speed
	
	var left_on = sin(siren_timer) > 0
	var right_on = sin(siren_timer + PI) > 0
	
	if siren_light_left:
		siren_light_left.visible = left_on
	if siren_light_right:
		siren_light_right.visible = right_on
	
	if siren_mesh_left and siren_mesh_left.material_override:
		var mat = siren_mesh_left.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 3.0 if left_on else 0.2
	
	if siren_mesh_right and siren_mesh_right.material_override:
		var mat = siren_mesh_right.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 3.0 if right_on else 0.2

func set_target_position(pos: Vector3):
	if pos == Vector3.ZERO:
		return
	last_known_player_position = pos
	target_position = pos
	is_pursuing = true
	is_searching = false
	is_siren_on = true
	print("[Police] ", police_id, " target set to ", pos)

func start_search():
	is_searching = true
	is_pursuing = false
	search_timer = 15.0
	print("[Police] ", police_id, " starting search at ", global_position)

func start_pursuit():
	is_pursuing = true
	is_searching = false
	is_siren_on = true

func stop_pursuit():
	is_pursuing = false
	is_searching = false
	is_siren_on = false
	target_position = Vector3.ZERO
	steering_target = 0.0
	if rear_left_wheel:
		rear_left_wheel.engine_force = 0.0
		rear_left_wheel.brake = 30.0
	if rear_right_wheel:
		rear_right_wheel.brake = 30.0
	print("[Police] ", police_id, " pursuit stopped")

func get_speed() -> float:
	return current_speed

func is_active() -> bool:
	return is_pursuing or is_searching
