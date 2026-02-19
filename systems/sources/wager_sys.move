/// WagerSystem — Escrow, settlement, and refund logic for on-chain wagers.
///
/// All settlement and refund operations require a `SettlementCap`, which is
/// created once per pool and bound to it via `pool_id`. Only the game contract
/// that holds the cap can settle or refund — preventing unauthorized fund access.
module systems::wager_sys;

use std::ascii;
use sui::event;
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::clock::Clock;
use entity::entity::{Self, Entity};
use components::wager;
use components::wager_pool;

// ─── Error Constants ────────────────────────

const ECapPoolMismatch: u64       = 0;
const ENotPoolEntity: u64         = 1;
const ENotPlayerEntity: u64       = 2;
const EAlreadySettled: u64        = 3;
const EWagerAmountMismatch: u64   = 4;
const EPoolFull: u64              = 5;
const EAlreadyWagered: u64        = 6;
const EWagerNotPending: u64       = 7;
const EWagerNotLocked: u64        = 8;
const ETimeoutNotExpired: u64     = 9;
const ESharesSumInvalid: u64      = 10;

// ─── Capability ─────────────────────────────

/// Created once per pool. Only the holder can settle or refund.
public struct SettlementCap has key, store {
    id: UID,
    pool_id: ID,  // bound to exactly one WagerPool entity
}

// ─── Events ─────────────────────────────────

public struct WagerPlacedEvent has copy, drop {
    pool_id: ID,
    player_entity_id: ID,
    player: address,
    amount: u64,
    player_count: u8,
}

public struct WagerSettledEvent has copy, drop {
    pool_id: ID,
    winner_entity_id: ID,
    winner: address,
    payout: u64,
    fee: u64,
    fee_recipient: address,
}

public struct WagerRefundedEvent has copy, drop {
    pool_id: ID,
    player_entity_id: ID,
    player: address,
    amount: u64,
}

public struct WagerLostEvent has copy, drop {
    pool_id: ID,
    player_entity_id: ID,
    player: address,
    amount_lost: u64,
}

// ─── Internal Assertions ────────────────────

fun assert_cap_matches(cap: &SettlementCap, pool_entity: &Entity) {
    assert!(cap.pool_id == object::id(pool_entity), ECapPoolMismatch);
}

fun assert_pool_entity(entity: &Entity) {
    assert!(entity.has_component(entity::wager_pool_bit()), ENotPoolEntity);
}

fun assert_player_entity(entity: &Entity) {
    assert!(entity.has_component(entity::wager_bit()), ENotPlayerEntity);
}

// ─── Pool Lifecycle ─────────────────────────

/// Create a wager pool entity and its bound SettlementCap.
/// Returns `(pool_entity, cap)` — caller stores both.
public fun create_pool(
    wager_amount: u64,
    max_players: u8,
    protocol_fee_bps: u16,
    fee_recipient: address,
    payout_mode: u8,
    timeout_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): (Entity, SettlementCap) {
    let pool_component = wager_pool::new(
        wager_amount,
        max_players,
        protocol_fee_bps,
        fee_recipient,
        payout_mode,
        clock.timestamp_ms(),
        timeout_ms,
    );

    // Create a new entity for the pool
    let mut pool_entity = entity::new(
        ascii::string(b"pool"),
        clock,
        ctx,
    );

    // Attach the WagerPool component
    wager_pool::add(&mut pool_entity, pool_component);

    let pool_id = object::id(&pool_entity);

    let cap = SettlementCap {
        id: object::new(ctx),
        pool_id,
    };

    (pool_entity, cap)
}

/// Destroy an empty pool. Removes WagerPool from entity and destroys it.
/// Aborts if pool still has funds.
public fun destroy_empty_pool(
    cap: &SettlementCap,
    pool_entity: &mut Entity,
) {
    assert_cap_matches(cap, pool_entity);
    assert_pool_entity(pool_entity);

    let pool = wager_pool::remove(pool_entity);
    wager_pool::destroy_empty(pool);
}

/// Destroy a SettlementCap after the game is fully done. Frees the UID.
public fun destroy_cap(cap: SettlementCap) {
    let SettlementCap { id, .. } = cap;
    id.delete();
}

// ─── Wager Operations ───────────────────────

