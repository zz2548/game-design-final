extends Node

const SCROLL_SPEED := 175.0

var _S         : Vector2
var _skip      : bool  = false
var _scrolling : bool  = false
var _marks     : Array = []
var _overlay   : ColorRect


func _ready() -> void:
	_S = get_viewport().get_visible_rect().size
	_run.call_deferred()


func _process(delta: float) -> void:
	if not _scrolling:
		return
	for mark in _marks:
		if is_instance_valid(mark):
			mark.position.y -= SCROLL_SPEED * delta
			if mark.position.y < -30.0:
				mark.position.y += _S.y + 60.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_skip = true
		get_viewport().set_input_as_handled()


func _w(t: float) -> void:
	if _skip:
		return
	await get_tree().create_timer(t).timeout


func _run() -> void:
	MusicManager.play(["res://assets/sounds/ambient_l2.mp3"])

	# ── Background ────────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.02, 0.05)
	bg.size  = _S
	add_child(bg)

	# ── Shaft walls ───────────────────────────────────────────────────────────
	for x_frac in [0.14, 0.86]:
		var wall := Line2D.new()
		wall.add_point(Vector2(_S.x * x_frac, 0.0))
		wall.add_point(Vector2(_S.x * x_frac, _S.y))
		wall.width         = 2.5
		wall.default_color = Color(0.14, 0.22, 0.32, 0.65)
		add_child(wall)

	# ── Scrolling depth rings (horizontal marks that move upward) ─────────────
	var spacing : float = 90.0
	var count   : int   = int((_S.y + 200.0) / spacing) + 2
	for i in count:
		var ring := Line2D.new()
		ring.add_point(Vector2(_S.x * 0.13, 0.0))
		ring.add_point(Vector2(_S.x * 0.87, 0.0))
		ring.width         = 1.0
		ring.default_color = Color(0.10, 0.18, 0.28, 0.45)
		ring.position      = Vector2(0.0, i * spacing)
		add_child(ring)
		_marks.append(ring)

	# ── Player swimming straight down ─────────────────────────────────────────
	var swim_tex : Texture2D = load("res://assets/player/player-swiming.png")
	var p_frames := SpriteFrames.new()
	p_frames.add_animation("swim")
	p_frames.set_animation_loop("swim", true)
	p_frames.set_animation_speed("swim", 10.0)
	for i in 7:
		var atlas := AtlasTexture.new()
		atlas.atlas  = swim_tex
		atlas.region = Rect2(i * 80, 0, 80, 80)
		p_frames.add_frame("swim", atlas)
	var p_sprite := AnimatedSprite2D.new()
	p_sprite.sprite_frames = p_frames
	p_sprite.position      = Vector2(_S.x * 0.5, _S.y * 0.42)
	p_sprite.rotation      = PI / 2.0  # face downward
	p_sprite.scale         = Vector2(2.0, 2.0)
	p_sprite.z_index       = 1
	add_child(p_sprite)
	p_sprite.play("swim")

	# Subtle rotation sway to sell the swimming effort
	var sway := create_tween().set_loops()
	sway.tween_property(p_sprite, "rotation", PI / 2.0 + 0.10, 0.75) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway.tween_property(p_sprite, "rotation", PI / 2.0 - 0.10, 0.75) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# ── Fade overlay (z_index 10 sits above the player sprite) ───────────────
	_overlay = ColorRect.new()
	_overlay.color   = Color.BLACK
	_overlay.size    = _S
	_overlay.z_index = 10
	add_child(_overlay)

	# ── UI layer for cards ────────────────────────────────────────────────────
	var ui := CanvasLayer.new()
	ui.layer = 20
	add_child(ui)

	create_tween().tween_property(_overlay, "color:a", 0.0, 1.4)
	_scrolling = true
	await _w(2.0)
	if _skip: _finish(); return

	# ── Narrative cards ───────────────────────────────────────────────────────
	# [text, hold_seconds_after_typewriter]
	var cards : Array = [
		["Cataloguing contact data from Kappa Station interior.", 2.2],
		["Fourteen distinct organism types confirmed, and each one was hostile.\n\nNone matching any prior xenobiology projection.", 3.0],
		["Station Kappa reported nominal conditions seventy-two hours before the blackout.\n\nThey reported no anomalies or biological incursion.", 3.5],
		["These organisms did not migrate into this facility, and by the looks of it, Kappa Station did not malfunction.", 3.5],
		["It was overrun.", 3.0],
	]

	for card_data in cards:
		if _skip:
			break
		await _show_card(ui, card_data[0], card_data[1])
		await _w(0.35)

	_finish()


func _show_card(ui: CanvasLayer, text: String, hold: float) -> void:
	if _skip:
		return

	var font := _make_font()

	var panel := PanelContainer.new()
	panel.layout_mode     = 1
	panel.anchor_left     = 0.0;   panel.anchor_top    = 1.0
	panel.anchor_right    = 1.0;   panel.anchor_bottom = 1.0
	panel.offset_left     = 72.0;  panel.offset_top    = -230.0
	panel.offset_right    = -72.0; panel.offset_bottom = -24.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	var sbox := StyleBoxFlat.new()
	sbox.bg_color     = Color(0.03, 0.07, 0.12, 0.93)
	sbox.border_color = Color(0.18, 0.52, 0.68, 0.6)
	sbox.set_border_width_all(1)
	sbox.set_corner_radius_all(6)
	sbox.content_margin_left   = 22.0; sbox.content_margin_right  = 22.0
	sbox.content_margin_top    = 14.0; sbox.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", sbox)
	panel.modulate.a = 0.0
	ui.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var spk := Label.new()
	spk.text      = "ORCA"
	spk.uppercase = true
	spk.add_theme_font_override("font", font)
	spk.add_theme_font_size_override("font_size", 12)
	spk.add_theme_color_override("font_color", Color(0.28, 0.82, 1.0))
	vbox.add_child(spk)

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
	rtl.text            = text
	rtl.add_theme_font_override("normal_font", font)
	rtl.add_theme_font_size_override("normal_font_size", 15)
	rtl.add_theme_color_override("default_color", Color(0.80, 0.91, 0.97))
	vbox.add_child(rtl)

	var ping := AudioStreamPlayer.new()
	ping.stream = load("res://assets/sounds/ping.mp3")
	ping.finished.connect(ping.queue_free)
	add_child(ping)
	ping.play()

	create_tween().tween_property(panel, "modulate:a", 1.0, 0.3)

	var type_dur : float = text.length() * 0.028
	create_tween().tween_property(rtl, "visible_ratio", 1.0, type_dur)
	await get_tree().create_timer(type_dur + hold).timeout

	create_tween().tween_property(panel, "modulate:a", 0.0, 0.3)
	await get_tree().create_timer(0.35).timeout
	panel.queue_free()


func _make_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names   = PackedStringArray(["Consolas", "Courier New", "monospace"])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


func _finish() -> void:
	_scrolling = false
	create_tween().tween_property(_overlay, "color:a", 1.0, 1.5)
	await get_tree().create_timer(1.8).timeout
	SceneManager.go_to_level(3)
