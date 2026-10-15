extends Node3D

# Camera Controller for third-person view
# Handles smooth follow, rotation, collision, touch and mouse input

@export var mouse_sensitivity: float = 0.003
@export var touch_sensitivity: float = 0.005
@export var min_pitch: float = -60.0
@export var max_pitch: float = 20.0
@export var smooth_speed: float = 10.0
@export var auto_rotate_speed: float = 1.5
@export var collision_enabled: bool = true

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var yaw: float = 0.0
var pitch: float = -15.0
var target_yaw: float = 0.0
var target_pitch: float = -15.0

var is_mouse_captured: bool = false
var is_touch_rotating: bool = false
var last_touch_pos: Vector2 = Vector2.ZERO

var camera_distance: float = 4.5
var min_distance: float = 1.5
var max_distance: float = 8.0

func _ready():
	# Initialize camera rotation
	yaw = rotation_degrees.y
	pitch = rotation_degrees.x
	target_yaw = yaw
	target_pitch = pitch
	
	if spring_arm:
		spring_arm.spring_length = camera_distance
		spring_arm.collision_mask = 1 # World layer
	
	# For PC testing, capture mouse on right click or middle
	# For mobile, we use touch area
	print("[CameraController] Initialized - yaw: ", yaw, " pitch: ", pitch)

func _input(event):
	# Mouse rotation for PC testing
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("camera_right") or is_mouse_captured or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_handle_mouse_motion(event.relative)
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				is_mouse_captured = true
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				is_mouse_captured = false
		# Zoom with wheel
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_adjust_zoom(-0.5)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_adjust_zoom(0.5)
	
	# Touch rotation handled via function calls from mobile controls
	# But also handle direct screen touch drag
	if event is InputEventScreenDrag:
		# Only handle if touch is on right side of screen (camera area)
		if event.position.x > get_viewport().get_visible_rect().size.x * 0.5:
			_handle_touch_drag(event.relative)

func _process(delta):
	# Smooth interpolation
	yaw = lerp_angle(yaw, target_yaw, smooth_speed * delta)
	pitch = lerp_angle(pitch, target_pitch, smooth_speed * delta)
	
	# Clamp pitch
	pitch = clamp(pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	target_pitch = clamp(target_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	
	# Apply rotation
	rotation.y = yaw
	rotation.x = pitch

func _handle_mouse_motion(relative: Vector2):
	var sens = mouse_sensitivity
	if GameManager:
		sens *= GameManager.get_setting("sensitivity") if GameManager.get_setting("sensitivity") else 1.0
	
	target_yaw -= relative.x * sens
	target_pitch -= relative.y * sens

func _handle_touch_drag(relative: Vector2):
	var sens = touch_sensitivity
	if GameManager:
		sens *= GameManager.get_setting("sensitivity") if GameManager.get_setting("sensitivity") else 1.0
	
	target_yaw -= relative.x * sens * 2.0
	target_pitch -= relative.y * sens * 2.0

func add_camera_rotation(delta_rotation: Vector2):
	# Called from mobile controls joystick area
	target_yaw -= delta_rotation.x * touch_sensitivity * 1.5
	target_pitch -= delta_rotation.y * touch_sensitivity * 1.5

func _adjust_zoom(amount: float):
	camera_distance = clamp(camera_distance + amount, min_distance, max_distance)
	if spring_arm:
		spring_arm.spring_length = camera_distance

func get_camera_forward() -> Vector3:
	if camera:
		return -camera.global_transform.basis.z
	return -global_transform.basis.z

func get_camera_right() -> Vector3:
	if camera:
		return camera.global_transform.basis.x
	return global_transform.basis.x

func reset_camera():
	target_yaw = 0.0
	target_pitch = deg_to_rad(-15.0)
	yaw = target_yaw
	pitch = target_pitch

func set_target_look_at(target_position: Vector3):
	# Make camera look at target (for cutscenes)
	var direction = (target_position - global_position).normalized()
	var target_yaw_rad = atan2(direction.x, direction.z)
	var target_pitch_rad = asin(-direction.y)
	target_yaw = target_yaw_rad
	target_pitch = clamp(target_pitch_rad, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
