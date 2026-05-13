
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
#        Beam Left     →  the ArenaEnergyBeam on the left side of the arena
#        Beam Right    →  the ArenaEnergyBeam on the right side of the arena
#
#   4. On the BossSerpent node set arena_center to the world-space centre of
#      the arena room (the boss returns here during the phase transition).
#
#   5. Fill in the ## TODO: dialogue lines below.
#
#   6. Replace the win_screen transition at the bottom with your ending scene.
#
# ── Arena beam mechanic ───────────────────────────────────────────────────────
#   The boss starts invulnerable. The player must activate both ArenaEnergyBeams
#   (one on each side of the arena) to make the boss damageable.
#   At 50% HP the boss retreats to the arena centre and re-shields. The beams
#   reset and the player must activate them a second time to finish the fight.
#
# ── Testing without the boss ──────────────────────────────────────────────────
#   Press F8 in a debug build to instantly trigger _on_boss_defeated().
#   Press F7 in a debug build to instantly make the boss vulnerable (skip beams).
# ─────────────────────────────────────────────────────────────────────────────

extends Node2D

# ── Boss references ───────────────────────────────────────────────────────────
@export var boss       : Node             = null  ## Must have `died` and `phase_2_started` signals
@export var beam_left  : ArenaEnergyBeam  = null  ## Left-side energy beam interactable
@export var beam_right : ArenaEnergyBeam  = null  ## Right-side energy beam interactable

var boss_body : BossBodyInteractable = null
var _boss_hud : CanvasLayer          = null  ## Instantiated at runtime

# ── Objective indices ─────────────────────────────────────────────────────────
var _obj_hostiles  : int
var _obj_boss      : int
var _obj_boss_hint : int  = -1  # current boss-fight guidance objective

# ── State ─────────────────────────────────────────────────────────────────────
var _remaining_enemies  : int  = 0
var _boss_defeated      : bool = false
var _level_ended        : bool = false
var _boss_is_phase_2    : bool = false


func _ready() -> void:
	SceneManager.current_level = 3

	# ── Music ─────────────────────────────────────────────────────────────────
	## TODO: Replace with level 3 ambient track when available
	MusicManager.play(["res://assets/sounds/ambient_l2.mp3"])

	# ── Level 3 objectives ────────────────────────────────────────────────────
	ObjectiveManager.clear_objectives()
	_obj_hostiles  = ObjectiveManager.add_objective("Clear all hostiles")
	_obj_boss      = ObjectiveManager.add_objective("Defeat the boss")
	_obj_boss_hint = ObjectiveManager.add_objective("Activate both energy beams")

	# ── Connect boss signals ──────────────────────────────────────────────────
	if boss != null and boss.has_signal("died"):
		boss.died.connect(_on_boss_defeated)
	elif boss == null:
		push_warning("Level3: No boss assigned. Use F8 to test the ending.")

	if boss != null and boss.has_signal("phase_2_started"):
		boss.phase_2_started.connect(_on_boss_phase_2_started)

	if boss != null and boss.has_signal("vulnerability_changed"):
		boss.vulnerability_changed.connect(_on_boss_vulnerability_changed)

	if boss != null and boss.has_signal("window_consumed"):
		boss.window_consumed.connect(_on_boss_window_consumed)

	# ── Boss HUD ──────────────────────────────────────────────────────────────
	if boss != null:
		var hud_scene := load("res://shared/ui/BossHUD.tscn") as PackedScene
		if hud_scene:
			_boss_hud = hud_scene.instantiate()
			add_child(_boss_hud)
			_boss_hud.connect_boss(boss)

	# ── Wire up arena beams ───────────────────────────────────────────────────
	if beam_left != null:
		beam_left.beam_primed.connect(_on_beam_activated)
	else:
		push_warning("Level3: beam_left not assigned.")
	if beam_right != null:
		beam_right.beam_primed.connect(_on_beam_activated)
	else:
		push_warning("Level3: beam_right not assigned.")

	# ── Enemy tracking ────────────────────────────────────────────────────────
	var enemies : Array = []
	_collect_enemies($Enemies, enemies)
	_remaining_enemies = enemies.size()
	for enemy in enemies:
		enemy.died.connect(_on_enemy_died)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	if event.keycode == KEY_F8:
		push_warning("Level3 [DEV]: F8 — simulating boss defeated.")
		_on_boss_defeated()

	if event.keycode == KEY_F7:
		push_warning("Level3 [DEV]: F7 — making boss vulnerable (skipping beams).")
		if boss != null and boss.has_method("make_vulnerable"):
			boss.make_vulnerable()


# ── Boss defeated ─────────────────────────────────────────────────────────────

func _on_boss_defeated() -> void:
	if _boss_defeated:
		return
	_boss_defeated = true
	if _obj_boss_hint >= 0:
		ObjectiveManager.complete_objective(_obj_boss_hint)
		_obj_boss_hint = -1
	ObjectiveManager.complete_objective(_obj_boss)

	_level_ended = true
	GameState.save_objectives_from_level_3()
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": ["Threat neutralised."],
	})
	DialogueManager.dialogue_ended.connect(func() -> void:
		get_tree().change_scene_to_file("res://cutscene/win_screen.tscn")
	, CONNECT_ONE_SHOT)


# ── Arena beam coordination ───────────────────────────────────────────────────

func _on_beam_activated() -> void:
	if boss == null or not boss.has_method("make_vulnerable"):
		return
	var left_on  := beam_left  != null and beam_left.is_primed()
	var right_on := beam_right != null and beam_right.is_primed()
	if left_on and right_on:
		boss.make_vulnerable()


## Called when the boss emits phase_2_started — resets beams for round 2.
func _on_boss_phase_2_started() -> void:
	_boss_is_phase_2 = true
	if beam_left != null:
		beam_left.reset()
	if beam_right != null:
		beam_right.reset()
	_set_boss_hint("Activate both energy beams again")


func _on_boss_window_consumed() -> void:
	if beam_left != null:
		beam_left.reset()
	if beam_right != null:
		beam_right.reset()


func _on_boss_vulnerability_changed(is_vulnerable: bool) -> void:
	if is_vulnerable:
		_set_boss_hint("Boss exposed — deal damage now")
	else:
		_set_boss_hint("Reactivate both energy beams")


func _set_boss_hint(text: String) -> void:
	if _obj_boss_hint >= 0:
		ObjectiveManager.complete_objective(_obj_boss_hint)
	_obj_boss_hint = ObjectiveManager.add_objective(text)


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
