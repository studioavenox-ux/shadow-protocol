extends CanvasLayer

# Driving HUD - Phase 4 with Wanted, Minimap, Pursuit Direction
# Mobile driving controls, speedometer, vehicle condition, mission objective, wanted indicators
# Compact landscape, center clear, reuse existing HUD

@onready var mission_title_label: Label = $TopBar/HBoxContainer/MissionInfo/MissionTitle
@onready var objective_label: Label = $TopBar/HBoxContainer/MissionInfo/ObjectiveLabel
@onready var speed_label: Label = $TopBar/HBoxContainer/VehicleStats/SpeedLabel
@onready var health_bar: ProgressBar = $TopBar/HBoxContainer/VehicleStats/HealthBar
@onready var pause_button: Button = $TopBar/HBoxContainer/PauseButton

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

# Phase 4 nodes - may not exist in old tscn, create if missing
var wanted_panel: Panel = null
var wanted_stars: HBoxContainer = null
var wanted_label: Label = null
var police_alert_panel: Panel = null
var police_alert_label: Label = null
var minimap_container: Control = null
var pursuit_direction_arrow: Control = null
var pursuit_direction_label: Label = null

var current_vehicle: VehicleBody3D = null
var mission_manager = null
var wanted_manager = null

var notification_queue: Array = []
var is_showing_notification: bool = false

# Input state - gradual steering
var steering_input: float = 0.0
var target_steering_input: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0
var handbrake_active: bool = false
var steering_speed: float = 3.0
var steering_return_speed: float = 4.5

# Wanted display
var current_wanted_level: int = 0
var current_pursuit_state: int = 0

func _ready():
	print("[DrivingHUD] Phase 4 - Initializing driving HUD with wanted/minimap")
	
	mission_manager = get_tree().get_first_node_in_group("mission_manager")
	if mission_manager:
		if mission_manager.has_signal("objective_updated"):
			mission_manager.objective_updated.connect(_on_objective_updated)
		if mission_manager.has_signal("show_notification"):
			mission_manager.show_notification.connect(_on_show_notification)
		if mission_manager.has_signal("mission_completed"):
			mission_manager.mission_completed.connect(_on_mission_completed)
	
	wanted_manager = get_tree().get_first_node_in_group("wanted_manager")
	if not wanted_manager:
		# Try to find via path
		wanted_manager = get_node_or_null("/root/World/WantedManager")
	if wanted_manager:
		if wanted_manager.has_signal("wanted_level_changed"):
			wanted_manager.wanted_level_changed.connect(_on_wanted_level_changed)
		if wanted_manager.has_signal("police_alert"):
			wanted_manager.police_alert.connect(_on_police_alert)
		if wanted_manager.has_signal("pursuit_started"):
			wanted_manager.pursuit_started.connect(_on_pursuit_started)
		if wanted_manager.has_signal("pursuit_ended"):
			wanted_manager.pursuit_ended.connect(_on_pursuit_ended)
		print("[DrivingHUD] Connected to WantedManager")
	
	_setup_controls()
	_setup_phase4_ui()
	
	if notification_panel:
		notification_panel.visible = false
	
	if mission_title_label:
		mission_title_label.text = "A NEW BEGINNING - DRIVE"
	if objective_label:
		objective_label.text = "Drive to Iron Gate Garage"
	
	print("[DrivingHUD] Driving HUD Phase 4 ready - large touch targets, wanted indicators")

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