/// Place a wager for a player. Exact coin amount required.
/// Attaches a Wager component to the player entity.
public fun place_wager(
    cap: &SettlementCap,
    pool_entity: &mut Entity,
    player_entity: &mut Entity,
    payment: Coin<SUI>,
    ctx: &TxContext,
) {
    assert_cap_matches(cap, pool_entity);
    assert_pool_entity(pool_entity);
    // Player must NOT already have a wager
    assert!(!player_entity.has_component(entity::wager_bit()), EAlreadyWagered);

    // Capture IDs and immutable reads BEFORE any mutable borrow
    let pool_id = object::id(pool_entity);
    let player = ctx.sender();
    let amount = payment.value();

    // Read pool immutably first for validation
    let pool_ref = wager_pool::borrow(pool_entity);
    assert!(!pool_ref.is_settled(), EAlreadySettled);
    assert!(!pool_ref.is_full(), EPoolFull);
    assert!(amount == pool_ref.wager_amount(), EWagerAmountMismatch);

    // Now mutate pool
    let pool = wager_pool::borrow_mut(pool_entity);
    pool.join_pool(coin::into_balance(payment));
    pool.increment_player_count();
    let count = pool.player_count();

    // Attach Wager component to player entity
    let w = wager::new(amount, player);
    wager::add(player_entity, w);

    event::emit(WagerPlacedEvent {
        pool_id,
        player_entity_id: object::id(player_entity),
        player,
        amount,
        player_count: count,
    });
}

/// Lock all wagers when the game starts (PENDING → LOCKED).
public fun lock_wagers(
    cap: &SettlementCap,
    pool_entity: &Entity,
    players: &mut vector<Entity>,
) {
    assert_cap_matches(cap, pool_entity);
    assert_pool_entity(pool_entity);

    let mut i = 0;
    while (i < players.length()) {
        let player = &mut players[i];
        if (player.has_component(entity::wager_bit())) {
            let w = wager::borrow_mut(player);
            assert!(w.is_pending(), EWagerNotPending);
            w.set_status(wager::status_locked());
        };
        i = i + 1;
    };
}

// ─── Settlement ─────────────────────────────

/// Settle: 100% to winner, no fee. Marks winner WON, losers LOST.
public fun settle_winner(
    cap: &SettlementCap,
    pool_entity: &mut Entity,
    winner_entity: &mut Entity,
    loser_entities: &mut vector<Entity>,
    ctx: &mut TxContext,
) {
    assert_cap_matches(cap, pool_entity);
    assert_pool_entity(pool_entity);
    assert_player_entity(winner_entity);

    // Capture IDs before mutable borrows
    let pool_id = object::id(pool_entity);
    let winner_id = object::id(winner_entity);
    let winner_addr = wager::borrow(winner_entity).player();

    // Read pool state, assert, then mutate
    let pool_ref = wager_pool::borrow(pool_entity);
    assert!(!pool_ref.is_settled(), EAlreadySettled);
    let total = pool_ref.pool_value();
    let fee_addr = pool_ref.fee_recipient();

    // Withdraw all funds
    let pool = wager_pool::borrow_mut(pool_entity);
    let payout_balance = pool.withdraw_all();
    pool.set_settled(true);

    // Transfer to winner
    let payout_coin = coin::from_balance(payout_balance, ctx);
    transfer::public_transfer(payout_coin, winner_addr);

    // Mark winner
    wager::borrow_mut(winner_entity).set_status(wager::status_won());

    event::emit(WagerSettledEvent {
        pool_id,
        winner_entity_id: winner_id,
        winner: winner_addr,
        payout: total,
        fee: 0,
        fee_recipient: fee_addr,
    });

    // Mark losers
    mark_losers(pool_id, loser_entities);
}

/// Settle with fee: fee → fee_recipient, remainder → winner.
public fun settle_with_fee(
    cap: &SettlementCap,
    pool_entity: &mut Entity,
    winner_entity: &mut Entity,
    loser_entities: &mut vector<Entity>,
    ctx: &mut TxContext,
) {
    assert_cap_matches(cap, pool_entity);
    assert_pool_entity(pool_entity);
    assert_player_entity(winner_entity);

    // Capture IDs and immutable state before mutable borrows
    let pool_id = object::id(pool_entity);
    let winner_id = object::id(winner_entity);
    let winner_addr = wager::borrow(winner_entity).player();

    let pool_ref = wager_pool::borrow(pool_entity);
    assert!(!pool_ref.is_settled(), EAlreadySettled);
    let total = pool_ref.pool_value();
    let fee_bps = pool_ref.protocol_fee_bps();
    let fee_addr = pool_ref.fee_recipient();

    // Overflow-safe fee calculation
    let fee = calc_fee(total, fee_bps);
    let payout = total - fee;

    // Mutate pool: extract fee then remainder
    let pool = wager_pool::borrow_mut(pool_entity);

    if (fee > 0) {
        let fee_balance = pool.split_pool(fee);
        let fee_coin = coin::from_balance(fee_balance, ctx);
        transfer::public_transfer(fee_coin, fee_addr);
    };

    let payout_balance = pool.withdraw_all();
    pool.set_settled(true);

    let payout_coin = coin::from_balance(payout_balance, ctx);
    transfer::public_transfer(payout_coin, winner_addr);

    // Mark winner
    wager::borrow_mut(winner_entity).set_status(wager::status_won());

    event::emit(WagerSettledEvent {
        pool_id,
        winner_entity_id: winner_id,
        winner: winner_addr,
        payout,
        fee,
        fee_recipient: fee_addr,
    });

    // Mark losers
    mark_losers(pool_id, loser_entities);
}

