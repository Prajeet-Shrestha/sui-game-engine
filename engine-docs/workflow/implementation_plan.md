# Sui On-Chain ECS Game Engine — Development Workflow

## Overview

Build the fully on-chain ECS game engine described in [ARCHITECTURE.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/engine-docs/ARCHITECTURE.md) using the 4 skills in [sui-move-skills](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills). Full component and system inventory in [components_and_systems.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/engine-docs/workflow/components_and_systems.md).

## Design Decisions

| Decision | Choice |
|----------|--------|
| **Package root** | Flat under `engine/` |
| **Component packaging** | Single `components/` package, multiple source files |
| **World module** | Deferred |
| **Events** | Colocated with their modules (entity events in entity, system events in each system) |
| **StatusEffect** | Single component with `effect_type: u8` enum |
| **Cards** | Inline `CardData` inside Deck (`vector<CardData>`) |
| **Randomness** | Use `sui::random` directly (no wrapper) |
| **Turn system** | Dual mode: simple counter + opt-in phase system |

## Directory Structure

```
engine/
├── entity/                        # Phase 1: Core primitive
│   ├── sources/entity.move
│   ├── tests/entity_tests.move
│   └── Move.toml
│
├── components/                    # Phase 2: ALL components in one package
│   ├── sources/
│   │   ├── position.move          # Tier 1
│   │   ├── identity.move
│   │   ├── health.move
│   │   ├── marker.move
│   │   ├── movement.move          # Tier 2
│   │   ├── defense.move
│   │   ├── team.move
│   │   ├── zone.move
│   │   ├── objective.move
│   │   ├── attack.move            # Tier 3
│   │   ├── energy.move
│   │   ├── status_effect.move
│   │   ├── stats.move
│   │   ├── deck.move              # Tier 4 (includes CardData inline)
│   │   ├── inventory.move
│   │   ├── relic.move
│   │   ├── gold.move
│   │   └── map_progress.move
│   ├── tests/components_tests.move
│   └── Move.toml                  # depends on entity
│
├── systems/                       # Phase 3: Each system is its own package
│   ├── spawn_sys/                 # Core
│   │   ├── sources/{entry,helpers,events}.move
│   │   └── Move.toml
│   ├── grid_sys/
│   │   ├── sources/{entry,helpers,events}.move
│   │   └── Move.toml
│   ├── turn_sys/
│   │   ├── sources/{entry,helpers,events}.move
│   │   └── Move.toml
│   ├── win_condition_sys/
│   │   ├── sources/{entry,helpers,events}.move
│   │   └── Move.toml
│   ├── movement_sys/              # Board/Strategy
│   │   └── ...
│   ├── swap_sys/
│   │   └── ...
│   ├── capture_sys/
│   │   └── ...
│   ├── objective_sys/
│   │   └── ...
│   ├── territory_sys/
│   │   └── ...
│   ├── combat_sys/                # Combat
│   │   └── ...
│   ├── status_effect_sys/
│   │   └── ...
│   ├── energy_sys/
│   │   └── ...
│   ├── card_sys/                  # Roguelike
│   │   └── ...
│   ├── encounter_sys/
│   │   └── ...
│   ├── reward_sys/
│   │   └── ...
│   ├── shop_sys/
│   │   └── ...
│   ├── map_sys/
│   │   └── ...
│   └── relic_sys/
│       └── ...
│
└── examples/                      # Phase 4: Proof game
    └── turn_based_pvp/
        ├── sources/turn_based_pvp.move
        └── Move.toml
```

---

## Skill Usage

| Skill | Role | When |
|-------|------|------|
| **game_engine** | Architecture & conventions | Before writing any module |
| **sui_move_patterns** | Design decisions | When making choices |
| **sui_framework** | Exact API signatures | While writing code |
| **sui_engineering** | Limits, errors, testing | Before commit / review |

---

## Implementation Phases

### Phase 1: Entity Package

**Output**: `engine/entity/`

| Step | Read First |
|------|-----------|
| Design Entity struct | [entity_reference.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/game_engine/references/entity_reference.md) |
| Abilities & ownership model | [object_model.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/sui_move_patterns/references/object_model.md), [abilities_and_generics.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/sui_move_patterns/references/abilities_and_generics.md) |
| Dynamic field operations | [storage_modules.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/sui_framework/references/storage_modules.md) |
| Move.toml setup | [project_setup.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/game_engine/references/project_setup.md) |
| Entity events | [events_reference.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/game_engine/references/events_reference.md) |
| Unit tests | [testing_reference.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/game_engine/references/testing_reference.md) |

**Verify**: `cd engine/entity && sui move test`

---

### Phase 2: Components Package (All 18 components)

**Output**: `engine/components/`

| Step | Read First |
|------|-----------|
| Component convention | [component_reference.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/game_engine/references/component_reference.md) |
| Example template | [simple_component.move](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/game_engine/examples/simple_component.move) |
| Abilities choice | [abilities_and_generics.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/sui_move_patterns/references/abilities_and_generics.md) |

**Components** (all built in one pass):
- **Tier 1**: Position, Identity, Health, Marker
- **Tier 2**: Movement, Defense, Team, Zone, Objective
- **Tier 3**: Attack, Energy, StatusEffect, Stats
- **Tier 4**: Deck (with CardData inline), Inventory, Relic, Gold, MapProgress

**Verify**: `cd engine/components && sui move test`

---

### Phase 3: Systems (All 18 systems)

**Output**: `engine/systems/*/`

| Step | Read First |
|------|-----------|
| System convention (entry/helpers/events) | [system_reference.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/game_engine/references/system_reference.md) |
| System template | [system_template/](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/game_engine/examples/system_template/) |
| Visibility rules | [upgradeability.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/sui_engineering/references/upgradeability.md) |
| Event patterns | [events_reference.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/game_engine/references/events_reference.md) + [game_modules.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/sui_framework/references/game_modules.md) |
| Error conventions | [error_handling.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/sui_engineering/references/error_handling.md) |
| Collections (grid, maps) | [collections.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/sui_move_patterns/references/collections.md), [collections_modules.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/sui_framework/references/collections_modules.md) |
| Gas limits | [gas_and_limits.md](file:///Users/ps/Documents/ibriz/git/game-engine/.agent/skills/sui-move-skills/sui_engineering/references/gas_and_limits.md) |

**Systems** (all built in one pass):
- **Core**: spawn_sys, grid_sys, turn_sys, win_condition_sys
- **Board/Strategy**: movement_sys, swap_sys, capture_sys, objective_sys, territory_sys
- **Combat**: combat_sys, status_effect_sys, energy_sys
- **Roguelike**: card_sys, encounter_sys, reward_sys, shop_sys, map_sys, relic_sys

**Verify**: `cd engine/systems/<sys> && sui move test` for each

---

### Phase 4: Example Game (Turn-Based PvP)

**Output**: `engine/examples/turn_based_pvp/`

All 4 skills combined — integration test for the engine.

**Verify**: `sui move test` + optionally `sui client publish` to devnet

---

## Cheatsheet

```
BEFORE WRITING → game_engine reference file
WHILE WRITING  → sui_framework exact signatures
DESIGN CHOICE  → sui_move_patterns decision matrix
BEFORE COMMIT  → sui_engineering limits & errors
TESTING        → game_engine + sui_engineering test helpers
```
