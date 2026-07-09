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
- Enemy stats and coin rewards scale by level and wave through `GameHandler`
- Enemy visuals now support **per-enemy health bar colors** through `EnemyData`
- The final scheduled wave is currently a **boss placeholder** using a golem until a real boss is added



## Enemy Scaling

Enemy resources store base stats. At spawn time, `GameHandler.get_scaled_enemy_data()` duplicates the enemy data and scales it using the current level number and wave number.

Formula:

```gdscript
level_offset = max(level_number - 1, 0)
wave_offset = max(wave_number - 1, 0)

health_scale = 1.0 + level_offset * 0.20 + wave_offset * 0.12
damage_scale = 1.0 + level_offset * 0.12 + wave_offset * 0.08
speed_scale = min(1.0 + level_offset * 0.03 + wave_offset * 0.015, 1.35)
coin_scale = 1.0 + level_offset * 0.15 + wave_offset * 0.08
```

Level 2 example:

| Wave | HP Scale | Damage Scale | Speed Scale | Coin Scale |
|---|---:|---:|---:|---:|
| 1 | 120% | 112% | 103.0% | 115% |
| 2 | 132% | 120% | 104.5% | 123% |
| 3 | 144% | 128% | 106.0% | 131% |
| 4 | 156% | 136% | 107.5% | 139% |
| 5 | 168% | 144% | 109.0% | 147% |

Speed scaling is capped at `135%` so later waves get stronger without becoming unreadably fast.

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

### 🔮 Magic Tower
- Fires focused magic beams from the tower top
- Uses `magic.tres` with 3 upgrade levels
- Strong range-focused damage option
- Plays `magicLaser.mp3` when firing

### 💣 Bomb Tower
- Launches arcing bomb projectiles at enemies in range
- Attacks in short burst patterns with reload downtime
- Uses separate base, launcher, and projectile visuals
- Uses `bomb.tres` with 3 upgrade levels
- Plays launcher and impact SFX for clearer hit feedback

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
| Enemy | Role | HP | Speed | Attack Speed | Damage | Coin Drop | Path Spacing | Scale | Health Bar Color |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| Goblin | Fast swarm | 70 | 120 | 1.1 | 8 | 12 | 26 | 2.0 | `#1ABC9C` |
| Gnoll | Mid bruiser | 130 | 95 | 0.9 | 16 | 18 | 80 | 2.0 | `#F39C12` |
| Imp | Fast pressure | 95 | 104 | 0.75 | 14 | 16 | 42 | 2.5 | `#ED301F` |
| Mushroom | Sturdy early tank | 180 | 76 | 1.05 | 18 | 24 | 52 | 2.0 | `#D64B40` |
| Demon | Elite pressure | 220 | 82 | 0.8 | 24 | 28 | 52 | 2.0 | `#8E44AD` |
| Zombie | Slow durable walker | 230 | 54 | 1.25 | 22 | 28 | 65 | 2.6 | `#6AA641` |
| Predator | Durable mid-late bruiser | 260 | 58 | 1.15 | 27 | 34 | 70 | 2.65 | `#9CCA3F` |
| Lizardman | Heavy melee fighter | 280 | 72 | 0.9 | 28 | 34 | 62 | 2.3 | `#3FA954` |
| Beholder | Late heavy threat | 310 | 48 | 1.35 | 34 | 42 | 76 | 2.8 | `#B951EA` |
| Golem | Boss placeholder tank | 360 | 45 | 1.6 | 32 | 38 | 68 | 2.2 | `#3498DB` |

**Balance notes:**
- Goblins and imps create early speed pressure before the player has a full defence online
- Gnolls and mushrooms fill the middle of the roster with moderate durability and predictable melee pressure
- Zombies, predators, and lizardmen are sturdier mid-to-late enemies that test whether the player has enough sustained damage
- Demons and beholders are higher-threat enemies with stronger attacks and better rewards
- The golem is currently used as the final boss placeholder until a dedicated boss enemy is added

### Enemy Art Resources
| Enemy | Data Resource | SpriteFrames Resource |
|---|---|---|
| Goblin | `resources/enemies/goblin.tres` | `resources/enemies/goblin/GoblinFrames.tres` |
| Gnoll | `resources/enemies/gnoll.tres` | `resources/enemies/gnoll/GnollFrames.tres` |
| Imp | `resources/enemies/imp.tres` | `resources/enemies/imp/ImpFrames.tres` |
| Mushroom | `resources/enemies/mushroom.tres` | `resources/enemies/mushroom/MushroomFrames.tres` |
| Demon | `resources/enemies/demon.tres` | `resources/enemies/demon/DemonFrames.tres` |
| Zombie | `resources/enemies/zombie.tres` | `resources/enemies/zombie/ZombieFrames.tres` |
| Predator | `resources/enemies/predator.tres` | `resources/enemies/predator/PredatorFrames.tres` |
| Lizardman | `resources/enemies/lizardman.tres` | `resources/enemies/Lizardman/LizardmanFrames.tres` |
| Beholder | `resources/enemies/beholder.tres` | `resources/enemies/beholder/BeholderFrames.tres` |
| Golem | `resources/enemies/golem.tres` | `resources/enemies/golem/GolemFrames.tres` |

Directional sheets for the newer enemies use row order `down`, `up`, `left`, `right`. Their generated SpriteFrames resources expose the animation names expected by `enemy.gd`: `walkDown`, `walkUp`, `walkLeft`, `walkRight`, plus matching `attack`, `hurt`, and `die` variants.

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
│   │   ├── barrack/     # barrackTower.tscn, BarrackSoldier.tscn
│   │   ├── bomb/        # BombTower.tscn
│   │   └── magic/       # magicTower.tscn
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
- [ ] Better wave presentation / countdown UI
- [ ] Tower upgrade system
- [ ] Real boss enemy and boss encounter flow
- [ ] Level unlock progression


