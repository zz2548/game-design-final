# dialogue_manager.gd
# AUTOLOAD: Add to Project Settings > Autoload as "DialogueManager"
#
# Dialogue data format (Dictionary):
# {
#   "speaker": "Diver",
#   "lines": [
#     "The pressure gauge is broken.",
#     "I need to find another way out.",
#   ],
#   "portrait": preload("res://ui/portraits/diver.png")  # optional
# }
#
# Usage:
#   DialogueManager.start_dialogue(my_dialogue_dict)

extends Node

# Keep processing even while the scene tree is paused so dialogue can drive
# input and advance lines.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

signal dialogue_started
signal line_advanced(speaker: String, text: String, portrait: Texture2D)
signal dialogue_ended

var _lines: Array = []
var _current_index: int = 0
var _current_speaker: String = ""
var _current_portrait: Texture2D = null
var is_active: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()

# ─── Public API ──────────────────────────────────────────────────────────────

func start_dialogue(dialogue: Dictionary) -> void:
	if is_active:
		return  # Don't interrupt ongoing dialogue

	_lines = dialogue.get("lines", [])
	_current_speaker = dialogue.get("speaker", "")
	_current_portrait = dialogue.get("portrait", null)
	_current_index = 0
	is_active = true
	get_tree().paused = true

	emit_signal("dialogue_started")
	_show_current_line()


func advance() -> void:
	_current_index += 1
	if _current_index >= _lines.size():
		_end_dialogue()
	else:
		_show_current_line()


func end_dialogue_early() -> void:
	_end_dialogue()

# ─── Private ─────────────────────────────────────────────────────────────────

func _show_current_line() -> void:
	var text: String = _lines[_current_index]
	emit_signal("line_advanced", _current_speaker, text, _current_portrait)


func _end_dialogue() -> void:
	is_active = false
	_lines = []
	_current_index = 0
	get_tree().paused = false
	emit_signal("dialogue_ended")
