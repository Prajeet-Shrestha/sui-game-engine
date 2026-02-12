# Game Engine — Task Flow

> Track progress across all phases. Mark items `[/]` when in-progress, `[x]` when done.

---

## Phase 0: Setup
- [x] Verify `sui --version` works (1.65.2)
- [x] Verify `sui move build` works
- [x] Create `engine/` root directory structure

---

## Phase 1: Entity Package (`engine/entity/`) ✅

### Research (read skill references first)
- [x] Read [entity_reference.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/game_engine/references/entity_reference.md)
- [x] Read [object_model.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/sui_move_patterns/references/object_model.md)
- [x] Read [abilities_and_generics.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/sui_move_patterns/references/abilities_and_generics.md)
- [x] Read [storage_modules.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/sui_framework/references/storage_modules.md)
- [x] Read [project_setup.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/game_engine/references/project_setup.md)

### Implementation
- [x] Create `engine/entity/Move.toml`
- [x] Create `engine/entity/sources/entity.move`
  - [x] Entity struct (`key` + UID, type, created_at, component_mask)
  - [x] `new()` constructor
  - [x] `add_component<T>()` — dynamic field add + bitmask update
  - [x] `has_component()` — O(1) bitmask check
  - [x] `borrow_component<T>()` — read component
  - [x] `borrow_mut_component<T>()` — write component
  - [x] `remove_component<T>()` — remove + bitmask clear
  - [x] Entity type constants (PLAYER, NPC, ITEM, TILE, GRID, PROJECTILE)
  - [x] Component bit constants (18 bits)
  - [x] Event structs (EntityCreated, EntityDestroyed)
  - [x] `new_for_testing()` test helper

### Verify
- [x] `sui move build` passes (zero warnings)
- [x] `sui move test` passes (11/11)
- [x] All entity operations covered by unit tests

---

## Phase 2: Components Package (`engine/components/`) ✅

### Research
- [x] Read [component_reference.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/game_engine/references/component_reference.md)
- [x] Read [simple_component.move](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/game_engine/examples/simple_component.move) template
- [x] Read [component_with_config.move](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/game_engine/examples/component_with_config.move)

### Implementation — Move.toml + shared types
- [x] Create `engine/components/Move.toml` (depends on `entity`)
- [x] Component keys defined per-module via `key()` function (no shared types file needed)

### Tier 1 — Core Components
- [x] `position.move` — Position { x, y } + key + constructor + add + borrow + borrow_mut + getters/setters
- [x] `identity.move` — Identity { name, entity_type } + standard API
- [x] `health.move` — Health { current, max } + standard API
- [x] `marker.move` — Marker { symbol } + standard API

### Tier 2 — Movement & Strategy
- [x] `movement.move` — Movement { speed, move_pattern }
- [x] `defense.move` — Defense { armor, block }
- [x] `team.move` — Team { team_id }
- [x] `zone.move` — Zone { zone_type, controlled_by, capture_progress }
- [x] `objective.move` — Objective { objective_type, holder, origin }

### Tier 3 — Combat & Status
- [x] `attack.move` — Attack { damage, range, cooldown_ms }
- [x] `energy.move` — Energy { current, max, regen }
- [x] `status_effect.move` — StatusEffect { effect_type, stacks, duration }
- [x] `stats.move` — Stats { strength, dexterity, luck }

### Tier 4 — Roguelike / Deck-building
- [x] `deck.move` — Deck { draw_pile, hand, discard } with CardData inline struct
- [x] `inventory.move` — Inventory { items, capacity } with ItemData inline struct
- [x] `relic.move` — Relic { relic_type, modifier_type, modifier_value }
- [x] `gold.move` — Gold { amount }
- [x] `map_progress.move` — MapProgress { current_floor, current_node, path_chosen }

### Verify
- [x] `sui move build` passes (zero warnings)
- [x] `sui move test` passes (19/19)
- [x] Each component follows convention: struct → key → constructor → add → borrow → borrow_mut → getters → setters

---

## Phase 3: Systems (`engine/systems/`) ✅

> Single package with all 18 systems. No cross-system imports, no shared helpers, inline utilities.

### Design Decisions
- [x] Single `engine/systems/` package (not 18 separate packages)
- [x] Each system = one `.move` module (events inlined, no separate helpers)
- [x] Systems only import `entity` + `components` — never other systems
- [x] `encounter_sys` creates entities directly via `entity::new()`, not `spawn_sys`
- [x] Added `remove_from_draw_pile()` and `shuffle_draw_pile()` to `deck` component

### Pass 1: Core + Board Systems
- [x] `Move.toml` (depends on `entity` + `components`, Sui `override = true`)
- [x] **spawn_sys** — Player/NPC/tile factories with component attachment
- [x] **grid_sys** — 2D grid (Table-backed cells, `occupied_count` for O(1) fullness)
- [x] **turn_sys** — Dual-mode: simple counter + phase-based (Draw→Play→Combat→End)
- [x] **win_condition_sys** — Generic `declare_winner()` emitter + `check_elimination()`
- [x] **movement_sys** — Validate bounds, speed, pattern; update grid + position
- [x] **swap_sys** — Swap positions of two entities on grid
- [x] **capture_sys** — Remove captured entity from grid
- [x] **objective_sys** — Flag `pick_up()`, `drop_flag()`, `score()`
- [x] **territory_sys** — Zone `claim()`, `contest()`, `capture_zone()`
- [x] `core_tests.move` — 17/17 pass

### Pass 2: Combat + Roguelike Systems
- [x] **combat_sys** — Damage pipeline: range check → defense reduction → HP damage → death
- [x] **status_effect_sys** — `apply_effect()`, `tick_effects()` (poison/regen), `remove_expired()`
- [x] **energy_sys** — `spend_energy()`, `regenerate_energy()`, `has_enough_energy()`
- [x] **card_sys** — `draw_cards()`, `play_card()` (energy cost), `shuffle_deck()` (Fisher-Yates)
- [x] **encounter_sys** — Floor-scaled enemy generation (HP/damage scales with floor)
- [x] **reward_sys** — `grant_gold()`, `grant_card()`, `grant_relic()`
- [x] **shop_sys** — `buy_card()`, `buy_relic()`, `remove_card()` (gold deduction)
- [x] **map_sys** — `choose_path()`, `advance_floor()`, floor/node tracking
- [x] **relic_sys** — `add_relic()`, `apply_relic_bonus()` (flat + percent modifiers)
- [x] `advanced_tests.move` — 17/17 pass

### Phase 3 Final Verify
- [x] `sui move build` — all 18 systems compile ✅
- [x] `sui move test` — **34/34 tests pass** ✅

---

## Phase 4: Example Game (`engine/examples/turn_based_pvp/`)

### Implementation
- [ ] Create `Move.toml` (depends on systems)
- [ ] Create `turn_based_pvp.move`
  - [ ] GameSession struct (shared object)
  - [ ] `create_game()` — spawn players, create grid, place entities
  - [ ] `join_game()` — P2 joins
  - [ ] `player_move()` — movement via movement_sys
  - [ ] `player_attack()` — combat via combat_sys
  - [ ] `end_turn()` — turn management via turn_sys
  - [ ] Win condition check via win_condition_sys
- [ ] Unit tests covering full game flow

### Verify
- [ ] `sui move build` passes
- [ ] `sui move test` — full game flow test passes
- [ ] Optionally: `sui client publish` to devnet

---

## Post-Build
- [ ] Create walkthrough documenting what was built and tested
- [ ] Verify all packages compile together
- [ ] Review AI-friendliness: can an AI read skills + example and produce a new game?
