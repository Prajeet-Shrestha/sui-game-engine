#[test_only]
module systems::wager_sys_tests;

use sui::test_scenario as ts;
use sui::clock;
use sui::coin;
use sui::sui::SUI;

use entity::entity;
use components::wager;
use components::wager_pool;
use systems::wager_sys;

const ADMIN: address  = @0xAD;
const PLAYER1: address = @0x1;
const PLAYER2: address = @0x2;
const PLAYER3: address = @0x3;
const FEE_RECIPIENT: address = @0xFEE;

// Amount: 1 SUI = 1_000_000_000 MIST
const WAGER_AMOUNT: u64 = 1_000_000_000;

// ─── Helpers ────────────────────────────────

/// Create a pool with standard params: 1 SUI wager, 2 players, 250 bps fee.
fun setup_pool(scenario: &mut ts::Scenario): (entity::Entity, wager_sys::SettlementCap) {
    let clk = clock::create_for_testing(ts::ctx(scenario));
    let (pool_entity, cap) = wager_sys::create_pool(
        WAGER_AMOUNT,       // 1 SUI
        2,                  // max 2 players
        250,                // 2.5% fee
        FEE_RECIPIENT,
        wager_pool::payout_winner_all(),
        600_000,            // 10 min timeout
        &clk,
        ts::ctx(scenario),
    );
    clock::destroy_for_testing(clk);
    (pool_entity, cap)
}

/// Create a pool with 3 players for proportional tests.
fun setup_pool_3(scenario: &mut ts::Scenario): (entity::Entity, wager_sys::SettlementCap) {
    let clk = clock::create_for_testing(ts::ctx(scenario));
    let (pool_entity, cap) = wager_sys::create_pool(
        WAGER_AMOUNT,
        3,
        250,
        FEE_RECIPIENT,
        wager_pool::payout_proportional(),
        600_000,
        &clk,
        ts::ctx(scenario),
    );
    clock::destroy_for_testing(clk);
    (pool_entity, cap)
}

/// Place a wager for sender in current tx context.
fun do_place_wager(
    cap: &wager_sys::SettlementCap,
    pool: &mut entity::Entity,
    player: &mut entity::Entity,
    scenario: &mut ts::Scenario,
) {
    let payment = coin::mint_for_testing<SUI>(WAGER_AMOUNT, ts::ctx(scenario));
    wager_sys::place_wager(cap, pool, player, payment, ts::ctx(scenario));
}

/// Cleanup: remove wager component from entity and destroy it.
fun cleanup_player(mut e: entity::Entity) {
    if (e.has_component(entity::wager_bit())) {
        let _ = wager::remove(&mut e);
    };
    e.destroy();
}

/// Cleanup pool entity — remove pool component (if not already removed) and destroy.
fun cleanup_pool(mut pool: entity::Entity) {
    if (pool.has_component(entity::wager_pool_bit())) {
        let wp = wager_pool::remove(&mut pool);
        // Must withdraw remaining balance before destroying
        // Likely the pool is already settled/empty in cleanup paths
        wager_pool::destroy_empty(wp);
    };
    pool.destroy();
}

// ═══════════════════════════════════════════════
// 1. Pool Creation
// ═══════════════════════════════════════════════

#[test]
fun test_create_pool_returns_cap() {
    let mut scenario = ts::begin(ADMIN);
    let (pool_entity, cap) = setup_pool(&mut scenario);

    // Cap's pool_id should match the pool entity's ID
    assert!(wager_sys::cap_pool_id(&cap) == object::id(&pool_entity));

    // Pool has WagerPool component
    assert!(pool_entity.has_component(entity::wager_pool_bit()));

    let pool = wager_pool::borrow(&pool_entity);
    assert!(pool.wager_amount() == WAGER_AMOUNT);
    assert!(pool.max_players() == 2);
    assert!(pool.protocol_fee_bps() == 250);
    assert!(pool.pool_value() == 0);

    // Cleanup
    wager_sys::destroy_empty_pool(&cap, &mut pool_entity);
    wager_sys::destroy_cap(cap);
    pool_entity.destroy();
    ts::end(scenario);
}

// ═══════════════════════════════════════════════
// 2. Place Wager
// ═══════════════════════════════════════════════

