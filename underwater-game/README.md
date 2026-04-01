# Underwater Survival Horror — Europa

**Group 2:** Rafid Ahmed, Justin Dutta, Jerry Zou
**Engine:** Godot 4.6 (GL Compatibility renderer)

---

## Concept

A top-down 2D survival horror game set beneath the ice of Jupiter's moon Europa. The player is a deep-sea researcher stranded after an incident at an underwater research facility. They must navigate flooded cave systems, scavenge supplies, and piece together what happened — all while managing limited oxygen and avoiding whatever is lurking in the dark.

---

## Project Structure

```
underwater-game/
├── autoloads/
│   ├── dialogue_manager.gd   # Global dialogue system (signals: started, line_advanced, ended)
│   ├── inventory.gd          # Global inventory (20 slots, stackable items)
│   └── scene_manager.gd      # Scene transitions
├── levels/
│   └── level_1/
│       ├── level_1.tscn      # Main level scene (background, player, interactables)
│       └── level_map.gd      # Procedural TileMapLayer — cave + research facility layout
├── scripts/
│   └── interactables/
│       ├── interactable.gd        # Base class for all interactable objects
│       ├── npc_interactable.gd    # NPC/object that triggers dialogue lines
│       └── pickup_item.gd         # Item pickups that add to inventory
├── shared/
│   ├── items/
│   │   ├── item_data.gd      # ItemData resource (id, display_name, max_stack)
│   │   └── test_item.tres    # Example item resource
│   ├── player/
│   │   ├── player.gd         # Movement (swim physics + buoyancy), cone light rotation
│   │   ├── player.tscn       # CharacterBody2D — 16x16 sprite, collision, lights, camera
│   │   └── interaction_system.gd  # Detects nearest interactable in range
│   └── ui/
│       ├── InventoryUI.tscn
│       ├── inventory_ui.gd
│       ├── dialogue_ui.tscn
│       ├── dialogue_ui.gd
│       └── interaction_prompt_ui.gd
├── assets/
│   ├── tiles/
│   │   └── tileset.png       # 128x16 strip — 8 distinct 16x16 cave-rock tiles (fBm noise)
│   └── player/
│       └── cone_light.png    # 256x256 cone light texture (apex at center, points right)
├── main.tscn
├── main.gd
└── project.godot
```

---

## What Is Built

### Player
- `CharacterBody2D` with 8-directional swim movement, momentum, and passive buoyancy
- **16x16** collision shape and visual placeholder (ColorRect)
- Cone-shaped `PointLight2D` spotlight that rotates to face the direction of movement
- Ambient `PointLight2D` for a soft radial glow
- `Camera2D` following the player
- Interaction zone (`Area2D`) that detects nearby interactables

### Level 1 — Cave + Research Facility
- **200x64 tile map** (3200x1024 px) with 16x16 tiles
- Runtime-generated `TileMapLayer` with physics collision on all wall tiles
- Level layout (open-zone system — everything outside a zone is solid wall):
  - **Wide open cave** (cols 2–96): large flooded cavern, player spawn area
  - **Narrow corridor** (cols 97–116, rows 27–32): tight 6-tile-tall squeeze
  - **Airlock antechamber** (cols 117–142): pressurisation room
  - **Main research lab** (cols 143–192): large facility interior
  - **Vertical shaft** (cols 162–169): connects lab to lower level
  - **Server/equipment room** (cols 152–186, rows 54–62): bottom floor
- Cave-rock tileset (`assets/tiles/tileset.png`) — 8 visually distinct 16x16 tiles generated with multi-octave fBm noise (Pillow/Python)

### Interactable System
- Base `Interactable` class with `interact()` virtual method
- `PickupItem` — adds `ItemData` resource to global inventory on interact
- `NpcInteractable` — plays an array of dialogue lines through `DialogueManager`
- `InteractionSystem` — polls `Area2D` overlap to find the closest interactable; prompts player with UI hint

### Autoloads (Global Singletons)
| Autoload | Purpose |
|---|---|
| `DialogueManager` | Manages dialogue state, emits signals to `DialogueUI` |
| `Inventory` | 20-slot inventory with stacking, add/remove/query API |
| `SceneManager` | Handles scene transitions |

### UI
- `InventoryUI` — grid display for inventory slots (Tab key to toggle)
- `DialogueUI` — displays speaker name + dialogue line, advances on E / ui_accept
- Interaction prompt — appears when player is in range of an interactable

### Input Bindings
| Action | Key |
|---|---|
| Move | Arrow keys / WASD (ui_left/right/up/down) |
| Interact | E |
| Inventory | Tab |

---

## What Still Needs to Be Done

### High Priority
- [ ] **Player sprite** — replace the 16x16 `ColorRect` placeholder with an actual character sprite (`Sprite2D` + spritesheet). Add idle/swim animation (`AnimationPlayer` or `AnimatedSprite2D`)
- [ ] **Update `level_1.tscn`** for the new 3200x1024 layout — background size, player spawn `(200, 520)`, and all object positions need updating to match `level_map.gd`'s zone coordinates
- [ ] **Enemy / creature** — at least one hostile entity that patrols or hunts the player (core horror mechanic from pitch)
- [ ] **Oxygen system** — depleting oxygen meter; player dies or panics when it hits zero; oxygen tanks as pickups

### Medium Priority
- [ ] **Actual interactable objects placed in level** — Submarine wreck, HQ Radio, Supply Kits, Research Terminal, Exit Airlock (currently only a test item and a radio placeholder exist)
- [ ] **Tileset art pass** — current cave tiles are procedural noise; need to look like ice-crusted rock/metal for the facility sections. Consider a second tileset for interior walls
- [ ] **Level 2** — the pitch describes multiple areas (cave → facility → deeper trench). Level 1 is the cave+facility; Level 2 would be the deeper/darker zone
- [ ] **Scene transitions** — `SceneManager` exists but transitions between levels/main menu aren't wired up
- [ ] **Main menu** — title screen with New Game / Continue

### Lower Priority
- [ ] **Sound design** — ambient underwater drone, creature sounds, footstep/swim bubbles, interaction SFX
- [ ] **Oxygen/hazard UI** — HUD showing oxygen bar, maybe a depth gauge
- [ ] **Dialogue content** — write actual story dialogue for HQ Radio, Research Terminal, NPC logs; currently only placeholder `"Hello... Can you hear me?"` exists
- [ ] **Creature AI behaviour** — idle patrol, alert on line-of-sight, chase/flee states
- [ ] **Save system** — checkpoint or slot-based save via `SceneManager` or a new `SaveManager` autoload
- [ ] **Mobile/controller support** — project is keyboard-only right now

---

## Running the Project

1. Open **Godot 4.6** (or latest 4.x)
2. Import the project by opening `project.godot`
3. Press **F5** or click **Play** — the game starts at `main.tscn` which loads `level_1`

> Godot may warn about missing `cone_light.png` or `tileset.png` on first run if the asset generation scripts haven't been run. See `assets/` for the Python generation scripts.

---

## Asset Generation

The cave tileset and cone light texture are generated via Python scripts (Pillow required):

```bash
pip install Pillow
python assets/tiles/gen_tileset.py      # generates assets/tiles/tileset.png
python assets/player/gen_cone_light.py  # generates assets/player/cone_light.png
```
