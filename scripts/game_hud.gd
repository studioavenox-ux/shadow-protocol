extends CanvasLayer

# Game HUD - Main in-game UI
# Includes mission info, health, stamina, mobile controls, interaction prompt

@onready var mission_title_label: Label = $TopBar/MissionInfo/MissionTitle
@onready var objective_label: Label = $TopBar/MissionInfo/ObjectiveLabel
@onready var health_bar: ProgressBar = $TopBar/StatsContainer/HealthBar
@onready var stamina_bar: ProgressBar = $TopBar/StatsContainer/StaminaBar
@onready var health_label: Label = $TopBar/StatsContainer/HealthLabel
@onready var stamina_label: Label = $TopBar/StatsContainer/StaminaLabel
@onready var interaction_prompt: Panel = $CenterContainer/InteractionPrompt
@onready var interaction_label: Label = $CenterContainer/InteractionPrompt/InteractionLabel
@onready var notification_panel: Panel = $TopCenter/NotificationPanel
@onready var notification_label: Label = $TopCenter/NotificationPanel/NotificationLabel
@onready var pause_button: Button = $TopBar/PauseButton

# Mobile controls
@onready var joystick_base: Panel = $BottomBar/JoystickContainer/JoystickBase
@onready var joystick_knob: Panel = $BottomBar/JoystickContainer/JoystickBase/JoystickKnob
@onready var camera_area: Control = $CameraLookArea
@onready var jump_button: Button = $BottomBar/RightControls/JumpButton
@onready var sprint_button: Button = $BottomBar/RightControls/SprintButton
@onready var interact_button: Button = $BottomBar/RightControls/InteractButton

var player: CharacterBody3D = null
var mission_manager = null
var camera_controller = null
var current_interactable: Interactable = null

var notification_queue: Array = []
var is_showing_notification: bool = false

func _ready():
	print("[GameHUD] Initializing HUD")
	
	# Find player and managers
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("../../Player") or get_node_or_null("../Player") or get_node_or_null("/root/World/Player")
	
	mission_manager = get_tree().get_first_node_in_group("mission_manager")
	if not mission_manager:
		mission_manager = get_node_or_null("../../MissionManager") or get_node_or_null("../MissionManager")
	
	if player:
		var cam_pivot = player.get_node_or_null("CameraPivot")
		if cam_pivot:
			camera_controller = cam_pivot
		# Connect player signals
		if player.has_signal("stamina_changed"):
			player.stamina_changed.connect(_on_stamina_changed)
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_health_changed)
	
	if mission_manager:
		if mission_manager.has_signal("objective_updated"):
			mission_manager.objective_updated.connect(_on_objective_updated)
		if mission_manager.has_signal("show_notification"):
			mission_manager.show_notification.connect(_on_show_notification)
		if mission_manager.has_signal("mission_completed"):
			mission_manager.mission_completed.connect(_on_mission_completed)
	
	# Setup mobile controls input
	_setup_mobile_controls()
	
	# Initial UI state
	interaction_prompt.visible = false
	notification_panel.visible = false
	interact_button.disabled = true
	interact_button.modulate.a = 0.5
	
	# Set initial mission text
	if mission_title_label:
		mission_title_label.text = "A NEW BEGINNING"
	if objective_label:
		objective_label.text = "Explore Blackwater City"
	
	print("[GameHUD] HUD ready")

func _setup_mobile_controls():
	# Connect joystick area
	if joystick_base:
		joystick_base.gui_input.connect(_on_joystick_input)
	
	# Connect camera look area
	if camera_area:
		camera_area.gui_input.connect(_on_camera_area_input)
	
	# Connect buttons
	if jump_button:
		jump_button.pressed.connect(_on_jump_pressed)
	if sprint_button:
		sprint_button.button_down.connect(_on_sprint_down)
		sprint_button.button_up.connect(_on_sprint_up)
	if interact_button:
		interact_button.pressed.connect(_on_interact_pressed)
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)

func _on_joystick_input(event: InputEvent):
	if not joystick_base or not joystick_knob:
		return
	
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		var center = joystick_base.size / 2
		var touch_pos = Vector2.ZERO
		
		if event is InputEventScreenTouch:
			if event.pressed:
				# Check if within base
				var global_pos = event.position
				var base_global_rect = joystick_base.get_global_rect()
				if base_global_rect.has_point(global_pos):
					touch_pos = global_pos - base_global_rect.position
					_update_joystick(touch_pos, center)
			else:
				_reset_joystick(center)
		elif event is InputEventScreenDrag:
			var base_global_rect = joystick_base.get_global_rect()
			touch_pos = event.position - base_global_rect.position
			_update_joystick(touch_pos, center)
	
	# Mouse fallback for PC testing
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var base_global_rect = joystick_base.get_global_rect()
				if base_global_rect.has_point(event.position):
					var touch_pos = event.position - base_global_rect.position
					_update_joystick(touch_pos, joystick_base.size / 2)
			else:
				_reset_joystick(joystick_base.size / 2)
	
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var base_global_rect = joystick_base.get_global_rect()
		if base_global_rect.has_point(event.position):
			var touch_pos = event.position - base_global_rect.position
			_update_joystick(touch_pos, joystick_base.size / 2)