/// Settle proportionally: fee first, remainder split by shares (basis points).
/// `shares` must sum to 10000. Dust goes to last winner.
public fun settle_proportional(
    cap: &SettlementCap,
    pool_entity: &mut Entity,
    winner_entities: &mut vector<Entity>,
    shares: vector<u64>,
    loser_entities: &mut vector<Entity>,
    ctx: &mut TxContext,
) {
    assert_cap_matches(cap, pool_entity);
    assert_pool_entity(pool_entity);

    // Validate shares sum to 10000
    let mut share_sum: u64 = 0;
    let mut j = 0;
    while (j < shares.length()) {
        share_sum = share_sum + shares[j];
        j = j + 1;
    };
    assert!(share_sum == 10000, ESharesSumInvalid);

    // Capture IDs and immutable state before mutable borrows
    let pool_id = object::id(pool_entity);

    let pool_ref = wager_pool::borrow(pool_entity);
    assert!(!pool_ref.is_settled(), EAlreadySettled);
    let total = pool_ref.pool_value();
    let fee_bps = pool_ref.protocol_fee_bps();
    let fee_addr = pool_ref.fee_recipient();

    // Fee first
    let fee = calc_fee(total, fee_bps);
    let remainder = total - fee;

    let pool = wager_pool::borrow_mut(pool_entity);

    if (fee > 0) {
        let fee_balance = pool.split_pool(fee);
        let fee_coin = coin::from_balance(fee_balance, ctx);
        transfer::public_transfer(fee_coin, fee_addr);
    };

    // Split remainder by shares
    let winner_count = winner_entities.length();
    let mut distributed: u64 = 0;
    let mut i = 0;
    while (i < winner_count) {
        let winner = &mut winner_entities[i];
        assert_player_entity(winner);

        let winner_addr = wager::borrow(winner).player();

        let share = if (i == winner_count - 1) {
            // Last winner gets remainder (absorbs dust)
            remainder - distributed
        } else {
            (((remainder as u128) * (shares[i] as u128) / 10000u128) as u64)
        };

        distributed = distributed + share;

        let payout_balance = pool.split_pool(share);
        let payout_coin = coin::from_balance(payout_balance, ctx);
        transfer::public_transfer(payout_coin, winner_addr);

        // Mark winner
        wager::borrow_mut(winner).set_status(wager::status_won());

        event::emit(WagerSettledEvent {
            pool_id,
            winner_entity_id: object::id(winner),
            winner: winner_addr,
            payout: share,
            fee: if (i == 0) { fee } else { 0 },
            fee_recipient: fee_addr,
        });

        i = i + 1;
    };

    pool.set_settled(true);

    // Mark losers
    mark_losers(pool_id, loser_entities);
}

/// Settle timeout: if lobby not full → abort (caller should refund), else → forfeit AFK.
public fun settle_timeout(
    cap: &SettlementCap,
    pool_entity: &mut Entity,
    winner_entity: &mut Entity,
    loser_entity: &mut Entity,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert_cap_matches(cap, pool_entity);
    assert_pool_entity(pool_entity);
    assert_player_entity(winner_entity);
    assert_player_entity(loser_entity);

    // Capture IDs before any mutable borrows
    let pool_id = object::id(pool_entity);
    let winner_id = object::id(winner_entity);
    let loser_id = object::id(loser_entity);
    let winner_addr = wager::borrow(winner_entity).player();
    let loser_addr = wager::borrow(loser_entity).player();
    let loser_amount = wager::borrow(loser_entity).amount();

    // Read pool immutably for validation
    let pool_ref = wager_pool::borrow(pool_entity);
    assert!(!pool_ref.is_settled(), EAlreadySettled);
    assert!(
        clock.timestamp_ms() > pool_ref.created_at() + pool_ref.timeout_ms(),
        ETimeoutNotExpired,
    );
    assert!(pool_ref.player_count() >= pool_ref.max_players(), ETimeoutNotExpired);

    let total = pool_ref.pool_value();
    let fee_bps = pool_ref.protocol_fee_bps();
    let fee_addr = pool_ref.fee_recipient();

    // Fee calc
    let fee = calc_fee(total, fee_bps);
    let payout = total - fee;

    // Mutate pool
    let pool = wager_pool::borrow_mut(pool_entity);

    if (fee > 0) {
        let fee_balance = pool.split_pool(fee);
        let fee_coin = coin::from_balance(fee_balance, ctx);
        transfer::public_transfer(fee_coin, fee_addr);
    };

    let payout_balance = pool.withdraw_all();
    pool.set_settled(true);

    let payout_coin = coin::from_balance(payout_balance, ctx);
    transfer::public_transfer(payout_coin, winner_addr);

    // Mark winner
    wager::borrow_mut(winner_entity).set_status(wager::status_won());

    event::emit(WagerSettledEvent {
        pool_id,
        winner_entity_id: winner_id,
        winner: winner_addr,
        payout,
        fee,
        fee_recipient: fee_addr,
    });

    // Mark loser
    wager::borrow_mut(loser_entity).set_status(wager::status_lost());

    event::emit(WagerLostEvent {
        pool_id,
        player_entity_id: loser_id,
        player: loser_addr,
        amount_lost: loser_amount,
    });
}