#[test]
fun test_place_wager() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool_entity, cap) = setup_pool(&mut scenario);
    let mut player1 = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut player1, &mut scenario);

    // Verify pool balance
    let pool = wager_pool::borrow(&pool_entity);
    assert!(pool.pool_value() == WAGER_AMOUNT);
    assert!(pool.player_count() == 1);

    // Verify Wager component attached
    assert!(player1.has_component(entity::wager_bit()));
    let w = wager::borrow(&player1);
    assert!(w.amount() == WAGER_AMOUNT);
    assert!(w.is_pending());

    // Cleanup
    cleanup_player(player1);
    cleanup_pool(pool_entity);
    wager_sys::destroy_cap(cap);
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 4)] // EWagerAmountMismatch
fun test_place_wager_wrong_amount() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool_entity, cap) = setup_pool(&mut scenario);
    let mut player1 = entity::new_for_testing(ts::ctx(&mut scenario));

    // Pay wrong amount (half the required)
    let payment = coin::mint_for_testing<SUI>(WAGER_AMOUNT / 2, ts::ctx(&mut scenario));
    wager_sys::place_wager(&cap, &mut pool_entity, &mut player1, payment, ts::ctx(&mut scenario));

    abort 99 // unreachable
}

#[test]
#[expected_failure(abort_code = 6)] // EAlreadyWagered
fun test_double_wager() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool_entity, cap) = setup_pool(&mut scenario);
    let mut player1 = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut player1, &mut scenario);
    // Second wager should fail
    do_place_wager(&cap, &mut pool_entity, &mut player1, &mut scenario);

    abort 99
}

// ═══════════════════════════════════════════════
// 3. Lock Wagers
// ═══════════════════════════════════════════════

#[test]
fun test_lock_wagers() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool_entity, cap) = setup_pool(&mut scenario);
    let mut p1 = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut p2 = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut p1, &mut scenario);
    do_place_wager(&cap, &mut pool_entity, &mut p2, &mut scenario);

    let mut players = vector[p1, p2];
    wager_sys::lock_wagers(&cap, &pool_entity, &mut players);

    // All should be LOCKED
    let p1_ref = &players[0];
    assert!(wager::borrow(p1_ref).is_locked());
    let p2_ref = &players[1];
    assert!(wager::borrow(p2_ref).is_locked());

    // Cleanup
    let p1_out = players.pop_back();
    let p2_out = players.pop_back();
    players.destroy_empty();
    cleanup_player(p1_out);
    cleanup_player(p2_out);
    cleanup_pool(pool_entity);
    wager_sys::destroy_cap(cap);
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 7)] // EWagerNotPending
fun test_lock_already_locked() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool_entity, cap) = setup_pool(&mut scenario);
    let mut p1 = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut p1, &mut scenario);

    let mut players = vector[p1];
    wager_sys::lock_wagers(&cap, &pool_entity, &mut players);
    // Lock again — should fail with EWagerNotPending
    wager_sys::lock_wagers(&cap, &pool_entity, &mut players);

    abort 99
}

// ═══════════════════════════════════════════════
// 4. Settle Winner (no fee)
// ═══════════════════════════════════════════════

#[test]
fun test_settle_winner() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool_entity, cap) = setup_pool(&mut scenario);
    let mut winner = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut loser = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut winner, &mut scenario);
    do_place_wager(&cap, &mut pool_entity, &mut loser, &mut scenario);

    let mut losers = vector[loser];
    wager_sys::settle_winner(
        &cap, &mut pool_entity, &mut winner, &mut losers, ts::ctx(&mut scenario),
    );

    // Pool should be empty and settled
    let pool = wager_pool::borrow(&pool_entity);
    assert!(pool.pool_value() == 0);
    assert!(pool.is_settled());

    // Winner marked WON
    assert!(wager::borrow(&winner).is_won());

    // Loser marked LOST
    let loser_ref = &losers[0];
    assert!(wager::borrow(loser_ref).is_lost());

    // Cleanup
    let loser_out = losers.pop_back();
    losers.destroy_empty();
    cleanup_player(loser_out);
    cleanup_player(winner);
    wager_sys::destroy_empty_pool(&cap, &mut pool_entity);
    wager_sys::destroy_cap(cap);
    pool_entity.destroy();
    ts::end(scenario);
}

// ═══════════════════════════════════════════════
// 5. Settle With Fee
// ═══════════════════════════════════════════════

