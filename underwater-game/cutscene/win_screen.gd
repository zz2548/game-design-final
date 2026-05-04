extends Node

const TYPEWRITER_SPEED : float = 0.06
const FADE_DURATION    : float = 0.65

@onready var _label   : RichTextLabel = $CenterContainer/Label
@onready var _prompt  : Label         = $PromptLabel
@onready var _overlay : ColorRect     = $FadeOverlay

var _is_typing : bool  = false
var _typewriter_tween : Tween = null


func _ready() -> void:
	MusicManager.stop()

	_overlay.modulate.a = 1.0
	_prompt.modulate.a  = 0.0

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	_label.add_theme_font_override("normal_font", font)
	_prompt.add_theme_font_override("font", font)
	_prompt.add_theme_font_size_override("font_size", 13)
	_prompt.add_theme_color_override("font_color", Color(0.30, 0.58, 0.72, 0.8))

	_label.text = (
		"[center][color=#11cc66][font_size=64][b]MISSION COMPLETE[/b][/font_size][/color]"
		+ "\n\n"
		+ "[color=#404040][font_size=13]Kappa Station neutralised. Surface team en route.[/font_size][/color][/center]"
	)
	_label.visible_ratio = 0.0

	_fade_overlay(0.0, FADE_DURATION)

	_is_typing = true
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_interval(FADE_DURATION * 0.6)
	_typewriter_tween.tween_property(
		_label, "visible_ratio", 1.0,
		_label.get_total_character_count() * TYPEWRITER_SPEED
	)
	_typewriter_tween.finished.connect(_on_typewriter_done)


func _unhandled_input(event: InputEvent) -> void:
	var pressed := event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	if not pressed and event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	if not pressed:
		return
	get_viewport().set_input_as_handled()

	if _is_typing:
		_finish_typewriter()
	else:
		_return_to_menu()


func _finish_typewriter() -> void:
	if _typewriter_tween:
		_typewriter_tween.kill()
	_label.visible_ratio = 1.0
	_is_typing = false
	_on_typewriter_done()


func _on_typewriter_done() -> void:
	_is_typing = false
	var tw := create_tween()
	tw.tween_property(_prompt, "modulate:a", 1.0, 0.5)


func _return_to_menu() -> void:
	_fade_overlay(1.0, FADE_DURATION)
	await get_tree().create_timer(FADE_DURATION).timeout
	get_tree().change_scene_to_file("res://main.tscn")


func _fade_overlay(target_alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", target_alpha, duration)
