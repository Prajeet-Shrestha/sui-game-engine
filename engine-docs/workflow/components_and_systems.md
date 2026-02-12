# Components & Systems Design — Game Scope Analysis

This document maps out what components and systems the engine needs to support games ranging from **tic-tac-toe** to **Slay the Spire-like roguelikes**.

---

## Target Game Spectrum

| Tier | Example Games | Complexity |
|------|--------------|------------|
| **Tier 1: Simple Board** | Tic-tac-toe, Connect-4 | Grid + markers + win condition |
| **Tier 2: Strategy Board** | Chess, Checkers | Grid + typed pieces + movement rules + capture |
| **Tier 2.5: Strategy** | Capture the Flag, King of the Hill, Territory Control | Zones + objectives + territory claiming |
| **Tier 3: Turn-Based Combat** | Auto-battler, monster tamer | Health + attack + status effects + turns |
| **Tier 4: Roguelike** | Slay the Spire-like | Cards + deck + map + encounters + relics + shops |

---

## Components (Data Structs)

### Tier 1 — Core (needed by almost every game)

| Component | Fields | Used By |
|-----------|--------|---------|
| **Position** | `x: u64, y: u64` | Any spatial game |
| **Identity** | `name: String, entity_type: u8` | Every game (what is this entity?) |
| **Health** | `current: u64, max: u64` | Combat, survival |
| **Marker** | `symbol: u8` (e.g. X=1, O=2) | Board games (tic-tac-toe, connect-4) |

### Tier 2 — Movement & Board

| Component | Fields | Used By |
|-----------|--------|---------|
| **Movement** | `speed: u8, move_pattern: u8` | Chess (piece rules), strategy |
| **Defense** | `armor: u64, block: u64` | Combat, roguelike |
| **Team** | `team_id: u8` | PvP, auto-battler |
| **Zone** | `zone_type: u8, controlled_by: u8, capture_progress: u64` | King of the Hill, Territory Control |
| **Objective** | `objective_type: u8, holder: Option<ID>, origin: Position` | Capture the Flag |

### Tier 3 — Combat & Status

| Component | Fields | Used By |
|-----------|--------|---------|
| **Attack** | `damage: u64, range: u8, cooldown_ms: u64` | Combat, roguelike |
| **Energy** | `current: u8, max: u8, regen: u8` | Turn-limited actions (Slay the Spire mana) |
| **StatusEffect** | `effect_type: u8, stacks: u64, duration: u8` | Poison, strength, weakness, etc. |
| **Stats** | `strength: u64, dexterity: u64, luck: u64` | RPG-like stat modifiers |

### Tier 4 — Roguelike / Deck-building

| Component | Fields | Used By |
|-----------|--------|---------|
| **Deck** | `draw_pile: vector<CardData>, hand: vector<CardData>, discard: vector<CardData>` | Card games, Slay the Spire |
| **CardData** | `name: String, cost: u8, card_type: u8, effect_type: u8, value: u64` | Inline struct inside Deck (not a separate entity) |
| **Inventory** | `items: vector<RelicData>, capacity: u64` | Roguelike relics, survival items |
| **Relic** | `relic_type: u8, modifier_type: u8, modifier_value: u64` | Passive bonuses (roguelike) |
| **Gold** | `amount: u64` | In-game currency for shops |
| **MapProgress** | `current_floor: u8, current_node: u8, path_chosen: vector<u8>` | Roguelike map progression |

---

## Systems (Stateless Logic Modules)

### Tier 1 — Core Systems

| System | What It Does | Components Required |
|--------|-------------|-------------------|
| **spawn_sys** | Create entities with initial components | Identity |
| **grid_sys** | Place/remove/query entities on a grid | Position |
| **turn_sys** | Manage turn order, validate whose turn | Identity, Team |
| **win_condition_sys** | Check win/loss/draw | Game-specific (configurable) |

### Tier 2 — Movement & Board

| System | What It Does | Components Required |
|--------|-------------|-------------------|
| **movement_sys** | Move entities with rule validation | Position, Movement |
| **swap_sys** | Swap positions of two entities | Position |
| **capture_sys** | Remove captured pieces | Position, Health or Marker |
| **objective_sys** | Pick up / drop / score flags and objectives | Position, Objective, Team |
| **territory_sys** | Claim / contest / capture zones over turns | Position, Zone, Team |

### Tier 3 — Combat

| System | What It Does | Components Required |
|--------|-------------|-------------------|
| **combat_sys** | Deal damage, check range, apply kills | Attack, Health, Position, Defense |
| **status_effect_sys** | Apply/tick/expire effects each turn | StatusEffect, Health, Stats |
| **energy_sys** | Spend/regenerate energy per turn | Energy |

### Tier 4 — Roguelike / Deck-building

| System | What It Does | Components Required |
|--------|-------------|-------------------|
| **card_sys** | Draw, play, discard, shuffle cards | Deck, Card, Energy |
| **encounter_sys** | Generate enemy encounters per floor | Identity, Health, Attack, MapProgress |
| **reward_sys** | Distribute loot after combat | Gold, Inventory, Card |
| **shop_sys** | Buy/sell items and cards | Gold, Inventory, Card |
| **map_sys** | Generate procedural map, track progress | MapProgress |
| **relic_sys** | Apply passive relic effects | Relic, Stats, Health |

---

## What Each Game Needs

### Tic-Tac-Toe (Tier 1)
```
Components: Position, Marker
Systems:    grid_sys, turn_sys, win_condition_sys, spawn_sys
```

### Chess (Tier 2)
```
Components: Position, Movement, Identity, Team
Systems:    grid_sys, movement_sys, capture_sys, turn_sys, win_condition_sys, spawn_sys
```

### Capture the Flag (Tier 2.5)
```
Components: Position, Movement, Team, Identity, Objective, Health
Systems:    grid_sys, movement_sys, objective_sys, turn_sys, win_condition_sys, spawn_sys
```

### King of the Hill (Tier 2.5)
```
Components: Position, Movement, Team, Identity, Zone, Health
Systems:    grid_sys, movement_sys, territory_sys, combat_sys, turn_sys, win_condition_sys, spawn_sys
```

### Territory Control (Tier 2.5)
```
Components: Position, Movement, Team, Identity, Zone
Systems:    grid_sys, movement_sys, territory_sys, turn_sys, win_condition_sys, spawn_sys
```

### Auto-Battler (Tier 3)
```
Components: Position, Health, Attack, Defense, Stats, StatusEffect, Team
Systems:    grid_sys, combat_sys, status_effect_sys, spawn_sys, win_condition_sys
```

### Slay the Spire-like Roguelike (Tier 4)
```
Components: Health, Attack, Defense, Energy, Stats, StatusEffect,
            Deck, Card, Inventory, Relic, Gold, MapProgress, Identity
Systems:    combat_sys, card_sys, status_effect_sys, energy_sys,
            encounter_sys, reward_sys, shop_sys, map_sys, relic_sys,
            spawn_sys, win_condition_sys
```

---

## Design Decisions (Resolved)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Build order** | All components at once, then all systems | Not tier-wise — build everything in Entity → Components → Systems order |
| **StatusEffect** | Single component with `effect_type: u8` enum | Simpler, one struct handles Poison, Strength, Weakness, etc. |
| **Cards** | Inline `CardData` inside Deck (`vector<CardData>`) | Cheaper gas, simpler than separate Card entities |
| **Randomness** | Use `sui::random` directly in each system | No wrapper — systems use framework randomness directly |
| **Turn system** | Dual mode: simple counter + opt-in phase system | Simple by default (P1→P2), phase-based (Draw→Play→Combat→End) for complex games |
