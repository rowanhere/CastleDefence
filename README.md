# Castle Defence

A 2D pixel-art tower-defence game built with Godot 4.6. Place and upgrade towers, earn coins from defeated enemies, hold the road with barrack soldiers, and protect the castle through every wave.

## Current Build

- Godot `4.6`, GDScript, Forward+ renderer
- `320 x 180` base viewport, stretched to the game window
- Two playable levels; Level 2 temporarily reuses the Level 1 map with its own scaled wave schedule
- Five scheduled waves with mixed enemy pools and a dedicated Vampire Lord boss
- Four playable tower types: Archer, Barrack, Magic, and Bomb
- Tower purchase, upgrade, destroy, refund, range preview, and insufficient-coin feedback
- Animated HUD counters, wave countdown, spawn-direction pointer, pause menu, win screen, and fail screen
- Threaded loading transition for entering, restarting, and leaving a level
- Music toggle with fades and randomized in-game music

## Gameplay Flow

1. Choose Level 1 from the level map.
2. Click a tower-builder location to open its four-tower purchase popup.
3. Buy a tower for `400` coins. The tower is placed at the builder's exact position.
4. Click a built tower to view its current stats, next upgrade, cost, and destroy refund.
5. Defeat enemies to earn their coin drops before they reach the castle.
6. Complete every scheduled wave while the castle has more than `0` HP to win.

Each level starts with `800` coins and `100` castle HP. Coins are battle-only currency and reset whenever a level starts.

## Economy and Tower Lifecycle

- Every tower purchase currently costs `400` coins.
- Failed purchases and upgrades flash the HUD coin value red and shake it.
- Upgrade costs come from the next level's `UpgradeData` resource.
- Destroying a tower refunds `80%` of its current level resource cost.
- Destroying a tower restores its original tower builder at the same transform.
- Destroying a barrack also removes its active soldier.
- Successful placement and upgrades play dedicated sound effects.

## Towers

### Archer Tower

Targets enemies in range and fires homing arrows. Its level-specific base and archer textures are supplied by the upgrade resources.

| Level | Damage | Attacks/sec | Range | Resource Cost |
|---|---:|---:|---:|---:|
| 1 | 22 | 1.75 | 260 | 400 |
| 2 | 34 | 2.25 | 290 | 650 |
| 3 | 52 | 2.85 | 325 | 1050 |

### Barrack Tower

Spawns one soldier that intercepts enemies near the path. The soldier becomes larger and tankier when the tower is upgraded.

- Initial soldier spawn delay: `3` seconds
- Soldier respawn delay: `10` seconds
- Soldier maximum HP: `tower level * 100`
- Soldier scale: `2.5x` at level 1 and `3.0x` at level 2
- Spawn and respawn progress is shown above the tower

| Level | Soldier Damage | Attacks/sec | Range | Resource Cost |
|---|---:|---:|---:|---:|
| 1 | 14 | 1.0 | 230 | 400 |
| 2 | 20 | 1.25 | 250 | 650 |

### Magic Tower

Maintains a visible magic beam while enemies are in range. It can chain through up to three nearby targets; each later target receives `65%` of the previous target's damage. The beam also refreshes a short slow effect.

| Level | Damage | Attacks/sec | Range | Slow | Resource Cost |
|---|---:|---:|---:|---:|---:|
| 1 | 14 | 0.65 | 240 | 10% | 650 |
| 2 | 23 | 0.75 | 270 | 15% | 1050 |
| 3 | 36 | 0.90 | 305 | 20% | 1550 |

### Bomb Tower

Launches three animated bomb shots, then enters a reload cooldown. Bombs rise vertically, steer toward their target while falling, rotate with their trajectory, and damage every enemy inside the impact radius.

| Level | Blast Damage | Attack Rate | Range | Resource Cost |
|---|---:|---:|---:|---:|
| 1 | 55 | 1.25 | 240 | 800 |
| 2 | 90 | 1.45 | 270 | 1200 |
| 3 | 140 | 2.00 | 310 | 1800 |

`Resource Cost` is the value stored on that level resource. Tower placement still uses the shared `400` purchase price; upgrades charge the next level's resource cost.

## Enemies

Enemy base stats live in `resources/enemies/<enemy>.tres`. Each resource also provides directional animation frames, path spacing, visual scale, coin reward, and a custom health-bar color.

