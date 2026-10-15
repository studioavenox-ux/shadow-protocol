extends CanvasLayer

# Game HUD - Phase 2 Polished
# Includes mission info, health, stamina, mobile controls, interaction prompt, dialogue
# Improvements: larger touch targets, better joystick, improved camera drag, dialogue support

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

# Mobile controls - Phase 2 larger targets
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

# Joystick state
var _joystick_vector: Vector2 = Vector2.ZERO
var _max_joystick_dist: float = 60.0
var _joystick_active: bool = false
var _joystick_touch_index: int = -1

# Camera drag
var _camera_touch_index: int = -1
var _last_camera_pos: Vector2 = Vector2.ZERO

func _ready():
	print("[GameHUD] Phase 2 - Initializing polished HUD")
	
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
		if player.has_signal("stamina_changed"):
			player.stamina_changed.connect(_on_stamina_changed)
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_health_changed)
		if player.has_signal("animation_state_changed"):
			player.animation_state_changed.connect(_on_animation_state_changed)
	
	if mission_manager:
		if mission_manager.has_signal("objective_updated"):
			mission_manager.objective_updated.connect(_on_objective_updated)
		if mission_manager.has_signal("show_notification"):
			mission_manager.show_notification.connect(_on_show_notification)
		if mission_manager.has_signal("mission_completed"):
			mission_manager.mission_completed.connect(_on_mission_completed)
		if mission_manager.has_signal("dialogue_started"):
			mission_manager.dialogue_started.connect(_on_dialogue_started)
	
	# Setup mobile controls
	_setup_mobile_controls()
	
	# Initial UI state
	interaction_prompt.visible = false
	notification_panel.visible = false
	interact_button.disabled = true
	interact_button.modulate.a = 0.5
	
	# Improve touch target sizes for Phase 2
	_apply_phase2_ui_polish()
	
	if mission_title_label:
		mission_title_label.text = "A NEW BEGINNING"
	if objective_label:
		objective_label.text = "Explore Blackwater City"
	
	print("[GameHUD] HUD ready - Phase 2 polished")

func _apply_phase2_ui_polish():
	# Larger touch targets for Android
	if joystick_base:
		joystick_base.custom_minimum_size = Vector2(140, 140)
		_max_joystick_dist = 60.0
	if joystick_knob:
		joystick_knob.custom_minimum_size = Vector2(60, 60)
	
	# Buttons 72x72 minimum for comfortable touch (was 64)
	for btn in [jump_button, sprint_button, interact_button]:
		if btn:
			btn.custom_minimum_size = Vector2(72, 72)
	
	if pause_button:
		pause_button.custom_minimum_size = Vector2(48, 48)
	
	print("[GameHUD] Applied Phase 2 touch target improvements")

func _setup_mobile_controls():
	if joystick_base:
		joystick_base.gui_input.connect(_on_joystick_input)
	if camera_area:
		camera_area.gui_input.connect(_on_camera_area_input)
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
	
	var center = joystick_base.size / 2
	
	if event is InputEventScreenTouch:
		if event.pressed:
			var base_rect = joystick_base.get_global_rect()
			if base_rect.has_point(event.position):
				_joystick_touch_index = event.index
				_joystick_active = true
				var touch_pos = event.position - base_rect.position
				_update_joystick(touch_pos, center)
		else:
			if event.index == _joystick_touch_index:
				_reset_joystick(center)
	
	elif event is InputEventScreenDrag:
		if event.index == _joystick_touch_index and _joystick_active:
			var base_rect = joystick_base.get_global_rect()
			var touch_pos = event.position - base_rect.position
			_update_joystick(touch_pos, center)
	
	# Mouse fallback for PC testing - improved
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var base_rect = joystick_base.get_global_rect()
				if base_rect.has_point(event.position):
					_joystick_active = true
					var touch_pos = event.position - base_rect.position
					_update_joystick(touch_pos, center)
			else:
				if _joystick_active:
					_reset_joystick(center)
	
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _joystick_active:
		var base_rect = joystick_base.get_global_rect()
		var touch_pos = event.position - base_rect.position
		# Only update if still somewhat near joystick (allow drag outside)
		_update_joystick(touch_pos, center)

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
	
	if player and player.has_method("set_move_input"):
		var move_vec = Vector2(vector.x, -vector.y)
		player.set_move_input(move_vec)

func _reset_joystick(center: Vector2):
	_joystick_active = false
	_joystick_touch_index = -1
	joystick_knob.position = center - joystick_knob.size / 2
	_joystick_vector = Vector2.ZERO
	if player and player.has_method("set_move_input"):
		player.set_move_input(Vector2.ZERO)

