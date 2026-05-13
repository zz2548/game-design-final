
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
var _boss_intro_triggered : bool = false


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

	if boss != null and boss.has_signal("became_visible"):
		boss.became_visible.connect(_on_boss_became_visible, CONNECT_ONE_SHOT)

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


# ── Boss intro cinematic ─────────────────────────────────────────────────────

func _on_boss_became_visible() -> void:
	if _boss_intro_triggered:
		return
	_boss_intro_triggered = true
	_run_boss_intro.call_deferred()


func _run_boss_intro() -> void:
	var player : Node2D = get_tree().get_first_node_in_group("player")
	if player == null or boss == null:
		return

	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return

	# Freeze all enemies (including boss) so nothing attacks during the cinematic.
	var all_enemies := get_tree().get_nodes_in_group("enemies")
	for e in all_enemies:
		if "ai_enabled" in e:
			e.ai_enabled = false
	if "ai_enabled" in boss:
		boss.ai_enabled = false
	player.movement_locked = true
	player.shooting_locked = true
	player.set_process_unhandled_input(false)
	if player.has_node("InteractionPromptLayer"):
		player.get_node("InteractionPromptLayer").hide()
	if player.has_node("InteractionSystem"):
		player.get_node("InteractionSystem").set_process_unhandled_input(false)

	# Create a temporary cinematic camera.
	var start_pos := cam.get_screen_center_position()
	cam.enabled = false
	var cine_cam := Camera2D.new()
	cine_cam.zoom         = Vector2(1.5, 1.5)
	cine_cam.limit_left   = -99999
	cine_cam.limit_top    = -99999
	cine_cam.limit_right  =  99999
	cine_cam.limit_bottom =  99999
	cine_cam.global_position = start_pos
	add_child(cine_cam)

	# Label shown at each point of interest.
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 30
	add_child(ui_layer)
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lbl.offset_top = -120.0
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate.a = 0.0
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(0.28, 0.82, 1.0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	ui_layer.add_child(lbl)

	const TRAVEL : float = 1.1
	const HOLD   : float = 1.0

	var stops : Array = []
	if beam_left  != null: stops.append([beam_left.global_position,  "Energy Emitter"])
	if beam_right != null: stops.append([beam_right.global_position, "Energy Emitter"])
	stops.append([boss.global_position, ""])

	for stop in stops:
		var dest : Vector2 = stop[0]
		var tag  : String  = stop[1]
		var move := create_tween()
		move.tween_property(cine_cam, "global_position", dest, TRAVEL) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await move.finished
		if tag != "":
			lbl.text = tag
			create_tween().tween_property(lbl, "modulate:a", 1.0, 0.25)
			await get_tree().create_timer(HOLD).timeout
			create_tween().tween_property(lbl, "modulate:a", 0.0, 0.2)
			await get_tree().create_timer(0.25).timeout
		else:
			await get_tree().create_timer(HOLD).timeout

	var tw_back := create_tween()
	tw_back.tween_property(cine_cam, "global_position", start_pos, TRAVEL) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw_back.finished

	ui_layer.queue_free()
	cam.enabled = true
	cine_cam.enabled = false
	cine_cam.queue_free()

	# ORCA warns the player about the shield mechanic before combat begins.
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"That creature is shielded — direct fire won't penetrate it.",
			"I'm detecting two energy emitters in this chamber.",
			"Activate both to bring the shield down.",
		],
	})
	await DialogueManager.dialogue_ended

	# Restore full player control and re-enable all enemy AI.
	player.movement_locked = false
	player.shooting_locked = false
	player.set_process_unhandled_input(true)
	if player.has_node("InteractionSystem"):
		player.get_node("InteractionSystem").set_process_unhandled_input(true)
	for e in all_enemies:
		if is_instance_valid(e) and "ai_enabled" in e:
			e.ai_enabled = true
	if "ai_enabled" in boss:
		boss.ai_enabled = true


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
