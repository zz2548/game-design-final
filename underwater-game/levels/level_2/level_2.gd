
# Objectives:
#   1. Find the access key to the bore shaft   (required)
#   2. Exit Kappa Station                      (required)
#   3. Eliminate all hostiles                  (optional)

extends Node2D

# ── Objective indices ─────────────────────────────────────────────────────────
var _obj_key: int
var _obj_exit: int
var _obj_hostiles: int

# ── State ─────────────────────────────────────────────────────────────────────
var _remaining_enemies: int = 0
var _has_key: bool = false
var _level_ended: bool = false

# ── Scene refs ────────────────────────────────────────────────────────────────
@onready var _level_gate : Area2D = $LevelGate


func _ready() -> void:
	SceneManager.current_level = 2

	# ── Ambient music ─────────────────────────────────────────────────────────
	MusicManager.play(["res://assets/sounds/ambient_l2.mp3"])

	# ── Restore Level 1 objective history ────────────────────────────────────
	# Replay the Level 1 snapshot so completed objectives appear at the top of
	# the HUD as a record of prior progress, then append Level 2 objectives.
	ObjectiveManager.clear_objectives()
	for entry in GameState.level_1_objectives:
		var idx := ObjectiveManager.add_objective(entry["text"])
		if entry["completed"]:
			ObjectiveManager.complete_objective(idx)

	# ── Level 2 objectives ────────────────────────────────────────────────────
	_obj_key      = ObjectiveManager.add_objective("Find the access key to the bore shaft")
	_obj_exit     = ObjectiveManager.add_objective("Exit Kappa Station")
	_obj_hostiles = ObjectiveManager.add_objective("Eliminate all hostiles [optional]")

	# ── Inventory signals ─────────────────────────────────────────────────────
	Inventory.item_added.connect(_on_item_added)

	# ── Level gate (exit trigger) ─────────────────────────────────────────────
	_level_gate.gate_opened.connect(_on_gate_reached)

	# ── Enemy tracking ────────────────────────────────────────────────────────
	var enemies: Array = []
	_collect_enemies($Enemies, enemies)
	_remaining_enemies = enemies.size()
	for enemy in enemies:
		enemy.died.connect(_on_enemy_died)


func _collect_enemies(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child.has_signal("died"):
			result.append(child)
		_collect_enemies(child, result)


# ── Objective callbacks ───────────────────────────────────────────────────────

func _on_item_added(item: ItemData, _qty: int) -> void:
	if item.id == "level2_key":
		_has_key = true
		ObjectiveManager.complete_objective(_obj_key)


func _on_gate_reached() -> void:
	if _level_ended:
		return

	# Gate already verified the key — complete the exit objective and advance.
	_level_ended = true
	ObjectiveManager.complete_objective(_obj_exit)

	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Bore shaft open. Descending to Level 3.",
			"Whatever is down there — it's been waiting.",
		],
	})
	DialogueManager.dialogue_ended.connect(
		func():
			GameState.save_objectives_from_level_2()
			SceneManager.next_level(),
		CONNECT_ONE_SHOT
	)


func _on_enemy_died() -> void:
	_remaining_enemies -= 1
	if _remaining_enemies <= 0:
		ObjectiveManager.complete_objective(_obj_hostiles)