// ─── Refunds ────────────────────────────────

/// Refund a single player (pre-game disconnect). Asserts wager is PENDING.
public fun refund_player(
    cap: &SettlementCap,
    pool_entity: &mut Entity,
    player_entity: &mut Entity,
    ctx: &mut TxContext,
) {
    assert_cap_matches(cap, pool_entity);
    assert_pool_entity(pool_entity);
    assert_player_entity(player_entity);

    // Capture IDs and immutable state before mutable borrows
    let pool_id = object::id(pool_entity);
    let player_id = object::id(player_entity);

    let w = wager::borrow(player_entity);
    assert!(w.is_pending(), EWagerNotPending);
    let amount = w.amount();
    let player = w.player();

    // Extract from pool and transfer back
    let pool = wager_pool::borrow_mut(pool_entity);
    let refund_balance = pool.split_pool(amount);
    let refund_coin = coin::from_balance(refund_balance, ctx);
    transfer::public_transfer(refund_coin, player);

    // Mark as refunded
    wager::borrow_mut(player_entity).set_status(wager::status_refunded());

    event::emit(WagerRefundedEvent {
        pool_id,
        player_entity_id: player_id,
        player,
        amount,
    });
}

/// Refund all players (game cancelled).
public fun refund_all(
    cap: &SettlementCap,
    pool_entity: &mut Entity,
    players: &mut vector<Entity>,
    ctx: &mut TxContext,
) {
    assert_cap_matches(cap, pool_entity);
    assert_pool_entity(pool_entity);

    let pool_id = object::id(pool_entity);

    let mut i = 0;
    while (i < players.length()) {
        let player = &mut players[i];
        if (player.has_component(entity::wager_bit())) {
            let w = wager::borrow(player);
            // Only refund pending or locked wagers
            if (w.is_pending() || w.is_locked()) {
                let amount = w.amount();
                let player_addr = w.player();
                let player_entity_id = object::id(player);

                let pool = wager_pool::borrow_mut(pool_entity);
                let refund_balance = pool.split_pool(amount);
                let refund_coin = coin::from_balance(refund_balance, ctx);
                transfer::public_transfer(refund_coin, player_addr);

                wager::borrow_mut(player).set_status(wager::status_refunded());

                event::emit(WagerRefundedEvent {
                    pool_id,
                    player_entity_id,
                    player: player_addr,
                    amount,
                });
            };
        };
        i = i + 1;
    };
}

// ─── Internal Helpers ───────────────────────

/// Overflow-safe fee calculation using u128 intermediate.
fun calc_fee(total: u64, fee_bps: u16): u64 {
    (((total as u128) * (fee_bps as u128) / 10000u128) as u64)
}

/// Mark all entities in the vector as LOST and emit events.
fun mark_losers(pool_id: ID, losers: &mut vector<Entity>) {
    let mut i = 0;
    while (i < losers.length()) {
        let loser = &mut losers[i];
        if (loser.has_component(entity::wager_bit())) {
            let amount_lost = wager::borrow(loser).amount();
            let player = wager::borrow(loser).player();
            let loser_id = object::id(loser);
            wager::borrow_mut(loser).set_status(wager::status_lost());

            event::emit(WagerLostEvent {
                pool_id,
                player_entity_id: loser_id,
                player,
                amount_lost,
            });
        };
        i = i + 1;
    };
}

// ─── Cap Accessor ───────────────────────────

/// Get the pool_id this cap is bound to.
public fun cap_pool_id(cap: &SettlementCap): ID { cap.pool_id }
