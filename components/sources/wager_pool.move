/// WagerPool — Session-level escrow for the wagering subsystem.
///
/// Holds the pooled `Balance<SUI>` for all wagers in a game session.
/// Has `store` only — no `copy`, no `drop` — because `Balance<SUI>` lacks
/// `drop`. This is a safety feature: a pool with funds cannot be silently
/// discarded. It must be explicitly destroyed via `destroy_empty()`.
module components::wager_pool;

use std::ascii::{Self, String};
use sui::balance::{Self, Balance};
use sui::sui::SUI;
use entity::entity::{Self, Entity};

// ─── Constants ──────────────────────────────

const PAYOUT_WINNER_ALL: u8    = 0;
const PAYOUT_PROPORTIONAL: u8  = 1;
const PAYOUT_CONSOLATION: u8   = 2;

// ─── Error Constants ────────────────────────

const EWagerAmountZero: u64    = 0;
const ETooFewPlayers: u64      = 1;
const EPoolNotEmpty: u64       = 2;
const EInsufficientBalance: u64 = 3;

// ─── Struct ─────────────────────────────────

public struct WagerPool has store {  // NO copy, NO drop — Balance<SUI> prevents it
    pool: Balance<SUI>,
    wager_amount: u64,       // required per-player wager (MIST)
    player_count: u8,
    max_players: u8,
    settled: bool,
    protocol_fee_bps: u16,   // fee basis points (250 = 2.5%)
    fee_recipient: address,
    payout_mode: u8,         // 0=winner-all, 1=proportional, 2=consolation
    created_at: u64,         // timestamp ms
    timeout_ms: u64,         // max game duration before auto-forfeit
}

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"wager_pool") }

// ─── Constructor ────────────────────────────

/// Create a new empty wager pool.
/// Aborts if `wager_amount` is 0 or `max_players` < 2.
public fun new(
    wager_amount: u64,
    max_players: u8,
    protocol_fee_bps: u16,
    fee_recipient: address,
    payout_mode: u8,
    created_at: u64,
    timeout_ms: u64,
): WagerPool {
    assert!(wager_amount > 0, EWagerAmountZero);
    assert!(max_players >= 2, ETooFewPlayers);
    WagerPool {
        pool: balance::zero<SUI>(),
        wager_amount,
        player_count: 0,
        max_players,
        settled: false,
        protocol_fee_bps,
        fee_recipient,
        payout_mode,
        created_at,
        timeout_ms,
    }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, pool: WagerPool) {
    entity.add_component(entity::wager_pool_bit(), key(), pool);
}

public fun remove(entity: &mut Entity): WagerPool {
    entity.remove_component(entity::wager_pool_bit(), key())
}

public fun borrow(entity: &Entity): &WagerPool {
    entity.borrow_component<WagerPool>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut WagerPool {
    entity.borrow_mut_component<WagerPool>(key())
}

// ─── Getters ────────────────────────────────

public fun pool_value(self: &WagerPool): u64 { self.pool.value() }
public fun wager_amount(self: &WagerPool): u64 { self.wager_amount }
public fun player_count(self: &WagerPool): u8 { self.player_count }
public fun max_players(self: &WagerPool): u8 { self.max_players }
public fun is_settled(self: &WagerPool): bool { self.settled }
public fun protocol_fee_bps(self: &WagerPool): u16 { self.protocol_fee_bps }
public fun fee_recipient(self: &WagerPool): address { self.fee_recipient }
public fun payout_mode(self: &WagerPool): u8 { self.payout_mode }
public fun created_at(self: &WagerPool): u64 { self.created_at }
public fun timeout_ms(self: &WagerPool): u64 { self.timeout_ms }
public fun is_full(self: &WagerPool): bool { self.player_count >= self.max_players }

// ─── Setters ────────────────────────────────

public fun increment_player_count(self: &mut WagerPool) {
    self.player_count = self.player_count + 1;
}

public fun set_settled(self: &mut WagerPool, settled: bool) {
    self.settled = settled;
}

// ─── Balance Operations ─────────────────────

/// Merge a balance into the pool. Returns new total.
public fun join_pool(self: &mut WagerPool, deposit: Balance<SUI>): u64 {
    self.pool.join(deposit)
}

/// Split an amount from the pool. Aborts if insufficient.
public fun split_pool(self: &mut WagerPool, amount: u64): Balance<SUI> {
    assert!(self.pool.value() >= amount, EInsufficientBalance);
    self.pool.split(amount)
}

/// Withdraw the entire pool balance.
public fun withdraw_all(self: &mut WagerPool): Balance<SUI> {
    self.pool.withdraw_all()
}

// ─── Payout Mode Accessors ──────────────────

public fun payout_winner_all(): u8 { PAYOUT_WINNER_ALL }
public fun payout_proportional(): u8 { PAYOUT_PROPORTIONAL }
public fun payout_consolation(): u8 { PAYOUT_CONSOLATION }

// ─── Destructor ─────────────────────────────

/// Destroy a fully-settled pool. Aborts if any MIST remains.
public fun destroy_empty(pool: WagerPool) {
    let WagerPool { pool: balance, .. } = pool;
    balance.destroy_zero();  // aborts if non-zero
}

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): WagerPool {
    new(
        10_000_000_000,  // 10 SUI
        2,               // 2 players
        250,             // 2.5% fee
        @0x0,            // fee recipient
        PAYOUT_WINNER_ALL,
        0,               // created_at
        600_000,         // 10 min timeout
    )
}
