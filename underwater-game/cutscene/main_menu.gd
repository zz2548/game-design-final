extends Node

const NEXT_SCENE := "res://cutscene/difficulty_select.tscn"

var _S             : Vector2
var _overlay       : ColorRect = null
var _transitioning : bool      = false
var _bg            : Sprite2D  = null
var _mg            : Sprite2D  = null
var _bg_x          : float     = 0.0
var _mg_x          : float     = 0.0
var _swimmers      : Array     = []  # Array of {node, vx}

const BG_SCROLL := 14.0
const MG_SCROLL := 28.0


func _ready() -> void:
	_S = get_viewport().get_visible_rect().size
	_build.call_deferred()


func _process(delta: float) -> void:
	_bg_x += BG_SCROLL * delta
	_mg_x += MG_SCROLL * delta
	if _bg != null:
		_bg.region_rect = Rect2(_bg_x, 0, 2461, 1645)
	if _mg != null:
		_mg.region_rect = Rect2(_mg_x, 0, 2461, 1645)

	for s in _swimmers:
		var node : AnimatedSprite2D = s["node"]
		if not is_instance_valid(node):
			continue
		node.position.x += s["vx"] * delta
		if s["vx"] > 0 and node.position.x > _S.x + 80:
			node.position.x = -80.0
		elif s["vx"] < 0 and node.position.x < -80:
			node.position.x = _S.x + 80.0


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning or _overlay == null:
		return
	var fired := false
	if event is InputEventKey:
		fired = (event as InputEventKey).pressed and not (event as InputEventKey).echo
	elif event is InputEventMouseButton:
		fired = (event as InputEventMouseButton).pressed
	if not fired:
		return
	_transitioning = true
	get_viewport().set_input_as_handled()
	_go()