| Enemy | Role | HP | Speed | Attack Delay | Damage | Coins | Path Spacing |
|---|---|---:|---:|---:|---:|---:|---:|
| Goblin | Fast swarm | 70 | 120 | 1.10 | 8 | 12 | 26 |
| Gnoll | Early bruiser | 130 | 95 | 0.90 | 16 | 18 | 80 |
| Imp | Fast pressure | 95 | 104 | 0.75 | 14 | 16 | 42 |
| Mushroom | Early tank | 180 | 76 | 1.05 | 18 | 24 | 52 |
| Demon | Elite pressure | 220 | 82 | 0.80 | 24 | 28 | 52 |
| Zombie | Slow durable unit | 230 | 54 | 1.25 | 22 | 28 | 65 |
| Predator | Mid-late bruiser | 260 | 58 | 1.15 | 27 | 34 | 70 |
| Lizardman | Heavy fighter | 280 | 72 | 0.90 | 28 | 34 | 62 |
| Beholder | Late heavy threat | 310 | 48 | 1.35 | 34 | 42 | 76 |
| Golem | Heavy tank | 360 | 45 | 1.60 | 32 | 38 | 68 |
| Vampire Lord | Final boss | 1800 | 30 | 1.80 | 170 | 0 | 125 |

Directional enemy sheets use the row order `down`, `up`, `left`, `right`. Their SpriteFrames expose matching walk, attack, hurt, and death animations.

## Enemy Movement and Barrack Combat

- Enemies travel through `Path2D` using `PathFollow2D` nodes.
- Normal waves spawn in groups of two with temporary spawn lanes.
- Crowd speed adjustment and lateral path lanes reduce visual overlap in large groups.
- Enemies near a soldier leave path movement and reserve positions around that soldier.
- Multiple enemies can surround and attack the same soldier instead of waiting in one strict queue.
- When combat ends, enemies return to the path and reclaim a lane.
- Enemies that reach the path end damage the castle and are removed.

## Waves and Scaling

Level 1 uses `scenes/levels/level1/level1_spawn.tres`:

| Wave | Start | Enemy Pool | Count |
|---|---:|---|---:|
| 1 | 0s | Imp, Goblin | 14 |
| 2 | 45s | Goblin, Gnoll, Imp | 15 |
| 3 | 75s | Gnoll, Zombie, Predator | 10 |
| 4 | 105s | Gnoll, Demon, Lizardman, Zombie, Beholder, Predator | 10 |
| 5 | 135s | Vampire Lord boss | 1 |

Non-boss enemies are duplicated and scaled at spawn time:

```gdscript
level_offset = max(level_number - 1, 0)
wave_offset = max(wave_number - 1, 0)

health_scale = 1.0 + level_offset * 0.20 + wave_offset * 0.12
damage_scale = 1.0 + level_offset * 0.12 + wave_offset * 0.08
speed_scale = min(1.0 + level_offset * 0.03 + wave_offset * 0.015, 1.35)
coin_scale = 1.0 + level_offset * 0.15 + wave_offset * 0.08
```

Bosses scale separately by level only:

```gdscript
boss_health_scale = 1.0 + level_offset * 0.35
boss_damage_scale = 1.0 + level_offset * 0.18
boss_speed_scale = min(1.0 + level_offset * 0.04, 1.35)
```

The Vampire Lord is the only boss and appears as the final threat on every level with level-scaled HP, damage, and speed. It uses its own scene and top-down SpriteFrames resource while sharing the established enemy combat contract. Its arrival triggers a short camera shake. It is `3.3x` scale, flies along the path using its run animation, descends to attack, and always drops zero coins. Reaching the castle is an immediate loss because its first castle strike consumes all remaining castle health.

## HUD, Win, and Fail States

- HUD displays castle HP, coins, current wave, total waves, and time until the next wave.
- A pulsing pointer appears five seconds before a wave and points toward its spawn direction.
- The level ends only after all waves are queued and every living enemy is gone.
- Castle HP `75-100`: 3 stars
- Castle HP `40-74`: 2 stars
- Castle HP `1-39`: 1 star
- Pause, restart, back-to-level-select, win, and fail actions use the loading transition where appropriate.

## Local Save Data

Persistent progress is managed by the `SaveManager` autoload and written to `user://save.cfg`. The save currently contains:

- Total reward currency earned from level wins
- Unlocked level numbers
- Best star rating for each completed level
- Highest completed level
- Owned Fire, Thunder, and Rock ability counts
- Music enabled/disabled state
- Sound-effect enabled/disabled state

Level coins are intentionally not saved. Every level starts with `800` coins, and enemy coin drops are used only during that battle. A win awards `1`, `2`, or `3` persistent reward currency based on the result shown by `RewardLabel`.

