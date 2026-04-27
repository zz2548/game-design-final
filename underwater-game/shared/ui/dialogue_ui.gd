extends CanvasLayer

@onready var panel: PanelContainer      = $Root/Panel
@onready var portrait_texture: TextureRect = $Root/Panel/VBox/Header/PortraitTexture
@onready var speaker_label: Label          = $Root/Panel/VBox/Header/SpeakerLabel
@onready var dialogue_text: RichTextLabel  = $Root/Panel/VBox/DialogueText
@onready var prompt_label: Label           = $Root/Panel/VBox/PromptLabel

var _typewriter_tween: Tween = null
var _is_typing: bool = false
@export var typewriter_speed: float = 0.033

func _ready() -> void:
	# Must keep processing while the tree is paused so the typewriter
	# tween and input handling still work during dialogue.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	panel.hide()
	_apply_theme()
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.line_advanced.connect(_on_line_advanced)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _unhandled_input(event: InputEvent) -> void:
	if not DialogueManager.is_active:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if _is_typing:
			# First press: finish the current line instantly
			_finish_typewriter()
			get_viewport().set_input_as_handled()
		# If not typing, let DialogueManager handle it (advance to next line)

# ── Theme ─────────────────────────────────────────────────────────────────────

func _apply_theme() -> void:
	# Panel background — dark translucent with a subtle teal border
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color        = Color(0.04, 0.09, 0.14, 0.93)
	panel_style.border_color    = Color(0.18, 0.52, 0.68, 0.75)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left   = 22.0
	panel_style.content_margin_right  = 22.0
	panel_style.content_margin_top    = 14.0
	panel_style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", panel_style)

	# Monospace/tech font — fitting for ORCA's readouts
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY

	# Speaker label — small, all-caps teal
	speaker_label.add_theme_font_override("font", font)
	speaker_label.add_theme_font_size_override("font_size", 12)
	speaker_label.add_theme_color_override("font_color", Color(0.28, 0.82, 1.0, 1.0))
	speaker_label.uppercase = true

	# Dialogue body — slightly larger, soft blue-white
	dialogue_text.add_theme_font_override("normal_font", font)
	dialogue_text.add_theme_font_size_override("normal_font_size", 15)
	dialogue_text.add_theme_color_override("default_color", Color(0.80, 0.91, 0.97, 1.0))

	# Divider tint
	var div := $Root/Panel/VBox/Divider as HSeparator
	if div:
		var sep_style := StyleBoxFlat.new()
		sep_style.bg_color = Color(0.18, 0.52, 0.68, 0.4)
		sep_style.set_content_margin_all(0)
		div.add_theme_stylebox_override("separator", sep_style)

	# Prompt — dim, right-aligned
	prompt_label.add_theme_font_override("font", font)
	prompt_label.add_theme_font_size_override("font_size", 11)
	prompt_label.add_theme_color_override("font_color", Color(0.30, 0.58, 0.72, 0.65))

# ── Dialogue signals ──────────────────────────────────────────────────────────

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
	dialogue_text.text = ""
	dialogue_text.visible_ratio = 0.0
	if _typewriter_tween:
		_typewriter_tween.kill()
	dialogue_text.text = text
	_is_typing = true
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(
		dialogue_text, "visible_ratio", 1.0,
		text.length() * typewriter_speed
	)
	_typewriter_tween.finished.connect(func(): _is_typing = false)

func _finish_typewriter() -> void:
	if _typewriter_tween:
		_typewriter_tween.kill()
	dialogue_text.visible_ratio = 1.0
	_is_typing = false

func _on_dialogue_ended() -> void:
	_finish_typewriter()
	panel.hide()
