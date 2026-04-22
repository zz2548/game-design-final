extends Node2D

@onready var _sub_sprite : AnimatedSprite2D = $Submarine
@onready var _fade_rect  : ColorRect        = $FadeOverlay/BlackRect
@onready var _bg_layer   : Sprite2D         = $BackgroundLayer
@onready var _mg_layer   : Sprite2D         = $MidgroundLayer

const SUB_SPEED : float = 80.0
const BG_SCROLL : float = 18.0
const MG_SCROLL : float = 38.0

var _bg_offset : float = 0.0
var _mg_offset : float = 0.0
var _scrolling : bool  = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_rect.modulate.a = 0.0
	_setup_sub_sprite()
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_callback(_trigger_dialogue)


func _process(delta: float) -> void:
	if not _scrolling:
		return
	_sub_sprite.position.x += SUB_SPEED * delta
	_bg_offset += BG_SCROLL * delta
	_mg_offset += MG_SCROLL * delta
	_bg_layer.region_rect = Rect2(_bg_offset, 0.0, 2000.0, 1200.0)
	_mg_layer.region_rect = Rect2(_mg_offset, 0.0, 2000.0, 1200.0)


func _trigger_dialogue() -> void:
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Tethys-7 approaching Kappa Station.",
			"Docking sequence initiated. Stand by.",
		],
	})
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)


func _on_dialogue_ended() -> void:
	_scrolling = false
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, 1.5)
	tween.tween_callback(func(): SceneManager.next_level())


func _setup_sub_sprite() -> void:
	var sheet : Texture2D = load("res://assets/player/sub_upgraded.png")
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 8.0)
	for i in 5:
		var atlas := AtlasTexture.new()
		atlas.atlas  = sheet
		atlas.region = Rect2(i * 126, 0, 126, 112)
		frames.add_frame("idle", atlas)
	_sub_sprite.sprite_frames = frames
	_sub_sprite.scale = Vector2(0.5, 0.5)
	_sub_sprite.play("idle")
