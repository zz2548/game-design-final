# Europa — Underwater Survival Horror

**Group 2:** Rafid Ahmed · Justin Dutta · Jerry Zou
**Engine:** Godot 4.6 · GDScript · GL Compatibility renderer

---

## Table of Contents

1. [How to Run](#how-to-run)
2. [Project Structure](#project-structure)
3. [Systems Overview](#systems-overview)
4. [How to Add an NPC](#how-to-add-an-npc)
5. [How to Add a New Item Type / Item](#how-to-add-a-new-item-type--item)
6. [How to Add an Ammo Pickup](#how-to-add-an-ammo-pickup)
7. [How to Add a New Level](#how-to-add-a-new-level)
8. [Controls](#controls)
9. [What Still Needs to Be Done (from the pitch)](#what-still-needs-to-be-done-from-the-pitch)

---

## How to Run

1. Open **Godot 4.6** (or any 4.x release)
2. Click **Import** and select `project.godot` in this folder
3. Press **F5** or click **Run** — the game starts at `main.tscn` → `level_1`

> **First time only:** If Godot warns about missing `tileset.png` or `cone_light.png`,
> run the Python generators in `assets/` (`pip install Pillow` first):
> ```
> python assets/tiles/gen_tileset.py
> python assets/player/gen_cone_light.py
> ```

---

## Project Structure

```
underwater-game/
│
├── autoloads/                      # Global singletons — always loaded
│   ├── dialogue_manager.gd         # Runs all dialogue; emit signals to UI
│   ├── inventory.gd                # 20-slot inventory with stacking
│   └── scene_manager.gd            # Change levels: SceneManager.go_to_level(2)
│
├── levels/
│   └── level_1/
│       ├── level_1.tscn            # The actual scene (place objects here)
│       └── level_map.gd            # Generates the TileMapLayer at runtime
│
├── scripts/
│   ├── interactables/
│   │   ├── interactable.gd         # BASE CLASS — extend this for any E-press object
│   │   ├── npc_interactable.gd     # Plays dialogue lines when pressed
│   │   └── pickup_item.gd          # Adds ItemData to inventory when pressed
│   └── weapons/
│       ├── bullet.gd               # Projectile — travels until it hits a wall
│       └── bullet.tscn             # Bullet scene (5×2 yellow rect)
│
├── shared/
│   ├── items/
│   │   ├── item_data.gd            # Resource class — define all item properties here
│   │   └── test_item.tres          # Example item resource
│   ├── player/
│   │   ├── player.gd               # Movement, mouse aiming, shooting, ammo
│   │   ├── player.tscn             # CharacterBody2D — 16×16, lights, camera
│   │   └── interaction_system.gd   # Detects nearest Interactable in the player's zone
│   └── ui/
│       ├── InventoryUI.tscn        # Grid of inventory slots (Tab to open)
│       ├── inventory_ui.gd
│       ├── dialogue_ui.tscn        # Dialogue box with typewriter text
│       ├── dialogue_ui.gd
│       └── interaction_prompt_ui.gd  # "[E] Talk to …" hint label
│
├── assets/
│   ├── tiles/tileset.png           # 128×16 strip — 8 cave-rock tile variants
│   └── player/cone_light.png       # Cone flashlight texture
│
├── main.tscn                       # Entry point — just calls SceneManager.go_to_level(1)
├── main.gd
└── project.godot
```

---

## Systems Overview

### How the pieces connect

```
main.tscn
  └─ main.gd  →  SceneManager.go_to_level(1)  →  level_1.tscn
                                                        │
                                     ┌──────────────────┼──────────────────┐
                                     │                  │                  │
                               LevelMap            player.tscn         Items/NPCs
                         (TileMapLayer walls)    (CharacterBody2D)    (Interactables)
                                                        │
                                              InteractionSystem
                                         (watches InteractionZone Area2D)
                                                        │
                                              Interactable.on_interact()
                                            ┌───────────┴────────────┐
                                      PickupItem               NpcInteractable
                                   Inventory.add_item()    DialogueManager.start_dialogue()
                                            │                        │
                                     InventoryUI.tscn          DialogueUI.tscn
                                     (signal: item_added)    (signal: line_advanced)
```

### Autoloads (always available by name everywhere)

| Singleton | What it does | Key methods |
|-----------|-------------|-------------|
| `DialogueManager` | Runs dialogue sequences | `start_dialogue(dict)`, `is_active` |
| `Inventory` | Stores picked-up items | `add_item(item, qty)`, `has_item(id)`, `remove_item(id)` |
| `SceneManager` | Changes levels | `go_to_level(n)`, `next_level()` |

### Player signals you can connect to

```gdscript
$player.ammo_changed.connect(func(cur, max_ammo):
    $HUD/AmmoLabel.text = "%d / %d" % [cur, max_ammo]
)
```

---

## How to Add an NPC

An NPC is any object the player can press **E** on to trigger dialogue.
No new scripts needed — use the existing `NpcInteractable` script.

### Step 1 — Add the node to your level scene

In the Godot editor, open `levels/level_1/level_1.tscn`:

1. Create a new **Area2D** node under the level root (or an "NPCs" Node2D group)
2. Add a **CollisionShape2D** child — set shape to a `RectangleShape2D` roughly the
   size you want the interaction trigger to be (e.g. 32×32)
3. Add a **ColorRect** child as a visual placeholder (or a `Sprite2D` when you have art)
4. On the Area2D, in the Inspector, set **Script → Load** to
   `res://scripts/interactables/npc_interactable.gd`

### Step 2 — Fill in the exported fields (Inspector)

| Field | What to put |
|-------|------------|
| `speaker_name` | The name shown in the dialogue box, e.g. `"HQ Radio"` |
| `dialogue_lines` | Array of strings — each entry is one press of E, e.g. `["Hello, can you hear me?", "Get to the airlock — NOW."]` |
| `portrait` | Optional — drag a Texture2D for a character portrait |
| `interaction_label` | Auto-set to `"Talk to <speaker_name>"`, but you can override |

### Step 3 — Done

The `InteractionSystem` on the player will automatically detect it when the player
walks into range and show the `[E]` prompt. Press E cycles through the dialogue lines.

### Example: a broken terminal log

```
Node: Area2D
  Script: npc_interactable.gd
  speaker_name: "Research Log #4"
  dialogue_lines:
    [0] "Day 14. The borehole breach is getting worse."
	[1] "Dr. Chen hasn't responded since yesterday."
	[2] "I think we're alone down here."
  └─ CollisionShape2D  (RectangleShape2D 48×48)
  └─ ColorRect         (visual placeholder, 32×32, green)
```

---

## How to Add a New Item Type / Item

### Part A — Create the ItemData resource

`ItemData` is a Godot Resource — it stores the definition of an item (not the
in-world pickup, just the data).

**In the editor:**
1. In the **FileSystem** panel, right-click `shared/items/` → **New Resource**
2. Search for `ItemData` and click **Create**
3. Save it as e.g. `shared/items/oxygen_tank.tres`
4. Fill in the fields:

| Field | Example |
|-------|---------|
| `id` | `"oxygen_tank"` — must be unique, used for `has_item()` checks |
| `display_name` | `"Oxygen Tank"` |
| `description` | `"Restores 30 seconds of oxygen."` |
| `icon` | Drag a Texture2D (optional for now) |
| `max_stack` | `3` |
| `is_usable` | `true` if the player can use it from inventory |
| `is_key_item` | `true` if it should never be droppable (e.g. keycards) |
| `custom_data` | `{"oxygen_restore": 30}` — put any extra data here |

**As a .tres file (text)** — you can also duplicate `test_item.tres` and edit it:
```
[gd_resource type="Resource" script_class="ItemData" format=3]
[ext_resource type="Script" path="res://shared/items/item_data.gd" id="1_j6h3p"]
[resource]
script = ExtResource("1_j6h3p")
id = "oxygen_tank"
display_name = "Oxygen Tank"
description = "Restores 30 seconds of oxygen."
max_stack = 3
is_usable = true
custom_data = { "oxygen_restore": 30 }
```

### Part B — Place the pickup in the level

1. In `level_1.tscn`, create an **Area2D** node under the `Items` group
2. Add a **CollisionShape2D** child (RectangleShape2D ~16×16)
3. Add a **ColorRect** child as a visual (or `Sprite2D`)
4. Assign script: `res://scripts/interactables/pickup_item.gd`
5. In the Inspector, drag your new `.tres` into the **item** field
6. Set **quantity** to however many to give

### Part C — Using the item (when the oxygen system exists)

When the player presses Use on the item in the inventory, check `custom_data`:

```gdscript
# In whatever handles item usage:
if item.id == "oxygen_tank":
    var restore: int = item.custom_data.get("oxygen_restore", 0)
    OxygenSystem.add_oxygen(restore)
    Inventory.remove_item("oxygen_tank", 1)
```

---

## How to Add an Ammo Pickup

Ammo is tracked directly on the player (not in the inventory).
To give the player ammo when they interact with a pickup, create a small custom script:

```gdscript
# scripts/interactables/ammo_pickup.gd
extends Interactable

@export var ammo_amount: int = 10

func _ready() -> void:
    interaction_label = "Pick up Ammo (%d)" % ammo_amount

func _on_interact(player: Node) -> void:
    player.add_ammo(ammo_amount)
    queue_free()
```

Then attach this script to an Area2D node in your level instead of `pickup_item.gd`.

---

## How to Add a New Level

1. Duplicate `levels/level_1/` → rename to `level_2/`
2. Edit the new `level_map.gd` — change `OPEN_ZONES` to define your layout
3. Open `autoloads/scene_manager.gd` and confirm level 2 is registered:
   ```gdscript
   const LEVELS = {
       1: "res://levels/level_1/level_1.tscn",
       2: "res://levels/level_2/level_2.tscn",  # already there
       ...
   }
   ```
4. Trigger the transition from a level exit object:
   ```gdscript
   func _on_interact(player: Node) -> void:
       SceneManager.next_level()
   ```

---

## Controls

| Action | Key |
|--------|-----|
| Move | Arrow keys or WASD |
| Aim | Mouse cursor |
| Shoot | Left mouse button |
| Interact | E |
| Inventory | Tab |

---

## What Still Needs to Be Done (from the pitch)

These are features your group pitched that are **not yet implemented**:

---

### 🔴 Critical — Core gameplay is incomplete without these

| Feature | Status | Notes |
|---------|--------|-------|
| **Oxygen / pressure system** | ❌ Not started | Central survival mechanic. Needs an `OxygenSystem` autoload (or node on player), a depleting meter, death/panic state when empty, and oxygen tank pickups. |
| **Enemy creature** | ❌ Not started | The pitch shows a hostile creature that hunts the player. Needs a `CharacterBody2D` enemy with patrol AI, line-of-sight detection, and a chase state. Bullets (`collision_layer=4`) can already hit enemies — an enemy just needs an `Area2D` with `collision_mask=4`. |
| **Player death / game over** | ❌ Not started | Needs a health or oxygen-depletion kill condition that triggers a Game Over screen and respawn or main-menu redirect. |
| **Level exit / win condition** | ❌ Not started | The Exit Airlock object exists in the design but needs logic to call `SceneManager.next_level()` and eventually trigger an ending. |

---

### 🟡 Important — The game is playable but feels incomplete

| Feature | Status | Notes |
|---------|--------|-------|
| **Player sprite** | ❌ Placeholder | Still a 16×16 colored rectangle. Replace `ColorRect` in `player.tscn` with a `Sprite2D` + `AnimatedSprite2D` for swim/idle animations. |
| **Level objects placed** | ⚠️ Partial | `level_1.tscn` still has old placeholder positions. Submarine, HQ Radio, Supply Kits, Research Terminal, and Exit Airlock need to be placed at correct tile-aligned positions in the new layout. |
| **HUD** | ❌ Not started | Player needs an on-screen oxygen bar, ammo counter (`player.ammo_changed` signal already exists), and possibly a depth gauge. |
| **Actual dialogue / story** | ⚠️ Placeholder | `NpcInteractable` and `DialogueManager` are fully working — they just need real written content. The pitch mentions audio logs, HQ transmissions, and environmental storytelling. |
| **Main menu** | ❌ Not started | No title screen. Game jumps straight into Level 1 on launch. Needs a menu with New Game, maybe Continue, and credits. |
| **Scene transitions** | ⚠️ Wired but untested | `SceneManager.go_to_level()` exists but no level-exit interactable actually calls it yet. |

---

### 🟢 Polish — Do these last

| Feature | Status | Notes |
|---------|--------|-------|
| **Sound design** | ❌ Not started | Ambient underwater hum, creature sounds, bubble SFX for movement, gunshot, pickup chime. |
| **Facility tileset** | ⚠️ Cave-only | Current tiles look like cave rock everywhere. The research facility sections (cols 117–200) should use a metal/panel texture instead. |
| **Enemy variety** | ❌ Not started | Pitch mentions multiple threat types. Build the first enemy well, then extend. |
| **Save system** | ❌ Not started | Checkpoint saves using `FileAccess` to write player position + inventory to disk. |
| **Level 2** | ❌ Not started | The pitch describes a deeper, darker zone below the facility. `SceneManager` already has slot 2 registered. |
| **Controller support** | ❌ Not started | All input is keyboard/mouse. Godot's input map supports adding controller bindings alongside existing keys. |
