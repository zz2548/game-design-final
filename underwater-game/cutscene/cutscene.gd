extends Node

# ── Cutscene cards ────────────────────────────────────────────────────────────
# Each entry is displayed as a full-screen text card on a black background.
const CARDS: Array[String] = [
	"06:42:00\n\nRelay Station Kappa lost contact 72 hours prior.\nCause of blackout: undetermined.\nCorporate has dispatched a single operative for assessment.",
	"09:17:33\n\nTethys-7 en route to Station Kappa.\nStandard transit.\nNo anomalies logged.",
	"11:58:21\n\nUnidentified contact.\nCollision imminent.\nEmergency protocols failed to initialize.",
	"11:58:28\n\nHull integrity compromised.\nPressure systems offline.\nNavigation core unresponsive.",
	"12:00:04\n\nOperative status: conscious.\nVessel status: critical.\nThree components confirmed missing.\n\nDrive coupling.\nPressure seal.\nNavigation core.",
	"12:00:47\n\nDistress signal blocked.\nRelay station Kappa offline.\nCause undetermined.",
	"12:01:09\n\nNature of contact: unclassified.\nOrigin: unknown.\nNo further data available.",
	"12:01:11\n\nRecovery objective logged.\nRetrieve components.\nRestore vessel.\nProceed to Station Kappa.\n\nDepth recorded: 3,847 meters.\nBackup unavailable.",
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
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_skip_all()
		return

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


func _skip_all() -> void:
	if _advancing:
		return
	_advancing = true
	_end_cutscene()


func _end_cutscene() -> void:
	_prompt.text = ""
	_fade_overlay(1.0, FADE_DURATION)
	await get_tree().create_timer(FADE_DURATION + 0.3).timeout
	SceneManager.go_to_level(1)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _fade_overlay(target_alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", target_alpha, duration)
