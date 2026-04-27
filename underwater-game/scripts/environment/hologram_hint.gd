class_name HologramHint
extends Node2D

@export_multiline var hint_text: String = ""
@export var detection_radius: float = 180.0
@export var fade_speed: float = 2.5

var _alpha: float = 0.0


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var target: float = 0.0
	if player != null:
		var dist := global_position.distance_to(player.global_position)
		if dist < detection_radius:
			target = clampf(1.0 - dist / detection_radius, 0.2, 1.0)
	_alpha = move_toward(_alpha, target, fade_speed * delta)
	queue_redraw()


func _draw() -> void:
	if _alpha < 0.01:
		return
	var font      := ThemeDB.fallback_font
	var font_size := 9
	var spacing   := 15.0
	var lines     := hint_text.split("\n")
	var total_h   := (lines.size() - 1) * spacing

	for i in lines.size():
		var line := lines[i]
		var sz   := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos  := Vector2(-sz.x * 0.5, -total_h * 0.5 + i * spacing)
		# soft glow shadow
		draw_string(font, pos + Vector2(1, 1), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				Color(0.0, 0.55, 0.85, _alpha * 0.55))
		# main hologram text
		draw_string(font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				Color(0.35, 0.92, 1.0, _alpha))