#[test]
fun test_settle_with_fee() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool_entity, cap) = setup_pool(&mut scenario);
    let mut winner = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut loser = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut winner, &mut scenario);
    do_place_wager(&cap, &mut pool_entity, &mut loser, &mut scenario);

    // Pool total = 2 SUI = 2_000_000_000 MIST. Fee = 2.5% = 50_000_000
    let mut losers = vector[loser];
    wager_sys::settle_with_fee(
        &cap, &mut pool_entity, &mut winner, &mut losers, ts::ctx(&mut scenario),
    );

    // Pool should be empty and settled
    let pool = wager_pool::borrow(&pool_entity);
    assert!(pool.pool_value() == 0);
    assert!(pool.is_settled());

    // Winner marked WON
    assert!(wager::borrow(&winner).is_won());

    // Loser marked LOST
    let loser_ref = &losers[0];
    assert!(wager::borrow(loser_ref).is_lost());

    // Cleanup
    let loser_out = losers.pop_back();
    losers.destroy_empty();
    cleanup_player(loser_out);
    cleanup_player(winner);
    wager_sys::destroy_empty_pool(&cap, &mut pool_entity);
    wager_sys::destroy_cap(cap);
    pool_entity.destroy();
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 3)] // EAlreadySettled
fun test_settle_already_settled() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool_entity, cap) = setup_pool(&mut scenario);
    let mut winner = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut loser = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut winner, &mut scenario);
    do_place_wager(&cap, &mut pool_entity, &mut loser, &mut scenario);

    let mut losers = vector[loser];
    wager_sys::settle_winner(
        &cap, &mut pool_entity, &mut winner, &mut losers, ts::ctx(&mut scenario),
    );
    // Settle again → should fail
    wager_sys::settle_winner(
        &cap, &mut pool_entity, &mut winner, &mut losers, ts::ctx(&mut scenario),
    );

    abort 99
}

// ═══════════════════════════════════════════════
// 6. Cap Validation
// ═══════════════════════════════════════════════

#[test]
#[expected_failure(abort_code = 0)] // ECapPoolMismatch
fun test_settle_wrong_cap() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool1, cap1) = setup_pool(&mut scenario);
    let (pool2, cap2) = setup_pool(&mut scenario);

    let mut winner = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut loser = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap1, &mut pool1, &mut winner, &mut scenario);
    do_place_wager(&cap1, &mut pool1, &mut loser, &mut scenario);

    let mut losers = vector[loser];
    // Use cap2 on pool1 → should fail
    wager_sys::settle_winner(
        &cap2, &mut pool1, &mut winner, &mut losers, ts::ctx(&mut scenario),
    );

    abort 99
}

// ═══════════════════════════════════════════════
// 7. Settle Timeout
// ═══════════════════════════════════════════════

#[test]
fun test_settle_timeout_active_game() {
    let mut scenario = ts::begin(PLAYER1);
    let mut clk = clock::create_for_testing(ts::ctx(&mut scenario));

    let (mut pool_entity, cap) = wager_sys::create_pool(
        WAGER_AMOUNT,
        2,
        250,
        FEE_RECIPIENT,
        wager_pool::payout_winner_all(),
        600_000,       // 10 min timeout
        &clk,
        ts::ctx(&mut scenario),
    );

    let mut winner = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut loser = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut winner, &mut scenario);
    do_place_wager(&cap, &mut pool_entity, &mut loser, &mut scenario);

    // Advance clock past timeout (10 minutes + 1 ms)
    clock::increment_for_testing(&mut clk, 600_001);

    wager_sys::settle_timeout(
        &cap, &mut pool_entity, &mut winner, &mut loser, &clk, ts::ctx(&mut scenario),
    );

    // Pool settled
    let pool = wager_pool::borrow(&pool_entity);
    assert!(pool.pool_value() == 0);
    assert!(pool.is_settled());

    // Winner won, loser lost
    assert!(wager::borrow(&winner).is_won());
    assert!(wager::borrow(&loser).is_lost());

    // Cleanup
    cleanup_player(winner);
    cleanup_player(loser);
    wager_sys::destroy_empty_pool(&cap, &mut pool_entity);
    wager_sys::destroy_cap(cap);
    pool_entity.destroy();
    clock::destroy_for_testing(clk);
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 9)] // ETimeoutNotExpired
fun test_settle_timeout_not_expired() {
    let mut scenario = ts::begin(PLAYER1);
    let clk = clock::create_for_testing(ts::ctx(&mut scenario));

    let (mut pool_entity, cap) = wager_sys::create_pool(
        WAGER_AMOUNT, 2, 250, FEE_RECIPIENT,
        wager_pool::payout_winner_all(), 600_000,
        &clk, ts::ctx(&mut scenario),
    );

    let mut winner = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut loser = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut winner, &mut scenario);
    do_place_wager(&cap, &mut pool_entity, &mut loser, &mut scenario);

    // Clock NOT advanced — timeout has not expired
    wager_sys::settle_timeout(
        &cap, &mut pool_entity, &mut winner, &mut loser, &clk, ts::ctx(&mut scenario),
    );

    abort 99
}

