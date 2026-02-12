/// World — Unified facade for the ECS game engine.
/// Game contracts import only this module. It re-exports all system
/// operations behind pause-checked wrappers and tracks entity counts.
#[allow(lint(public_random))]
module world::world;

use std::ascii::String;
use sui::clock::Clock;
use sui::event;
use sui::random::Random;
use entity::entity::Entity;

// Systems
use systems::spawn_sys;
use systems::grid_sys::{Self, Grid};
use systems::turn_sys::{Self, TurnState};
use systems::win_condition_sys;
use systems::movement_sys;
use systems::swap_sys;
use systems::capture_sys;
use systems::objective_sys;
use systems::territory_sys;
use systems::combat_sys;
use systems::status_effect_sys;
use systems::energy_sys;
use systems::card_sys;
use systems::encounter_sys;
use systems::reward_sys;
use systems::shop_sys;
use systems::map_sys;
use systems::relic_sys;

// Components re-exported for convenience
use components::deck::CardData;
// Note: objective_sys and territory_sys operate on Entity objects
// (entities with Objective/Zone components attached), not raw component structs.

// ─── Error Constants ────────────────────────

const EWorldPaused: u64 = 0;
const EMaxEntities: u64 = 1;
const ENotCreator: u64 = 2;

// ─── Events ─────────────────────────────────

public struct WorldCreatedEvent has copy, drop {
    world_id: ID,
    name: String,
    creator: address,
}

public struct WorldPausedEvent has copy, drop {
    world_id: ID,
    paused: bool,
}

// ─── World Struct ───────────────────────────

/// The game world — central config and counter.
/// Shared object created once per game instance.
public struct World has key {
    id: UID,
    name: String,
    version: u64,
    creator: address,    // Game master — responsibilities defined in later phases
    paused: bool,
    entity_count: u64,
    max_entities: u64,
}

// ─── Internal Helpers ───────────────────────

fun assert_not_paused(world: &World) {
    assert!(!world.paused, EWorldPaused);
}

fun assert_creator(world: &World, ctx: &TxContext) {
    assert!(world.creator == ctx.sender(), ENotCreator);
}

fun increment_entity_count(world: &mut World) {
    world.entity_count = world.entity_count + 1;
    assert!(world.entity_count <= world.max_entities, EMaxEntities);
}

// ═══════════════════════════════════════════════
// ADMIN
// ═══════════════════════════════════════════════

/// Create a new game world and share it.
public fun create_world(
    name: String,
    max_entities: u64,
    ctx: &mut TxContext,
): World {
    let world = World {
        id: object::new(ctx),
        name,
        version: 1,
        creator: ctx.sender(),
        paused: false,
        entity_count: 0,
        max_entities,
    };

    event::emit(WorldCreatedEvent {
        world_id: object::id(&world),
        name: world.name,
        creator: world.creator,
    });

    world
}

/// Share the world as a shared object.
public fun share(world: World) {
    transfer::share_object(world);
}

/// Pause the world. Only the creator can pause.
public fun pause(world: &mut World, ctx: &TxContext) {
    assert_creator(world, ctx);
    world.paused = true;
    event::emit(WorldPausedEvent { world_id: object::id(world), paused: true });
}

/// Resume the world. Only the creator can resume.
public fun resume(world: &mut World, ctx: &TxContext) {
    assert_creator(world, ctx);
    world.paused = false;
    event::emit(WorldPausedEvent { world_id: object::id(world), paused: false });
}

// ─── World Getters ──────────────────────────

public fun name(world: &World): String { world.name }
public fun version(world: &World): u64 { world.version }
public fun creator(world: &World): address { world.creator }
public fun is_paused(world: &World): bool { world.paused }
public fun entity_count(world: &World): u64 { world.entity_count }
public fun max_entities(world: &World): u64 { world.max_entities }

// ═══════════════════════════════════════════════
// SPAWN WRAPPERS
// ═══════════════════════════════════════════════

/// Spawn a player entity.
public fun spawn_player(
    world: &mut World,
    name: String,
    x: u64, y: u64,
    max_hp: u64,
    team_id: u8,
    clock: &Clock,
    ctx: &mut TxContext,
): Entity {
    assert_not_paused(world);
    increment_entity_count(world);
    spawn_sys::spawn_player(name, x, y, max_hp, team_id, clock, ctx)
}

