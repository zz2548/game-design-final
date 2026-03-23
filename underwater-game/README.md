# 🎮 Underwater Horror — Core Systems
## Godot 4 · Inventory · Interaction · Dialogue

---

## Files Overview

| File | Purpose |
|------|---------|
| `item_data.gd` | Resource class — defines what an item IS |
| `inventory.gd` | Autoload — manages player inventory |
| `interactable.gd` | Base class for all world interactables |
| `pickup_item.gd` | Interactable: picks up an item on E |
| `npc_interactable.gd` | Interactable: starts dialogue on E |
| `interaction_system.gd` | Component on Player — detects nearby interactables |
| `dialogue_manager.gd` | Autoload — manages dialogue state |
| `dialogue_ui.gd` | UI node — renders dialogue box with typewriter |
| `interaction_prompt_ui.gd` | HUD label — shows "[E] Pick up Flare" etc. |

---

## Setup Steps

### 1. Autoloads
Go to **Project > Project Settings > Autoload** and add:
- `inventory.gd` as **`Inventory`**
- `dialogue_manager.gd` as **`DialogueManager`**

### 2. Input Map
Go to **Project > Project Settings > Input Map** and add:
- Action: **`interact`** → bind to `E`
- (You probably already have `ui_accept` bound to `Enter`/`Space` — used for dialogue too)

### 3. Player Setup
On your Player node:
1. Add a child **`Area3D`** named `InteractionZone`
2. Give it a **`CollisionShape3D`** (SphereShape, radius ~1.5)
3. Set `InteractionZone`'s collision layer/mask to detect interactable objects
4. Add `interaction_system.gd` as a child Node of the Player
5. In Inspector, drag `InteractionZone` into the `interaction_zone` export field

### 4. Creating Items
1. In FileSystem, right-click → **New Resource** → choose `ItemData`
2. Fill out `id`, `display_name`, `description`, etc.
3. Save as `res://items/flare.tres` (for example)

### 5. Placing a Pickup in the World
1. Create an **`Area3D`** node in your scene
2. Add a `CollisionShape3D` child
3. Attach `pickup_item.gd`
4. Drag your `.tres` item resource into the `item` export field

### 6. Placing an NPC / Note
1. Create an **`Area3D`** node
2. Add a `CollisionShape3D`
3. Attach `npc_interactable.gd`
4. Fill in `speaker_name` and `dialogue_lines` in the Inspector

### 7. HUD / UI
- Create a **`CanvasLayer`** in your scene for the HUD
- Add a **`Label`**, attach `interaction_prompt_ui.gd`, drag in the InteractionSystem
- For dialogue: add a `CanvasLayer` with a `Panel` + labels per the comments in `dialogue_ui.gd`

---

## Adding a New Interactable Type

Just extend `Interactable` and override `_on_interact`:

```gdscript
class_name OxygenTank
extends Interactable

func _ready():
    interaction_label = "Refill Oxygen"

func _on_interact(player: Node) -> void:
    player.oxygen = player.max_oxygen
    queue_free()
```

---

## Triggering Dialogue from Code

```gdscript
var log_entry = {
	"speaker": "Captain's Log",
	"lines": [
		"Day 14. The sonar stopped working.",
		"Something is down here with us.",
		"I don't think we're going to make it back up.",
    ],
}
DialogueManager.start_dialogue(log_entry)
```

---

## Checking Inventory from Code

```gdscript
# Add item
Inventory.add_item(my_item_resource, 1)

# Check
if Inventory.has_item("flare"):
	Inventory.remove_item("flare", 1)
    # use flare logic...

# Get count
var count = Inventory.get_item_count("oxygen_canister")
```
