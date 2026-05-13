extends Node2D

const BAR_COUNT  : int   = 5
const BAR_WIDTH  : float = 7.0
const BAR_HEIGHT : float = 48.0
const DOOR_WIDTH : float = 128.0
const BAR_COLOR  : Color = Color(0.28, 0.32, 0.38, 1.0)
const RIM_COLOR  : Color = Color(0.45, 0.50, 0.58, 1.0)


func _draw() -> void:
	var spacing := DOOR_WIDTH / (BAR_COUNT + 1)
	var top_y   := -64.0 - BAR_HEIGHT  # sit flush above top edge of 128px sprite
	for i in BAR_COUNT:
		var x := -DOOR_WIDTH * 0.5 + spacing * (i + 1) - BAR_WIDTH * 0.5
		var rect := Rect2(x, top_y, BAR_WIDTH, BAR_HEIGHT)
		draw_rect(rect, BAR_COLOR)
		draw_rect(rect, RIM_COLOR, false, 1.0)
