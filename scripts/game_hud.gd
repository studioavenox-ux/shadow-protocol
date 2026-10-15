extends CanvasLayer

# Game HUD - Phase 4 with Wanted System
# Includes mission info, health, stamina, mobile controls, interaction prompt, dialogue, wanted

@onready var mission_title_label: Label = $TopBar/HBoxContainer/MissionInfo/MissionTitle
@onready var objective_label: Label = $TopBar/HBoxContainer/MissionInfo/ObjectiveLabel
@onready var health_bar: ProgressBar = $TopBar/HBoxContainer/StatsContainer/HealthBar
@onready var stamina_bar: ProgressBar = $TopBar/HBoxContainer/StatsContainer/StaminaBar
@onready var health_label: Label = $TopBar/HBoxContainer/StatsContainer/HealthLabel
@onready var stamina_label: Label = $TopBar/HBoxContainer/StatsContainer/StaminaLabel
@onready var interaction_prompt: Panel = $CenterContainer/InteractionPrompt
@onready var interaction_label: Label = $CenterContainer/InteractionPrompt/InteractionLabel
@onready var notification_panel: Panel = $TopCenter/NotificationPanel
@onready var notification_label: Label = $TopCenter/NotificationPanel/NotificationLabel
@onready var pause_button: Button = $TopBar/HBoxContainer/PauseButton

# Mobile controls
@onready var joystick_base: Panel = $BottomBar/JoystickContainer/JoystickBase
@onready var joystick_knob: Panel = $BottomBar/JoystickContainer/JoystickBase/JoystickKnob
@onready var camera_area: Control = $CameraLookArea
@onready var jump_button: Button = $BottomBar/RightControls/JumpButton
@onready var sprint_button: Button = $BottomBar/RightControls/SprintButton
@onready var interact_button: Button = $BottomBar/RightControls/InteractButton

# Phase 4 wanted
var wanted_panel: Panel = null
var wanted_label: Label = null
var wanted_stars: HBoxContainer = null
var police_alert_panel: Panel = null
var police_alert_label: Label = null

var player: CharacterBody3D = null
var mission_manager = null
var camera_controller = null
var current_interactable: Interactable = null
var wanted_manager = null
var audio_manager = null

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

var current_wanted_level: int = 0

func _ready():
	print("[GameHUD] Phase 4 - Polished HUD with wanted system")
	
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("../../Player") as CharacterBody3D
		if player == null:
			player = get_node_or_null("../Player") as CharacterBody3D
		if player == null:
			player = get_node_or_null("/root/World/Player") as CharacterBody3D
	
	mission_manager = get_tree().get_first_node_in_group("mission_manager")
	wanted_manager = get_tree().get_first_node_in_group("wanted_manager")
	audio_manager = get_tree().get_first_node_in_group("audio_manager")
	
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
	
	if wanted_manager:
		if wanted_manager.has_signal("wanted_level_changed"):
			wanted_manager.wanted_level_changed.connect(_on_wanted_level_changed)
		if wanted_manager.has_signal("police_alert"):
			wanted_manager.police_alert.connect(_on_police_alert)
		print("[GameHUD] Connected to WantedManager")
	
	_setup_mobile_controls()
	_setup_phase4_ui()
	
	interaction_prompt.visible = false
	notification_panel.visible = false
	interact_button.disabled = true
	interact_button.modulate.a = 0.5
	
	_apply_phase2_ui_polish()
	
	if mission_title_label:
		mission_title_label.text = "A NEW BEGINNING"
	if objective_label:
		objective_label.text = "Explore Blackwater City"
	
	print("[GameHUD] HUD ready - Phase 4")

func _apply_phase2_ui_polish():
	if joystick_base:
		joystick_base.custom_minimum_size = Vector2(140, 140)
		_max_joystick_dist = 60.0
	if joystick_knob:
		joystick_knob.custom_minimum_size = Vector2(60, 60)
	
	for btn in [jump_button, sprint_button, interact_button]:
		if btn:
			btn.custom_minimum_size = Vector2(72, 72)
	
	if pause_button:
		pause_button.custom_minimum_size = Vector2(48, 48)