func _setup_phase4_ui():
	# Create wanted panel if not exists - compact landscape top left under mission
	var top_bar = $TopBar
	if not top_bar:
		return
	
	# Wanted panel - compact, top right near vehicle stats
	if not has_node("TopBar/WantedPanel"):
		wanted_panel = Panel.new()
		wanted_panel.name = "WantedPanel"
		wanted_panel.custom_minimum_size = Vector2(140, 40)
		wanted_panel.position = Vector2(0, 0)
		# Style
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.12, 0.7)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		wanted_panel.add_theme_stylebox_override("panel", style)
		
		# Place in TopBar - we'll add as child of TopBar/HBoxContainer/VehicleStats or TopBar itself
		var vehicle_stats = $TopBar/HBoxContainer/VehicleStats
		if vehicle_stats:
			# Create container for wanted inside VehicleStats
			wanted_panel.custom_minimum_size = Vector2(120, 35)
			vehicle_stats.add_child(wanted_panel)
			
			var vbox = VBoxContainer.new()
			vbox.name = "WantedVBox"
			wanted_panel.add_child(vbox)
			
			wanted_label = Label.new()
			wanted_label.name = "WantedLabel"
			wanted_label.text = "WANTED: 0"
			wanted_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			wanted_label.add_theme_font_size_override("font_size", 12)
			wanted_label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
			vbox.add_child(wanted_label)
			
			wanted_stars = HBoxContainer.new()
			wanted_stars.name = "WantedStars"
			wanted_stars.alignment = BoxContainer.ALIGNMENT_CENTER
			vbox.add_child(wanted_stars)
			
			for i in range(3):
				var star = Label.new()
				star.name = "Star%d" % i
				star.text = "☆"
				star.add_theme_font_size_override("font_size", 16)
				star.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
				wanted_stars.add_child(star)
		else:
			top_bar.add_child(wanted_panel)
	
	# Police alert panel - top center but above notification
	if not has_node("PoliceAlertPanel"):
		police_alert_panel = Panel.new()
		police_alert_panel.name = "PoliceAlertPanel"
		police_alert_panel.custom_minimum_size = Vector2(300, 36)
		police_alert_panel.visible = false
		police_alert_panel.position = Vector2(0, 0)
		police_alert_panel.anchor_left = 0.5
		police_alert_panel.anchor_top = 0.0
		police_alert_panel.anchor_right = 0.5
		police_alert_panel.anchor_bottom = 0.0
		police_alert_panel.offset_left = -150
		police_alert_panel.offset_top = 60
		police_alert_panel.offset_right = 150
		police_alert_panel.offset_bottom = 96
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.8, 0.1, 0.1, 0.85)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		police_alert_panel.add_theme_stylebox_override("panel", style)
		
		police_alert_label = Label.new()
		police_alert_label.name = "PoliceAlertLabel"
		police_alert_label.text = "POLICE ALERT"
		police_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		police_alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		police_alert_label.add_theme_font_size_override("font_size", 13)
		police_alert_label.add_theme_color_override("font_color", Color(1, 1, 1))
		police_alert_panel.add_child(police_alert_label)
		
		$TopCenter.add_child(police_alert_panel)
	
	# Minimap / pursuit direction - bottom left near steering, compact
	if not has_node("BottomBar/MinimapContainer"):
		minimap_container = Control.new()
		minimap_container.name = "MinimapContainer"
		minimap_container.custom_minimum_size = Vector2(100, 100)
		minimap_container.position = Vector2(0, 0)
		minimap_container.visible = false # Only visible when wanted >0
		
		var bg = Panel.new()
		bg.name = "MinimapBG"
		bg.custom_minimum_size = Vector2(100, 100)
		bg.size = Vector2(100, 100)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.08, 0.12, 0.75)
		style.corner_radius_top_left = 50
		style.corner_radius_top_right = 50
		style.corner_radius_bottom_left = 50
		style.corner_radius_bottom_right = 50
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.2, 0.4, 0.8, 0.8)
		bg.add_theme_stylebox_override("panel", style)
		minimap_container.add_child(bg)
		
		pursuit_direction_arrow = Control.new()
		pursuit_direction_arrow.name = "PursuitArrow"
		pursuit_direction_arrow.custom_minimum_size = Vector2(20, 20)
		pursuit_direction_arrow.position = Vector2(40, 40)
		minimap_container.add_child(pursuit_direction_arrow)
		
		pursuit_direction_label = Label.new()
		pursuit_direction_label.name = "DirectionLabel"
		pursuit_direction_label.text = "N"
		pursuit_direction_label.position = Vector2(0, 105)
		pursuit_direction_label.custom_minimum_size = Vector2(100, 20)
		pursuit_direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pursuit_direction_label.add_theme_font_size_override("font_size", 10)
		minimap_container.add_child(pursuit_direction_label)
		
		$BottomBar.add_child(minimap_container)
	
	# Initialize wanted display
	_update_wanted_display(0)

