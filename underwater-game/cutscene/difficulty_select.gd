extends Node

const NEXT_SCENE := "res://cutscene/level_select.tscn"

const COL_EASY : Color = Color(0.20, 0.78, 0.40)
const COL_HARD : Color = Color(0.85, 0.22, 0.18)

var _selected  : int  = 1
var _confirmed : bool = false
var _panels    : Array[PanelContainer] = []
var _ui        : CanvasLayer

var _bg       : Sprite2D = null
var _mg       : Sprite2D = null
var _bg_x     : float    = 0.0
var _mg_x     : float    = 0.0
var _swimmers : Array    = []

const BG_SCROLL := 14.0
const MG_SCROLL := 28.0


func _ready() -> void:
	_build_bg()
	_build_ui()
	_refresh_selection()


func _process(delta: float) -> void:
	_bg_x += BG_SCROLL * delta
	_mg_x += MG_SCROLL * delta
	if _bg: _bg.region_rect = Rect2(_bg_x, 0, 2461, 1645)
	if _mg: _mg.region_rect = Rect2(_mg_x, 0, 2461, 1645)
	var S := get_viewport().get_visible_rect().size
	for s in _swimmers:
		var node : AnimatedSprite2D = s["node"]
		if not is_instance_valid(node): continue
		node.position.x += s["vx"] * delta
		if s["vx"] > 0 and node.position.x > S.x + 80: node.position.x = -80.0
		elif s["vx"] < 0 and node.position.x < -80:    node.position.x = S.x + 80.0


func _build_bg() -> void:
	var S := get_viewport().get_visible_rect().size

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

	var p := _make_swimmer("res://assets/player/player-swiming.png", 7, 80, 80, 10.0)
	p.position = Vector2(S.x * 0.38, S.y * 0.54); p.scale = Vector2(2.0, 2.0)
	add_child(p); _swimmers.append({"node": p, "vx": 72.0})

	var e1 := _make_swimmer("res://assets/enemies/fish.png", 4, 32, 32, 8.0)
	e1.position = Vector2(S.x * 0.70, S.y * 0.30); e1.scale = Vector2(1.8, 1.8)
	add_child(e1); _swimmers.append({"node": e1, "vx": 45.0})

	var e2 := _make_swimmer("res://assets/enemies/fish-big.png", 4, 54, 49, 8.0)
	e2.position = Vector2(S.x * 0.20, S.y * 0.68); e2.scale = Vector2(1.7, 1.7); e2.flip_h = true
	add_child(e2); _swimmers.append({"node": e2, "vx": -52.0})

	var e3 := _make_swimmer("res://assets/enemies/fish.png", 4, 32, 32, 8.0)
	e3.position = Vector2(S.x * 0.10, S.y * 0.40); e3.scale = Vector2(1.4, 1.4)
	add_child(e3); _swimmers.append({"node": e3, "vx": 36.0})


func _make_swimmer(path: String, fc: int, fw: int, fh: int, fps: float) -> AnimatedSprite2D:
	var tex := load(path) as Texture2D
	var sf  := SpriteFrames.new()
	sf.add_animation("swim"); sf.set_animation_loop("swim", true); sf.set_animation_speed("swim", fps)
	for i in fc:
		var a := AtlasTexture.new(); a.atlas = tex; a.region = Rect2(i * fw, 0, fw, fh); sf.add_frame("swim", a)
	var sp := AnimatedSprite2D.new(); sp.sprite_frames = sf; sp.play("swim")
	return sp


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)

	# Fade-in overlay
	var fade := ColorRect.new()
	fade.name = "Fade"
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 0.6)

	var S := get_viewport().get_visible_rect().size

	# Title
	var title := Label.new()
	title.text = "DIFFICULTY"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.28, 0.82, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top    = S.y * 0.14
	title.offset_bottom = S.y * 0.14 + 56.0
	_ui.add_child(title)

	# Subtitle
	var sub := Label.new()
	sub.text = "Choose before your mission begins."
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.55, 0.70, 0.80))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top    = S.y * 0.14 + 58.0
	sub.offset_bottom = S.y * 0.14 + 86.0
	_ui.add_child(sub)

	# Option panels
	var panel_w : float = minf(300.0, (S.x - 120.0) * 0.5 - 20.0)
	var panel_h : float = 210.0
	var gap     : float = 40.0
	var total_w : float = panel_w * 2.0 + gap
	var px      : float = S.x * 0.5 - total_w * 0.5
	var py      : float = S.y * 0.5 - panel_h * 0.5

	var options := [
		{"label": "EASY", "col": COL_EASY},
		{"label": "HARD", "col": COL_HARD},
	]

	for i in 2:
		var opt    : Dictionary    = options[i]
		var panel  := _make_panel(opt["label"], opt["col"] as Color)
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.offset_left   = px + i * (panel_w + gap)
		panel.offset_top    = py
		panel.offset_right  = panel.offset_left + panel_w
		panel.offset_bottom = py + panel_h
		_ui.add_child(panel)
		_panels.append(panel)

		# Mouse click
		var idx := i
		panel.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
				_selected = idx
				_refresh_selection()
				_confirm()
		)

	# Hint label
	var hint := Label.new()
	hint.text = "A / D to select   ·   Enter / E to confirm"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.40, 0.55, 0.65))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top    = -50.0
	hint.offset_bottom = -20.0
	_ui.add_child(hint)


func _make_panel(label: String, col: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(col.r * 0.12, col.g * 0.12, col.b * 0.12, 0.95)
	style.border_color = col
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left   = 20.0
	style.content_margin_right  = 20.0
	style.content_margin_top    = 20.0
	style.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", style)

	var title := Label.new()
	title.text = label
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", col)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	return panel


# ── Selection highlight ───────────────────────────────────────────────────────

func _refresh_selection() -> void:
	var cols : Array[Color] = [COL_EASY, COL_HARD]
	for i in _panels.size():
		var style := _panels[i].get_theme_stylebox("panel") as StyleBoxFlat
		var col : Color = cols[i]
		if i == _selected:
			style.bg_color = Color(col.r * 0.28, col.g * 0.28, col.b * 0.28, 1.0)
			style.set_border_width_all(3)
		else:
			style.bg_color = Color(col.r * 0.08, col.g * 0.08, col.b * 0.08, 0.85)
			style.set_border_width_all(1)


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _confirmed:
		return
	if not event is InputEventKey or not (event as InputEventKey).pressed:
		return
	var key := (event as InputEventKey).keycode
	match key:
		KEY_LEFT, KEY_A:
			_selected = 0
			_refresh_selection()
		KEY_RIGHT, KEY_D:
			_selected = 1
			_refresh_selection()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_confirm()
		KEY_E:
			_confirm()


# ── Confirm ───────────────────────────────────────────────────────────────────

func _confirm() -> void:
	if _confirmed:
		return
	_confirmed = true

	GameState.difficulty = (
		GameState.Difficulty.EASY if _selected == 0
		else GameState.Difficulty.HARD
	)

	# Fade to black then load the intro cinematic
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.55)
	tw.tween_callback(func() -> void:
		get_tree().change_scene_to_file(NEXT_SCENE)
	)