func _build() -> void:
	# ── Overlay first so _go() is safe at any time ────────────────────────────
	var top_layer := CanvasLayer.new()
	top_layer.layer = 99
	add_child(top_layer)
	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_layer.add_child(_overlay)

	# ── Background — same setup as level_1.tscn ───────────────────────────────
	_bg = Sprite2D.new()
	_bg.texture        = load("res://assets/background/background.png")
	_bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_bg.region_enabled = true
	_bg.region_rect    = Rect2(0, 0, 2461, 1645)
	_bg.modulate       = Color(1, 1, 1, 0.6)
	_bg.position       = Vector2(744, 432)
	add_child(_bg)

	_mg = Sprite2D.new()
	_mg.texture        = load("res://assets/background/midground.png")
	_mg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_mg.region_enabled = true
	_mg.region_rect    = Rect2(0, 0, 2461, 1645)
	_mg.modulate       = Color(1, 1, 1, 0.8)
	_mg.position       = Vector2(744, 432)
	add_child(_mg)

	# ── Swimming characters ───────────────────────────────────────────────────
	var player := _make_swimmer("res://assets/player/player-swiming.png", 7, 80, 80, 10.0)
	player.position = Vector2(_S.x * 0.38, _S.y * 0.54)
	player.scale    = Vector2(2.0, 2.0)
	add_child(player)
	_swimmers.append({"node": player, "vx": 72.0})

	var e1 := _make_swimmer("res://assets/enemies/fish.png", 4, 32, 32, 8.0)
	e1.position = Vector2(_S.x * 0.70, _S.y * 0.30)
	e1.scale    = Vector2(1.8, 1.8)
	add_child(e1)
	_swimmers.append({"node": e1, "vx": 45.0})

	var e2 := _make_swimmer("res://assets/enemies/fish-big.png", 4, 54, 49, 8.0)
	e2.position = Vector2(_S.x * 0.25, _S.y * 0.68)
	e2.scale    = Vector2(1.7, 1.7)
	e2.flip_h   = true
	add_child(e2)
	_swimmers.append({"node": e2, "vx": -52.0})

	var e3 := _make_swimmer("res://assets/enemies/fish.png", 4, 32, 32, 8.0)
	e3.position = Vector2(_S.x * 0.10, _S.y * 0.40)
	e3.scale    = Vector2(1.4, 1.4)
	add_child(e3)
	_swimmers.append({"node": e3, "vx": 36.0})

	# ── UI layer ──────────────────────────────────────────────────────────────
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	var title_font := SystemFont.new()
	title_font.font_names   = PackedStringArray(["Impact", "Arial Black", "Franklin Gothic Heavy", "sans-serif"])
	title_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY

	var mono := SystemFont.new()
	mono.font_names   = PackedStringArray(["Consolas", "Courier New", "monospace"])
	mono.antialiasing = TextServer.FONT_ANTIALIASING_GRAY

	var title_y : float = _S.y * 0.26

	# Title outer glow
	var t_glow := Label.new()
	t_glow.text = "EUROPA DEEP"
	t_glow.add_theme_font_override("font", title_font)
	t_glow.add_theme_font_size_override("font_size", 82)
	t_glow.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.0))
	t_glow.add_theme_constant_override("outline_size", 22)
	t_glow.add_theme_color_override("font_outline_color", Color(0.12, 0.48, 0.90, 0.22))
	t_glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	t_glow.offset_top    = title_y
	t_glow.offset_bottom = title_y + 112.0
	t_glow.modulate.a = 0.0
	ui.add_child(t_glow)

	# Title main
	var t_main := Label.new()
	t_main.text = "EUROPA DEEP"
	t_main.add_theme_font_override("font", title_font)
	t_main.add_theme_font_size_override("font_size", 82)
	t_main.add_theme_color_override("font_color", Color(0.84, 0.96, 1.0))
	t_main.add_theme_constant_override("outline_size", 3)
	t_main.add_theme_color_override("font_outline_color", Color(0.10, 0.38, 0.72, 0.80))
	t_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_main.set_anchors_preset(Control.PRESET_TOP_WIDE)
	t_main.offset_top    = title_y
	t_main.offset_bottom = title_y + 112.0
	t_main.modulate.a = 0.0
	ui.add_child(t_main)

	# Separator
	var sep_y : float = title_y + 116.0
	var sep := ColorRect.new()
	sep.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sep.offset_left   =  _S.x * 0.28
	sep.offset_right  = -_S.x * 0.28
	sep.offset_top    = sep_y
	sep.offset_bottom = sep_y + 1.0
	sep.color = Color(0.22, 0.52, 0.80, 0.55)
	sep.modulate.a = 0.0
	ui.add_child(sep)

	# Credits
	var credits := Label.new()
	credits.text = "Justin Dutta   ·   Jerry Zou   ·   Rafid Ahmed"
	credits.add_theme_font_override("font", mono)
	credits.add_theme_font_size_override("font_size", 14)
	credits.add_theme_color_override("font_color", Color(0.40, 0.62, 0.78))
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.set_anchors_preset(Control.PRESET_TOP_WIDE)
	credits.offset_top    = sep_y + 12.0
	credits.offset_bottom = sep_y + 36.0
	credits.modulate.a = 0.0
	ui.add_child(credits)

	# Prompt
	var prompt := Label.new()
	prompt.text = "PRESS ANY KEY"
	prompt.add_theme_font_override("font", mono)
	prompt.add_theme_font_size_override("font_size", 13)
	prompt.add_theme_color_override("font_color", Color(0.28, 0.82, 1.0))
	prompt.add_theme_constant_override("outline_size", 2)
	prompt.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.65))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top    = -50.0
	prompt.offset_bottom = -22.0
	prompt.modulate.a = 0.0
	ui.add_child(prompt)

	# ── Staggered reveal ──────────────────────────────────────────────────────
	create_tween().tween_property(_overlay, "color:a", 0.0, 2.0).set_trans(Tween.TRANS_SINE)

	await get_tree().create_timer(0.7).timeout
	var tw_title := create_tween().set_parallel(true)
	tw_title.tween_property(t_main, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
	tw_title.tween_property(t_glow, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(1.4).timeout

	var t_pulse := create_tween().set_loops()
	t_pulse.tween_property(t_main, "modulate:a", 0.86, 3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t_pulse.tween_property(t_main, "modulate:a", 1.0,  3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	create_tween().tween_property(sep, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.45).timeout

	create_tween().tween_property(credits, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(1.0).timeout

	create_tween().tween_property(prompt, "modulate:a", 1.0, 0.5)
	await get_tree().create_timer(0.55).timeout
	var p_pulse := create_tween().set_loops()
	p_pulse.tween_property(prompt, "modulate:a", 0.25, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	p_pulse.tween_property(prompt, "modulate:a", 1.0,  1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _make_swimmer(path: String, frame_count: int, fw: int, fh: int, fps: float) -> AnimatedSprite2D:
	var tex    : Texture2D = load(path)
	var frames := SpriteFrames.new()
	frames.add_animation("swim")
	frames.set_animation_loop("swim", true)
	frames.set_animation_speed("swim", fps)
	for i in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2(i * fw, 0, fw, fh)
		frames.add_frame("swim", atlas)
	var sp := AnimatedSprite2D.new()
	sp.sprite_frames = frames
	sp.play("swim")
	return sp


func _go() -> void:
	var tw := create_tween()
	tw.tween_property(_overlay, "color:a", 1.0, 0.65).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		get_tree().change_scene_to_file(NEXT_SCENE)
	)
