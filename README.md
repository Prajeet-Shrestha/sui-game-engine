# Sui On-Chain Game Engine

An ECS (Entity-Component-System) game engine written in [Sui](https://sui.io/) Move. Games import the engine's pre-built systems and components, compose them into game-specific logic, and deploy as standalone packages.

Currently deployed on Sui Testnet — see [Deployed Addresses](#deployed-addresses).

---

## Architecture

```
                   ┌─────────────────┐
 Game Contract ──▶ │      World      │  ← pause control + entity counting
                   │    (facade)     │
                   └────────┬────────┘
                            │ delegates to
              ┌─────────────┼──────────────┐
              ▼             ▼              ▼
          systems       components      entity
        (18 modules)   (18 modules)    (core ECS)
```

4 Move packages, deployed in dependency order:

| # | Package | Description |
|---|---------|-------------|
| 1 | **entity** | Core ECS primitive — `Entity` struct with u256 bitmask for O(1) component checks |
| 2 | **components** | 18 pure-data component modules (Position, Health, Attack, Deck, Gold, …) |
| 3 | **systems** | 18 stateless logic modules (combat, movement, turns, cards, shops, …) |
| 4 | **world** | Facade — wraps all systems with pause control and entity counting |

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| `component_mask: u256` | O(1) "has component?" checks — no dynamic field lookup needed |
| Dynamic fields for storage | Sui-native object model — components attach to entities as dynamic fields |
| World as facade | Single import for game devs, built-in pause/resume and entity caps |
| Stateless systems | Pure function modules — no stored state, easy to compose and test |

---

## Quick Start

### Prerequisites

| Requirement | Version |
|-------------|---------|
| [Sui CLI](https://docs.sui.io/guides/developer/getting-started/sui-install) | ≥ 1.0 |
| Sui Move | Knowledge of structs, abilities, generics |

### Using the Engine in Your Game

Add the `world` package as a dependency in your game's `Move.toml`:

```toml
[dependencies]
world = { git = "https://github.com/<org>/game-engine.git", subdir = "engine/world", rev = "main" }
```

### Deployment

1. Copy `.env.example` → `.env` and fill in your mnemonic:
   ```bash
   cp .env.example .env
   ```

2. Run the deploy script:
   ```bash
   ./deploy.sh
   ```

   This builds and publishes all 4 packages in dependency order, writes the resulting package IDs to `package.ts`.


## Deployed Addresses

> **Network:** Sui Testnet

| Package | Address |
|---------|---------|
| entity | `0x5027c19c807223b4b91e8f70b694c5b37118d5ea727d982820b837b54697d7f4` |
| components | `0x56056e084dec3522b3b069577bf1409a0927778401ce5534bfe2efba48eae3b4` |
| systems | `0x63c83d51f8bd8e07e165df2beab847ac8d5d19f28bc58bbdc6fc47172648f204` |
| world | `0xaa168c61e541e29f3ba20fe13c5a27f13fb8858fb11373167012e132fbc64401` |

---

## Testing

Run tests for each package:

```bash
# Test all packages
sui move test --path entity
sui move test --path components
sui move test --path systems
sui move test --path world
```

---

## Documentation

Detailed API references are in [`engine-docs/`](engine-docs/):

- [Entity API](engine-docs/entity.md) — lifecycle, bitmask, component operations
- [Components Catalog](engine-docs/components.md) — all 18 components with full signatures
- [Systems Catalog](engine-docs/systems.md) — all 18 systems with signatures and descriptions
- [World Facade](engine-docs/world.md) — admin API, all wrapper functions, re-exported constants

---
