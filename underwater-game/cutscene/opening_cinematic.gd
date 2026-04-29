extends Node

const TEXT_SPEED := 0.028

# ── Scene graph ───────────────────────────────────────────────────────────────
# Root
#   _cam   (Node2D)  ← camera zoom + pan applied here
#     _world (Node2D) ← shake applied here
#       _env_layer (Node2D) ← enemies/mines, scrolls left to be "passed by"
#       _bg, _mg, _sub     ← not in env_layer; independent
#   _ui  (CanvasLayer) ← overlays, flash, dialogue

var _S          : Vector2
var _cam        : Node2D
var _world      : Node2D
var _env_layer  : Node2D
var _ui         : CanvasLayer
var _bg_rect    : ColorRect
var _flash_rect : ColorRect

var _bg      : Sprite2D
var _mg      : Sprite2D
var _bg_x    : float = 0.0
var _mg_x    : float = 0.0
var _scroll  : bool  = false
var _env_spd : float = 70.0

var _sub : AnimatedSprite2D

# Serpent
var _serpent   : Line2D
var _serp_t    : float = 0.0
var _serp_x    : float = 0.0
var _serp_live : bool  = false
const SERP_N    := 38
const SERP_STEP := 42.0
const SERP_SPD  := 660.0

# Camera animation state (applied in _process)
var _cam_zoom  : float   = 1.0
var _cam_focus : Vector2 = Vector2.ZERO   # world point to keep centered

# Dialogue box
var _cur_dbox : Control = null

# Skip
var _skip      : bool = false
var _card_skip : bool = false


func _ready() -> void:
	_S = get_viewport().get_visible_rect().size
	_cam_focus = _S * 0.5

	_cam   = Node2D.new(); add_child(_cam)
	_world = Node2D.new(); _cam.add_child(_world)

	_ui = CanvasLayer.new(); _ui.layer = 20; add_child(_ui)

	_bg_rect = ColorRect.new()
	_bg_rect.color = Color.BLACK
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_bg_rect)

	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1,1,1,0)
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_flash_rect)

	_run.call_deferred()


func _process(delta: float) -> void:
	if _scroll:
		_bg_x += 20.0 * delta
		_mg_x += 44.0 * delta
		if _bg: _bg.region_rect = Rect2(_bg_x, 0, 6000, 4000)
		if _mg: _mg.region_rect = Rect2(_mg_x, 0, 6000, 4000)
		_env_layer.position.x -= _env_spd * delta

	if _serp_live and is_instance_valid(_serpent):
		_serp_t += delta * 2.4
		_serp_x += delta * SERP_SPD
		var pts := PackedVector2Array()
		var cy  := _S.y * 0.46
		for i in SERP_N:
			var x := i * SERP_STEP + _serp_x
			var y := cy + sin(i * 0.21 + _serp_t * 2.1) * 168.0 + sin(i * 0.47 + _serp_t * 0.88) * 58.0
			pts.append(Vector2(x, y))
		_serpent.points = pts

	# Apply camera zoom/pan every frame
	_cam.scale   = Vector2(_cam_zoom, _cam_zoom)
	_cam.position = _S * 0.5 - _cam_focus * _cam_zoom


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_skip = true
		get_viewport().set_input_as_handled()
		return
	var pressed := event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	if not pressed and event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	if pressed:
		_card_skip = true
		get_viewport().set_input_as_handled()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _w(t: float) -> void:
	if _skip: return
	await get_tree().create_timer(t).timeout


func _wait_i(duration: float) -> bool:
	var end := Time.get_ticks_msec() + int(duration * 1000.0)
	while Time.get_ticks_msec() < end:
		if _skip or _card_skip: return true
		await get_tree().process_frame
	return false


func _do_flash(col: Color, fade: float) -> void:
	_flash_rect.color = col
	create_tween().tween_property(_flash_rect, "color:a", 0.0, fade)


func _shake(strength: float, duration: float) -> void:
	var tw := create_tween()
	for _i in maxi(int(duration / 0.035), 4):
		tw.tween_property(_world, "position",
			Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.035)
	tw.tween_property(_world, "position", Vector2.ZERO, 0.05)


