extends CanvasLayer

# Driving HUD - Phase 3
# Mobile driving controls, speedometer, vehicle condition, mission objective

@onready var mission_title_label: Label = $TopBar/MissionInfo/MissionTitle
@onready var objective_label: Label = $TopBar/MissionInfo/ObjectiveLabel
@onready var speed_label: Label = $TopBar/VehicleStats/SpeedLabel
@onready var health_bar: ProgressBar = $TopBar/VehicleStats/HealthBar
@onready var pause_button: Button = $TopBar/PauseButton

@onready var speed_value_label: Label = $Speedometer/VBoxContainer/SpeedValue
@onready var gear_label: Label = $Speedometer/VBoxContainer/GearLabel

@onready var steer_left_button: Button = $BottomBar/SteeringContainer/SteerLeftButton
@onready var steer_right_button: Button = $BottomBar/SteeringContainer/SteerRightButton
@onready var accelerate_button: Button = $BottomBar/RightControls/AccelerateButton
@onready var brake_button: Button = $BottomBar/RightControls/BrakeButton
@onready var handbrake_button: Button = $BottomBar/RightControls/HandbrakeButton
@onready var exit_button: Button = $BottomBar/RightControls/ExitButton
@onready var camera_area: Control = $CameraLookArea

@onready var notification_panel: Panel = $TopCenter/NotificationPanel
@onready var notification_label: Label = $TopCenter/NotificationPanel/NotificationLabel

var current_vehicle: VehicleBody3D = null
var mission_manager = null

var notification_queue: Array = []
var is_showing_notification: bool = false

# Input state
var steering_input: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0
var handbrake_active: bool = false

func _ready():
	print("[DrivingHUD] Phase 3 - Initializing driving HUD")
	
	mission_manager = get_tree().get_first_node_in_group("mission_manager")
	if mission_manager:
		if mission_manager.has_signal("objective_updated"):
			mission_manager.objective_updated.connect(_on_objective_updated)
		if mission_manager.has_signal("show_notification"):
			mission_manager.show_notification.connect(_on_show_notification)
		if mission_manager.has_signal("mission_completed"):
			mission_manager.mission_completed.connect(_on_mission_completed)
	
	_setup_controls()
	
	notification_panel.visible = false
	
	if mission_title_label:
		mission_title_label.text = "A NEW BEGINNING - DRIVE"
	if objective_label:
		objective_label.text = "Drive to Iron Gate Garage"
	
	print("[DrivingHUD] Driving HUD ready - large touch targets")

func _setup_controls():
	# Steering buttons
	if steer_left_button:
		steer_left_button.button_down.connect(_on_steer_left_down)
		steer_left_button.button_up.connect(_on_steer_up)
	if steer_right_button:
		steer_right_button.button_down.connect(_on_steer_right_down)
		steer_right_button.button_up.connect(_on_steer_up)
	
	# Accelerate/Brake
	if accelerate_button:
		accelerate_button.button_down.connect(_on_accelerate_down)
		accelerate_button.button_up.connect(_on_accelerate_up)
	if brake_button:
		brake_button.button_down.connect(_on_brake_down)
		brake_button.button_up.connect(_on_brake_up)
	if handbrake_button:
		handbrake_button.button_down.connect(_on_handbrake_down)
		handbrake_button.button_up.connect(_on_handbrake_up)
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
	
	# Camera look area
	if camera_area:
		camera_area.gui_input.connect(_on_camera_input)

func set_vehicle(vehicle: VehicleBody3D):
	current_vehicle = vehicle
	if current_vehicle:
		if current_vehicle.has_signal("speed_changed"):
			if not current_vehicle.speed_changed.is_connected(_on_speed_changed):
				current_vehicle.speed_changed.connect(_on_speed_changed)
		if current_vehicle.has_signal("vehicle_damaged"):
			if not current_vehicle.vehicle_damaged.is_connected(_on_vehicle_damaged):
				current_vehicle.vehicle_damaged.connect(_on_vehicle_damaged)
		print("[DrivingHUD] Vehicle set: ", vehicle.vehicle_name if vehicle.has_method("get") else vehicle.name)

func _on_speed_changed(speed_kmh: float):
	if speed_label:
		speed_label.text = "%d KM/H" % int(speed_kmh)
	if speed_value_label:
		speed_value_label.text = "%d" % int(speed_kmh)
	if gear_label:
		if speed_kmh < 1:
			gear_label.text = "P"
		elif speed_kmh < 0:
			gear_label.text = "R"
		else:
			gear_label.text = "D"

func _on_vehicle_damaged(health: float):
	if health_bar:
		health_bar.value = health

