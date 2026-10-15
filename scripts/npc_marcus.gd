extends Interactable

# Marcus Reed - First contact in Blackwater City
# Part of mission "A NEW BEGINNING"

@export var npc_name: String = "Marcus Reed"
@export var dialogue_lines: Array[String] = [
	"Alex... you actually came back.",
	"Blackwater isn't the same city you left. It's worse.",
	"The old garage is still ours. For now.",
	"Listen, I got a job. Simple courier run. You in?",
	"Every choice leaves a trace, kid. Remember that."
]
@export var is_mission_critical: bool = true

var current_dialogue_index: int = 0
var has_talked: bool = false

signal dialogue_started(npc_name: String)
signal dialogue_line_shown(line: String, index: int)
signal dialogue_finished(npc_name: String)
signal mission_trigger_completed

func _ready():
	super._ready()
	prompt_text = "Talk to Marcus Reed"
	interaction_id = "marcus_reed"
	one_shot = false
	print("[Marcus] NPC ready at position: ", global_position)

func interact():
	if has_talked and not is_mission_critical:
		# Already talked, show last line again
		emit_signal("dialogue_line_shown", dialogue_lines[-1], dialogue_lines.size() - 1)
		return
	
	super.interact()
	has_talked = true
	_start_dialogue()

func _start_dialogue():
	emit_signal("dialogue_started", npc_name)
	current_dialogue_index = 0
	_show_next_line()

func _show_next_line():
	if current_dialogue_index < dialogue_lines.size():
		var line = dialogue_lines[current_dialogue_index]
		emit_signal("dialogue_line_shown", line, current_dialogue_index)
		print("[Marcus] Dialogue ", current_dialogue_index, ": ", line)
		current_dialogue_index += 1
		# Auto-advance after delay, or wait for interact again
		# For prototype, we'll use timer
		await get_tree().create_timer(2.5).timeout
		if current_dialogue_index < dialogue_lines.size():
			_show_next_line()
		else:
			_finish_dialogue()
	else:
		_finish_dialogue()

func _finish_dialogue():
	emit_signal("dialogue_finished", npc_name)
	if is_mission_critical:
		emit_signal("mission_trigger_completed")
		print("[Marcus] Mission trigger completed - A NEW BEGINNING")
	
	# Update prompt after first talk
	prompt_text = "Talk to Marcus Reed [Done]"

func advance_dialogue():
	# Called when player presses interact during dialogue
	if current_dialogue_index < dialogue_lines.size():
		_show_next_line()

func reset_dialogue():
	has_talked = false
	current_dialogue_index = 0
	prompt_text = "Talk to Marcus Reed"
	has_been_used = false
	monitoring = true
