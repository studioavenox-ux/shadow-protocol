extends Node3D

# Camera Controller for third-person view (Phase 2 Improved)
# Handles smooth follow, rotation, collision, touch and mouse input
# Improvements: better smoothing, damping, pitch limits, stable movement

@export_group("Sensitivity")
@export var mouse_sensitivity: float = 0.003
@export var touch_sensitivity: float = 0.005
@export var joystick_sensitivity: float = 0.008

@export_group("Limits")
@export var min_pitch: float = -55.0
@export var max_pitch: float = 25.0
@export var min_yaw: float = -360.0
@export var max_yaw: float = 360.0

@export_group("Smoothing")
@export var smooth_speed: float = 12.0
@export var rotation_smooth: float = 10.0
@export var follow_smooth: float = 15.0
@export var damping: float = 0.85

@export_group("Distance")
@export var camera_distance: float = 4.5
@export var min_distance: float = 1.2
@export var max_distance: float = 7.0
@export var collision_enabled: bool = true
@export var collision_margin: float = 0.3

@export_group("Behavior")
@export var auto_rotate_speed: float = 1.5
@export var auto_center_enabled: bool = false
@export var auto_center_delay: float = 3.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var yaw: float = 0.0
var pitch: float = -15.0
var target_yaw: float = 0.0
var target_pitch: float = -15.0

var is_mouse_captured: bool = false
var is_touch_rotating: bool = false
var last_touch_pos: Vector2 = Vector2.ZERO

var _velocity_yaw: float = 0.0
var _velocity_pitch: float = 0.0
var _time_since_input: float = 0.0
var _is_auto_centering: bool = false

func _ready():
	# Initialize camera rotation
	yaw = rotation_degrees.y
	pitch = rotation_degrees.x
	# Convert initial degrees to radians for internal use
	yaw = deg_to_rad(yaw)
	pitch = deg_to_rad(pitch)
	target_yaw = yaw
	target_pitch = pitch
	
	if spring_arm:
		spring_arm.spring_length = camera_distance
		spring_arm.collision_mask = 1 # World layer
		spring_arm.margin = collision_margin
		if not collision_enabled:
			spring_arm.collision_mask = 0
	
	print("[CameraController] Phase 2 - Initialized yaw:", rad_to_deg(yaw), " pitch:", rad_to_deg(pitch), " dist:", camera_distance)

func _input(event):
	# Mouse rotation for PC testing
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("camera_right") or is_mouse_captured or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_handle_mouse_motion(event.relative)
			_time_since_input = 0.0
			_is_auto_centering = false
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				is_mouse_captured = true
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				is_mouse_captured = false
		# Zoom with wheel - improved
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_adjust_zoom(-0.4)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_adjust_zoom(0.4)
	
	# Touch rotation handled via function calls from mobile controls
	# But also handle direct screen touch drag for fallback
	if event is InputEventScreenDrag:
		# Only handle if touch is on right side of screen (camera area)
		if event.position.x > get_viewport().get_visible_rect().size.x * 0.45:
			_handle_touch_drag(event.relative)
			_time_since_input = 0.0
			_is_auto_centering = false

func _process(delta):
	_time_since_input += delta
	
	# Auto center if enabled and no input for delay
	if auto_center_enabled and _time_since_input > auto_center_delay and not _is_auto_centering:
		if not is_mouse_captured and not is_touch_rotating:
			_start_auto_center()
	
	# Smooth interpolation with damping for stability
	var smooth_factor = 1.0 - pow(damping, delta * smooth_speed)
	
	# Use lerp_angle for yaw to handle wrapping
	yaw = lerp_angle(yaw, target_yaw, rotation_smooth * delta)
	pitch = lerp_angle(pitch, target_pitch, rotation_smooth * delta)
	
	# Clamp pitch
	var min_pitch_rad = deg_to_rad(min_pitch)
	var max_pitch_rad = deg_to_rad(max_pitch)
	pitch = clamp(pitch, min_pitch_rad, max_pitch_rad)
	target_pitch = clamp(target_pitch, min_pitch_rad, max_pitch_rad)
	
	# Apply rotation with smoothing
	rotation.y = yaw
	rotation.x = pitch
	
	# Smooth spring arm length if needed
	if spring_arm and abs(spring_arm.spring_length - camera_distance) > 0.01:
		spring_arm.spring_length = lerp(spring_arm.spring_length, camera_distance, delta * follow_smooth)

func _handle_mouse_motion(relative: Vector2):
	var sens = mouse_sensitivity
	if GameManager:
		var setting = GameManager.get_setting("sensitivity")
		if setting != null:
			sens *= setting
	
	target_yaw -= relative.x * sens
	target_pitch -= relative.y * sens

func _handle_touch_drag(relative: Vector2):
	var sens = touch_sensitivity
	if GameManager:
		var setting = GameManager.get_setting("sensitivity")
		if setting != null:
			sens *= setting
	
	target_yaw -= relative.x * sens * 2.2
	target_pitch -= relative.y * sens * 2.2

func add_camera_rotation(delta_rotation: Vector2):
	# Called from mobile controls joystick area - Phase 2 improved
	_time_since_input = 0.0
	_is_auto_centering = false
	
	var sens = touch_sensitivity
	if GameManager:
		var setting = GameManager.get_setting("sensitivity")
		if setting != null:
			sens *= setting
	
	# Scale by delta length for consistent feel
	target_yaw -= delta_rotation.x * sens * 1.8
	target_pitch -= delta_rotation.y * sens * 1.8

func _adjust_zoom(amount: float):
	camera_distance = clamp(camera_distance + amount, min_distance, max_distance)
	if spring_arm:
		# Smooth zoom via target, actual lerp in _process
		pass

func _start_auto_center():
	_is_auto_centering = true
	# Center behind player or to default pitch
	target_pitch = deg_to_rad(-15.0)
	print("[CameraController] Auto-centering")

func get_camera_forward() -> Vector3:
	if camera:
		return -camera.global_transform.basis.z
	return -global_transform.basis.z

func get_camera_right() -> Vector3:
	if camera:
		return camera.global_transform.basis.x
	return global_transform.basis.x

func get_camera_basis() -> Basis:
	if camera:
		return camera.global_transform.basis
	return global_transform.basis

func reset_camera():
	target_yaw = 0.0
	target_pitch = deg_to_rad(-15.0)
	# Don't snap, let _process smooth it
	print("[CameraController] Reset requested")

func set_target_look_at(target_position: Vector3):
	# Make camera look at target (for cutscenes/markers)
	var direction = (target_position - global_position).normalized()
	var target_yaw_rad = atan2(direction.x, direction.z)
	var target_pitch_rad = asin(-direction.y)
	target_yaw = target_yaw_rad
	target_pitch = clamp(target_pitch_rad, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	_time_since_input = 0.0

func set_distance(dist: float):
	camera_distance = clamp(dist, min_distance, max_distance)

func get_distance() -> float:
	return camera_distance

func is_colliding() -> bool:
	if spring_arm:
		return spring_arm.get_hit_length() < spring_arm.spring_length - 0.1
	return false
