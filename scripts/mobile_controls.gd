extends CanvasLayer

# Mobile Controls - Android-friendly landscape HUD
# Left: joystick, Right: camera look, jump, sprint, interact

signal move_vector_changed(vector: Vector2)
signal jump_pressed
signal sprint_started
signal sprint_ended
signal interact_pressed
signal camera_drag(relative: Vector2)
signal pause_pressed

@export var joystick_deadzone: float = 0.15
@export var joystick_max_distance: float = 60.0

# UI References - will be set via @onready or created dynamically
var joystick_base: Control = null
var joystick_knob: Control = null
var joystick_touch_index: int = -1
var joystick_center: Vector2 = Vector2.ZERO
var joystick_current_pos: Vector2 = Vector2.ZERO
var is_joystick_active: bool = false

var camera_touch_index: int = -1
var last_camera_pos: Vector2 = Vector2.ZERO
var is_camera_dragging: bool = false

var sprint_held: bool = false
var interact_available: bool = false

# For keyboard testing
var keyboard_move: Vector2 = Vector2.ZERO

func _ready():
	print("[MobileControls] Initializing mobile HUD")
	# Setup will be done in game_hud.tscn script, but we provide logic here
	# This script is designed to be attached to the HUD CanvasLayer

func _input(event):
	# Keyboard fallback for testing
	if event is InputEventKey:
		_handle_keyboard_input(event)

func _handle_keyboard_input(event: InputEventKey):
	var move = Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		move.y -= 1
	if Input.is_action_pressed("move_back"):
		move.y += 1
	if Input.is_action_pressed("move_left"):
		move.x -= 1
	if Input.is_action_pressed("move_right"):
		move.x += 1
	keyboard_move = move.normalized() if move.length() > 0 else Vector2.ZERO
	if keyboard_move != Vector2.ZERO:
		emit_signal("move_vector_changed", keyboard_move)

# Joystick handling - called from UI
func handle_joystick_input(event: InputEvent, base_control: Control, knob_control: Control):
	if base_control == null or knob_control == null:
		return
	
	if event is InputEventScreenTouch:
		if event.pressed:
			# Check if touch is within joystick base
			var base_rect = base_control.get_global_rect()
			if base_rect.has_point(event.position):
				joystick_touch_index = event.index
				joystick_base = base_control
				joystick_knob = knob_control
				joystick_center = base_rect.get_center()
				is_joystick_active = true
				_update_joystick(event.position)
		else:
			# Release
			if event.index == joystick_touch_index:
				_reset_joystick()
	
	elif event is InputEventScreenDrag:
		if event.index == joystick_touch_index and is_joystick_active:
			_update_joystick(event.position)

func _update_joystick(touch_pos: Vector2):
	if joystick_base == null or joystick_knob == null:
		return
	
	var offset = touch_pos - joystick_center
	var distance = offset.length()
	
	if distance > joystick_max_distance:
		offset = offset.normalized() * joystick_max_distance
	
	# Move knob
	joystick_knob.position = joystick_base.size / 2 + offset - joystick_knob.size / 2
	
	# Calculate normalized vector (-1 to 1)
	var vector = offset / joystick_max_distance
	if vector.length() < joystick_deadzone:
		vector = Vector2.ZERO
	
	emit_signal("move_vector_changed", vector)

func _reset_joystick():
	is_joystick_active = false
	joystick_touch_index = -1
	if joystick_knob and joystick_base:
		joystick_knob.position = joystick_base.size / 2 - joystick_knob.size / 2
	emit_signal("move_vector_changed", Vector2.ZERO)

# Camera look handling
func handle_camera_input(event: InputEvent, camera_area: Control):
	if camera_area == null:
		return
	
	if event is InputEventScreenTouch:
		if event.pressed:
			var area_rect = camera_area.get_global_rect()
			if area_rect.has_point(event.position):
				# Don't capture if over buttons
				camera_touch_index = event.index
				last_camera_pos = event.position
				is_camera_dragging = true
		else:
			if event.index == camera_touch_index:
				camera_touch_index = -1
				is_camera_dragging = false
	
	elif event is InputEventScreenDrag:
		if event.index == camera_touch_index and is_camera_dragging:
			var delta = event.position - last_camera_pos
			last_camera_pos = event.position
			# Invert Y for natural camera
			emit_signal("camera_drag", delta)
			# Also emit as Vector2 for camera controller
			# The camera controller will handle sensitivity

# Button handlers - called from UI buttons
func on_jump_button_pressed():
	emit_signal("jump_pressed")
	print("[MobileControls] Jump pressed")

func on_sprint_button_down():
	sprint_held = true
	emit_signal("sprint_started")
	print("[MobileControls] Sprint started")

func on_sprint_button_up():
	sprint_held = false
	emit_signal("sprint_ended")
	print("[MobileControls] Sprint ended")

func on_interact_button_pressed():
	emit_signal("interact_pressed")
	print("[MobileControls] Interact pressed")

func on_pause_button_pressed():
	emit_signal("pause_pressed")
	print("[MobileControls] Pause pressed")

func set_interact_available(available: bool):
	interact_available = available

# Utility to create a simple touch button style
static func create_button_style(bg_color: Color, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	return style