// ═══════════════════════════════════════════════
// 8. Loser Status
// ═══════════════════════════════════════════════

#[test]
fun test_loser_status_marked() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool_entity, cap) = setup_pool_3(&mut scenario);
    let mut winner = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut l1 = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut l2 = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut winner, &mut scenario);
    do_place_wager(&cap, &mut pool_entity, &mut l1, &mut scenario);
    do_place_wager(&cap, &mut pool_entity, &mut l2, &mut scenario);

    let mut losers = vector[l1, l2];
    wager_sys::settle_winner(
        &cap, &mut pool_entity, &mut winner, &mut losers, ts::ctx(&mut scenario),
    );

    // Both losers should be LOST
    assert!(wager::borrow(&losers[0]).is_lost());
    assert!(wager::borrow(&losers[1]).is_lost());

    // Cleanup
    let l2_out = losers.pop_back();
    let l1_out = losers.pop_back();
    losers.destroy_empty();
    cleanup_player(l1_out);
    cleanup_player(l2_out);
    cleanup_player(winner);
    wager_sys::destroy_empty_pool(&cap, &mut pool_entity);
    wager_sys::destroy_cap(cap);
    pool_entity.destroy();
    ts::end(scenario);
}

// ═══════════════════════════════════════════════
// 9. Refund Player
// ═══════════════════════════════════════════════

#[test]
fun test_refund_player() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool_entity, cap) = setup_pool(&mut scenario);
    let mut p1 = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut p1, &mut scenario);

    // Refund while still PENDING
    wager_sys::refund_player(
        &cap, &mut pool_entity, &mut p1, ts::ctx(&mut scenario),
    );

    // Pool balance reduced
    let pool = wager_pool::borrow(&pool_entity);
    assert!(pool.pool_value() == 0);

    // Wager marked REFUNDED
    assert!(wager::borrow(&p1).is_refunded());

    // Cleanup
    cleanup_player(p1);
    cleanup_pool(pool_entity);
    wager_sys::destroy_cap(cap);
    ts::end(scenario);
}

// ═══════════════════════════════════════════════
// 10. Refund All
// ═══════════════════════════════════════════════

#[test]
fun test_refund_all() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool_entity, cap) = setup_pool(&mut scenario);
    let mut p1 = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut p2 = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut p1, &mut scenario);
    do_place_wager(&cap, &mut pool_entity, &mut p2, &mut scenario);

    let mut players = vector[p1, p2];
    wager_sys::refund_all(&cap, &mut pool_entity, &mut players, ts::ctx(&mut scenario));

    // Pool should be empty
    let pool = wager_pool::borrow(&pool_entity);
    assert!(pool.pool_value() == 0);

    // Both marked REFUNDED
    assert!(wager::borrow(&players[0]).is_refunded());
    assert!(wager::borrow(&players[1]).is_refunded());

    // Cleanup
    let p2_out = players.pop_back();
    let p1_out = players.pop_back();
    players.destroy_empty();
    cleanup_player(p1_out);
    cleanup_player(p2_out);
    cleanup_pool(pool_entity);
    wager_sys::destroy_cap(cap);
    ts::end(scenario);
}

// ═══════════════════════════════════════════════
// 11. Pool Destruction
// ═══════════════════════════════════════════════

#[test]
#[expected_failure(abort_code = components::wager_pool::EPoolNotEmpty)]
fun test_destroy_pool_with_balance() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool_entity, cap) = setup_pool(&mut scenario);
    let mut p1 = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut p1, &mut scenario);

    // Try destroy with funds still in pool → should abort
    wager_sys::destroy_empty_pool(&cap, &mut pool_entity);

    abort 99
}

#[test]
fun test_destroy_cap() {
    let mut scenario = ts::begin(ADMIN);
    let (mut pool_entity, cap) = setup_pool(&mut scenario);

    wager_sys::destroy_empty_pool(&cap, &mut pool_entity);
    wager_sys::destroy_cap(cap); // UID freed, no abort
    pool_entity.destroy();
    ts::end(scenario);
}