func _zoom_to(z: float, focus: Vector2, dur: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_cam_zoom",  z,     dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_cam_focus", focus, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _boom(pos: Vector2, sc: float, fps: float, big: bool) -> void:
	var anim := AnimatedSprite2D.new()
	var tex  : Texture2D = load("res://assets/vfx/explosion-big.png" if big else "res://assets/vfx/explosion.png")
	var frm  := SpriteFrames.new()
	frm.add_animation("e"); frm.set_animation_loop("e", false); frm.set_animation_speed("e", fps)
	var fw := 78 if big else 60
	var fh := 87 if big else 82
	for i in 11:
		var a := AtlasTexture.new(); a.atlas = tex; a.region = Rect2(i * fw, 0, fw, fh); frm.add_frame("e", a)
	anim.sprite_frames = frm; anim.scale = Vector2(sc, sc)
	anim.position = pos
	anim.animation_finished.connect(anim.queue_free)
	_world.add_child(anim); anim.play("e")


func _make_fish(path: String, fc: int, fw: int, fh: int, sc: float) -> AnimatedSprite2D:
	var anim := AnimatedSprite2D.new()
	var frm  := SpriteFrames.new()
	frm.add_animation("s"); frm.set_animation_loop("s", true); frm.set_animation_speed("s", 8.0)
	var tex : Texture2D = load(path)
	for i in fc:
		var a := AtlasTexture.new(); a.atlas = tex; a.region = Rect2(i * fw, 0, fw, fh); frm.add_frame("s", a)
	anim.sprite_frames = frm; anim.scale = Vector2(sc, sc); anim.play("s")
	return anim


func _make_sub() -> AnimatedSprite2D:
	return _make_fish("res://assets/player/sub_upgraded.png", 5, 126, 112, 0.8)


func _make_mine(sc: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/enemies/mine.png")
	s.scale   = Vector2(sc, sc)
	return s


# ── Dialogue box (matches dialogue_ui.gd style exactly) ──────────────────────

func _make_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names    = PackedStringArray(["Consolas", "Courier New", "monospace"])
	f.antialiasing  = TextServer.FONT_ANTIALIASING_GRAY
	return f


# Builds a panel + inner nodes matching dialogue_ui.tscn layout.
# Returns [panel, rtl, prompt_label].
func _build_dbox(speaker: String, text: String, show_prompt: bool) -> Array:
	var font := _make_font()

	# Root panel
	var panel := PanelContainer.new()
	panel.layout_mode    = 1
	panel.anchor_left    = 0.0
	panel.anchor_top     = 1.0
	panel.anchor_right   = 1.0
	panel.anchor_bottom  = 1.0
	panel.offset_left    = 72.0
	panel.offset_top     = -210.0
	panel.offset_right   = -72.0
	panel.offset_bottom  = -24.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.04, 0.09, 0.14, 0.93)
	style.border_color = Color(0.18, 0.52, 0.68, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left   = 22.0
	style.content_margin_right  = 22.0
	style.content_margin_top    = 14.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	panel.modulate.a = 0.0
	_ui.add_child(panel)

	# VBox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	var spk := Label.new()
	spk.text = speaker
	spk.uppercase = true
	spk.add_theme_font_override("font", font)
	spk.add_theme_font_size_override("font_size", 12)
	spk.add_theme_color_override("font_color", Color(0.28, 0.82, 1.0, 1.0))
	header.add_child(spk)

	# Divider
	var div := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.18, 0.52, 0.68, 0.4)
	sep_style.set_content_margin_all(0)
	div.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(div)

	# Dialogue text
	var rtl := RichTextLabel.new()
	rtl.custom_minimum_size = Vector2(20, 80)
	rtl.bbcode_enabled  = true
	rtl.fit_content     = false
	rtl.scroll_active   = false
	rtl.autowrap_mode   = TextServer.AUTOWRAP_WORD_SMART
	rtl.visible_ratio   = 0.0
	rtl.text            = text
	rtl.add_theme_font_override("normal_font", font)
	rtl.add_theme_font_size_override("normal_font_size", 15)
	rtl.add_theme_color_override("default_color", Color(0.80, 0.91, 0.97, 1.0))
	vbox.add_child(rtl)

	# Prompt
	var prompt := Label.new()
	prompt.text               = "[E] Continue"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt.visible            = show_prompt
	prompt.modulate.a         = 0.0
	prompt.add_theme_font_override("font", font)
	prompt.add_theme_font_size_override("font_size", 11)
	prompt.add_theme_color_override("font_color", Color(0.30, 0.58, 0.72, 0.65))
	vbox.add_child(prompt)

	return [panel, rtl, prompt]


# Non-blocking — plays during the cinematic and auto-dismisses.
func _dbox(speaker: String, text: String, duration: float) -> void:
	if is_instance_valid(_cur_dbox):
		var old := _cur_dbox
		create_tween().tween_property(old, "modulate:a", 0.0, 0.25).finished.connect(old.queue_free)
	var result := _build_dbox(speaker, text, false)
	var panel  := result[0] as Control
	var rtl    := result[1] as RichTextLabel
	_cur_dbox  = panel
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.3)
	create_tween().tween_property(rtl, "visible_ratio", 1.0, text.length() * TEXT_SPEED)
	var dismiss := create_tween()
	dismiss.tween_interval(duration)
	dismiss.tween_property(panel, "modulate:a", 0.0, 0.4)
	dismiss.tween_callback(panel.queue_free)


