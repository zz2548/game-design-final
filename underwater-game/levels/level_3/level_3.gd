
# Objectives:
#   1. Eliminate all hostiles   (required — triggers end game)

extends Node2D

# ── Objective indices ─────────────────────────────────────────────────────────
var _obj_hostiles: int

# ── State ─────────────────────────────────────────────────────────────────────
var _remaining_enemies: int = 0
var _level_ended: bool = false


func _ready() -> void:
	SceneManager.current_level = 3

	# ── Ambient music ─────────────────────────────────────────────────────────
	MusicManager.play(["res://assets/sounds/ambient_l2.mp3"])

	# ── Restore Level 1 & 2 objective history ─────────────────────────────────
	ObjectiveManager.clear_objectives()
	for entry in GameState.level_1_objectives:
		var idx := ObjectiveManager.add_objective(entry["text"])
		if entry["completed"]:
			ObjectiveManager.complete_objective(idx)
	for entry in GameState.level_2_objectives:
		var idx := ObjectiveManager.add_objective(entry["text"])
		if entry["completed"]:
			ObjectiveManager.complete_objective(idx)

	# ── Level 3 objectives ────────────────────────────────────────────────────
	_obj_hostiles = ObjectiveManager.add_objective("Eliminate all hostiles")

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


# ── End game ──────────────────────────────────────────────────────────────────

func _on_enemy_died() -> void:
	_remaining_enemies -= 1
	if _remaining_enemies <= 0 and not _level_ended:
		_level_ended = true
		ObjectiveManager.complete_objective(_obj_hostiles)
		_trigger_ending()


func _trigger_ending() -> void:
	GameState.save_objectives_from_level_3()

	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"All hostiles neutralised. The station is clear.",
			"Mission complete. Returning to surface.",
		],
	})
	DialogueManager.dialogue_ended.connect(
		func():
			get_tree().change_scene_to_file("res://cutscene/win_screen.tscn"),
		CONNECT_ONE_SHOT
	)
