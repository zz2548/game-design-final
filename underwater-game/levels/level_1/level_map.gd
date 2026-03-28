# level_map.gd
# Attach to a Node2D called "LevelMap" inside a level scene.
# Builds a TileMapLayer (walls + collision) at runtime from the room/corridor
# definitions below — no StaticBody2D rectangles needed.
#
# ── Map grid ─────────────────────────────────────────────────────────────────
#   222 columns × 40 rows  →  3552 × 640 px  (each tile = 16 × 16 px)
#
# ── Column zones ─────────────────────────────────────────────────────────────
#   Docking Bay   cols   0 –  49
#   Corridor 1    cols  50 –  87
#   Central Hub   cols  88 – 131
#   Corridor 2    cols 132 – 169
#   Research Lab  cols 170 – 221
#
# ── Row zones ────────────────────────────────────────────────────────────────
#   0 – 1   outer top wall
#   2 – 3   room top wall
#   4 – 35  room / corridor interior
#  36 – 37  room bottom wall
#  38 – 39  outer bottom wall
#
#   Corridor passage (open water): rows 14 – 25  (12 tiles = 192 px)

extends Node2D

# ── Constants ─────────────────────────────────────────────────────────────────

const TILE_SIZE : int = 16
const MAP_COLS  : int = 222
const MAP_ROWS  : int = 40

## Thickness (in tiles) of every wall border.
const WALL : int = 2

## First and last open row inside the room interior.
const INTERIOR_ROW_FIRST : int = WALL * 2      # = 4  (outer + room top wall)
const INTERIOR_ROW_LAST  : int = MAP_ROWS - WALL * 2 - 1  # = 35

## Vertical range of the corridor passage (inclusive).
const PASSAGE_FIRST : int = 14
const PASSAGE_LAST  : int = 25

## Room definitions – col_start / col_end are the outermost wall columns.
const ROOMS : Array[Dictionary] = [
	{col_start =   0, col_end =  49},   # Docking Bay
	{col_start =  88, col_end = 131},   # Central Hub
	{col_start = 170, col_end = 221},   # Research Lab
]

## Corridor definitions – every cell here is wall except passage rows.
const CORRIDORS : Array[Dictionary] = [
	{col_start =  50, col_end =  87},   # Corridor 1
	{col_start = 132, col_end = 169},   # Corridor 2
]

## Wall tile tint colour (no art yet – solid white texture × modulate).
const WALL_COLOUR : Color = Color(0.07, 0.12, 0.20)


# ── Entry point ───────────────────────────────────────────────────────────────

func _ready() -> void:
	add_child(_build_tilemap())


# ── Tilemap construction ──────────────────────────────────────────────────────

func _build_tilemap() -> TileMapLayer:
	var tilemap := TileMapLayer.new()
	tilemap.tile_set = _make_tileset()
	tilemap.modulate  = WALL_COLOUR

	for row in MAP_ROWS:
		for col in MAP_COLS:
			if _is_wall(col, row):
				tilemap.set_cell(Vector2i(col, row), 0, Vector2i(0, 0))

	return tilemap


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Physics layer — must be added before tile data references it.
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)  # same layer as CharacterBody2D
	ts.set_physics_layer_collision_mask(0, 1)

	# Solid 16×16 white texture – tinted at the TileMapLayer level.
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)

	var source := TileSetAtlasSource.new()
	source.texture             = tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	source.create_tile(Vector2i(0, 0))

	# ⚠️  Source must be registered with the TileSet BEFORE setting collision
	# data — tile_data validates polygon counts against the TileSet's physics
	# layers, so the order here matters.
	ts.add_source(source, 0)

	# Full-tile collision square centred on the tile origin.
	var tile_data : TileData = source.get_tile_data(Vector2i(0, 0), 0)
	var h         : float    = TILE_SIZE / 2.0
	tile_data.set_collision_polygons_count(0, 1)
	tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h),
	]))

	return ts


# ── Wall logic ────────────────────────────────────────────────────────────────

func _is_wall(col: int, row: int) -> bool:
	return not _is_open(col, row)


## Returns true when the cell at (col, row) should be open water.
func _is_open(col: int, row: int) -> bool:
	# Outer top / bottom border → always solid.
	if row < WALL or row >= MAP_ROWS - WALL:
		return false

	# Corridor zone: open only within the passage rows.
	for corridor in CORRIDORS:
		if col >= corridor.col_start and col <= corridor.col_end:
			return row >= PASSAGE_FIRST and row <= PASSAGE_LAST

	# Room zone.
	for room in ROOMS:
		if col >= room.col_start and col <= room.col_end:
			return _room_cell_is_open(col, row, room)

	# Falls outside every defined zone → solid.
	return false


## Determines whether a cell that lies inside a room boundary is open water.
func _room_cell_is_open(col: int, row: int, room: Dictionary) -> bool:
	# Room top / bottom walls.
	if row < INTERIOR_ROW_FIRST or row > INTERIOR_ROW_LAST:
		return false

	# Left side wall – open only if a corridor is immediately to the left
	# AND the row falls within the passage band.
	if col < room.col_start + WALL:
		return _corridor_at(room.col_start - 1) \
			and row >= PASSAGE_FIRST and row <= PASSAGE_LAST

	# Right side wall – same logic for a corridor to the right.
	if col > room.col_end - WALL:
		return _corridor_at(room.col_end + 1) \
			and row >= PASSAGE_FIRST and row <= PASSAGE_LAST

	# Interior cell.
	return true


## Returns true when the given column belongs to a corridor zone.
func _corridor_at(col: int) -> bool:
	for corridor in CORRIDORS:
		if col >= corridor.col_start and col <= corridor.col_end:
			return true
	return false
