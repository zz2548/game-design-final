# level_map.gd
# Generates the Level 1 wall geometry at runtime via a TileMapLayer.
#
# Layout — reading left to right:
#
#   ┌──────────────────────────────────────────────────────────────────────┐
#   │  WIDE OPEN CAVE                                                      │
#   │  cols 2–96, rows 2–61  (1504 × 960 px)                              │
#   │                                                        ┌──────────┐  │
#   │  Player spawns here.                           ════════╡ NARROW   │  │
#   │  Submarine docked near the right wall.         (rows   │ CORRIDOR │  │
#   │                                                27–32)  │ 97–116   │  │
#   └──────────────────────────────────────────────────────────────────────┘
#                                                            └──────────┘
#                                                                 ║ (rows 27–32)
#                                                    ┌────────────╨──────────────────────────┐
#                                                    │  AIRLOCK ANTECHAMBER  cols 117–142     │
#                                                    │  rows 20–43  (opens wider on arrival)  │
#                                                    └───────────────────────────────────────┘
#                                                                ║ (rows 20–43, full width)
#                                   ┌────────────────────────────╨──────────────────────────────┐
#                                   │  MAIN RESEARCH LAB   cols 143–192,  rows 15–48             │
#                                   │                                                             │
#                                   └─────────────────────────────┬─────────────────────────────┘
#                                                                  │ vertical shaft cols 162–169
#                                                     ┌────────────┴──────────────────┐
#                                                     │  SERVER / EQUIPMENT ROOM      │
#                                                     │  cols 152–186,  rows 54–62    │
#                                                     └───────────────────────────────┘
#
# Map: 200 cols × 64 rows  →  3200 × 1024 px  (16 px / tile)
#
# Rule: a cell is open water iff it falls inside at least one OPEN_ZONE rectangle.
#       Every other cell is solid rock wall.

extends Node2D

const TILE_SIZE     : int    = 16
const MAP_COLS      : int    = 200
const MAP_ROWS      : int    = 64
const TILE_VARIANTS : int    = 8
const TILESET_PATH  : String = "res://assets/tiles/tileset.png"

# ── Open-water zones (all coordinates inclusive) ──────────────────────────────
# Zones that share a boundary row/column automatically form a doorway at
# the overlapping rows — no extra passage logic needed.

const OPEN_ZONES : Array[Dictionary] = [
	# Wide open cave — very tall, very wide; gives a sense of scale and dread.
	{x1 =   2, x2 =  96, y1 =  2, y2 = 61},

	# Narrow corridor — only 6 tiles (96 px) tall; tight bottleneck.
	# Shares col 97 boundary with cave: opening is restricted to rows 27–32.
	{x1 =  97, x2 = 116, y1 = 27, y2 = 32},

	# Airlock antechamber — taller than the corridor (rows 20–43).
	# Space visibly expands as the player exits the tight passage.
	{x1 = 117, x2 = 142, y1 = 20, y2 = 43},

	# Main research lab — wide, tall, the heart of the facility.
	# Left wall opens fully onto the airlock (rows 20–43 are shared).
	{x1 = 143, x2 = 192, y1 = 15, y2 = 48},

	# Vertical shaft — punches down from the lab floor.
	# Cols 162–169 at rows 49–53 are the only way into the server room.
	{x1 = 162, x2 = 169, y1 = 49, y2 = 53},

	# Server / equipment room — accessible only through the shaft above.
	{x1 = 152, x2 = 186, y1 = 54, y2 = 62},
]


# ── Entry point ───────────────────────────────────────────────────────────────

func _ready() -> void:
	add_child(_build_tilemap())


# ── Tilemap construction ──────────────────────────────────────────────────────

func _build_tilemap() -> TileMapLayer:
	var tilemap := TileMapLayer.new()
	tilemap.tile_set = _make_tileset()

	for row in MAP_ROWS:
		for col in MAP_COLS:
			if _is_wall(col, row):
				tilemap.set_cell(
					Vector2i(col, row), 0,
					Vector2i(_tile_variant(col, row), 0)
				)

	return tilemap


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Physics layer — added BEFORE tile data so tile_data can reference it.
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 1)

	var tex    : Texture2D           = load(TILESET_PATH)
	var source : TileSetAtlasSource  = TileSetAtlasSource.new()
	source.texture             = tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	for x in TILE_VARIANTS:
		source.create_tile(Vector2i(x, 0))

	# Source registered with TileSet BEFORE setting per-tile collision data.
	ts.add_source(source, 0)

	var h    : float             = TILE_SIZE / 2.0
	var poly : PackedVector2Array = PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h),
	])
	for x in TILE_VARIANTS:
		var td : TileData = source.get_tile_data(Vector2i(x, 0), 0)
		td.set_collision_polygons_count(0, 1)
		td.set_collision_polygon_points(0, 0, poly)

	return ts


# ── Wall logic ────────────────────────────────────────────────────────────────

## Returns true when (col, row) is solid rock — i.e. it falls outside every
## open-water zone.
func _is_wall(col: int, row: int) -> bool:
	for zone in OPEN_ZONES:
		if col >= zone.x1 and col <= zone.x2 \
				and row >= zone.y1 and row <= zone.y2:
			return false
	return true


## Deterministic position hash → tile variant index in [0, TILE_VARIANTS).
## Same position always maps to the same variant; adjacent tiles differ.
func _tile_variant(col: int, row: int) -> int:
	return ((col * 1619 + row * 31337) & 0x7FFFFFFF) % TILE_VARIANTS
