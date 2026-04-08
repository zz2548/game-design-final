# level_2_map.gd
# Generates the Kappa Station wall geometry at runtime via a TileMapLayer.
#
# Layout — reading left to right:
#
#  ┌─────────────────────┐
#  │  DOCK RING          │   cols 2–48,  rows 18–46
#  │  Zone A             │   Entry point. Tethys-7 moors at left wall.
#  │  (47 × 29 tiles)    │   Comms room, Fadel + Bosch bodies, archive case.
#  └──────────┬──────────┘
#             │ tight corridor  cols 49–58, rows 28–36  (10 × 9 tiles)
#  ┌──────────┴──────────────────────────────────────────┐
#  │  RESEARCH WING                                      │  cols 59–130, rows 12–52
#  │  Zone B  (72 × 41 tiles)                            │
#  │  Unlit-colonized. Specimen tanks, workstations.     │
#  │  Pelagis memo case. Fadel keycard on her body.      │
#  │                         ┌──────────────────────┐   │
#  │  sub bay alcove ────────►│ cols 70–110 rows 46–52│  │
#  └──────────────┬───────────└──────────────────────┘───┘
#                 │ tight corridor  cols 131–140, rows 22–32  (10 × 11 tiles)
#       ┌─────────┴─────────────────────────────────────────────────┐
#       │  BORE SHAFT / EXTERIOR HULL                               │
#       │  Zone C  cols 141–196, rows 8–56  (56 × 49 tiles)        │
#       │  Open water outside the station. No sub.                  │
#       │  Antenna array on far-right hull exterior.                │
#       │                ┌──────────────────┐                       │
#       │  bore shaft ───►cols 158–172 48–56 │ (vertical drop)      │
#       └───────────────────────────────────────────────────────────┘
#
# Map: 200 cols × 64 rows  →  3200 × 1024 px  (16 px / tile)
#
# Rule: a cell is open water iff it falls inside at least one OPEN_ZONE.
#       Every other cell is solid wall.
# The corridors are deliberately tight (≤11 tiles tall) to create pressure and
# force the player to commit to each zone transition.

extends Node2D

const TILE_SIZE     : int    = 16
const MAP_COLS      : int    = 200
const MAP_ROWS      : int    = 64
const TILE_VARIANTS : int    = 8
const TILESET_PATH  : String = "res://assets/tiles/tileset.png"

# ── Open-water zones (all coordinates inclusive) ──────────────────────────────

const OPEN_ZONES : Array[Dictionary] = [
	# ── Zone A: Dock Ring ────────────────────────────────────────────────────
	# Wide enough for the Tethys-7 to sit docked at the left wall.
	# Ceiling is higher on the right side — the architecture opens toward the
	# interior, giving the sense that the station was designed with grandeur
	# that the flooding has since ruined.
	{x1 =  2, x2 = 48, y1 = 18, y2 = 46},

	# Comms room alcove — recessed off the upper-right of the Dock Ring.
	# This is where Fadel and Bosch are found seated, facing each other.
	{x1 = 36, x2 = 48, y1 = 10, y2 = 18},

	# ── Corridor A → B ───────────────────────────────────────────────────────
	# Only 9 tiles tall. The player has to thread through this; enemies
	# waiting on the other side will hear them coming.
	{x1 = 49, x2 = 58, y1 = 28, y2 = 36},

	# ── Zone B: Research Wing ────────────────────────────────────────────────
	# Tallest zone. The ceiling is cathedral-high relative to the corridors.
	# Specimen tanks would have lined the upper half; now they're burst open.
	# The Unlit move through the middle of this space unhurried.
	{x1 = 59, x2 = 130, y1 = 12, y2 = 52},

	# Upper equipment gallery — accessible from Zone B main floor via a
	# vertical gap. ORCA flags interesting readings from up here.
	{x1 = 80, x2 = 120, y1 = 4, y2 = 12},

	# Sub bay alcove — recessed below the main floor of Zone B.
	# Locked by the Pelagis blast door until ORCA's override.
	# The Tethys-7 is re-fueled and waiting here for departure.
	{x1 = 70, x2 = 110, y1 = 52, y2 = 60},

	# ── Corridor B → C ───────────────────────────────────────────────────────
	# Slightly taller than A→B but still tight. The transition to open water
	# on the other side should feel like exhaling after holding your breath.
	{x1 = 131, x2 = 140, y1 = 22, y2 = 32},

	# ── Zone C: Bore Shaft / Exterior Hull ───────────────────────────────────
	# The main exterior cavity. High and wide — the pressure of open ocean
	# is visceral here. The far wall is the actual hull of the station.
	{x1 = 141, x2 = 196, y1 = 8, y2 = 56},

	# Bore shaft vertical drop — punches down from Zone C floor.
	# The actual drill hole. Looking down it is looking into nothing.
	{x1 = 158, x2 = 172, y1 = 56, y2 = 62},

	# Antenna platform — a narrow ledge on the upper-right exterior hull.
	# The player works here in open water. The relay node that needs repair
	# is at the far right end of this platform.
	{x1 = 175, x2 = 198, y1 = 8, y2 = 16},
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

	# Occlusion layer — wall tiles block the player's PointLight2D so the
	# solid rock outside the playable zones stays completely dark.
	ts.add_occlusion_layer(0)

	var tex    : Texture2D          = load(TILESET_PATH)
	var source : TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture             = tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	for x in TILE_VARIANTS:
		source.create_tile(Vector2i(x, 0))

	# Source registered with TileSet BEFORE setting per-tile data.
	ts.add_source(source, 0)

	var h        : float            = TILE_SIZE / 2.0
	var poly     : PackedVector2Array = PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h),
	])
	var occluder : OccluderPolygon2D = OccluderPolygon2D.new()
	occluder.polygon = poly

	for x in TILE_VARIANTS:
		var td : TileData = source.get_tile_data(Vector2i(x, 0), 0)
		td.set_collision_polygons_count(0, 1)
		td.set_collision_polygon_points(0, 0, poly)
		td.set_occluder(0, occluder)

	return ts


# ── Wall logic ────────────────────────────────────────────────────────────────

## Returns true when (col, row) is solid wall — i.e. outside every open-water zone.
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
