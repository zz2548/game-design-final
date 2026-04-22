# arena_map.gd
# Procedurally generates a rectangular walled arena at runtime.
# Arena interior: 50 × 37 tiles (800 × 592 px). Wall thickness: 2 tiles.

extends Node2D

const TILE_SIZE    : int    = 16
const ARENA_W      : int    = 50
const ARENA_H      : int    = 37
const WALL_THICK   : int    = 2
const TILE_VARIANTS: int    = 8
const TILESET_PATH : String = "res://assets/tiles/1_Mine_Tileset_1.png"

const TOTAL_COLS : int = ARENA_W + WALL_THICK * 2
const TOTAL_ROWS : int = ARENA_H + WALL_THICK * 2


func _ready() -> void:
	add_child(_build_tilemap())


func _build_tilemap() -> TileMapLayer:
	var tilemap := TileMapLayer.new()
	tilemap.tile_set = _make_tileset()
	for row in TOTAL_ROWS:
		for col in TOTAL_COLS:
			if _is_wall(col, row):
				tilemap.set_cell(Vector2i(col, row), 0, Vector2i(_variant(col, row), 0))
	return tilemap


func _is_wall(col: int, row: int) -> bool:
	return col < WALL_THICK or col >= WALL_THICK + ARENA_W \
		or row < WALL_THICK or row >= WALL_THICK + ARENA_H


func _variant(col: int, row: int) -> int:
	return ((col * 1619 + row * 31337) & 0x7FFFFFFF) % TILE_VARIANTS


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 1)
	ts.add_occlusion_layer(0)

	var source := TileSetAtlasSource.new()
	source.texture = load(TILESET_PATH)
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for x in TILE_VARIANTS:
		source.create_tile(Vector2i(x, 0))
	ts.add_source(source, 0)

	var h    := TILE_SIZE / 2.0
	var poly := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var occ  := OccluderPolygon2D.new()
	occ.polygon = poly

	for x in TILE_VARIANTS:
		var td := source.get_tile_data(Vector2i(x, 0), 0)
		td.set_collision_polygons_count(0, 1)
		td.set_collision_polygon_points(0, 0, poly)
		td.set_occluder(0, occ)

	return ts