func _on_objective_updated(index: int, description: String, completed: bool):
	if objective_label:
		objective_label.text = description
		if completed:
			objective_label.modulate = Color(0.5, 1.0, 0.5)
		else:
			objective_label.modulate = Color(1, 1, 1)

func _on_show_notification(text: String, duration: float):
	show_notification(text, duration)

func show_notification(text: String, duration: float = 3.0):
	notification_queue.append({"text": text, "duration": duration})
	if not is_showing_notification:
		_process_notification_queue()

func _process_notification_queue():
	if notification_queue.is_empty():
		is_showing_notification = false
		if notification_panel:
			notification_panel.visible = false
		return
	
	is_showing_notification = true
	var notif = notification_queue.pop_front()
	
	if notification_label:
		notification_label.text = notif.text
	if notification_panel:
		notification_panel.visible = true
		notification_panel.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(notification_panel, "modulate:a", 1.0, 0.3)
	
	await get_tree().create_timer(notif.duration).timeout
	
	if notification_panel:
		var tween = create_tween()
		tween.tween_property(notification_panel, "modulate:a", 0.0, 0.3)
		await tween.finished
		notification_panel.visible = false
	
	_process_notification_queue()

func _on_mission_completed(mission_name: String):
	show_notification("★ MISSION COMPLETE: " + mission_name, 4.5)

# Steering
func _on_steer_left_down():
	steering_input = -1.0
	_update_vehicle_steering()

func _on_steer_right_down():
	steering_input = 1.0
	_update_vehicle_steering()

func _on_steer_up():
	steering_input = 0.0
	_update_vehicle_steering()

func _update_vehicle_steering():
	if current_vehicle and current_vehicle.has_method("set_steering_input"):
		current_vehicle.set_steering_input(steering_input)

# Throttle/Brake
func _on_accelerate_down():
	throttle_input = 1.0
	_update_vehicle_throttle()

func _on_accelerate_up():
	throttle_input = 0.0
	_update_vehicle_throttle()

func _on_brake_down():
	brake_input = 1.0
	if current_vehicle and current_vehicle.has_method("set_brake_input"):
		current_vehicle.set_brake_input(brake_input)

func _on_brake_up():
	brake_input = 0.0
	if current_vehicle and current_vehicle.has_method("set_brake_input"):
		current_vehicle.set_brake_input(brake_input)

func _update_vehicle_throttle():
	if current_vehicle and current_vehicle.has_method("set_throttle_input"):
		current_vehicle.set_throttle_input(throttle_input)

func _on_handbrake_down():
	handbrake_active = true
	if current_vehicle and current_vehicle.has_method("set_handbrake_input"):
		current_vehicle.set_handbrake_input(true)

func _on_handbrake_up():
	handbrake_active = false
	if current_vehicle and current_vehicle.has_method("set_handbrake_input"):
		current_vehicle.set_handbrake_input(false)

func _on_exit_pressed():
	print("[DrivingHUD] Exit vehicle pressed")
	if current_vehicle:
		if current_vehicle.has_method("can_exit") and not current_vehicle.can_exit():
			show_notification("Cannot exit - vehicle moving too fast!", 2.5)
			return
		if current_vehicle.has_method("exit_vehicle"):
			var success = current_vehicle.exit_vehicle()
			if not success:
				show_notification("Cannot exit - unsafe position", 2.5)

func _on_pause_pressed():
	if GameManager:
		GameManager.pause_game()

func _on_camera_input(event: InputEvent):
	if event is InputEventScreenDrag:
		var delta = event.relative
		# Send to vehicle camera
		if current_vehicle:
			var cam_pivot = current_vehicle.get_node_or_null("CameraPivot")
			if cam_pivot:
				# Simple yaw rotation for driving camera
				cam_pivot.rotation.y -= delta.x * 0.005
				cam_pivot.rotation.x = clamp(cam_pivot.rotation.x - delta.y * 0.005, deg_to_rad(-20), deg_to_rad(15))

func _input(event):
	# Keyboard handling for PC testing is done in vehicle_controller
	# Here we handle exit via E
	if event.is_action_pressed("interact"):
		if current_vehicle and visible:
			_on_exit_pressed()

func _process(delta):
	# Smooth steering return when no input
	if steering_input == 0 and current_vehicle:
		# Gradually center steering
		if current_vehicle.has_method("set_steering_input"):
			var current = current_vehicle.steering_input if "steering_input" in current_vehicle else 0.0
			if abs(current) > 0.01:
				current_vehicle.set_steering_input(lerp(current, 0.0, delta * 3.0))