func set_vehicle(vehicle: VehicleBody3D):
	current_vehicle = vehicle
	if current_vehicle:
		if current_vehicle.has_signal("speed_changed"):
			if not current_vehicle.speed_changed.is_connected(_on_speed_changed):
				current_vehicle.speed_changed.connect(_on_speed_changed)
		if current_vehicle.has_signal("vehicle_damaged"):
			if not current_vehicle.vehicle_damaged.is_connected(_on_vehicle_damaged):
				current_vehicle.vehicle_damaged.connect(_on_vehicle_damaged)
		print("[DrivingHUD] Vehicle set: ", vehicle.vehicle_name if "vehicle_name" in vehicle else vehicle.name)

func _on_speed_changed(speed_kmh: float):
	if speed_label:
		speed_label.text = "%d KM/H" % int(speed_kmh)
	if speed_value_label:
		speed_value_label.text = "%d" % int(speed_kmh)
	if gear_label:
		if speed_kmh < 1:
			gear_label.text = "P"
		elif current_vehicle and "is_reversing" in current_vehicle and current_vehicle.is_reversing:
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

# Phase 4 Wanted
func _on_wanted_level_changed(new_level: int, old_level: int):
	current_wanted_level = new_level
	_update_wanted_display(new_level)
	if new_level > old_level:
		# Flash
		_flash_wanted_panel()

func _update_wanted_display(level: int):
	if not wanted_panel:
		# Try to find
		wanted_panel = get_node_or_null("TopBar/HBoxContainer/VehicleStats/WantedPanel")
		if wanted_panel:
			wanted_label = wanted_panel.get_node_or_null("WantedVBox/WantedLabel")
			wanted_stars = wanted_panel.get_node_or_null("WantedVBox/WantedStars")
	
	if wanted_label:
		wanted_label.text = "WANTED: %d" % level
		if level == 0:
			wanted_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		elif level == 1:
			wanted_label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
		elif level == 2:
			wanted_label.add_theme_color_override("font_color", Color(1, 0.5, 0.1))
		else:
			wanted_label.add_theme_color_override("font_color", Color(1, 0.1, 0.1))
	
	if wanted_stars:
		for i in range(wanted_stars.get_child_count()):
			var star = wanted_stars.get_child(i)
			if i < level:
				star.text = "★"
				if level == 3:
					star.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
				else:
					star.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
			else:
				star.text = "☆"
				star.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	
	# Minimap visibility
	if minimap_container:
		minimap_container.visible = level > 0

func _flash_wanted_panel():
	if not wanted_panel:
		return
	var tween = create_tween()
	tween.tween_property(wanted_panel, "modulate", Color(1.5, 1.5, 1.5, 1), 0.15)
	tween.tween_property(wanted_panel, "modulate", Color(1, 1, 1, 1), 0.25)

func _on_police_alert(message: String, duration: float):
	show_police_alert(message, duration)

func show_police_alert(message: String, duration: float = 3.0):
	if not police_alert_panel:
		police_alert_panel = get_node_or_null("TopCenter/PoliceAlertPanel")
		if police_alert_panel:
			police_alert_label = police_alert_panel.get_node_or_null("PoliceAlertLabel")
	
	if police_alert_panel and police_alert_label:
		police_alert_label.text = message
		police_alert_panel.visible = true
		police_alert_panel.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(police_alert_panel, "modulate:a", 1.0, 0.2)
		await get_tree().create_timer(duration).timeout
		var tween2 = create_tween()
		tween2.tween_property(police_alert_panel, "modulate:a", 0.0, 0.3)
		await tween2.finished
		police_alert_panel.visible = false

