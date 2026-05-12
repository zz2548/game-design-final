# level_1.gd
# Attached to the Level1 node.
# Sets up objectives, marks them complete as the player progresses,
# and orchestrates the submarine driving sequence at the end.

extends Node2D

# ── Objective indices ─────────────────────────────────────────────────────────
var _obj_engine: int
var _obj_hull: int
var _obj_nav: int
var _obj_repair: int
var _obj_escape: int

# ── Scene refs ────────────────────────────────────────────────────────────────
@onready var _submarine        : SubmarineInteractable     = $Objects/Submarine
@onready var _submarine_sprite : AnimatedSprite2D          = $Objects/Submarine/Sub
@onready var _exit_trigger     : Area2D                    = $ExitTrigger
@onready var _corridor_trigger : Area2D                    = $CorridorTrigger
@onready var _camera           : Camera2D                  = $player/Camera2D
@onready var _slot_engine      : ComponentSlotInteractable = $Objects/SlotEngine
@onready var _slot_hull        : ComponentSlotInteractable = $Objects/SlotHull
@onready var _slot_nav         : ComponentSlotInteractable = $Objects/SlotNav
@onready var _canvas_modulate  : CanvasModulate            = $CanvasModulate
@onready var _player           : CharacterBody2D           = $player
@onready var _engine_part      : Node2D                    = $Objects/EnginePart
@onready var _hull_part        : Node2D                    = $Objects/HullPart
@onready var _nav_part         : Node2D                    = $Objects/NavPart
@onready var _enemy_1          : Enemy                     = $Enemy
@onready var _enemy_2          : Enemy                     = $Enemy2

var _level_ended        : bool     = false
var _cine_cam           : Camera2D = null
var _tutorial_triggered : bool     = false


func _process(delta: float) -> void:
	if not is_instance_valid(_cine_cam):
		return
	var to_cam := _cine_cam.global_position - _player.global_position
	if to_cam.length() > 1.0:
		_player.cone_light.rotation = lerp_angle(
			_player.cone_light.rotation, to_cam.angle(), 6.0 * delta)
		_player.cone_light.position = Vector2.from_angle(_player.cone_light.rotation) * 5.0


func _ready() -> void:
	# ── Ambient music ─────────────────────────────────────────────────────────
	MusicManager.play(["res://assets/sounds/ambient_l1.mp3", "res://assets/sounds/ambient_l1_2.mp3"], -10.0)

	# ── Objectives ────────────────────────────────────────────────────────────
	ObjectiveManager.clear_objectives()
	_obj_engine = ObjectiveManager.add_objective("Recover the Drive Coupling")
	_obj_hull   = ObjectiveManager.add_objective("Recover the Pressure Seal")
	_obj_nav    = ObjectiveManager.add_objective("Recover the Nav Core")
	_obj_repair = ObjectiveManager.add_objective("Restore the Tethys-7")
	_obj_escape = ObjectiveManager.add_objective("Proceed to Kappa Station")

	# ── Inventory signals (mark collect objectives) ───────────────────────────
	Inventory.item_added.connect(_on_item_added)

	# ── Component slot signals ────────────────────────────────────────────────
	_slot_engine.slot_filled.connect(_on_slot_filled)
	_slot_hull.slot_filled.connect(_on_slot_filled)
	_slot_nav.slot_filled.connect(_on_slot_filled)

	# ── Submarine boarding ────────────────────────────────────────────────────
	_submarine.boarded.connect(_on_submarine_boarded)

	# ── Exit trigger ──────────────────────────────────────────────────────────
	_exit_trigger.body_entered.connect(_on_exit_reached)

	# ── Corridor boundary (block until sub is repaired) ───────────────────────
	_corridor_trigger.body_entered.connect(_on_corridor_entered)

	# ── Camera limits ─────────────────────────────────────────────────────────
	_camera.limit_left   = -50
	_camera.limit_top    = -50
	_camera.limit_right  = 1025
	_camera.limit_bottom = 655

	# ── Hide slots from interaction detection (TaskUI still uses them as data) ──
	_slot_engine.collision_layer = 0
	_slot_hull.collision_layer   = 0
	_slot_nav.collision_layer    = 0

	# ── Submarine sprite ──────────────────────────────────────────────────────
	_setup_sub_sprite()

	# ── Intro pan ─────────────────────────────────────────────────────────────
	_intro_pan.call_deferred()

	# ── Melee tutorial hook ───────────────────────────────────────────────────
	if not GameState.melee_tutorial_shown:
		_enemy_1.detection_zone.body_entered.connect(
			func(b: Node2D) -> void: _on_melee_detected(b, _enemy_1))
		_enemy_2.detection_zone.body_entered.connect(
			func(b: Node2D) -> void: _on_melee_detected(b, _enemy_2))


