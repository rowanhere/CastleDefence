# 🏰 Castle Defence

A 2D pixel-art **castle defence** game built with **Godot 4.6**.  
Place towers along the enemy path, fight off waves, and protect your castle's HP from reaching zero.

---

## 🎮 How It Works

- Enemies spawn and follow a fixed **Path2D** toward your castle
- Place towers at designated spots alongside the path to stop them
- Each tower costs **400 coins** to place
- Enemies now **drop coins on death**
- Enemies that reach the end of the path **damage the castle**
- **Game over** when the castle's HP hits zero
- Survive all **10 waves** to complete the level

## 📌 Current Build

- One playable level is currently set up under `scenes/levels/level1/`
- Enemy spawning is driven by a level spawn resource: `level1_spawn.tres`
- Waves use timed starts instead of one hardcoded enemy list
- Mixed enemy pools are spawned in **round-robin order** until the wave multiplier total is reached
- Enemy stats and coin rewards scale by level through `GameHandler`
- Enemy visuals now support **per-enemy health bar colors** through `EnemyData`
- The final scheduled wave is currently a **boss placeholder** using a goblin until a real boss is added



## 🗼 Towers

### 🏹 Archer Tower
- Fires arrows at enemies within range
- **25 damage** per arrow
- Fast attack speed
- Best for consistent ranged single-target damage
- Plays `arrowHit.mp3` on impact

### 🪖 Barrack Tower
- Spawns **3 soldiers** that engage enemies in melee
- First spawn has a **3-second** delay after placement
- If all 3 soldiers die → respawns all 3 after **10 seconds**
- Progress bar on tower shows the respawn countdown
- Soldiers march out of the tower door one by one (staggered tween + fade-in)
- Each soldier takes a unique flanking position around the enemy
- Soldiers return to their wait positions when no enemies are present
- Plays `soldierSpawn.mp3` per soldier as they march out

### 🔮 Magic Tower *(coming soon)*
### 💣 Bomb Tower *(coming soon)*

---

## 👹 Enemies

Enemies use a **3-state system** powered by dynamic reparenting:

| State | Behaviour |
|---|---|
| **On path** | Walks via `PathFollow2D`, detects soldiers within 150px |
| **In combat** | Reparented to scene root — moves freely, claims a unique angle slot around the soldier, attacks when at slot |
| **Returning** | Walks `move_toward` the nearest point on the path curve, reparents back once it physically arrives |

**Key details:**
- Each enemy claims one of 8 evenly-spaced angle slots around the soldier so they physically surround it
- Combat uses direct position movement (no physics collision) so enemies don't push each other
- When a soldier dies, enemies walk back to the path smoothly — no teleporting
- If a new soldier appears while returning, the enemy immediately re-enters combat
- Show **floating red damage numbers** when hit
- Play a death animation before being freed
- Reaching the castle end → damages castle HP

### Enemy Types
| Enemy | HP | Speed | Attack Speed | Damage | Coin Drop | Health Bar Color |
|---|---:|---:|---:|---:|---:|---|
| Goblin | 80 | 110 | 1.0 | 10 | 10 | `#1ABC9C` |
| Gnoll | 140 | 95 | 0.8 | 18 | 16 | `#F39C12` |
| Demon | 220 | 85 | 0.9 | 24 | 22 | `#8E44AD` |
| Golem | 320 | 50 | 1.7 | 30 | 28 | `#3498DB` |

**Balance notes:**
- Goblins are the fast, low-health frontline swarm enemy
- Gnolls are mid-tier melee bruisers with better damage and staying power
- Demons are elite pressure units that hit harder than gnolls without replacing the golem tank role
- Golems are slow, heavy lane tanks with the largest health pool and highest melee damage

---

## ⚔️ Soldier Behaviour

| State | Action |
|---|---|
| No enemies in tower area | Walk to wait position near tower, idle |
| Enemy enters tower area | Assigned a target by the tower |
| Target assigned | Chase enemy, take unique flanking slot |
| In attack range | Stop, swing continuously, deal damage |
| Enemy dead | Stop attacking, return to wait position |
| All 3 soldiers dead | Tower starts 10s respawn countdown |

---

## 🔊 Audio

| File | Trigger |
|---|---|
| `soldierSpawn.mp3` | Each soldier marching out of barrack (staggered) |
| `swordHit.mp3` | Soldier landing a hit on an enemy |
| `arrowHit.mp3` | Arrow hitting an enemy |
| `Forest Day.ogg` | Main menu background music |
| `levelMap.ogg` | Level select screen music |

---

## 🗂️ Project Structure

```
defence/
├── assets/
│   ├── audio/
│   │   ├── music/       # Forest Day.ogg, levelMap.ogg
│   │   └── sfx/         # arrowHit, swordHit, soldierSpawn
│   ├── fonts/           # JosefinSans, WinkySans
│   └── textures/
│       ├── enemies/     # Walk, Attack, Hurt, Dead sprites
│       ├── levels/      # Grass tiles, tower slot buttons
│       ├── towers/      # Archer, Barrack sprite sheets
│       └── ui/          # Buttons, backgrounds, icons
├── resources/
│   └── towers/          # TowerData + UpgradeData (.tres)
├── scenes/
│   ├── autoload/        # AudioController, GameSound singletons
│   ├── enemies/         # enemy.tscn, DamageNumber.tscn
│   ├── levels/          # level1/level_1.tscn, level1/level1_path.tscn
│   ├── projectiles/     # arrow.tscn
│   ├── systems/tower/   # Tower builder UI popup
│   ├── towers/
│   │   ├── archer/      # archerTower.tscn
│   │   └── barrack/     # barrackTower.tscn, BarrackSoldier.tscn
│   └── ui/              # main_menu, level select, HUD, buttons
└── scripts/
    ├── autoload/        # music_player.gd
    ├── gameplay/        # enemy.gd, level_path_handler.gd, damage_number.gd
    │                    # game_handler.gd, enemy_spawn_schedule.gd, enemy_spawn_wave.gd
    ├── systems/         # tower_builder.gd, tower_builder_button.gd
    ├── towers/          # barrackTower.gd, barrackSoldierHandler.gd
    │                    # archer_tower_attack.gd, arrow.gd, game_sound.gd
    └── ui/              # main_menu.gd, level.gd, level_button.gd
```

---

## 🛠️ Built With

- [Godot 4.6](https://godotengine.org/)
- GDScript
- Pixel art assets — 320×180 base resolution

---

## 🚀 Running the Project

1. Clone the repo
2. Open **Godot 4.6**
3. Import the project by selecting `project.godot`
4. Press **F5** to run

---

## 🛣️ Roadmap

- [ ] Castle HP bar + proper game over screen
- [ ] Magic Tower
- [ ] Bomb Tower
- [ ] Better wave presentation / countdown UI
- [ ] Tower upgrade system
- [ ] Real boss enemy and boss encounter flow
- [ ] Level unlock progression
