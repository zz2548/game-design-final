extends Node2D

var _bg       : Sprite2D = null
var _mg       : Sprite2D = null
var _bg_x     : float    = 0.0
var _mg_x     : float    = 0.0
var _swimmers : Array    = []

const BG_SCROLL := 14.0
const MG_SCROLL := 28.0

const SCENES := {
	0: "res://cutscene/opening_cinematic.tscn",
	1: "res://levels/level_1/level_1.tscn",
	2: "res://levels/level_2/level_2.tscn",
	3: "res://levels/level_3/level_3.tscn",
}

const COL_BG     : Color = Color(0.02, 0.05, 0.10)
const COL_ACCENT : Color = Color(0.28, 0.82, 1.00)

const OPTIONS := [
	{"label": "NEW GAME",  "sub": "Watch the intro",    "col": Color(0.28, 0.82, 1.00)},
	{"label": "LEVEL  1",  "sub": "Trench",              "col": Color(0.30, 0.55, 0.90)},
	{"label": "LEVEL  2",  "sub": "Station",             "col": Color(0.55, 0.30, 0.90)},
	{"label": "LEVEL  3",  "sub": "Bore Shaft",          "col": Color(0.90, 0.45, 0.20)},
]

var _selected  : int  = 0
var _confirmed : bool = false
var _panels    : Array[PanelContainer] = []
var _ui        : CanvasLayer


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


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)

	var fade := ColorRect.new()
	fade.name = "Fade"
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 0.5)

	var S := get_viewport().get_visible_rect().size

	var title := Label.new()
	title.text = "START POINT"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", COL_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top    = S.y * 0.13
	title.offset_bottom = S.y * 0.13 + 56.0
	_ui.add_child(title)

	var sub := Label.new()
	sub.text = "Begin from the intro or jump straight to a level."
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.55, 0.70, 0.80))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top    = S.y * 0.13 + 58.0
	sub.offset_bottom = S.y * 0.13 + 86.0
	_ui.add_child(sub)

	var panel_w : float = minf(220.0, (S.x - 100.0) / 4.0 - 20.0)
	var panel_h : float = 190.0
	var gap     : float = 24.0
	var total_w : float = panel_w * 4.0 + gap * 3.0
	var px      : float = S.x * 0.5 - total_w * 0.5
	var py      : float = S.y * 0.5 - panel_h * 0.5 + 10.0

	for i in OPTIONS.size():
		var opt   : Dictionary   = OPTIONS[i]
		var panel := _make_panel(opt["label"] as String, opt["sub"] as String, opt["col"] as Color)
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.offset_left   = px + i * (panel_w + gap)
		panel.offset_top    = py
		panel.offset_right  = panel.offset_left + panel_w
		panel.offset_bottom = py + panel_h
		_ui.add_child(panel)
		_panels.append(panel)

		var idx := i
		panel.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
				_selected = idx
				_refresh_selection()
				_confirm()
		)

	var hint := Label.new()
	hint.text = "A / D to select   ·   Enter / E to confirm"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.40, 0.55, 0.65))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top    = -50.0
	hint.offset_bottom = -20.0
	_ui.add_child(hint)


func _make_panel(label: String, subtitle: String, col: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(col.r * 0.10, col.g * 0.10, col.b * 0.10, 0.95)
	style.border_color = col
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left   = 16.0
	style.content_margin_right  = 16.0
	style.content_margin_top    = 20.0
	style.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", col)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(sep)

	var sub := Label.new()
	sub.text = subtitle
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(col.r * 0.75, col.g * 0.75, col.b * 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(sub)

	return panel


func _refresh_selection() -> void:
	for i in _panels.size():
		var col : Color = OPTIONS[i]["col"]
		var style := _panels[i].get_theme_stylebox("panel") as StyleBoxFlat
		if i == _selected:
			style.bg_color = Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 1.0)
			style.set_border_width_all(3)
		else:
			style.bg_color = Color(col.r * 0.08, col.g * 0.08, col.b * 0.08, 0.85)
			style.set_border_width_all(1)


func _unhandled_input(event: InputEvent) -> void:
	if _confirmed:
		return
	if not event is InputEventKey or not (event as InputEventKey).pressed:
		return
	match (event as InputEventKey).keycode:
		KEY_LEFT, KEY_A:
			_selected = wrapi(_selected - 1, 0, OPTIONS.size())
			_refresh_selection()
		KEY_RIGHT, KEY_D:
			_selected = wrapi(_selected + 1, 0, OPTIONS.size())
			_refresh_selection()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
			_confirm()


func _confirm() -> void:
	if _confirmed:
		return
	_confirmed = true

	# When skipping to a level, clear saved weapon state so the player starts fresh.
	if _selected > 0:
		GameState.saved_weapons = []
		GameState.saved_current_weapon = ""
		SceneManager.current_level = _selected

	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.45)
	tw.tween_callback(func() -> void:
		get_tree().change_scene_to_file(SCENES[_selected])
	)