/// Spawn an NPC entity.
public fun spawn_npc(
    world: &mut World,
    name: String,
    x: u64, y: u64,
    max_hp: u64,
    atk_damage: u64,
    atk_range: u8,
    clock: &Clock,
    ctx: &mut TxContext,
): Entity {
    assert_not_paused(world);
    increment_entity_count(world);
    spawn_sys::spawn_npc(name, x, y, max_hp, atk_damage, atk_range, clock, ctx)
}

/// Spawn a tile entity.
public fun spawn_tile(
    world: &mut World,
    x: u64, y: u64,
    symbol: u8,
    clock: &Clock,
    ctx: &mut TxContext,
): Entity {
    assert_not_paused(world);
    increment_entity_count(world);
    spawn_sys::spawn_tile(x, y, symbol, clock, ctx)
}

// ═══════════════════════════════════════════════
// GRID WRAPPERS
// ═══════════════════════════════════════════════

/// Create a new grid.
public fun create_grid(
    world: &World,
    width: u64,
    height: u64,
    ctx: &mut TxContext,
): Grid {
    assert_not_paused(world);
    grid_sys::create_grid(width, height, ctx)
}

/// Share a grid as a shared object.
public fun share_grid(grid: Grid) {
    grid_sys::share(grid);
}

/// Place an entity on the grid.
public fun place(world: &World, grid: &mut Grid, entity_id: ID, x: u64, y: u64) {
    assert_not_paused(world);
    grid_sys::place(grid, entity_id, x, y);
}

/// Remove an entity from the grid.
public fun remove_from_grid(world: &World, grid: &mut Grid, x: u64, y: u64): ID {
    assert_not_paused(world);
    grid_sys::remove(grid, x, y)
}

// ═══════════════════════════════════════════════
// MOVEMENT WRAPPERS
// ═══════════════════════════════════════════════

/// Move an entity to a new position with validation.
public fun move_entity(
    world: &World,
    entity: &mut Entity,
    grid: &mut Grid,
    to_x: u64, to_y: u64,
) {
    assert_not_paused(world);
    movement_sys::move_entity(entity, grid, to_x, to_y);
}

/// Swap positions of two entities on a grid.
public fun swap(
    world: &World,
    e1: &mut Entity,
    e2: &mut Entity,
    grid: &mut Grid,
) {
    assert_not_paused(world);
    swap_sys::swap(e1, e2, grid);
}

/// Capture an entity, removing it from the grid.
public fun capture(
    world: &World,
    capturer: &Entity,
    target: &Entity,
    grid: &mut Grid,
) {
    assert_not_paused(world);
    capture_sys::capture(capturer, target, grid);
}

// ═══════════════════════════════════════════════
// TURN WRAPPERS
// ═══════════════════════════════════════════════

/// Create a turn state.
public fun create_turn_state(
    world: &World,
    player_count: u8,
    mode: u8,
    ctx: &mut TxContext,
): TurnState {
    assert_not_paused(world);
    turn_sys::create_turn_state(player_count, mode, ctx)
}

/// Share turn state as a shared object.
public fun share_turn_state(state: TurnState) {
    turn_sys::share(state);
}

/// End the current turn.
public fun end_turn(world: &World, state: &mut TurnState) {
    assert_not_paused(world);
    turn_sys::end_turn(state);
}

/// Advance to the next phase (phase mode only).
public fun advance_phase(world: &World, state: &mut TurnState) {
    assert_not_paused(world);
    turn_sys::advance_phase(state);
}

// ═══════════════════════════════════════════════
// COMBAT WRAPPERS
// ═══════════════════════════════════════════════

/// Attack a defender. Returns actual damage dealt.
public fun attack(
    world: &World,
    attacker: &Entity,
    defender: &mut Entity,
): u64 {
    assert_not_paused(world);
    combat_sys::attack(attacker, defender)
}

/// Apply a status effect to an entity.
public fun apply_effect(
    world: &World,
    entity: &mut Entity,
    effect_type: u8,
    stacks: u64,
    duration: u8,
) {
    assert_not_paused(world);
    status_effect_sys::apply_effect(entity, effect_type, stacks, duration);
}

/// Tick all status effects on an entity. Returns total damage dealt.
public fun tick_effects(world: &World, entity: &mut Entity): u64 {
    assert_not_paused(world);
    status_effect_sys::tick_effects(entity)
}

/// Remove expired status effects. Returns true if an effect was removed.
public fun remove_expired(world: &World, entity: &mut Entity): bool {
    assert_not_paused(world);
    status_effect_sys::remove_expired(entity)
}

// ═══════════════════════════════════════════════
// ENERGY WRAPPERS
// ═══════════════════════════════════════════════