Special-ability inventory is stored under `inventory/special_abilities`. A new save begins with one Fire, one Thunder, and one Rock ability in the global inventory. These are one-time starting items, not a refill for every level. Used abilities remain consumed across scene changes, while shop purchases add permanently saved charges. Empty ability buttons are disabled. `SaveManager.add_ability()`, `get_ability_count()`, and `consume_ability()` provide the inventory API.

Selecting an owned in-game ability adds a gold outline to its button and displays a `100px` green world-space targeting radius at the mouse. Selecting it again, right-clicking, or pressing Escape cancels targeting. Fire deals `120` AOE damage, Thunder deals `220`, and Rock deals `180`; each ability applies gameplay damage only once regardless of its visual instance count. All three consume one global inventory charge on placement and start a `20s` per-ability cooldown.

While ability targeting is active, a transparent HUD input layer blocks tower selection, tower upgrades, builders, and other underlying controls. The ability dock remains interactive for switching or cancelling the selected ability, and the overlay forwards the world placement click to the active effect.

Special abilities share the same effect scene, `100px` radius, AOE targeting, `1.25s` duration, and `20s` cooldown. Each `SpecialAbilityData` resource supplies its own damage, `SpriteFrames`, animation name, `effect_scale`, `effect_offset`, visual instance count, spread, stagger, and optional sound. Scale and offset adjust only the visual; they do not move or resize the gameplay AOE. Ability animations use the non-looping `special` animation and are played through `AnimatedSprite2D.play()`.

The level selector includes a persistent special-ability shop. Fire costs `3`, Thunder costs `5`, and Rock costs `4` reward currency. Plus/minus controls build a temporary cart without allowing its total to exceed the saved balance. `DONE` commits all selected quantities in one atomic save through `SaveManager.purchase_abilities()`; closing the shop discards the unconfirmed cart.

## Audio

| Asset | Use |
|---|---|
| `tower_purchase.mp3` | Successful tower placement |
| `tower-upgrade.mp3` | Successful tower upgrade |
| `arrowHit.mp3` | Arrow impact |
| `swordHit.mp3` | Soldier melee hit |
| `soldierSpawn.mp3` | Barrack soldier spawn |
| `magicLaser.mp3` | Active magic beam |
| `BombTowerLauncher.mp3` | Bomb launch |
| `bombImpact.mp3` | Bomb explosion |
| `Forest Day.ogg` | Main menu music |
| `levelMap.ogg` | Level-select music |
| `GameMusic/music1-4.mp3` | Randomized gameplay music |

## Project Structure

```text
defence/
|-- assets/                 # Fonts, music, SFX, and textures
|-- resources/
|   |-- enemies/            # EnemyData and SpriteFrames resources
|   `-- towers/             # TowerData and per-level UpgradeData
|-- scenes/
|   |-- gameplay/           # GameHandler and wave pointer
|   |-- levels/             # Castle and level content
|   |-- projectiles/        # Arrow and bomb projectiles
|   |-- systems/tower/      # Builder and upgrade interfaces
|   |-- towers/             # Archer, barrack, bomb, and magic scenes
|   `-- ui/                 # Menus, HUD, and scene transition
|-- scripts/
|   |-- autoload/           # Music state and transitions
|   |-- gameplay/           # Waves, enemies, castle, and rewards
|   |-- systems/            # Tower purchase popup
|   |-- towers/             # Tower attacks, soldiers, and upgrades
|   `-- ui/                 # Menus, HUD, levels, and loading
`-- project.godot
```

## Running the Project

1. Install Godot `4.6.x`.
2. Clone this repository.
3. Import `project.godot` in the Godot Project Manager.
4. Allow the initial asset import to finish.
5. Press `F5` to start from `scenes/ui/menu.tscn`.

The optional GDScript Formatter editor plugin expects the external `gdformat` command from `gdtoolkit`. The game can run without that formatter command, but the editor prints a plugin warning when it is unavailable.

## Known Gaps and Next Work

- [ ] Add boss-specific abilities, telegraphs, and HUD presentation.
- [ ] Replace the temporary Level 2 map and add playable scenes and schedules for Levels 3-15.
- [x] Persist unlocked levels, star ratings, settings, reward currency, and ability inventory between sessions.
- [ ] Continue stress-testing crowd lanes and barrack combat with very large waves and builders near spawn points.
- [ ] Add automated smoke tests for scene loading, purchases, upgrades, win/fail transitions, and resource validity.
- [ ] Remove obsolete temporary level scene files after confirming they are not needed.

## Adding Content

### Add a playable level

The level loader is convention-based. For level number `N`, it looks for both of these exact paths:

```text
scenes/levels/levelN/level_N.tscn
scenes/levels/levelN/levelN_spawn.tres
```

