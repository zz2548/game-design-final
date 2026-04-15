extends Node

# ── Cutscene cards ────────────────────────────────────────────────────────────
# Each entry is displayed as a full-screen text card on a black background.
const CARDS: Array[String] = [
	"FORTY SECONDS BEFORE IMPACT\n\nYou were not supposed to be this deep.",

	"The Tethys-7 was on a routine transit.\nA maintenance job. Nothing classified.\n\nThen something hit you.",

	"The hull groaned.\nPressure alarms cascaded down the board.\n\nThen —\n\nsilence.",

	"IMPACT + 00:40\n\nORCA comes back online.\nDiagnostics running.\nShe does not wait to be asked.",

	"Three components.\nMissing.\n\nThe drive coupling.\nThe pressure seal.\nThe nav core.\n\nShe marks them on your HUD.",

	"You ask what hit the sub.\n\nShe considers this for 1.2 seconds.\n\n\"Insufficient data.\"",

	"The relay station ahead has gone offline.\nYour distress signal is blocked.\n\nYou are very, very deep.\n\nYou are not alone.\nYou have ORCA.\n\nThat will have to be enough.",
]

const TYPEWRITER_SPEED : float = 0.033   # seconds per character
const AUTO_ADVANCE_PAD : float = 2.2     # extra seconds after typing finishes before auto-advance
const FADE_DURATION    : float = 0.55

@onready var _label         : RichTextLabel = $CenterContainer/Label
@onready var _prompt        : Label         = $PromptLabel
@onready var _overlay       : ColorRect     = $FadeOverlay

var _card_index     : int   = 0
var _is_typing      : bool  = false
var _advancing      : bool  = false   # true while cross-fade await is running
var _typewriter_tween : Tween = null
var _auto_timer     : SceneTreeTimer = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_overlay.color = Color.BLACK
	_overlay.color.a = 1.0
	_prompt.modulate.a = 0.0
	_show_card(_card_index)
	_fade_overlay(0.0, FADE_DURATION)   # fade in from black


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	if not pressed and event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	if not pressed:
		return
	get_viewport().set_input_as_handled()

	if _is_typing:
		_finish_typewriter()
	else:
		_advance()


# ── Card display ──────────────────────────────────────────────────────────────

func _show_card(index: int) -> void:
	var text := CARDS[index]
	_label.text = text
	_label.visible_ratio = 0.0
	_prompt.modulate.a = 0.0

	if _typewriter_tween:
		_typewriter_tween.kill()

	_is_typing = true
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(
		_label, "visible_ratio", 1.0, text.length() * TYPEWRITER_SPEED
	)
	_typewriter_tween.finished.connect(_on_typewriter_done)


func _finish_typewriter() -> void:
	if _typewriter_tween:
		_typewriter_tween.kill()
	_label.visible_ratio = 1.0
	_is_typing = false
	_on_typewriter_done()


func _on_typewriter_done() -> void:
	_is_typing = false
	# Fade in the [E] prompt
	var tw := create_tween()
	tw.tween_property(_prompt, "modulate:a", 1.0, 0.4)
	# Auto-advance after a pause
	_auto_timer = get_tree().create_timer(AUTO_ADVANCE_PAD)
	_auto_timer.timeout.connect(_advance)


func _advance() -> void:
	if _advancing:
		return

	# Disconnect auto-timer if it's still pending
	if _auto_timer and _auto_timer.timeout.is_connected(_advance):
		_auto_timer.timeout.disconnect(_advance)

	_advancing = true
	_card_index += 1

	if _card_index >= CARDS.size():
		_end_cutscene()
		return   # leave _advancing = true — no more input after final card

	# Cross-fade to next card
	_fade_overlay(1.0, FADE_DURATION / 2.0)
	await get_tree().create_timer(FADE_DURATION / 2.0).timeout
	_show_card(_card_index)
	_fade_overlay(0.0, FADE_DURATION / 2.0)
	_advancing = false


func _end_cutscene() -> void:
	_prompt.text = ""
	_fade_overlay(1.0, FADE_DURATION)
	await get_tree().create_timer(FADE_DURATION + 0.3).timeout
	SceneManager.go_to_level(1)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _fade_overlay(target_alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", target_alpha, duration)