/// Spend energy.
public fun spend_energy(world: &World, entity: &mut Entity, cost: u8) {
    assert_not_paused(world);
    energy_sys::spend_energy(entity, cost);
}

/// Regenerate energy.
public fun regenerate_energy(world: &World, entity: &mut Entity) {
    assert_not_paused(world);
    energy_sys::regenerate_energy(entity);
}

/// Check if entity has enough energy.
public fun has_enough_energy(world: &World, entity: &Entity, cost: u8): bool {
    assert_not_paused(world);
    energy_sys::has_enough_energy(entity, cost)
}

// ═══════════════════════════════════════════════
// CARD WRAPPERS
// ═══════════════════════════════════════════════

/// Draw cards from draw pile into hand.
public fun draw_cards(world: &World, entity: &mut Entity, count: u64): u64 {
    assert_not_paused(world);
    card_sys::draw_cards(entity, count)
}

/// Play a card from hand by index. Costs energy. Returns the played card.
public fun play_card(world: &World, entity: &mut Entity, hand_index: u64): CardData {
    assert_not_paused(world);
    card_sys::play_card(entity, hand_index)
}

/// Discard a card from hand by index.
public fun discard_card(world: &World, entity: &mut Entity, hand_index: u64) {
    assert_not_paused(world);
    card_sys::discard_card(entity, hand_index);
}

/// Shuffle deck: move discard into draw pile, randomize.
public fun shuffle_deck(
    world: &World,
    entity: &mut Entity,
    r: &Random,
    ctx: &mut TxContext,
) {
    assert_not_paused(world);
    card_sys::shuffle_deck(entity, r, ctx);
}

// ═══════════════════════════════════════════════
// ENCOUNTER WRAPPERS
// ═══════════════════════════════════════════════

/// Generate a floor encounter with scaled enemies.
public fun generate_encounter(
    world: &mut World,
    floor: u8,
    enemy_count: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): vector<Entity> {
    assert_not_paused(world);
    // Each enemy counts as an entity
    let mut i = 0;
    while (i < enemy_count) {
        increment_entity_count(world);
        i = i + 1;
    };
    encounter_sys::generate_encounter(floor, enemy_count, clock, ctx)
}

// ═══════════════════════════════════════════════
// REWARD WRAPPERS
// ═══════════════════════════════════════════════

/// Grant gold reward to an entity.
public fun grant_gold(world: &World, entity: &mut Entity, amount: u64) {
    assert_not_paused(world);
    reward_sys::grant_gold(entity, amount);
}

/// Grant a card reward.
public fun grant_card(world: &World, entity: &mut Entity, card: CardData) {
    assert_not_paused(world);
    reward_sys::grant_card(entity, card);
}

/// Grant a relic reward.
public fun grant_relic(
    world: &World,
    entity: &mut Entity,
    relic_type: u8,
    modifier_value: u64,
) {
    assert_not_paused(world);
    reward_sys::grant_relic(entity, relic_type, modifier_value);
}

// ═══════════════════════════════════════════════
// SHOP WRAPPERS
// ═══════════════════════════════════════════════

/// Buy a card from the shop.
public fun buy_card(world: &World, entity: &mut Entity, card: CardData, cost: u64) {
    assert_not_paused(world);
    shop_sys::buy_card(entity, card, cost);
}

/// Buy a relic from the shop.
public fun buy_relic(
    world: &World,
    entity: &mut Entity,
    relic_type: u8,
    modifier_value: u64,
    cost: u64,
) {
    assert_not_paused(world);
    shop_sys::buy_relic(entity, relic_type, modifier_value, cost);
}

/// Remove a card from draw pile (pay gold to thin deck).
public fun remove_card(world: &World, entity: &mut Entity, draw_pile_index: u64, cost: u64) {
    assert_not_paused(world);
    shop_sys::remove_card(entity, draw_pile_index, cost);
}

// ═══════════════════════════════════════════════
// MAP WRAPPERS
// ═══════════════════════════════════════════════

/// Choose a path node on the current floor.
public fun choose_path(world: &World, entity: &mut Entity, node: u8) {
    assert_not_paused(world);
    map_sys::choose_path(entity, node);
}

/// Advance to the next floor.
public fun advance_floor(world: &World, entity: &mut Entity) {
    assert_not_paused(world);
    map_sys::advance_floor(entity);
}

/// Get current floor.
public fun current_floor(entity: &Entity): u8 {
    map_sys::current_floor(entity)
}

/// Get current node.
public fun current_node(entity: &Entity): u8 {
    map_sys::current_node(entity)
}