For example, Level 3 must be stored as `scenes/levels/level3/level_3.tscn` with `scenes/levels/level3/level3_spawn.tres`. A level button remains locked-looking if either file is missing, even when that number exists in the saved unlocked-level list.

Recommended workflow:

1. Duplicate `scenes/levels/level1/` and rename the folder and two numbered files for the new level.
2. Open `level_N.tscn`, rename its root to something clear such as `Level3`, and replace the map art or TileMap layers.
3. Keep or add one `Camera2D` that frames the playable map. The boss arrival shake uses the viewport's active camera when one exists.
4. Add a `Path2D` for the enemy route. Attach `scripts/gameplay/level_path_handler.gd` and give it a direct child `Timer` named `Timer`.
5. Draw the path curve from the enemy entrance to the castle. The first curve point is the spawn location and its initial direction controls the incoming-wave pointer orientation.
6. Add the path anywhere under the level scene. The path script automatically joins the `level_path` group, which enemies and barrack soldiers use to find it.
7. Instance `scenes/levels/castle.tscn` and keep the instantiated node named `Castle`. Enemy castle detection searches recursively by that exact name.
8. Instance `scenes/systems/tower/tower_builder.tscn` at every allowed tower location. Builders are optional for loading, but the player needs them to purchase towers.
9. Keep road visuals, terrain, decorations, and obstacle layers separate for editing clarity. Nodes named `PathNode` and `Obstacle` are useful organization in the current maps but are not required by the runtime loader.
10. Create the matching `levelN_spawn.tres`, assign `EnemySpawnSchedule`, and add ordered `EnemySpawnWave` resources to its `waves` array.
11. Test the level from the selector, not only by running its scene directly. `GameHandler.queued_level` determines which map, schedule, enemy scaling, completion record, and next-level unlock are used.

Required runtime nodes:

| Node | Requirement | Purpose |
|---|---|---|
| Level root | `Node2D` recommended | Container instantiated under `GameHandler/LevelContainer` |
| Enemy route | `Path2D` with `level_path_handler.gd` | Spawning, path movement, wave state, and completion detection |
| Path timer | Direct child `Timer` named `Timer` | Controls spacing between enemy spawns |
| Castle | Instance named `Castle` | Receives enemies and castle damage |
| Camera | Active `Camera2D` recommended | Frames the map and supports boss arrival shake |
| Builders | Any number of `tower_builder.tscn` instances | Fixed legal tower purchase locations |

Each wave resource provides:

- `start_time`: seconds after the level begins when the wave is queued. Keep waves ordered by ascending time.
- `enemy_pool`: lowercase IDs that resolve to `resources/enemies/<id>.tres`.
- `total_multiplier`: total number of enemies, not the number of repetitions per pool member. IDs are selected round-robin from the pool.
- `is_boss_wave`: when enabled, the wave uses `scenes/enemies/boss/boss.tscn`, boss-only stat scaling, a single spawn lane, and the arrival shake. Use `enemy_pool = ["boss"]` and `total_multiplier = 1` for the final boss.

Level completion happens only after every scheduled wave has started, the spawn queue and timer are empty, all enemies are dead, and castle HP is above zero. Completing Level `N` saves the best star result and unlocks `N + 1`; the next button becomes playable only after its correctly named scene and schedule files also exist.

Before considering a new level complete, verify:

- Enemies spawn at the first path point facing along the route and reach the castle at the final point.
- The path is centered on the visible road and does not cut through tower-builder locations.
- The wave pointer remains inside the viewport and points toward the entrance.
- Every enemy ID loads without resource warnings.
- Barrack soldiers can locate the `level_path` group and reach nearby combat positions.
- Tower builders place and restore towers at their own exact positions.
- The final enemy death triggers the win overlay, stars, reward save, and next-level unlock.
- Castle destruction triggers the fail overlay and never records completion.

### Add an enemy

1. Add its directional sprite sheets and imports under `resources/enemies/<id>/`.
2. Create a SpriteFrames resource with the animation names expected by `enemy.gd`.
3. Create `resources/enemies/<id>.tres` using `EnemyData`.
4. Add the lowercase resource ID to a wave's `enemy_pool`.
5. Test path spacing, directional facing, death cleanup, coin drops, and barrack combat.

### Add a tower level

1. Create the next `levelN.tres` using `UpgradeData`.
2. Add it to the tower's ordered `upgrades` array.
3. Supply all required level textures, including tower-top or bomb-launcher parts where relevant.
4. Confirm the tower applies damage, attack speed, range, slow, and visuals through `handle_upgrade_applied()`.
5. Verify the upgrade preview, payment, max-level state, refund, and restored builder.