// ═══════════════════════════════════════════════
// 12. Proportional Settlement
// ═══════════════════════════════════════════════

#[test]
fun test_proportional_fee_then_split() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool_entity, cap) = setup_pool_3(&mut scenario);
    let mut w1 = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut w2 = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut loser = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut w1, &mut scenario);
    do_place_wager(&cap, &mut pool_entity, &mut w2, &mut scenario);
    do_place_wager(&cap, &mut pool_entity, &mut loser, &mut scenario);

    // Total = 3 SUI. Fee = 2.5% of 3 SUI = 75_000_000 MIST
    // Remainder = 2_925_000_000 MIST
    // Shares: 6000 bps (60%) and 4000 bps (40%)
    let shares = vector[6000, 4000];
    let mut winners = vector[w1, w2];
    let mut losers = vector[loser];

    wager_sys::settle_proportional(
        &cap, &mut pool_entity, &mut winners, shares, &mut losers, ts::ctx(&mut scenario),
    );

    // Pool empty and settled
    let pool = wager_pool::borrow(&pool_entity);
    assert!(pool.pool_value() == 0);
    assert!(pool.is_settled());

    // Winners marked WON
    assert!(wager::borrow(&winners[0]).is_won());
    assert!(wager::borrow(&winners[1]).is_won());

    // Loser marked LOST
    assert!(wager::borrow(&losers[0]).is_lost());

    // Cleanup
    let l = losers.pop_back();
    losers.destroy_empty();
    let w2_out = winners.pop_back();
    let w1_out = winners.pop_back();
    winners.destroy_empty();
    cleanup_player(w1_out);
    cleanup_player(w2_out);
    cleanup_player(l);
    wager_sys::destroy_empty_pool(&cap, &mut pool_entity);
    wager_sys::destroy_cap(cap);
    pool_entity.destroy();
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 10)] // ESharesSumInvalid
fun test_proportional_shares_sum() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool_entity, cap) = setup_pool_3(&mut scenario);
    let mut w1 = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut w2 = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut loser = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut w1, &mut scenario);
    do_place_wager(&cap, &mut pool_entity, &mut w2, &mut scenario);
    do_place_wager(&cap, &mut pool_entity, &mut loser, &mut scenario);

    // Shares don't sum to 10000 → should abort
    let shares = vector[6000, 3000]; // = 9000, not 10000
    let mut winners = vector[w1, w2];
    let mut losers = vector[loser];

    wager_sys::settle_proportional(
        &cap, &mut pool_entity, &mut winners, shares, &mut losers, ts::ctx(&mut scenario),
    );

    abort 99
}

// ═══════════════════════════════════════════════
// 13. Fee Overflow — Large Pool
// ═══════════════════════════════════════════════

#[test]
fun test_fee_overflow_large_pool() {
    let mut scenario = ts::begin(PLAYER1);
    let clk = clock::create_for_testing(ts::ctx(&mut scenario));

    // 1 billion SUI (1e18 MIST) — stress tests u128 fee calc
    let huge_amount: u64 = 1_000_000_000_000_000_000;

    let (mut pool_entity, cap) = wager_sys::create_pool(
        huge_amount,
        2,
        250,
        FEE_RECIPIENT,
        wager_pool::payout_winner_all(),
        600_000,
        &clk,
        ts::ctx(&mut scenario),
    );

    let mut winner = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut loser = entity::new_for_testing(ts::ctx(&mut scenario));

    // Mint huge coins
    let pay1 = coin::mint_for_testing<SUI>(huge_amount, ts::ctx(&mut scenario));
    wager_sys::place_wager(&cap, &mut pool_entity, &mut winner, pay1, ts::ctx(&mut scenario));
    let pay2 = coin::mint_for_testing<SUI>(huge_amount, ts::ctx(&mut scenario));
    wager_sys::place_wager(&cap, &mut pool_entity, &mut loser, pay2, ts::ctx(&mut scenario));

    // Settle with fee — total = 2e18 MIST, fee = 2.5% = 5e16.
    // u64::MAX is ~1.8e19, so total * fee_bps = 2e18 * 250 = 5e20.
    // This overflows u64 but our u128-based calc handles it fine.
    let mut losers = vector[loser];
    wager_sys::settle_with_fee(
        &cap, &mut pool_entity, &mut winner, &mut losers, ts::ctx(&mut scenario),
    );

    // Pool empty
    let pool = wager_pool::borrow(&pool_entity);
    assert!(pool.pool_value() == 0);
    assert!(pool.is_settled());

    // Cleanup
    let l = losers.pop_back();
    losers.destroy_empty();
    cleanup_player(l);
    cleanup_player(winner);
    wager_sys::destroy_empty_pool(&cap, &mut pool_entity);
    wager_sys::destroy_cap(cap);
    pool_entity.destroy();
    clock::destroy_for_testing(clk);
    ts::end(scenario);
}

