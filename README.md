# 🏰 Castle Defence

A 2D pixel-art **castle defence** game built with **Godot 4.6**.  
Place towers along the enemy path, fight off waves, and protect your castle's HP from reaching zero.

---

## 🎮 How It Works

- Enemies spawn and follow a fixed **Path2D** toward your castle
- Place towers at designated spots alongside the path to stop them
- Each tower costs **400 coins** to place
- Enemies that reach the end of the path **damage the castle**
- **Game over** when the castle's HP hits zero
- Survive all **10 waves** to complete the level



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

- Walk along the path using Godot's `PathFollow2D`
- **Stop and fight** soldiers when in melee range
- Resume walking once all nearby soldiers are dead
- Show **floating red damage numbers** when hit
- Play a death animation before being freed
- Reaching the castle end → damages castle HP → **game over** when HP = 0

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
│   ├── levels/          # level_1.tscn, level1_path.tscn
│   ├── projectiles/     # arrow.tscn
│   ├── systems/tower/   # Tower builder UI popup
│   ├── towers/
│   │   ├── archer/      # archerTower.tscn
│   │   └── barrack/     # barrackTower.tscn, BarrackSoldier.tscn
│   └── ui/              # main_menu, level select, HUD, buttons
└── scripts/
    ├── autoload/        # music_player.gd
    ├── gameplay/        # enemy.gd, level_1_path.gd, damage_number.gd
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
- [ ] Enemy waves with increasing difficulty
- [ ] Tower upgrade system
- [ ] Coin earning on enemy kill
- [ ] Level unlock progression