# Blocking — waits for typewriter then E/auto-advance. Used on black-screen cards.
func _card_dbox(speaker: String, text: String, hold: float) -> void:
	if is_instance_valid(_cur_dbox):
		var old := _cur_dbox; _cur_dbox = null
		create_tween().tween_property(old, "modulate:a", 0.0, 0.2).finished.connect(old.queue_free)
		await get_tree().create_timer(0.25).timeout
	var result  := _build_dbox(speaker, text, true)
	var panel   := result[0] as Control
	var rtl     := result[1] as RichTextLabel
	var prompt  := result[2] as Label
	_cur_dbox   = panel
	_card_skip  = false
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.35)
	var type_dur := text.length() * TEXT_SPEED
	var type_tw  := create_tween()
	type_tw.tween_property(rtl, "visible_ratio", 1.0, type_dur)
	if await _wait_i(type_dur):
		type_tw.kill(); rtl.visible_ratio = 1.0; _card_skip = false
	if _skip: panel.queue_free(); return
	# Show [E] prompt once typing is done
	create_tween().tween_property(prompt, "modulate:a", 1.0, 0.3)
	await _wait_i(hold)
	_card_skip = false
	if _skip: panel.queue_free(); return
	var out := create_tween()
	out.tween_property(panel, "modulate:a", 0.0, 0.35)
	await get_tree().create_timer(0.45).timeout
	panel.queue_free()


# ── Main cinematic ────────────────────────────────────────────────────────────