var _joystick_vector: Vector2 = Vector2.ZERO
var _max_joystick_dist: float = 50.0

func _update_joystick(touch_pos: Vector2, center: Vector2):
	var offset = touch_pos - center
	var distance = offset.length()
	
	if distance > _max_joystick_dist:
		offset = offset.normalized() * _max_joystick_dist
	
	joystick_knob.position = center + offset - joystick_knob.size / 2
	
	var vector = offset / _max_joystick_dist
	if vector.length() < 0.15:
		vector = Vector2.ZERO
	
	_joystick_vector = vector
	
	# Send to player
	if player and player.has_method("set_move_input"):
		# Convert joystick to movement (joystick Y inverted for forward)
		var move_vec = Vector2(vector.x, -vector.y)
		player.set_move_input(move_vec)

func _reset_joystick(center: Vector2):
	joystick_knob.position = center - joystick_knob.size / 2
	_joystick_vector = Vector2.ZERO
	if player and player.has_method("set_move_input"):
		player.set_move_input(Vector2.ZERO)

func _on_camera_area_input(event: InputEvent):
	if event is InputEventScreenDrag:
		var delta = event.relative
		# Send to camera controller
		if camera_controller and camera_controller.has_method("add_camera_rotation"):
			camera_controller.add_camera_rotation(delta)
		elif player:
			var cam_pivot = player.get_node_or_null("CameraPivot")
			if cam_pivot and cam_pivot.has_method("add_camera_rotation"):
				cam_pivot.add_camera_rotation(delta)
	
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if camera_controller and camera_controller.has_method("add_camera_rotation"):
			camera_controller.add_camera_rotation(event.relative * 0.5)

func _on_jump_pressed():
	print("[GameHUD] Jump button")
	if player and player.has_method("queue_jump"):
		player.queue_jump()
	# Also trigger input action for compatibility
	Input.action_press("jump")
	await get_tree().process_frame
	Input.action_release("jump")

func _on_sprint_down():
	print("[GameHUD] Sprint down")
	if player and player.has_method("set_sprinting"):
		player.set_sprinting(true)

func _on_sprint_up():
	print("[GameHUD] Sprint up")
	if player and player.has_method("set_sprinting"):
		player.set_sprinting(false)

func _on_interact_pressed():
	print("[GameHUD] Interact button")
	if current_interactable:
		current_interactable.interact()
	# Also trigger input action
	Input.action_press("interact")
	await get_tree().process_frame
	Input.action_release("interact")

func _on_pause_pressed():
	print("[GameHUD] Pause pressed")
	if GameManager:
		GameManager.pause_game()
	# Show pause menu
	var pause_menu = get_node_or_null("../PauseMenu") or get_node_or_null("/root/World/UI/PauseMenu")
	if pause_menu:
		pause_menu.visible = true

func _on_stamina_changed(current: float, max_val: float):
	if stamina_bar:
		stamina_bar.value = (current / max_val) * 100.0
	if stamina_label:
		stamina_label.text = "STA: %d%%" % int((current / max_val) * 100)

func _on_health_changed(current: float, max_val: float):
	if health_bar:
		health_bar.value = (current / max_val) * 100.0
	if health_label:
		health_label.text = "HP: %d%%" % int((current / max_val) * 100)

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
		# Fade in
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
	show_notification("MISSION COMPLETE: " + mission_name, 4.0)
	# Show special completion UI
	if objective_label:
		objective_label.text = "Mission Complete! Welcome to Blackwater City."
		objective_label.modulate = Color(0.647, 0.122, 0.169)

# Interaction system integration
func set_interaction_prompt(interactable: Interactable):
	current_interactable = interactable
	if interactable and interactable.can_interact():
		interaction_prompt.visible = true
		if interaction_label:
			interaction_label.text = "[E] " + interactable.get_prompt()
		if interact_button:
			interact_button.disabled = false
			interact_button.modulate.a = 1.0
			# Pulse animation
			var tween = create_tween()
			tween.set_loops(2)
			tween.tween_property(interact_button, "scale", Vector2(1.1, 1.1), 0.15)
			tween.tween_property(interact_button, "scale", Vector2(1.0, 1.0), 0.15)
	else:
		clear_interaction_prompt()

func clear_interaction_prompt():
	current_interactable = null
	interaction_prompt.visible = false
	if interact_button:
		interact_button.disabled = true
		interact_button.modulate.a = 0.5

func _input(event):
	# Keyboard interact
	if event.is_action_pressed("interact"):
		if current_interactable:
			current_interactable.interact()