func _on_pursuit_started(level: int):
	current_pursuit_state = 2 # PURSUIT
	_update_wanted_display(level)
	if minimap_container:
		minimap_container.visible = true

func _on_pursuit_ended(escaped: bool):
	if escaped:
		show_police_alert("ESCAPED", 3.0)
		current_pursuit_state = 0
		# Keep wanted visible for decay
		await get_tree().create_timer(5.0).timeout
		if current_wanted_level == 0 and minimap_container:
			minimap_container.visible = false

# Steering - Phase 4 gradual
func _on_steer_left_down():
	target_steering_input = -1.0

func _on_steer_right_down():
	target_steering_input = 1.0

func _on_steer_up():
	target_steering_input = 0.0

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
		if current_vehicle:
			var cam_pivot = current_vehicle.get_node_or_null("CameraPivot")
			if cam_pivot and cam_pivot.has_method("add_camera_rotation"):
				cam_pivot.add_camera_rotation(delta)
			elif cam_pivot:
				cam_pivot.rotation.y -= delta.x * 0.005
				cam_pivot.rotation.x = clamp(cam_pivot.rotation.x - delta.y * 0.005, deg_to_rad(-20), deg_to_rad(15))

func _input(event):
	if event.is_action_pressed("interact"):
		if current_vehicle and visible:
			_on_exit_pressed()

func _process(delta):
	# Gradual steering
	if target_steering_input != 0:
		steering_input = lerp(steering_input, target_steering_input, steering_speed * delta)
	else:
		steering_input = lerp(steering_input, 0.0, steering_return_speed * delta)
	
	if abs(steering_input) < 0.01:
		steering_input = 0.0
	
	_update_vehicle_steering()
	
	# Update pursuit direction arrow if in pursuit
	if current_wanted_level > 0 and minimap_container and minimap_container.visible:
		_update_pursuit_direction()

func _update_pursuit_direction():
	if not wanted_manager:
		wanted_manager = get_tree().get_first_node_in_group("wanted_manager")
		if not wanted_manager:
			return
	
	var player_pos = Vector3.ZERO
	if current_vehicle:
		player_pos = current_vehicle.global_position
	else:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player_pos = player.global_position
	
	var last_known = wanted_manager.get_last_known_position() if wanted_manager.has_method("get_last_known_position") else Vector3.ZERO
	
	# For minimap, show direction to police or last known
	var police_vehicles = get_tree().get_nodes_in_group("police")
	if police_vehicles.size() > 0 and player_pos != Vector3.ZERO:
		var closest = police_vehicles[0]
		var closest_dist = player_pos.distance_to(closest.global_position)
		for p in police_vehicles:
			var d = player_pos.distance_to(p.global_position)
			if d < closest_dist:
				closest = p
				closest_dist = d
		
		if pursuit_direction_label:
			var dir = (closest.global_position - player_pos).normalized()
			var angle = atan2(dir.x, dir.z)
			# Convert to compass
			var deg = rad_to_deg(angle)
			if deg < 0:
				deg += 360
			var compass = "N"
			if deg >= 22.5 and deg < 67.5:
				compass = "NE"
			elif deg >= 67.5 and deg < 112.5:
				compass = "E"
			elif deg >= 112.5 and deg < 157.5:
				compass = "SE"
			elif deg >= 157.5 and deg < 202.5:
				compass = "S"
			elif deg >= 202.5 and deg < 247.5:
				compass = "SW"
			elif deg >= 247.5 and deg < 292.5:
				compass = "W"
			elif deg >= 292.5 and deg < 337.5:
				compass = "NW"
			
			pursuit_direction_label.text = "%s %.0fm" % [compass, closest_dist]
