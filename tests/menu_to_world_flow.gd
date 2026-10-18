extends SceneTree

# Headless menu-to-world flow test.
#
# Run from the project root with the project's own configuration (autoloads and
# run/main_scene come from project.godot):
#   godot --headless --path . -s res://tests/menu_to_world_flow.gd
#   godot --headless --path . -s res://tests/menu_to_world_flow.gd -- continue
#
# What it checks:
#   - project.godot run/main_scene is the main menu and GameManager is registered
#   - the menu reaches full opacity and its New Game (or Continue) button is on screen
#   - pressing the button makes world.tscn the current scene
#   - the world has an active 3D camera, the Player, the GameHUD, and one DialogueUI
#
# Limits: the button press is simulated with the button's pressed signal, and no
# pixels are read. This verifies the scene graph and transition, not what is drawn.
# Exit code: 0 when every check passes, 1 otherwise.

const MENU_PATH := "res://scenes/main_menu.tscn"
const WORLD_PATH := "res://scenes/world.tscn"

var _phase := 0
var _t0 := 0
var _failures: Array[String] = []
var _button_name := "NewGameButton"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "continue":
		_button_name = "ContinueButton"
	_t0 = Time.get_ticks_msec()
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_check(main_scene == MENU_PATH, "application/run/main_scene is " + MENU_PATH + " (found '" + main_scene + "')")
	_check(root.get_node_or_null("GameManager") != null, "GameManager autoload is registered in the scene root")
	change_scene_to_file(MENU_PATH)

func _check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		print("FAIL: ", what)
		_failures.append(what)

func _elapsed() -> int:
	return Time.get_ticks_msec() - _t0

func _finish() -> bool:
	if _failures.is_empty():
		print("FLOW RESULT: PASSED (", _button_name, ")")
		quit(0)
	else:
		print("FLOW RESULT: FAILED (", _failures.size(), " check(s))")
		quit(1)
	return true

func _process(_delta: float) -> bool:
	var scene: Node = current_scene
	var scene_path: String = scene.scene_file_path if scene else ""
	match _phase:
		0:
			# Wait for the menu and its 0.8 s entrance fade to finish.
			if scene_path == MENU_PATH and _elapsed() > 1500:
				var menu := scene as Control
				_check(menu != null, "main menu root is a Control")
				if menu:
					_check(menu.modulate.a >= 0.99, "menu fade-in finished (modulate.a = %.2f)" % menu.modulate.a)
				var btn := scene.get_node_or_null("CenterContainer/VBoxContainer/MenuButtons/" + _button_name) as Button
				_check(btn != null, _button_name + " exists")
				if btn:
					_check(btn.is_visible_in_tree() and btn.size.x > 0.0 and btn.size.y > 0.0,
						_button_name + " is visible on screen (size %s)" % str(btn.size))
					_check(not btn.disabled, _button_name + " is enabled")
					btn.pressed.emit()
				_phase = 1
				_t0 = Time.get_ticks_msec()
			elif _elapsed() > 15000:
				_check(false, "main menu appeared within 15 s (current scene: " + scene_path + ")")
				return _finish()
		1:
			if scene_path == WORLD_PATH:
				_check(true, "world.tscn became the current scene after the button press")
				_phase = 2
				_t0 = Time.get_ticks_msec()
			elif _elapsed() > 10000:
				_check(false, "world.tscn became the current scene within 10 s (current scene: " + scene_path + ")")
				return _finish()
		2:
			# Give the world's _ready() coroutines time to run.
			if _elapsed() > 2500:
				if scene == null:
					_check(false, "world scene is still loaded after the transition")
					return _finish()
				var cam := root.get_camera_3d()
				_check(cam != null and cam.current, "an active 3D camera is the viewport camera")
				_check(scene.get_node_or_null("Player") != null, "Player node exists")
				_check(scene.get_node_or_null("UI/GameHUD") != null, "GameHUD exists under UI")
				var dialogue_members := get_nodes_in_group("dialogue_ui").size()
				_check(dialogue_members == 1, "exactly one node is in group dialogue_ui (found %d)" % dialogue_members)
				return _finish()
	return false
