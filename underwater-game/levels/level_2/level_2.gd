
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
var _remaining_enemies          : int      = 0
var _has_key                    : bool     = false
var _level_ended                : bool     = false
var _ranged_tutorial_triggered  : bool     = false
var _cine_cam                   : Camera2D = null

# ── Scene refs ────────────────────────────────────────────────────────────────
@onready var _level_gate     : Area2D          = $LevelGate
@onready var _player         : CharacterBody2D = $player
@onready var _camera         : Camera2D        = $player/Camera2D
@onready var _ranged_1       : Enemy           = $Enemies/Ranged/Ranged1
@onready var _shotgun_pickup : PickupWeapon    = $ShotgunPickup


func _ready() -> void:
	SceneManager.current_level = 2

	# ── Ambient music ─────────────────────────────────────────────────────────
	MusicManager.play(["res://assets/sounds/ambient_l2.mp3"])

	# ── Level 2 objectives ────────────────────────────────────────────────────
	ObjectiveManager.clear_objectives()
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

	# ── Ranged tutorial ───────────────────────────────────────────────────────
	_ranged_1.detection_zone.body_entered.connect(_on_ranged_1_detected, CONNECT_ONE_SHOT)

	# ── Shotgun pickup ────────────────────────────────────────────────────────
	_shotgun_pickup.tree_exiting.connect(_on_shotgun_picked_up, CONNECT_ONE_SHOT)


func _collect_enemies(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child.has_signal("died"):
			result.append(child)
		_collect_enemies(child, result)


# ── Cinematic camera helpers ──────────────────────────────────────────────────

func _start_cine_cam() -> void:
	var start_pos := _camera.get_screen_center_position()
	_camera.enabled = false
	_player.get_node("InteractionPromptLayer").hide()
	_player.get_node("InteractionSystem").set_process_unhandled_input(false)
	_player.shooting_locked = true
	_cine_cam = Camera2D.new()
	_cine_cam.zoom          = Vector2(1.5, 1.5)
	_cine_cam.limit_left    = -99999
	_cine_cam.limit_top     = -99999
	_cine_cam.limit_right   =  99999
	_cine_cam.limit_bottom  =  99999
	_cine_cam.global_position = start_pos
	add_child(_cine_cam)


func _stop_cine_cam() -> void:
	_camera.enabled = true
	_player.get_node("InteractionPromptLayer").show()
	_player.get_node("InteractionSystem").set_process_unhandled_input(true)
	_player.shooting_locked = false
	if is_instance_valid(_cine_cam):
		_cine_cam.enabled = false
		_cine_cam.queue_free()
		_cine_cam = null


func _make_ui_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names   = PackedStringArray(["Consolas", "Courier New", "monospace"])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


# Non-blocking ORCA text — only the calling coroutine awaits; physics keeps running.
func _hud_dialogue(speaker: String, lines: Array) -> void:
	var font  := _make_ui_font()
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

	create_tween().tween_property(panel, "modulate:a", 1.0, 0.3)

	for line in lines:
		rtl.text          = line
		rtl.visible_ratio = 0.0
		var type_dur : float = line.length() * 0.028
		create_tween().tween_property(rtl, "visible_ratio", 1.0, type_dur)
		await get_tree().create_timer(type_dur + 1.6).timeout

	create_tween().tween_property(panel, "modulate:a", 0.0, 0.35)
	await get_tree().create_timer(0.4).timeout
	layer.queue_free()


# ── Ranged enemy tutorial ─────────────────────────────────────────────────────

func _on_ranged_1_detected(body: Node2D) -> void:
	if not body.is_in_group("player") or _ranged_tutorial_triggered:
		return
	_ranged_tutorial_triggered = true
	_run_ranged_tutorial.call_deferred()


func _run_ranged_tutorial() -> void:
	if not is_instance_valid(_ranged_1):
		return
	_start_cine_cam()
	_player.shooting_locked = false  # _start_cine_cam locks this; undo it

	var pan := create_tween()
	pan.tween_property(_cine_cam, "global_position", _ranged_1.global_position, 0.85) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await pan.finished
	await get_tree().create_timer(0.3).timeout

	await _hud_dialogue("ORCA", [
		"New contact — ranged organism.",
		"This variant maintains distance and fires biological projectiles.",
		"Find cover between engagements.",
	])

	var pan_back := create_tween()
	pan_back.tween_property(_cine_cam, "global_position", _player.global_position, 0.85) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await pan_back.finished

	_stop_cine_cam()


# ── Pickup reactions ──────────────────────────────────────────────────────────

func _on_shotgun_picked_up() -> void:
	# Deferred so the pickup node finishes freeing before dialogue starts.
	DialogueManager.start_dialogue.call_deferred({
		"speaker": "ORCA",
		"lines": [
			"Scatter weapon acquired. Effective at close range.",
			"Station schematics show a bore shaft access route deeper in this section.",
			"An access key will be required. Keep searching.",
		],
	})


func _on_key_picked_up() -> void:
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Access key recovered.",
			"Station logs flagged this sub-level as a seismic survey zone.",
			"The survey team never reported back. Find the gate.",
		],
	})


# ── Objective callbacks ───────────────────────────────────────────────────────

func _on_item_added(item: ItemData, _qty: int) -> void:
	if item.id == "level2_key":
		_has_key = true
		ObjectiveManager.complete_objective(_obj_key)
		_on_key_picked_up()


func _on_gate_reached() -> void:
	if _level_ended:
		return

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
			var player := get_tree().get_first_node_in_group("player")
			if player != null:
				GameState.save_player_stats(player)
			SceneManager.next_level(),
		CONNECT_ONE_SHOT
	)


func _on_enemy_died() -> void:
	_remaining_enemies -= 1
	if _remaining_enemies <= 0:
		ObjectiveManager.complete_objective(_obj_hostiles)