func _setup_sub_sprite() -> void:
	var sheet: Texture2D = load("res://assets/player/sub_upgraded.png")
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 8.0)
	for i in 5:
		var atlas := AtlasTexture.new()
		atlas.atlas  = sheet
		atlas.region = Rect2(i * 126, 0, 126, 112)
		frames.add_frame("idle", atlas)
	_submarine_sprite.sprite_frames = frames
	_submarine_sprite.scale = Vector2(0.5, 0.5)
	_submarine_sprite.play("idle")


# ── Cinematic camera helpers ──────────────────────────────────────────────────

func _start_cine_cam() -> Camera2D:
	var start_pos := _camera.get_screen_center_position()
	_camera.enabled = false
	_player.cone_light.energy = 0.99
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
	return _cine_cam


func _stop_cine_cam() -> void:
	_camera.enabled = true
	_player.cone_light.energy = 1.0
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


# ── Intro pan ─────────────────────────────────────────────────────────────────

func _intro_pan() -> void:
	_player.movement_locked = true
	_player.set_process_unhandled_input(false)
	var start_pos := _camera.get_screen_center_position()
	_start_cine_cam()

	const TRAVEL : float = 1.1
	const HOLD   : float = 0.9

	# Points of interest with a brief label shown at each stop
	var stops : Array = [
		[_exit_trigger.global_position + Vector2(0, 180),  "Exit Point"],
		[_engine_part.global_position,   "Drive Coupling"],
		[_hull_part.global_position,     "Pressure Seal"],
		[_nav_part.global_position,      "Nav Core"],
	]

	var font := _make_ui_font()

	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 30
	add_child(ui_layer)

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lbl.offset_top      = -120.0
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate.a  = 0.0
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(0.28, 0.82, 1.0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	ui_layer.add_child(lbl)

	for stop in stops:
		var dest : Vector2 = stop[0]
		var tag  : String  = stop[1]

		var move := create_tween()
		move.tween_property(_cine_cam, "global_position", dest, TRAVEL) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await move.finished

		lbl.text = tag
		create_tween().tween_property(lbl, "modulate:a", 1.0, 0.25)
		await get_tree().create_timer(HOLD).timeout
		create_tween().tween_property(lbl, "modulate:a", 0.0, 0.2)
		await get_tree().create_timer(0.25).timeout

	var tw_back := create_tween()
	tw_back.tween_property(_cine_cam, "global_position", start_pos, TRAVEL) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw_back.finished

	ui_layer.queue_free()
	_stop_cine_cam()
	_player.movement_locked = false
	_player.set_process_unhandled_input(true)


# ── Melee tutorial ────────────────────────────────────────────────────────────

func _on_melee_detected(body: Node2D, enemy: Enemy) -> void:
	if not body.is_in_group("player") or _tutorial_triggered:
		return
	_tutorial_triggered = true
	_run_melee_tutorial(enemy)


func _run_melee_tutorial(enemy: Enemy) -> void:
	enemy.ai_enabled = false
	_player.movement_locked = true
	_player.set_process_unhandled_input(false)
	var start_pos := _camera.get_screen_center_position()
	_start_cine_cam()
	_cine_cam.global_position = start_pos

	var pan := create_tween()
	pan.tween_property(_cine_cam, "global_position", enemy.global_position, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await pan.finished

	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Warning — hostile fauna detected.",
			"This creature will close distance and attack on contact.",
		],
	})
	await DialogueManager.dialogue_ended

	# dialogue_ended fires player._on_dialogue_ended which re-enables input —
	# keep movement locked; unlock shooting for the slow-mo phase
	_player.movement_locked = true
	_player.shooting_locked = false
	_player.set_process_unhandled_input(true)
	enemy.ai_enabled  = true
	enemy._player_ref = _player
	enemy._enter_state(Enemy.State.CHASE)
	GameState.melee_tutorial_shown = true

	# ── Slow-motion + B&W ────────────────────────────────────────────────────
	Engine.time_scale = 0.25

	# Grayscale overlay via screen-texture shader
	var bw_layer := CanvasLayer.new()
	bw_layer.layer        = 50
	bw_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bw_layer)

	var bw_rect := ColorRect.new()
	bw_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bw_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bw_rect.color        = Color.WHITE
	var bw_shader := Shader.new()
	bw_shader.code = """
shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 c = texture(screen_texture, SCREEN_UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(g), strength), 1.0);
}
"""
	var bw_mat := ShaderMaterial.new()
	bw_mat.shader = bw_shader
	bw_rect.material = bw_mat
	bw_layer.add_child(bw_rect)

	# Fade to B&W over ~1.6 real seconds (0.4 game-sec at 0.25 time_scale)
	create_tween().tween_method(
		func(v: float) -> void: bw_mat.set_shader_parameter("strength", v),
		0.0, 1.0, 0.4)

	# Slight zoom-out (0.5 game-sec ≈ 2 real sec at 0.25 time_scale)
	var zoom_tw := create_tween().set_parallel(true)
	zoom_tw.tween_property(_cine_cam, "global_position",
		(_player.global_position + enemy.global_position) * 0.5, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	zoom_tw.tween_property(_cine_cam, "zoom", Vector2(1.35, 1.35), 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Heartbeat (looped)
	var hb_stream := load("res://assets/sounds/heartbeat.mp3") as AudioStreamMP3
	hb_stream.loop = true
	var hb_snd := AudioStreamPlayer.new()
	hb_snd.stream = hb_stream
	add_child(hb_snd)
	hb_snd.play()

	# Tutorial text panel — top of screen
	var font := _make_ui_font()
	var txt_layer := CanvasLayer.new()
	txt_layer.layer        = 55
	txt_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(txt_layer)

	var txt_panel := PanelContainer.new()
	txt_panel.layout_mode     = 1
	txt_panel.anchor_left     = 0.5
	txt_panel.anchor_right    = 0.5
	txt_panel.anchor_top      = 0.0
	txt_panel.anchor_bottom   = 0.0
	txt_panel.offset_left     = -200.0
	txt_panel.offset_right    =  200.0
	txt_panel.offset_top      =  18.0
	txt_panel.offset_bottom   =  18.0
	txt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	txt_panel.grow_vertical   = Control.GROW_DIRECTION_END
	txt_panel.modulate.a      = 0.0
	var txt_style := StyleBoxFlat.new()
	txt_style.bg_color     = Color(0.04, 0.09, 0.14, 0.93)
	txt_style.border_color = Color(0.18, 0.52, 0.68, 0.75)
	txt_style.set_border_width_all(1)
	txt_style.set_corner_radius_all(6)
	txt_style.content_margin_left   = 22.0
	txt_style.content_margin_right  = 22.0
	txt_style.content_margin_top    = 12.0
	txt_style.content_margin_bottom = 12.0
	txt_panel.add_theme_stylebox_override("panel", txt_style)
	txt_layer.add_child(txt_panel)

	var txt_vbox := VBoxContainer.new()
	txt_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	txt_panel.add_child(txt_vbox)

	for line in ["Shoot the creature", "to defend yourself!"]:
		var lbl := Label.new()
		lbl.text = line
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(0.80, 0.91, 0.97, 1.0))
		txt_vbox.add_child(lbl)

	await get_tree().create_timer(0.3, true, false, true).timeout
	txt_panel.modulate.a = 1.0

	# Flash the panel — 0.1 game-sec per step ≈ 0.4 real-sec at 0.25 time_scale
	var flash_tw := create_tween().set_loops()
	flash_tw.tween_property(txt_panel, "modulate:a", 0.15, 0.1)
	flash_tw.tween_property(txt_panel, "modulate:a", 1.0,  0.1)

	# Wait until enemy dies or 5 real seconds pass, whichever comes first
	var _tut_done := false
	if is_instance_valid(enemy):
		enemy.died.connect(func() -> void: _tut_done = true, CONNECT_ONE_SHOT)
	get_tree().create_timer(5.0, true, false, true).timeout.connect(
		func() -> void: _tut_done = true)
	while not _tut_done:
		if not is_instance_valid(enemy):
			break
		await get_tree().process_frame

	# ── Restore ───────────────────────────────────────────────────────────────
	Engine.time_scale = 1.0
	flash_tw.kill()
	hb_snd.stop()
	hb_snd.queue_free()
	txt_panel.modulate.a = 0.0
	create_tween().tween_method(
		func(v: float) -> void: bw_mat.set_shader_parameter("strength", v),
		1.0, 0.0, 0.4)
	await get_tree().create_timer(0.5).timeout
	txt_layer.queue_free()
	bw_layer.queue_free()
	_player.movement_locked = false
	_stop_cine_cam()


# ── Objective helpers ─────────────────────────────────────────────────────────

func _on_item_added(item: ItemData, _qty: int) -> void:
	match item.id:
		"drive_coupling":
			ObjectiveManager.complete_objective(_obj_engine)
		"pressure_seal":
			ObjectiveManager.complete_objective(_obj_hull)
		"nav_core":
			ObjectiveManager.complete_objective(_obj_nav)


func _on_slot_filled() -> void:
	if not (_slot_engine.is_filled and _slot_hull.is_filled and _slot_nav.is_filled):
		return
	var snd := AudioStreamPlayer.new()
	snd.stream = load("res://assets/sounds/repair.mp3")
	snd.finished.connect(snd.queue_free)
	add_child(snd)
	snd.play()
	GameState.submarine_fixed = true
	ObjectiveManager.complete_objective(_obj_repair)
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Drive coupling installed.",
			"Pressure seal nominal.",
			"Nav core online.",
			"Tethys-7 is operational.",
			"Approach the helm to depart.",
		],
	})


