extends Node2D

var _t : float = 0.0

func _process(delta: float) -> void:
	_t += delta
	position.y = sin(_t * 2.2) * 3.0
	queue_redraw()


func _draw() -> void:
	var CHIP_W    := 16.0
	var CHIP_H    := 13.0
	var PIN_LEN   := 4.0
	var PIN_THICK := 3.0
	var PIN_GAP   := 7.0

	var chip_bg     := Color(0.04, 0.13, 0.08)
	var chip_border := Color(0.18, 0.72, 0.42)
	var pin_col     := Color(0.55, 0.58, 0.65)
	var trace_col   := Color(0.1, 0.45, 0.25, 0.55)
	var gun_col     := Color(1.0, 0.78, 0.18)
	var glow_col    := Color(1.0, 0.78, 0.18, 0.18)

	# ── Glow halo ────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-CHIP_W - 4, -CHIP_H - 4, (CHIP_W + 4) * 2, (CHIP_H + 4) * 2), glow_col)

	# ── Pins ─────────────────────────────────────────────────────────────────────
	for i in 2:
		var off := -PIN_GAP / 2.0 + i * PIN_GAP - PIN_THICK / 2.0
		# Left
		draw_rect(Rect2(-CHIP_W - PIN_LEN, off, PIN_LEN, PIN_THICK), pin_col)
		# Right
		draw_rect(Rect2(CHIP_W, off, PIN_LEN, PIN_THICK), pin_col)
	for i in 2:
		var off := -PIN_GAP / 2.0 + i * PIN_GAP - PIN_THICK / 2.0
		# Top
		draw_rect(Rect2(off, -CHIP_H - PIN_LEN, PIN_THICK, PIN_LEN), pin_col)
		# Bottom
		draw_rect(Rect2(off, CHIP_H, PIN_THICK, PIN_LEN), pin_col)

	# ── Chip body ────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-CHIP_W, -CHIP_H, CHIP_W * 2, CHIP_H * 2), chip_bg)
	draw_rect(Rect2(-CHIP_W, -CHIP_H, CHIP_W * 2, CHIP_H * 2), chip_border, false, 1.2)

	# Corner notch (top-left)
	draw_line(Vector2(-CHIP_W, -CHIP_H + 4), Vector2(-CHIP_W + 4, -CHIP_H), chip_border, 1.2)

	# ── Circuit traces ───────────────────────────────────────────────────────────
	draw_line(Vector2(-CHIP_W, -3.5), Vector2(-7, -3.5), trace_col, 1.0)
	draw_line(Vector2(-7, -3.5),      Vector2(-7,  2.0), trace_col, 1.0)
	draw_line(Vector2(5, 3.5),        Vector2(CHIP_W, 3.5), trace_col, 1.0)
	draw_line(Vector2(2, -CHIP_H),    Vector2(2, -6),    trace_col, 1.0)

	# ── Shotgun silhouette ───────────────────────────────────────────────────────
	# Stock
	draw_rect(Rect2(-13, -4, 5, 8), gun_col)
	# Grip notch
	draw_rect(Rect2(-10,  2, 3, 3), gun_col)
	# Receiver body
	draw_rect(Rect2( -8, -4, 10, 7), gun_col)
	# Pump grip (darker stripe)
	draw_rect(Rect2( -4, -4,  4, 7), Color(0.7, 0.55, 0.1))
	# Barrel (wide — scatter cannon)
	draw_rect(Rect2(  2, -3, 12, 5), gun_col)
	# Barrel tip (double-barrel look: two thin lines)
	draw_line(Vector2(13, -3), Vector2(13, -1), chip_bg, 1.2)
	# Muzzle end cap
	draw_rect(Rect2( 13, -4,  2, 7), gun_col)