func _run() -> void:

	# ── Cards 1–2 on black screen ─────────────────────────────────────────────
	await _card_dbox("TRANSMISSION LOG",
		"06:42:00 — Relay Station Kappa lost contact 72 hours prior.\nCause of blackout: undetermined. Corporate has dispatched a single operative for assessment.",
		2.2)
	if _skip: _finish(); return

	await _card_dbox("ORCA",
		"09:17:33 — Tethys-7 en route to Station Kappa.\nStandard transit. No anomalies logged.",
		2.0)
	if _skip: _finish(); return

	# ── Build underwater scene ────────────────────────────────────────────────
	# Ocean fallback — sits behind everything so no black ever shows through.
	var ocean := ColorRect.new()
	ocean.color    = Color(0.02, 0.05, 0.10)
	ocean.size     = Vector2(_S.x * 4, _S.y * 4)
	ocean.position = Vector2(-_S.x * 1.5, -_S.y * 1.5)
	_world.add_child(ocean)

	_bg = Sprite2D.new()
	_bg.texture        = load("res://assets/background/background.png")
	_bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_bg.region_enabled = true
	_bg.region_rect    = Rect2(0, 0, 6000, 4000)
	_bg.position       = _S * 0.5
	_world.add_child(_bg)

	_mg = Sprite2D.new()
	_mg.texture        = load("res://assets/background/midground.png")
	_mg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_mg.region_enabled = true
	_mg.region_rect    = Rect2(0, 0, 6000, 4000)
	_mg.position       = _S * 0.5
	_world.add_child(_mg)

	# Env layer added AFTER backgrounds so fish/mines render on top of them.
	_env_layer = Node2D.new()
	_world.add_child(_env_layer)

	var dark := ColorRect.new()
	dark.color = Color(0.0, 0.03, 0.10, 0.45)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(dark)

	# Fade in scene
	create_tween().tween_property(_bg_rect, "color:a", 0.0, 1.3)
	_scroll = true

	# Sub enters from the left, stays in _world (not env_layer — not "passed by")
	_sub = _make_sub()
	_sub.position = Vector2(-130, _S.y * 0.44)
	_world.add_child(_sub)
	create_tween().tween_property(_sub, "position:x", _S.x * 0.28, 3.6).set_trans(Tween.TRANS_SINE)

	# Slight zoom-out for a wide cinematic feel
	_zoom_to(0.92, _S * 0.5, 2.0)

	await _w(1.6)
	if _skip: _finish(); return

	# ── Spawn enemies + mines in env_layer (these scroll LEFT, getting passed by)
	var fish_data := [
		["res://assets/enemies/fish.png",      4, 32, 32, 1.0],
		["res://assets/enemies/fish.png",      4, 32, 32, 0.75],
		["res://assets/enemies/fish-big.png",  4, 54, 49, 1.1],
		["res://assets/enemies/fish-big.png",  4, 54, 49, 0.85],
		["res://assets/enemies/fish-dart.png", 4, 39, 20, 1.2],
		["res://assets/enemies/fish-dart.png", 4, 39, 20, 0.9],
		["res://assets/enemies/fish.png",      4, 32, 32, 1.3],
		["res://assets/enemies/fish-big.png",  4, 54, 49, 1.5],
	]
	var fish_nodes : Array = []
	for i in fish_data.size():
		var d : Array = fish_data[i]
		var f  := _make_fish(d[0], d[1], d[2], d[3], d[4])
		# Place them spread across and AHEAD of the sub (to the right), so they scroll past
		f.position = Vector2(_S.x * (0.45 + randf() * 0.7), _S.y * (0.1 + randf() * 0.78))
		f.flip_h   = randf() > 0.5
		f.modulate.a = 0.0
		_env_layer.add_child(f)
		fish_nodes.append(f)
		create_tween().tween_property(f, "modulate:a", 0.55 + randf() * 0.3, 1.0 + randf())

	var mine_nodes : Array = []
	for i in 6:
		var m  := _make_mine(1.0 + randf() * 0.8)
		m.position = Vector2(_S.x * (0.3 + randf() * 0.85), _S.y * (0.1 + randf() * 0.78))
		m.modulate.a = 0.0
		_env_layer.add_child(m)
		mine_nodes.append(m)
		create_tween().tween_property(m, "modulate:a", 0.75, 1.5 + randf())
		var bob := create_tween().set_loops()
		bob.tween_property(m, "position:y", m.position.y - 7.0, 1.3+randf()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(m, "position:y", m.position.y + 7.0, 1.3+randf()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_dbox("ORCA", "All systems nominal. Proceeding to Station Kappa at standard depth.", 4.5)

	await _w(2.6)
	if _skip: _finish(); return

	# ── Tension ───────────────────────────────────────────────────────────────
	create_tween().tween_property(dark, "color:a", 0.65, 2.2)

	var ts1 := Label.new()
	ts1.text = "11:58:21"
	ts1.position = Vector2(_S.x * 0.06, _S.y * 0.07)
	ts1.modulate.a = 0.0
	ts1.add_theme_color_override("font_color", Color(0.82, 0.8, 0.48))
	ts1.add_theme_font_size_override("font_size", 20)
	_ui.add_child(ts1)
	create_tween().tween_property(ts1, "modulate:a", 1.0, 0.4)

	# Fish start drifting erratically
	for f in fish_nodes:
		if not is_instance_valid(f): continue
		var tw := create_tween().set_loops()
		tw.tween_property(f, "position",
			f.position + Vector2(randf_range(-160, 160), randf_range(-70, 70)),
			0.3 + randf() * 0.22).set_trans(Tween.TRANS_QUAD)

	await _w(1.0)
	if _skip: _finish(); return

	_dbox("ORCA", "⚠  Anomalous reading. Bearing 0-4-7.", 3.5)

	# Sub wobble
	var wobble := create_tween().set_loops()
	wobble.tween_property(_sub, "rotation",  0.06, 0.26)
	wobble.tween_property(_sub, "rotation", -0.06, 0.26)
	_shake(3.0, 0.5)

	# Warning HUD
	var warn := Label.new()
	warn.text = "⚠  UNIDENTIFIED CONTACT"
	warn.position = Vector2(_S.x * 0.5 - 210, _S.y * 0.14)
	warn.modulate.a = 0.0
	warn.add_theme_color_override("font_color", Color(1.0, 0.18, 0.07))
	warn.add_theme_font_size_override("font_size", 26)
	_ui.add_child(warn)
	var warn_pulse := create_tween().set_loops(8)
	warn_pulse.tween_property(warn, "modulate:a", 1.0, 0.12)
	warn_pulse.tween_property(warn, "modulate:a", 0.2, 0.22)

	await _w(1.4)
	if _skip: _finish(); return

	# ── THE SERPENT enters from the left edge ─────────────────────────────────
	wobble.kill(); _sub.rotation = 0.0

	_do_flash(Color(0.06, 0.1, 0.26, 0.4), 0.9)
	_shake(4.5, 0.6)

	# Push-in toward sub as the serpent arrives
	_zoom_to(1.1, _sub.position, 1.5)

	_serpent = Line2D.new()
	_serpent.width = 98.0
	_serpent.default_color = Color(0.02, 0.03, 0.10, 0.90)
	_serpent.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_serpent.end_cap_mode   = Line2D.LINE_CAP_ROUND
	_serpent.joint_mode     = Line2D.LINE_JOINT_ROUND
	var wc := Curve.new()
	wc.add_point(Vector2(0.0, 0.55))
	wc.add_point(Vector2(0.5, 1.0))
	wc.add_point(Vector2(0.88, 1.28))
	wc.add_point(Vector2(1.0, 1.12))
	_serpent.width_curve = wc
	# Start entirely off-screen left: head (last point, highest x) just beyond left edge
	# Head x at t=0: (SERP_N-1)*SERP_STEP + _serp_x_start = must be < 0
	_serp_x = -float(SERP_N - 1) * SERP_STEP - _S.x * 0.25
	var init_pts := PackedVector2Array()
	for i in SERP_N: init_pts.append(Vector2(i * SERP_STEP + _serp_x, _S.y * 0.46))
	_serpent.points = init_pts
	_world.add_child(_serpent)
	_serp_live = true

	create_tween().tween_property(dark, "color:a", 0.80, 0.5)
	_shake(9.0, 1.2)

	warn_pulse.kill()
	warn.text     = "⚠  COLLISION IMMINENT"
	warn.modulate.a = 1.0
	var warn_flash := create_tween().set_loops(5)
	warn_flash.tween_property(warn, "modulate:a", 0.1, 0.1)
	warn_flash.tween_property(warn, "modulate:a", 1.0, 0.1)

	_dbox("ORCA", "EMERGENCY PROTOCOLS — BRACE FOR IMPACT —", 3.0)

	# Wait until the serpent head is just left of the sub (so body sweeps through).
	while is_instance_valid(_sub) and _serp_live and not _skip:
		var head_x := float(SERP_N - 1) * SERP_STEP + _serp_x
		if head_x >= _sub.position.x - 80.0:
			break
		await get_tree().process_frame

	if _skip: _finish(); return

	# Brief beat — head is arriving, body crossing the sub.
	_shake(7.0, 0.25)
	await get_tree().create_timer(0.18).timeout

	# ── IMPACT — serpent keeps going, fades out after clearing the sub ────────
	var serp_ref := _serpent
	var serp_tw  := create_tween()
	serp_tw.tween_interval(1.8)
	serp_tw.tween_callback(func():
		if not is_instance_valid(serp_ref): return
		var fade_tw := create_tween()
		fade_tw.tween_property(serp_ref, "default_color:a", 0.0, 0.6)
		fade_tw.tween_callback(func():
			_serp_live = false
			if is_instance_valid(serp_ref): serp_ref.queue_free()
		)
	)
	_env_spd   = 0.0   # stop world scroll during chaos

	# Hard zoom-in on sub
	_zoom_to(2.0, _sub.position + Vector2(0, -20), 0.3)

	_do_flash(Color(1.0, 0.95, 0.75, 1.0), 0.65)
	_shake(32.0, 0.7)

	_boom(_sub.position, 5.5, 14.0, true)
	_boom(_sub.position + Vector2(70, -35), 3.5, 16.0, true)

	var tumble := create_tween()
	tumble.tween_property(_sub, "rotation", TAU * 2.6, 2.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tumble.parallel().tween_property(_sub, "position", _sub.position + Vector2(160, 370), 2.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await _w(0.2)

	# Pull back out slightly as chaos unfolds
	_zoom_to(1.4, _sub.position, 0.8)

	# Chain explosions
	for i in 8:
		var ep : Vector2 = _sub.position + Vector2(randf_range(-280, 280), randf_range(-180, 180))
		_boom(ep, 1.5 + randf() * 2.0, 20.0, randf() > 0.4)
		_do_flash(Color(1.0, 0.35 + randf() * 0.3, 0.08, 0.45 + randf() * 0.3), 0.28)
		_shake(15.0 + randf() * 8.0, 0.25)
		await get_tree().create_timer(0.1 + randf() * 0.09).timeout

	# Mines chain-detonate (pan camera to follow the chaos)
	for m in mine_nodes:
		if not is_instance_valid(m): continue
		var delay := randf() * 1.3
		var mine_tw := create_tween()
		mine_tw.tween_interval(delay)
		mine_tw.tween_callback(func():
			if not is_instance_valid(m): return
			_boom(m.position + _env_layer.position, 2.8, 18.0, true)
			_do_flash(Color(1.0, 0.5, 0.1, 0.4), 0.22)
			_shake(13.0, 0.28)
			m.queue_free()
		)

	await _w(0.45)
	if _skip: _finish(); return

	# Hull breach — hard red + pull back to wide
	_do_flash(Color(0.9, 0.0, 0.0, 0.88), 1.2)
	_shake(24.0, 0.9)
	_zoom_to(1.0, _S * 0.5, 1.4)

	var ts2 := Label.new()
	ts2.text = "11:58:28"; ts2.position = Vector2(_S.x*0.06, _S.y*0.14); ts2.modulate.a = 0.0
	ts2.add_theme_color_override("font_color", Color(0.82, 0.8, 0.48))
	ts2.add_theme_font_size_override("font_size", 20)
	_ui.add_child(ts2)
	create_tween().tween_property(ts2, "modulate:a", 1.0, 0.2)

	# Fish scatter
	for f in fish_nodes:
		if not is_instance_valid(f): continue
		var fpos : Vector2 = f.position + _env_layer.position
		var spos : Vector2 = _sub.position
		var dir  : Vector2 = (fpos - spos).normalized()
		var flee := create_tween()
		flee.tween_property(f, "position", f.position + dir * randf_range(350, 700), 0.55+randf()).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		flee.parallel().tween_property(f, "modulate:a", 0.0, 0.45)

	await _w(0.9)
	if _skip: _finish(); return

	# ── Aftermath ─────────────────────────────────────────────────────────────
	# Slow zoom in on sinking sub for emotional beat
	if is_instance_valid(_sub):
		_zoom_to(1.35, _sub.position + Vector2(0, 150), 3.0)
		create_tween().tween_property(_sub, "position:y", _sub.position.y + 480, 3.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		create_tween().tween_property(_sub, "modulate:a", 0.0, 3.0)

	for i in 4:
		await get_tree().create_timer(0.42).timeout
		if is_instance_valid(_sub):
			_boom(_sub.position + Vector2(randf_range(-55,55), randf_range(-35,35)), 1.2, 22.0, false)

	await _w(0.5)
	if _skip: _finish(); return

	# ── Fade to black ─────────────────────────────────────────────────────────
	_scroll = false
	_zoom_to(1.0, _S * 0.5, 1.5)
	create_tween().tween_property(_bg_rect, "color:a", 1.0, 2.0)
	for c in _ui.get_children():
		if c != _bg_rect and c != _flash_rect:
			create_tween().tween_property(c, "modulate:a", 0.0, 1.2)
	await _w(2.3)

	# ── Remaining cards as dialogue boxes ─────────────────────────────────────
	var cards := [
		["TRANSMISSION LOG", "11:58:21 — Unidentified contact. Collision imminent.\nEmergency protocols failed to initialize."],
		["TRANSMISSION LOG", "11:58:28 — Hull integrity compromised.\nPressure systems offline. Navigation core unresponsive."],
		["ORCA",             "12:00:04 — Operative status: conscious. Vessel status: critical.\nThree components confirmed missing.\n\nDrive coupling.  Pressure seal.  Navigation core."],
		["ORCA",             "12:00:47 — Distress signal blocked.\nRelay station Kappa offline. Cause undetermined."],
		["TRANSMISSION LOG", "12:01:09 — Nature of contact: unclassified.\nOrigin: unknown. No further data available."],
		["ORCA",             "12:01:11 — Recovery objective logged.\nRetrieve components. Restore vessel. Proceed to Station Kappa.\n\nDepth recorded: 3,847 meters.  Backup unavailable."],
	]
	for c in cards:
		if _skip: break
		await _card_dbox(c[0], c[1], 2.0)

	_finish()


func _finish() -> void:
	_scroll = false
	if is_instance_valid(_cur_dbox):
		_cur_dbox.queue_free()
	create_tween().tween_property(_bg_rect, "color:a", 1.0, 0.7)
	await get_tree().create_timer(0.9).timeout
	SceneManager.go_to_level(1)