# ── Submarine driving sequence ────────────────────────────────────────────────

func _on_submarine_boarded(player: Node) -> void:
	player.global_position = _submarine.global_position
	_submarine_sprite.reparent(player)
	_submarine_sprite.position = Vector2.ZERO
	player._sub_sprite = _submarine_sprite
	player.enter_submarine_mode()
	var tw := create_tween()
	tw.tween_property(_canvas_modulate, "color", Color(0.12, 0.13, 0.15, 1.0), 0.6)


func _on_corridor_entered(body: Node) -> void:
	if not body.is_in_group("player") or GameState.submarine_fixed:
		return
	body.global_position = Vector2(1530.0, 480.0)
	body.velocity        = Vector2.ZERO
	if not DialogueManager.is_active:
		DialogueManager.start_dialogue({
			"speaker": "ORCA",
			"lines": [
				"Tethys-7 is non-operational. The corridor ahead leads to open ocean.",
				"Install all three components into the hull bays, then board the submarine.",
			],
		})


func _on_exit_reached(body: Node) -> void:
	if _level_ended:
		return
	if "submarine_mode" in body and body.submarine_mode:
		_level_ended = true
		ObjectiveManager.complete_objective(_obj_escape)
		DialogueManager.start_dialogue({
			"speaker": "ORCA",
			"lines": [
				"Tethys-7 clear of the trench.",
				"Auto-routing to Station Kappa — the only pressurized structure in range.",
				"Pulling Kappa's last status report.",
				"Most of it is redacted.",
			],
		})
		DialogueManager.dialogue_ended.connect(
			func():
				# Snapshot all completed Level 1 objectives into GameState
				# before the scene is destroyed.
				GameState.save_objectives_from_level_1()
				get_tree().change_scene_to_file("res://cutscene/transit_cinematic.tscn"),
			CONNECT_ONE_SHOT
		)