// ═══════════════════════════════════════════════
// RELIC WRAPPERS
// ═══════════════════════════════════════════════

/// Add a relic to an entity.
public fun add_relic(
    world: &World,
    entity: &mut Entity,
    relic_type: u8,
    modifier_type: u8,
    modifier_value: u64,
) {
    assert_not_paused(world);
    relic_sys::add_relic(entity, relic_type, modifier_type, modifier_value);
}

/// Apply relic passive bonus. Returns the bonus value applied.
public fun apply_relic_bonus(world: &World, entity: &mut Entity): u64 {
    assert_not_paused(world);
    relic_sys::apply_relic_bonus(entity)
}

/// Remove the relic from an entity.
public fun remove_relic(world: &World, entity: &mut Entity) {
    assert_not_paused(world);
    relic_sys::remove_relic(entity);
}

// ═══════════════════════════════════════════════
// WIN CONDITION WRAPPERS
// ═══════════════════════════════════════════════

/// Check if an entity has been eliminated.
public fun check_elimination(entity: &Entity): bool {
    win_condition_sys::check_elimination(entity)
}

/// Declare a winner. Emits GameOverEvent.
public fun declare_winner(
    world: &World,
    winner_id: ID,
    condition: u8,
    clock: &Clock,
) {
    assert_not_paused(world);
    win_condition_sys::declare_winner(winner_id, condition, clock);
}

// ═══════════════════════════════════════════════
// OBJECTIVE WRAPPERS
// ═══════════════════════════════════════════════

/// Pick up an objective (flag_entity is an Entity with Objective component).
public fun pick_up(world: &World, carrier: &mut Entity, flag_entity: &mut Entity) {
    assert_not_paused(world);
    objective_sys::pick_up(carrier, flag_entity);
}

/// Drop an objective.
public fun drop_flag(world: &World, carrier: &mut Entity, flag_entity: &mut Entity) {
    assert_not_paused(world);
    objective_sys::drop_flag(carrier, flag_entity);
}

/// Score an objective.
public fun score(world: &World, carrier: &mut Entity, flag_entity: &mut Entity, team: u8) {
    assert_not_paused(world);
    objective_sys::score(carrier, flag_entity, team);
}

// ═══════════════════════════════════════════════
// TERRITORY WRAPPERS
// ═══════════════════════════════════════════════

/// Claim a zone (zone_entity is an Entity with Zone component).
public fun claim(world: &World, entity: &Entity, zone_entity: &mut Entity) {
    assert_not_paused(world);
    territory_sys::claim(entity, zone_entity);
}

/// Contest a zone. Adds capture progress.
public fun contest(world: &World, entity: &Entity, zone_entity: &mut Entity, amount: u64) {
    assert_not_paused(world);
    territory_sys::contest(entity, zone_entity, amount);
}

/// Capture a zone for a team.
public fun capture_zone(world: &World, zone_entity: &mut Entity, team: u8) {
    assert_not_paused(world);
    territory_sys::capture_zone(zone_entity, team);
}

// ═══════════════════════════════════════════════
// RE-EXPORTED CONSTANTS
// ═══════════════════════════════════════════════

// Turn modes
public fun mode_simple(): u8 { turn_sys::mode_simple() }
public fun mode_phase(): u8 { turn_sys::mode_phase() }

// Turn phases
public fun phase_draw(): u8 { turn_sys::phase_draw() }
public fun phase_play(): u8 { turn_sys::phase_play() }
public fun phase_combat(): u8 { turn_sys::phase_combat() }
public fun phase_end(): u8 { turn_sys::phase_end() }

// Win conditions
public fun condition_elimination(): u8 { win_condition_sys::condition_elimination() }
public fun condition_board_full(): u8 { win_condition_sys::condition_board_full() }
public fun condition_objective(): u8 { win_condition_sys::condition_objective() }
public fun condition_surrender(): u8 { win_condition_sys::condition_surrender() }
public fun condition_timeout(): u8 { win_condition_sys::condition_timeout() }
public fun condition_custom(): u8 { win_condition_sys::condition_custom() }

// ─── Cleanup ────────────────────────────────

/// Destroy the world. Only creator can do this.
public fun destroy(world: World, ctx: &TxContext) {
    assert_creator(&world, ctx);
    let World { id, .. } = world;
    id.delete();
}

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun create_for_testing(
    name: String,
    max_entities: u64,
    ctx: &mut TxContext,
): World {
    create_world(name, max_entities, ctx)
}
