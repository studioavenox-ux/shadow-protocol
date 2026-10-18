extends Control

# Main Menu - SHADOW PROTOCOL
# Cinematic dark design with logo and menu options

@onready var new_game_button: Button = $CenterContainer/VBoxContainer/MenuButtons/NewGameButton
@onready var continue_button: Button = $CenterContainer/VBoxContainer/MenuButtons/ContinueButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/MenuButtons/SettingsButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/MenuButtons/ExitButton
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleContainer/TitleLabel
@onready var tagline_label: Label = $CenterContainer/VBoxContainer/TitleContainer/TaglineLabel
@onready var version_label: Label = $BottomBar/VersionLabel
@onready var city_label: Label = $BottomBar/CityLabel
@onready var settings_panel: Panel = $SettingsPanel
@onready var settings_back_button: Button = $SettingsPanel/VBoxContainer/BackButton

var menu_tween: Tween = null

func _ready():
	print("[MainMenu] Initializing main menu")
	
	# Setup UI
	_setup_ui()
	
	# Connect buttons
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
	if settings_back_button:
		settings_back_button.pressed.connect(_on_settings_back_pressed)
	
	# Check continue availability
	_update_continue_button()
	
	# Animate entrance
	_animate_entrance()
	
	# Set version
	if version_label:
		version_label.text = "v0.1.0 PROTOTYPE | BLACKWATER CITY"
	
	print("[MainMenu] Main menu ready - EVERY CHOICE LEAVES A TRACE")

func _setup_ui():
	# Style buttons with SHADOW PROTOCOL palette
	var buttons = [new_game_button, continue_button, settings_button, exit_button]
	for btn in buttons:
		if btn == null:
			continue
		# Ensure minimum size for touch
		btn.custom_minimum_size = Vector2(280, 56)
	
	if settings_panel:
		settings_panel.visible = false

func _animate_entrance():
	# Fade in and slide up animation
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	
	# Animate title
	if title_label:
		title_label.modulate.a = 0.0
		title_label.position.y += 30
		var t2 = create_tween()
		t2.tween_property(title_label, "modulate:a", 1.0, 0.6).set_delay(0.3)
		t2.parallel().tween_property(title_label, "position:y", title_label.position.y - 30, 0.6).set_ease(Tween.EASE_OUT).set_delay(0.3)

func _update_continue_button():
	if continue_button == null:
		return
	if GameManager and GameManager.has_save:
		continue_button.disabled = false
		continue_button.modulate.a = 1.0
		continue_button.text = "CONTINUE"
	else:
		continue_button.disabled = true
		continue_button.modulate.a = 0.5
		continue_button.text = "CONTINUE [NO SAVE]"

func _on_new_game_pressed():
	print("[MainMenu] New Game pressed")
	# Button feedback
	_animate_button_press(new_game_button)
	
	# Confirm if save exists
	if GameManager and GameManager.has_save:
		# For prototype, just start new game directly
		# In full version, show confirmation dialog
		print("[MainMenu] Overwriting existing save")
	
	# Transition effect
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	var started := false
	if GameManager:
		started = GameManager.new_game()
	else:
		started = get_tree().change_scene_to_file("res://scenes/world.tscn") == OK
	if not started:
		_restore_after_failed_transition()

func _on_continue_pressed():
	print("[MainMenu] Continue pressed")
	if not GameManager or not GameManager.has_save:
		print("[MainMenu] No save to continue")
		return
	
	_animate_button_press(continue_button)
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	var started := false
	if GameManager:
		started = GameManager.continue_game()
	else:
		started = get_tree().change_scene_to_file("res://scenes/world.tscn") == OK
	if not started:
		_restore_after_failed_transition()

# The menu fades out before the scene change. If the change fails, the menu
# would stay transparent and the window would look blank, so bring it back.
func _restore_after_failed_transition() -> void:
	modulate.a = 1.0
	push_error("[MainMenu] Scene change to the world failed; the menu has been restored.")

func _on_settings_pressed():
	print("[MainMenu] Settings pressed")
	_animate_button_press(settings_button)
	if settings_panel:
		settings_panel.visible = true
		settings_panel.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(settings_panel, "modulate:a", 1.0, 0.3)

func _on_settings_back_pressed():
	if settings_panel:
		var tween = create_tween()
		tween.tween_property(settings_panel, "modulate:a", 0.0, 0.2)
		await tween.finished
		settings_panel.visible = false

func _on_exit_pressed():
	print("[MainMenu] Exit pressed")
	_animate_button_press(exit_button)
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	
	get_tree().quit()

func _animate_button_press(button: Button):
	if button == null:
		return
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.08)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.08)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if settings_panel and settings_panel.visible:
			_on_settings_back_pressed()
