
# level_3.gd — FINAL LEVEL
#
# ── How to wire up the boss (for the team) ────────────────────────────────────
#
#   1. Build the boss scene. The boss root node MUST have a `died` signal.
#
#   2. Add a BossBodyInteractable node as a child of the boss scene.
#      (res://scripts/interactables/boss_body_interactable.gd)
#      Set its interaction_label to something fitting, e.g. "Examine APEX-7".
#
#   3. In the Level3 scene, select this node (Level3) and assign:
#        Boss          →  the boss node
#        Boss Body     →  the BossBodyInteractable node inside the boss scene
#
#   4. Fill in the ## TODO: dialogue lines below.
#
#   5. Replace the win_screen transition at the bottom with your ending scene.
#
# ── Testing without the boss ──────────────────────────────────────────────────
#   Press F8 in a debug build to instantly trigger _on_boss_defeated().
# ─────────────────────────────────────────────────────────────────────────────

extends Node2D

# ── Boss references (assign in Inspector once boss scene exists) ──────────────
@export var boss      : Node               = null  ## Root node of the boss — must have `died` signal
@export var boss_body : BossBodyInteractable = null  ## Interactable child of boss scene

# ── Objective indices ─────────────────────────────────────────────────────────
var _obj_hostiles : int
var _obj_boss     : int

# ── State ─────────────────────────────────────────────────────────────────────
var _remaining_enemies : int  = 0
var _boss_defeated     : bool = false
var _level_ended       : bool = false


func _ready() -> void:
	SceneManager.current_level = 3

	# ── Music ─────────────────────────────────────────────────────────────────
	## TODO: Replace with level 3 ambient track when available
	MusicManager.play(["res://assets/sounds/ambient_l2.mp3"])

	# ── Restore objective history ─────────────────────────────────────────────
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
	_obj_boss     = ObjectiveManager.add_objective("Defeat the boss") ## TODO: rename

	# ── Connect boss signal ───────────────────────────────────────────────────
	if boss != null and boss.has_signal("died"):
		boss.died.connect(_on_boss_defeated)
	elif boss == null:
		push_warning("Level3: No boss assigned. Use F8 to test the ending.")

	# ── Boss body starts hidden until boss dies ───────────────────────────────
	if boss_body != null:
		boss_body.process_mode = Node.PROCESS_MODE_DISABLED
		boss_body.visible      = false

	# ── Enemy tracking ────────────────────────────────────────────────────────
	var enemies : Array = []
	_collect_enemies($Enemies, enemies)
	_remaining_enemies = enemies.size()
	for enemy in enemies:
		enemy.died.connect(_on_enemy_died)


func _unhandled_input(event: InputEvent) -> void:
	# ── DEV SHORTCUT: simulate boss death (debug builds only) ─────────────────
	if OS.is_debug_build() \
			and event is InputEventKey \
			and event.keycode == KEY_F8 \
			and event.pressed \
			and not event.echo:
		push_warning("Level3 [DEV]: F8 pressed — simulating boss defeated.")
		_on_boss_defeated()


# ── Boss defeated ─────────────────────────────────────────────────────────────

func _on_boss_defeated() -> void:
	if _boss_defeated:
		return
	_boss_defeated = true
	ObjectiveManager.complete_objective(_obj_boss)

	# Enable the body interactable so the player can trigger story content
	if boss_body != null:
		boss_body.process_mode = Node.PROCESS_MODE_INHERIT
		boss_body.visible      = true
		boss_body.examined.connect(_on_boss_examined, CONNECT_ONE_SHOT)

	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			## TODO: Add ORCA lines for boss death moment
			"Threat neutralised.",
			"Approach for further analysis.",
		],
	})


# ── Boss body interaction — story cutscenes ───────────────────────────────────

func _on_boss_examined() -> void:
	if _level_ended:
		return
	_level_ended = true
	GameState.save_objectives_from_level_3()

	# ── TODO: Build your story cutscene sequence here ─────────────────────────
	# Each dialogue block, cinematic, or scene transition goes in sequence.
	# Example pattern:
	#
	#   DialogueManager.start_dialogue({ "speaker": "ORCA", "lines": [...] })
	#   DialogueManager.dialogue_ended.connect(func(): _play_next_cutscene(), CONNECT_ONE_SHOT)
	#
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			## TODO: Replace with actual story dialogue
			"...",
		],
	})
	DialogueManager.dialogue_ended.connect(_finish_ending, CONNECT_ONE_SHOT)


func _finish_ending() -> void:
	## TODO: Replace with your actual ending scene (credits, epilogue, etc.)
	get_tree().change_scene_to_file("res://cutscene/win_screen.tscn")


# ── Enemy tracking ────────────────────────────────────────────────────────────

func _collect_enemies(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child.has_signal("died"):
			result.append(child)
		_collect_enemies(child, result)


func _on_enemy_died() -> void:
	_remaining_enemies -= 1
	if _remaining_enemies <= 0:
		ObjectiveManager.complete_objective(_obj_hostiles)