func _setup_phase4_ui():
	var top_bar = $TopBar
	if not top_bar:
		return
	
	# Wanted panel for on-foot HUD - compact top right
	if not has_node("TopBar/WantedPanel"):
		wanted_panel = Panel.new()
		wanted_panel.name = "WantedPanel"
		wanted_panel.custom_minimum_size = Vector2(120, 35)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.12, 0.7)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		wanted_panel.add_theme_stylebox_override("panel", style)
		
		var stats = $TopBar/HBoxContainer/StatsContainer
		if stats:
			stats.add_child(wanted_panel)
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
	
	# Police alert panel
	if not has_node("PoliceAlertPanel"):
		police_alert_panel = Panel.new()
		police_alert_panel.name = "PoliceAlertPanel"
		police_alert_panel.custom_minimum_size = Vector2(300, 36)
		police_alert_panel.visible = false
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
	
	_update_wanted_display(0)

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
	if event is InputEventScreenTouch:
		if event.pressed:
			var area_rect = camera_area.get_global_rect()
			if area_rect.has_point(event.position):
				_camera_touch_index = event.index
				_last_camera_pos = event.position
		else:
			if event.index == _camera_touch_index:
				_camera_touch_index = -1
	
	elif event is InputEventScreenDrag:
		if event.index == _camera_touch_index:
			var delta = event.position - _last_camera_pos
			_last_camera_pos = event.position
			if camera_controller and camera_controller.has_method("add_camera_rotation"):
				camera_controller.add_camera_rotation(delta)
			elif player:
				var cam_pivot = player.get_node_or_null("CameraPivot")
				if cam_pivot and cam_pivot.has_method("add_camera_rotation"):
					cam_pivot.add_camera_rotation(delta)
	
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if camera_controller and camera_controller.has_method("add_camera_rotation"):
			camera_controller.add_camera_rotation(event.relative * 0.6)

func _on_jump_pressed():
	if player and player.has_method("queue_jump"):
		player.queue_jump()
	Input.action_press("jump")
	await get_tree().process_frame
	Input.action_release("jump")
	_animate_button(jump_button)

func _on_sprint_down():
	if player and player.has_method("set_sprinting"):
		player.set_sprinting(true)
	_animate_button(sprint_button)
	# Footstep audio hook
	if audio_manager and audio_manager.has_method("set_walking"):
		audio_manager.set_walking(true, true, player.global_position if player else Vector3.ZERO)

func _on_sprint_up():
	if player and player.has_method("set_sprinting"):
		player.set_sprinting(false)
	if audio_manager and audio_manager.has_method("set_walking"):
		var moving = _joystick_vector.length() > 0.1
		audio_manager.set_walking(moving, false, player.global_position if player else Vector3.ZERO)

func _on_interact_pressed():
	if current_interactable:
		current_interactable.interact()
		if audio_manager and audio_manager.has_method("play_interaction_feedback"):
			audio_manager.play_interaction_feedback()
	Input.action_press("interact")
	await get_tree().process_frame
	Input.action_release("interact")
	_animate_button(interact_button)

func _on_pause_pressed():
	if GameManager:
		GameManager.pause_game()
	var pause_menu = get_node_or_null("../PauseMenu")
	if pause_menu == null:
		pause_menu = get_node_or_null("/root/World/UI/PauseMenu")
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
	if new_state == "sprinting" and sprint_button:
		sprint_button.modulate = Color(0.8, 1.0, 0.8)
	elif sprint_button:
		sprint_button.modulate = Color(1, 1, 1)

func _on_objective_updated(index: int, description: String, completed: bool):
	if objective_label:
		objective_label.text = description
		if completed:
			objective_label.modulate = Color(0.5, 1.0, 0.5)
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
	show_notification("Talking to " + speaker + "...", 2.0)

func _on_wanted_level_changed(new_level: int, old_level: int):
	current_wanted_level = new_level
	_update_wanted_display(new_level)
	if new_level > old_level:
		_flash_wanted_panel()
		if audio_manager and audio_manager.has_method("play_wanted_alert"):
			audio_manager.play_wanted_alert()

func _update_wanted_display(level: int):
	if not wanted_panel:
		wanted_panel = get_node_or_null("TopBar/HBoxContainer/StatsContainer/WantedPanel")
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
			if audio_manager and audio_manager.has_method("play_interaction_feedback"):
				audio_manager.play_interaction_feedback()
