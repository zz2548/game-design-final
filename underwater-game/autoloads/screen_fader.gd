extends CanvasLayer

var _rect       : ColorRect
var _last_scene : Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)


func _process(_delta: float) -> void:
	var current := get_tree().current_scene
	if current != null and current != _last_scene:
		_last_scene = current
		_fade_in()


func _fade_in(duration: float = 0.8) -> void:
	_rect.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_rect, "modulate:a", 0.0, duration)
