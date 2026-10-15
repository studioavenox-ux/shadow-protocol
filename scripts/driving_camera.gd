extends Node3D

# Driving Camera - Phase 4 Improved
# Smooth third-person chase camera behind vehicle with reversing handling

@export var follow_speed: float = 6.0
@export var rotation_speed: float = 3.0
@export var mouse_sensitivity: float = 0.004
@export var touch_sensitivity: float = 0.005
@export var min_pitch: float = -15.0
@export var max_pitch: float = 20.0
@export var default_distance: float = 6.0
@export var min_distance: float = 3.0
@export var max_distance: float = 10.0
@export var reversing_distance: float = 4.5
@export var auto_center_speed: float = 1.2
@export var camera_collision_enabled: bool = true

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var yaw: float = 0.0
var pitch: float = -8.0
var target_yaw: float = 0.0
var target_pitch: float = -8.0
var current_distance: float = 6.0
var target_distance: float = 6.0

var is_reversing: bool = false
var vehicle: VehicleBody3D = null
var last_input_time: float = 0.0
var is_auto_centering: bool = false

func _ready():
	yaw = rotation.y
	pitch = rotation.x
	target_yaw = yaw
	target_pitch = pitch
	current_distance = default_distance
	target_distance = default_distance
	
	vehicle = get_parent() as VehicleBody3D
	if not vehicle:
		vehicle = get_parent().get_parent() as VehicleBody3D
	
	if spring_arm:
		spring_arm.spring_length = current_distance
		spring_arm.collision_mask = 1
		if not camera_collision_enabled:
			spring_arm.collision_mask = 0
	
	print("[DrivingCamera] Initialized - distance ", current_distance, " reversing handling enabled")

func _input(event):
	if not get_parent().is_in_group("vehicle"):
		return
	# Only handle when player in vehicle
	var veh = get_parent() as VehicleBody3D
	if veh and not veh.is_player_in_vehicle:
		return
	
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_handle_mouse_motion(event.relative)
		last_input_time = 0.0
		is_auto_centering = false
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_adjust_zoom(-0.5)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_adjust_zoom(0.5)

func _process(delta):
	last_input_time += delta
	
	# Check if reversing
	if vehicle:
		if vehicle.has_method("get_speed_kmh"):
			var speed = vehicle.get_speed_kmh()
			var throttle = vehicle.throttle_input if "throttle_input" in vehicle else 0.0
			is_reversing = throttle < -0.1 and speed < 10.0
	
	# Auto center when driving forward and no input for 3 seconds
	if last_input_time > 3.0 and not is_auto_centering and not is_reversing:
		if vehicle and abs(vehicle.steering_input) < 0.1:
			_start_auto_center()
	
	# Smooth interpolation
	yaw = lerp_angle(yaw, target_yaw, rotation_speed * delta)
	pitch = lerp_angle(pitch, target_pitch, rotation_speed * delta)
	
	# Clamp pitch
	pitch = clamp(pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	target_pitch = clamp(target_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	
	# Handle reversing - camera should not snap, but slightly adjust
	if is_reversing:
		target_distance = lerp(target_distance, reversing_distance, delta * 2.0)
		# Keep camera behind vehicle but allow more freedom when reversing
	else:
		target_distance = lerp(target_distance, default_distance, delta * 2.0)
	
	current_distance = lerp(current_distance, target_distance, follow_speed * delta * 0.5)
	
	# Apply rotation
	rotation.y = yaw
	rotation.x = pitch
	
	if spring_arm:
		spring_arm.spring_length = current_distance

func _handle_mouse_motion(relative: Vector2):
	target_yaw -= relative.x * mouse_sensitivity
	target_pitch -= relative.y * mouse_sensitivity

func add_camera_rotation(delta_rotation: Vector2):
	last_input_time = 0.0
	is_auto_centering = false
	target_yaw -= delta_rotation.x * touch_sensitivity
	target_pitch -= delta_rotation.y * touch_sensitivity

func _adjust_zoom(amount: float):
	target_distance = clamp(target_distance + amount, min_distance, max_distance)

func _start_auto_center():
	is_auto_centering = true
	# Center behind vehicle based on velocity
	if vehicle:
		var vel = vehicle.linear_velocity
		if vel.length() > 2.0:
			var vel_dir = vel.normalized()
			var target_yaw_from_vel = atan2(vel_dir.x, vel_dir.z)
			target_yaw = lerp_angle(target_yaw, target_yaw_from_vel + PI, auto_center_speed * 0.1)
	target_pitch = deg_to_rad(-8.0)

func reset_camera():
	target_yaw = 0.0
	target_pitch = deg_to_rad(-8.0)
	target_distance = default_distance
	last_input_time = 0.0
	is_auto_centering = false

func set_distance(dist: float):
	target_distance = clamp(dist, min_distance, max_distance)

func get_distance() -> float:
	return current_distance

func set_reversing(rev: bool):
	is_reversing = rev
