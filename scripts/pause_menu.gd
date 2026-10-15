extends Control

# Pause Menu - In-game pause overlay
# Handles resume, restart, settings, main menu

@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $CenterContainer/VBoxContainer/RestartButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var main_menu_button: Button = $CenterContainer/VBoxContainer/MainMenuButton
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var settings_panel: Panel = $SettingsPanel
@onready var settings_back: Button = $SettingsPanel/VBoxContainer/BackButton

var is_paused: bool = false

func _ready():
	print("[PauseMenu] Initializing pause menu")
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Connect buttons
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if settings_back:
		settings_back.pressed.connect(_on_settings_back_pressed)
	
	# Connect to GameManager signals
	if GameManager:
		GameManager.game_paused.connect(_on_game_paused)
		GameManager.game_resumed.connect(_on_game_resumed)
	
	if settings_panel:
		settings_panel.visible = false
	
	print("[PauseMenu] Pause menu ready")

func _on_game_paused():
	is_paused = true
	visible = true
	# Animate in
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	print("[PauseMenu] Game paused, showing menu")

func _on_game_resumed():
	is_paused = false
	# Animate out
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	visible = false
	print("[PauseMenu] Game resumed, hiding menu")

func _on_resume_pressed():
	print("[PauseMenu] Resume pressed")
	if GameManager:
		GameManager.resume_game()
	else:
		get_tree().paused = false
		visible = false

func _on_restart_pressed():
	print("[PauseMenu] Restart pressed")
	# Confirm restart?
	if GameManager:
		GameManager.restart_mission()
	else:
		get_tree().paused = false
		get_tree().reload_current_scene()

func _on_settings_pressed():
	print("[PauseMenu] Settings pressed")
	if settings_panel:
		settings_panel.visible = true
		settings_panel.modulate.a = 0.0
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(settings_panel, "modulate:a", 1.0, 0.25)

func _on_settings_back_pressed():
	if settings_panel:
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(settings_panel, "modulate:a", 0.0, 0.2)
		await tween.finished
		settings_panel.visible = false

func _on_main_menu_pressed():
	print("[PauseMenu] Main menu pressed")
	if GameManager:
		GameManager.go_to_main_menu()
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _input(event):
	if event.is_action_pressed("pause") and visible:
		_on_resume_pressed()
	if event.is_action_pressed("ui_cancel"):
		if settings_panel and settings_panel.visible:
			_on_settings_back_pressed()
		elif visible:
			_on_resume_pressed()
