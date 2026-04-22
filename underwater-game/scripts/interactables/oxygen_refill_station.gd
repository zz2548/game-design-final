# oxygen_refill_station.gd
# An oxygen refill station that can work in one of two modes:
#
#   PASSIVE  — Constantly refills the player's oxygen while they are nearby.
#              No interaction prompt is shown; the station just works on proximity.
#
#   INTERACT — Shows an [E] prompt. One press gives the player a full burst of
#              oxygen. Optionally disables itself after use (single-use mode).
#
# How to place:
#   1. Instance OxygenRefillStation.tscn into your level.
#   2. In the Inspector, pick Mode and tweak the other exports to taste.

class_name OxygenRefillStation
extends Interactable

enum Mode {
	PASSIVE,   ## Refill continuously while the player is nearby.
	INTERACT,  ## Refill on E press (optionally single-use).
}

# ── Exports ───────────────────────────────────────────────────────────────────

## Choose how this station behaves.
@export var mode : Mode = Mode.INTERACT

## PASSIVE: oxygen units restored per second while the player is inside the zone.
@export var passive_refill_rate : float = 15.0

## INTERACT: oxygen units added on a single press.
@export var interact_refill_amount : float = 90.0   # full tank by default

## INTERACT: if true the station disappears after one use.
@export var single_use : bool = false

# ── Internal ──────────────────────────────────────────────────────────────────

var _player_in_range : Node = null   # non-null only in PASSIVE mode while overlapping
var _used            : bool = false  # guards single-use stations
var _bubbles         : AudioStreamPlayer


func _ready() -> void:
	_bubbles = AudioStreamPlayer.new()
	_bubbles.stream = load("res://assets/sounds/bubbles.wav")
	add_child(_bubbles)
	# Passive stations have no prompt — hide from the InteractionSystem by
	# setting an empty label and connecting body signals manually.
	if mode == Mode.PASSIVE:
		interaction_label = ""
		# Disable the Interactable's Area2D monitoring so the InteractionSystem
		# never picks it up as a prompt target.
		monitoring = false
		# Use a sibling or self body-overlap signals for range detection.
		var zone := $PassiveZone as Area2D
		if zone:
			zone.body_entered.connect(_on_body_entered)
			zone.body_exited.connect(_on_body_exited)
	else:
		interaction_label = "Refill Oxygen"


func _process(delta: float) -> void:
	if mode == Mode.PASSIVE and _player_in_range != null:
		if _player_in_range.has_method("refill_oxygen"):
			# Drip-feed oxygen each frame; refill_oxygen clamps to MAX_OXYGEN.
			_player_in_range.refill_oxygen(passive_refill_rate * delta)


# ── PASSIVE zone callbacks ────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = body
		_bubbles.play()


func _on_body_exited(body: Node) -> void:
	if body == _player_in_range:
		_player_in_range = null
		_bubbles.stop()


# ── INTERACT override ─────────────────────────────────────────────────────────

func _on_interact(player: Node) -> void:
	if mode != Mode.INTERACT:
		return
	if _used:
		return

	if player.has_method("refill_oxygen"):
		player.refill_oxygen(interact_refill_amount)
		_bubbles.play()

	if single_use:
		_used = true
		# Visually indicate depletion and remove the prompt.
		interaction_label = "Depleted"
		monitoring = false          # stop InteractionSystem from showing prompt
		$Sprite.modulate = Color(0.35, 0.35, 0.35)   # grey out (if sprite present)
