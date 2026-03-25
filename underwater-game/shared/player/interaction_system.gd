# interaction_system.gd
# res://shared/player/interaction_system.gd
# Attach to the Player node as a child Node.
# Requires: a child Area2D named "InteractionZone" with a CollisionShape2D
#
# In Project > Project Settings > Input Map, add an action called "interact" and bind E to it.

class_name InteractionSystem
extends Node

signal interactable_focused(interactable: Interactable)
signal interactable_unfocused

@export var interaction_zone: Area2D   # Drag your InteractionZone Area3D here

var _current_interactable: Interactable = null
var _player: Node = null

func _ready() -> void:
	_player = get_parent()
	if not interaction_zone:
		push_error("InteractionSystem: No interaction_zone assigned!")
		return

	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)
	interaction_zone.area_entered.connect(_on_area_entered)
	interaction_zone.area_exited.connect(_on_area_exited)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _current_interactable:
		_current_interactable._on_interact(_player)

# ─── Detection ───────────────────────────────────────────────────────────────

func _on_area_entered(area: Area2D) -> void:
	if area is Interactable:
		_set_focus(area)


func _on_area_exited(area: Area2D) -> void:
	if area == _current_interactable:
		_clear_focus()


func _on_body_entered(body: Node) -> void:
	# Some interactables might be on bodies instead of areas
	if body is Interactable:
		_set_focus(body)


func _on_body_exited(body: Node) -> void:
	if body == _current_interactable:
		_clear_focus()

# ─── Focus Management ────────────────────────────────────────────────────────

func _set_focus(interactable: Interactable) -> void:
	if _current_interactable == interactable:
		return
	_current_interactable = interactable
	interactable.is_in_range = true
	emit_signal("interactable_focused", interactable)


func _clear_focus() -> void:
	if _current_interactable:
		_current_interactable.is_in_range = false
		_current_interactable = null
	emit_signal("interactable_unfocused")


func get_current_interactable() -> Interactable:
	return _current_interactable