func _on_camera_area_input(event: InputEvent):
	# Improved camera drag with touch index tracking
	if event is InputEventScreenTouch:
		if event.pressed:
			var area_rect = camera_area.get_global_rect()
			if area_rect.has_point(event.position):
				# Check if not over buttons
				_camera_touch_index = event.index
				_last_camera_pos = event.position
		else:
			if event.index == _camera_touch_index:
				_camera_touch_index = -1
	
	elif event is InputEventScreenDrag:
		if event.index == _camera_touch_index:
			var delta = event.position - _last_camera_pos
			_last_camera_pos = event.position
			# Apply with smoothing
			if camera_controller and camera_controller.has_method("add_camera_rotation"):
				camera_controller.add_camera_rotation(delta)
			elif player:
				var cam_pivot = player.get_node_or_null("CameraPivot")
				if cam_pivot and cam_pivot.has_method("add_camera_rotation"):
					cam_pivot.add_camera_rotation(delta)
	
	# Mouse fallback
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if camera_controller and camera_controller.has_method("add_camera_rotation"):
			camera_controller.add_camera_rotation(event.relative * 0.6)

func _on_jump_pressed():
	print("[GameHUD] Jump button - Phase 2")
	if player and player.has_method("queue_jump"):
		player.queue_jump()
	Input.action_press("jump")
	await get_tree().process_frame
	Input.action_release("jump")
	# Haptic feedback placeholder
	_animate_button(jump_button)

func _on_sprint_down():
	print("[GameHUD] Sprint down")
	if player and player.has_method("set_sprinting"):
		player.set_sprinting(true)
	_animate_button(sprint_button)

func _on_sprint_up():
	print("[GameHUD] Sprint up")
	if player and player.has_method("set_sprinting"):
		player.set_sprinting(false)

func _on_interact_pressed():
	print("[GameHUD] Interact button")
	if current_interactable:
		current_interactable.interact()
	Input.action_press("interact")
	await get_tree().process_frame
	Input.action_release("interact")
	_animate_button(interact_button)

func _on_pause_pressed():
	print("[GameHUD] Pause pressed")
	if GameManager:
		GameManager.pause_game()
	var pause_menu = get_node_or_null("../PauseMenu") or get_node_or_null("/root/World/UI/PauseMenu")
	if pause_menu:
		pause_menu.visible = true

func _animate_button(btn: Button):
	if btn == null:
		return
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.08)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_ease(Tween.EASE_OUT)

func _on_stamina_changed(current: float, max_val: float):
	if stamina_bar:
		stamina_bar.value = (current / max_val) * 100.0
		# Change color when low
		if current / max_val < 0.25:
			stamina_bar.modulate = Color(1, 0.5, 0.5)
		else:
			stamina_bar.modulate = Color(1, 1, 1)
	if stamina_label:
		stamina_label.text = "STA: %d%%" % int((current / max_val) * 100)

func _on_health_changed(current: float, max_val: float):
	if health_bar:
		health_bar.value = (current / max_val) * 100.0
	if health_label:
		health_label.text = "HP: %d%%" % int((current / max_val) * 100)

func _on_animation_state_changed(new_state: String):
	# Could update HUD based on animation state (e.g., show sprinting indicator)
	if new_state == "sprinting" and sprint_button:
		sprint_button.modulate = Color(0.8, 1.0, 0.8)
	elif sprint_button:
		sprint_button.modulate = Color(1, 1, 1)

func _on_objective_updated(index: int, description: String, completed: bool):
	if objective_label:
		objective_label.text = description
		if completed:
			objective_label.modulate = Color(0.5, 1.0, 0.5)
			# Flash animation
			var tween = create_tween()
			tween.tween_property(objective_label, "modulate", Color(1, 1, 1), 0.5)
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
	if objective_label:
		objective_label.text = "Mission Complete! Welcome to Blackwater City."
		objective_label.modulate = Color(0.647, 0.122, 0.169)

func _on_dialogue_started(speaker: String):
	print("[GameHUD] Dialogue started with ", speaker)
	show_notification("Talking to " + speaker + "...", 2.0)

func set_interaction_prompt(interactable: Interactable):
	current_interactable = interactable
	if interactable and interactable.can_interact():
		interaction_prompt.visible = true
		if interaction_label:
			interaction_label.text = "[E] " + interactable.get_prompt()
		if interact_button:
			interact_button.disabled = false
			interact_button.modulate.a = 1.0
			var tween = create_tween()
			tween.set_loops(2)
			tween.tween_property(interact_button, "scale", Vector2(1.15, 1.15), 0.15)
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
	if event.is_action_pressed("interact"):
		if current_interactable:
			current_interactable.interact()
