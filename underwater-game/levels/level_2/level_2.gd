# level_2.gd
# Battle arena — survive endless waves of enemies.

extends Node2D

const MELEE_SCENE  : String = "res://shared/Enemies/enemy.tscn"
const RANGED_SCENE : String = "res://shared/Enemies/enemy_ranged.tscn"
const AOE_SCENE    : String = "res://shared/Enemies/enemy_aoe.tscn"

# Each wave is a list of [count, type] pairs.
const WAVES : Array = [
	[[3, "melee"]],
	[[4, "melee"], [2, "ranged"]],
	[[3, "melee"], [3, "ranged"], [1, "aoe"]],
	[[5, "melee"], [3, "ranged"], [2, "aoe"]],
	[[4, "melee"], [5, "ranged"], [3, "aoe"]],
]

var _wave          : int  = 0
var _enemies_alive : int  = 0

@onready var _spawn_points : Array = $SpawnPoints.get_children()
@onready var _wave_label   : Label = $WaveHUD/WaveLabel


func _ready() -> void:
	await get_tree().process_frame
	_start_wave()


func _start_wave() -> void:
	if _wave >= WAVES.size():
		_wave_label.text = "You survived!"
		return

	_enemies_alive = 0
	_wave_label.text = "Wave %d / %d" % [_wave + 1, WAVES.size()]

	var spawn_idx := 0
	for group in WAVES[_wave]:
		var count : int    = group[0]
		var type  : String = group[1]
		var packed := load(_scene_for(type)) as PackedScene
		for i in count:
			var enemy : Node2D = packed.instantiate()
			add_child(enemy)
			var pt : Node2D = _spawn_points[spawn_idx % _spawn_points.size()]
			enemy.position = pt.position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			enemy.died.connect(_on_enemy_died)
			_enemies_alive += 1
			spawn_idx += 1


func _scene_for(type: String) -> String:
	match type:
		"ranged": return RANGED_SCENE
		"aoe":    return AOE_SCENE
		_:        return MELEE_SCENE


func _on_enemy_died() -> void:
	_enemies_alive -= 1
	if _enemies_alive <= 0:
		_wave += 1
		await get_tree().create_timer(2.0).timeout
		_start_wave()
