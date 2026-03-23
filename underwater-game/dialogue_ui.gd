# dialogue_ui.gd
# Attach to a CanvasLayer (or Control) node that contains:
#   - Panel (background box)
#     - VBoxContainer
#       - HBoxContainer
#         - TextureRect  (name: PortraitTexture)
#         - Label        (name: SpeakerLabel)
#       - RichTextLabel  (name: DialogueText)
#   - Label              (name: PromptLabel)  e.g. "[E] Continue"
#
# Wire up DialogueManager signals in _ready().

extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var portrait_texture: TextureRect = $Panel/VBoxContainer/HBoxContainer/PortraitTexture
@onready var speaker_label: Label = $Panel/VBoxContainer/HBoxContainer/SpeakerLabel
@onready var dialogue_text: RichTextLabel = $Panel/VBoxContainer/DialogueText
@onready var prompt_label: Label = $Panel/PromptLabel

# Typewriter effect
var _typewriter_tween: Tween = null
@export var typewriter_speed: float = 0.04  # Seconds per character

func _ready() -> void:
	panel.hide()
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.line_advanced.connect(_on_line_advanced)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


func _on_dialogue_started() -> void:
	panel.show()
	prompt_label.text = "[E] Continue"


func _on_line_advanced(speaker: String, text: String, portrait: Texture2D) -> void:
	speaker_label.text = speaker

	if portrait:
		portrait_texture.texture = portrait
		portrait_texture.show()
	else:
		portrait_texture.hide()

	# Typewriter effect
	dialogue_text.text = ""
	dialogue_text.visible_ratio = 0.0

	if _typewriter_tween:
		_typewriter_tween.kill()

	dialogue_text.text = text
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(
		dialogue_text, "visible_ratio", 1.0,
		text.length() * typewriter_speed
	)


func _on_dialogue_ended() -> void:
	if _typewriter_tween:
		_typewriter_tween.kill()
	panel.hide()
