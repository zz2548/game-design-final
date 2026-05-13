
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
			"That creature is shielded. Direct fire won't penetrate it.",
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
	_run_ending.call_deferred()


func _run_ending() -> void:
	# Freeze player and all remaining enemies.
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.movement_locked = true
		player.shooting_locked = true
		if player.has_node("InteractionSystem"):
			player.get_node("InteractionSystem").set_process_unhandled_input(false)
	for e in get_tree().get_nodes_in_group("enemies"):
		if "ai_enabled" in e:
			e.ai_enabled = false
	if is_instance_valid(_boss_hud):
		_boss_hud.hide()

	# Slow creeping zoom in on the player over the full dialogue duration.
	var cam : Camera2D = null
	if player != null:
		cam = player.get_node_or_null("Camera2D")
	if cam != null:
		create_tween().tween_property(cam, "zoom", Vector2(2.5, 2.5), 32.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# ORCA pieces it together — one panel, lines cycle through.
	await _ending_dialogue("ORCA", [
		["Threat neutralised.", 1.4],
		["Apex organism confirmed. Europa's subsurface biosphere is intact and inhabited.", 1.4],
		["Cross-referencing station logs. A seismic survey team accessed the bore shaft six days before the blackout. There is no record of their return.", 1.4],
		["Corporate filed no emergency response. No missing persons report...", 1.4],
		["They knew a team had gone in and not come back. They sent us anyway.", 1.4],
		["We were sent to confirm how dangerous it was, not to assess a blackout... They view us as expendable.", 1.8],
		["If we hadn't made it back... they would have had their answer.", 1.4],
		["Once we make it back, we have some questioning to do.", 3.0]
	])

	# Cut to black, then win screen.
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 99
	add_child(fade_layer)
	var fade_rect := ColorRect.new()
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)
	create_tween().tween_property(fade_rect, "color:a", 1.0, 1.8)
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://cutscene/win_screen.tscn")


# ── Ending dialogue ───────────────────────────────────────────────────────────
# Builds one panel and cycles all lines through it without flickering.
# lines: Array of [text: String, hold_seconds: float] pairs.

func _ending_dialogue(speaker: String, lines: Array) -> void:
	var font := _make_ui_font()
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)

	var panel := PanelContainer.new()
	panel.layout_mode     = 1
	panel.anchor_left     = 0.0;   panel.anchor_top    = 1.0
	panel.anchor_right    = 1.0;   panel.anchor_bottom = 1.0
	panel.offset_left     = 72.0;  panel.offset_top    = -210.0
	panel.offset_right    = -72.0; panel.offset_bottom = -24.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	var sbox := StyleBoxFlat.new()
	sbox.bg_color     = Color(0.04, 0.09, 0.14, 0.93)
	sbox.border_color = Color(0.18, 0.52, 0.68, 0.75)
	sbox.set_border_width_all(1)
	sbox.set_corner_radius_all(6)
	sbox.content_margin_left   = 22.0; sbox.content_margin_right  = 22.0
	sbox.content_margin_top    = 14.0; sbox.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", sbox)
	panel.modulate.a = 0.0
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var spk_lbl := Label.new()
	spk_lbl.text      = speaker
	spk_lbl.uppercase = true
	spk_lbl.add_theme_font_override("font", font)
	spk_lbl.add_theme_font_size_override("font_size", 12)
	spk_lbl.add_theme_color_override("font_color", Color(0.28, 0.82, 1.0))
	vbox.add_child(spk_lbl)

	var div  := HSeparator.new()
	var dsep := StyleBoxFlat.new()
	dsep.bg_color = Color(0.18, 0.52, 0.68, 0.4)
	dsep.set_content_margin_all(0)
	div.add_theme_stylebox_override("separator", dsep)
	vbox.add_child(div)

	var rtl := RichTextLabel.new()
	rtl.custom_minimum_size = Vector2(20, 60)
	rtl.bbcode_enabled  = true
	rtl.fit_content     = false
	rtl.scroll_active   = false
	rtl.autowrap_mode   = TextServer.AUTOWRAP_WORD_SMART
	rtl.visible_ratio   = 0.0
	rtl.add_theme_font_override("normal_font", font)
	rtl.add_theme_font_size_override("normal_font_size", 15)
	rtl.add_theme_color_override("default_color", Color(0.80, 0.91, 0.97))
	vbox.add_child(rtl)

	create_tween().tween_property(panel, "modulate:a", 1.0, 0.4)
	await get_tree().create_timer(0.45).timeout

	for line_data in lines:
		var text : String = line_data[0]
		var hold : float  = line_data[1]
		rtl.text          = text
		rtl.visible_ratio = 0.0
		create_tween().tween_property(rtl, "visible_ratio", 1.0, text.length() * 0.028)
		await get_tree().create_timer(text.length() * 0.028 + hold).timeout

	create_tween().tween_property(panel, "modulate:a", 0.0, 0.4)
	await get_tree().create_timer(0.45).timeout
	layer.queue_free()


func _make_ui_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names   = PackedStringArray(["Consolas", "Courier New", "monospace"])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


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