// ═══════════════════════════════════════════════
// 14. Pool Full — Can't Place More
// ═══════════════════════════════════════════════

#[test]
#[expected_failure(abort_code = 5)] // EPoolFull
fun test_pool_full() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool_entity, cap) = setup_pool(&mut scenario);
    let mut p1 = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut p2 = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut p3 = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut p1, &mut scenario);
    do_place_wager(&cap, &mut pool_entity, &mut p2, &mut scenario);
    // Pool is full (max 2), third wager should fail
    do_place_wager(&cap, &mut pool_entity, &mut p3, &mut scenario);

    abort 99
}

// ═══════════════════════════════════════════════
// 15. Refund Locked Player Fails
// ═══════════════════════════════════════════════

#[test]
#[expected_failure(abort_code = 7)] // EWagerNotPending
fun test_refund_locked_player_fails() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool_entity, cap) = setup_pool(&mut scenario);
    let mut p1 = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut p1, &mut scenario);

    // Lock
    let mut players = vector[p1];
    wager_sys::lock_wagers(&cap, &pool_entity, &mut players);
    let mut locked_p1 = players.pop_back();
    players.destroy_empty();

    // Try refund_player on a LOCKED wager → fails (only PENDING allowed)
    wager_sys::refund_player(
        &cap, &mut pool_entity, &mut locked_p1, ts::ctx(&mut scenario),
    );

    abort 99
}

// ═══════════════════════════════════════════════
// 16. Settle Winner With Cap Validation
// ═══════════════════════════════════════════════

#[test]
fun test_settle_with_cap() {
    let mut scenario = ts::begin(PLAYER1);
    let (mut pool_entity, cap) = setup_pool(&mut scenario);
    let mut winner = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut loser = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut winner, &mut scenario);
    do_place_wager(&cap, &mut pool_entity, &mut loser, &mut scenario);

    // Valid cap should succeed
    let mut losers = vector[loser];
    wager_sys::settle_winner(
        &cap, &mut pool_entity, &mut winner, &mut losers, ts::ctx(&mut scenario),
    );

    assert!(wager_pool::borrow(&pool_entity).is_settled());

    // Cleanup
    let l = losers.pop_back();
    losers.destroy_empty();
    cleanup_player(l);
    cleanup_player(winner);
    wager_sys::destroy_empty_pool(&cap, &mut pool_entity);
    wager_sys::destroy_cap(cap);
    pool_entity.destroy();
    ts::end(scenario);
}

// ═══════════════════════════════════════════════
// 17. Timeout Lobby Not Full
// ═══════════════════════════════════════════════

#[test]
#[expected_failure(abort_code = 9)] // ETimeoutNotExpired (used for lobby not full check too)
fun test_settle_timeout_lobby_not_full() {
    let mut scenario = ts::begin(PLAYER1);
    let mut clk = clock::create_for_testing(ts::ctx(&mut scenario));

    let (mut pool_entity, cap) = wager_sys::create_pool(
        WAGER_AMOUNT, 2, 250, FEE_RECIPIENT,
        wager_pool::payout_winner_all(), 600_000,
        &clk, ts::ctx(&mut scenario),
    );

    // Only 1 player out of 2 joined
    let mut winner = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut loser = entity::new_for_testing(ts::ctx(&mut scenario));

    do_place_wager(&cap, &mut pool_entity, &mut winner, &mut scenario);
    // Attach a wager to loser for the function assertion, but don't add to pool
    wager::add(&mut loser, wager::new(WAGER_AMOUNT, PLAYER2));

    // Advance past timeout
    clock::increment_for_testing(&mut clk, 600_001);

    // Only 1 player in pool (not full) → should abort with ETimeoutNotExpired
    wager_sys::settle_timeout(
        &cap, &mut pool_entity, &mut winner, &mut loser, &clk, ts::ctx(&mut scenario),
    );

    abort 99
}
