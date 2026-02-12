#[test_only]
module systems::advanced_tests;

use sui::test_scenario::{Self as ts};
use std::ascii;

use entity::entity;
use components::position;
use components::identity;
use components::health;
use components::attack;
use components::defense;
use components::energy;
use components::status_effect;
use components::stats;
use components::deck;
use components::gold;
use components::inventory;
use components::map_progress;
use components::relic;

use systems::combat_sys;
use systems::status_effect_sys;
use systems::energy_sys;
use systems::card_sys;
use systems::encounter_sys;
use systems::reward_sys;
use systems::shop_sys;
use systems::map_sys;
use systems::relic_sys;

const PLAYER1: address = @0x1;

// ─── Combat System Tests ────────────────────

#[test]
fun test_combat_basic() {
    let mut scenario = ts::begin(PLAYER1);
    let mut attacker = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut defender = entity::new_for_testing(ts::ctx(&mut scenario));

    // Attacker: pos(0,0), hp=100, atk=20 range=1
    position::add(&mut attacker, position::new(0, 0));
    health::add(&mut attacker, health::new(100));
    attack::add(&mut attacker, attack::new(20, 1, 0));

    // Defender: pos(1,0), hp=50, no defense
    position::add(&mut defender, position::new(1, 0));
    health::add(&mut defender, health::new(50));

    let dmg = combat_sys::attack(&attacker, &mut defender);
    assert!(dmg == 20);

    let hp = health::borrow(&defender);
    assert!(hp.current() == 30);

    // Cleanup
    let _ = position::remove(&mut attacker);
    let _ = health::remove(&mut attacker);
    let _ = attack::remove(&mut attacker);
    let _ = position::remove(&mut defender);
    let _ = health::remove(&mut defender);
    attacker.destroy();
    defender.destroy();
    ts::end(scenario);
}

#[test]
fun test_combat_with_defense() {
    let mut scenario = ts::begin(PLAYER1);
    let mut attacker = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut defender = entity::new_for_testing(ts::ctx(&mut scenario));

    position::add(&mut attacker, position::new(0, 0));
    health::add(&mut attacker, health::new(100));
    attack::add(&mut attacker, attack::new(20, 1, 0));

    position::add(&mut defender, position::new(1, 0));
    health::add(&mut defender, health::new(50));
    defense::add(&mut defender, defense::new(5, 3)); // armor=5, block=3

    let dmg = combat_sys::attack(&attacker, &mut defender);
    // raw=20, block=3 → 17, armor=5 → 12
    assert!(dmg == 12);

    // Cleanup
    let _ = position::remove(&mut attacker);
    let _ = health::remove(&mut attacker);
    let _ = attack::remove(&mut attacker);
    let _ = position::remove(&mut defender);
    let _ = health::remove(&mut defender);
    let _ = defense::remove(&mut defender);
    attacker.destroy();
    defender.destroy();
    ts::end(scenario);
}

#[test]
fun test_combat_death() {
    let mut scenario = ts::begin(PLAYER1);
    let mut attacker = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut defender = entity::new_for_testing(ts::ctx(&mut scenario));

    position::add(&mut attacker, position::new(0, 0));
    health::add(&mut attacker, health::new(100));
    attack::add(&mut attacker, attack::new(100, 1, 0));

    position::add(&mut defender, position::new(1, 0));
    health::add(&mut defender, health::new(50));

    let dmg = combat_sys::attack(&attacker, &mut defender);
    assert!(dmg == 100);

    let hp = health::borrow(&defender);
    assert!(!hp.is_alive());

    // Cleanup
    let _ = position::remove(&mut attacker);
    let _ = health::remove(&mut attacker);
    let _ = attack::remove(&mut attacker);
    let _ = position::remove(&mut defender);
    let _ = health::remove(&mut defender);
    attacker.destroy();
    defender.destroy();
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 2)] // EOutOfRange
fun test_combat_out_of_range() {
    let mut scenario = ts::begin(PLAYER1);
    let mut attacker = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut defender = entity::new_for_testing(ts::ctx(&mut scenario));

    position::add(&mut attacker, position::new(0, 0));
    health::add(&mut attacker, health::new(100));
    attack::add(&mut attacker, attack::new(20, 1, 0)); // range=1

    position::add(&mut defender, position::new(5, 5)); // distance=10
    health::add(&mut defender, health::new(50));

    combat_sys::attack(&attacker, &mut defender); // should abort
    abort 99
}

// ─── Status Effect System Tests ─────────────

#[test]
fun test_status_effect_poison() {
    let mut scenario = ts::begin(PLAYER1);
    let mut e = entity::new_for_testing(ts::ctx(&mut scenario));

    health::add(&mut e, health::new(100));
    status_effect_sys::apply_effect(&mut e, status_effect::poison(), 5, 3);

    // Tick 1: 5 poison damage
    let dmg = status_effect_sys::tick_effects(&mut e);
    assert!(dmg == 5);
    let hp = health::borrow(&e);
    assert!(hp.current() == 95);

    // Tick 2
    let _dmg2 = status_effect_sys::tick_effects(&mut e);
    let hp2 = health::borrow(&e);
    assert!(hp2.current() == 90);

    // Tick 3 — duration becomes 0
    let _dmg3 = status_effect_sys::tick_effects(&mut e);

    // Remove expired
    let removed = status_effect_sys::remove_expired(&mut e);
    assert!(removed);

    // Cleanup
    let _ = health::remove(&mut e);
    e.destroy();
    ts::end(scenario);
}

// ─── Energy System Tests ────────────────────

#[test]
fun test_energy_spend_and_regen() {
    let mut scenario = ts::begin(PLAYER1);
    let mut e = entity::new_for_testing(ts::ctx(&mut scenario));

    energy::add(&mut e, energy::new(3, 1)); // max=3, regen=1

    assert!(energy_sys::has_enough_energy(&e, 2));
    energy_sys::spend_energy(&mut e, 2);

    let en = energy::borrow(&e);
    assert!(en.current() == 1);

    energy_sys::regenerate_energy(&mut e);
    let en2 = energy::borrow(&e);
    assert!(en2.current() == 2);

    // Cleanup
    let _ = energy::remove(&mut e);
    e.destroy();
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 0)] // ENotEnoughEnergy
fun test_energy_insufficient() {
    let mut scenario = ts::begin(PLAYER1);
    let mut e = entity::new_for_testing(ts::ctx(&mut scenario));

    energy::add(&mut e, energy::new(3, 1));
    energy_sys::spend_energy(&mut e, 5); // only have 3

    abort 99
}

// ─── Card System Tests ──────────────────────

#[test]
fun test_card_draw_and_play() {
    let mut scenario = ts::begin(PLAYER1);
    let mut e = entity::new_for_testing(ts::ctx(&mut scenario));

    let cards = vector[
        deck::new_card(ascii::string(b"Strike"), 1, 0, 0, 6),
        deck::new_card(ascii::string(b"Defend"), 1, 1, 1, 5),
    ];
    deck::add(&mut e, deck::new(cards));
    energy::add(&mut e, energy::new(3, 1));

    // Draw 2
    let drawn = card_sys::draw_cards(&mut e, 2);
    assert!(drawn == 2);

    let d = deck::borrow(&e);
    assert!(d.hand_size() == 2);
    assert!(d.draw_pile_size() == 0);

    // Play card at index 0 (Strike, cost=1)
    let card = card_sys::play_card(&mut e, 0);
    assert!(card.card_cost() == 1);

    let d2 = deck::borrow(&e);
    assert!(d2.hand_size() == 1);
    assert!(d2.discard_size() == 1);

    // Cleanup
    let _ = deck::remove(&mut e);
    let _ = energy::remove(&mut e);
    e.destroy();
    ts::end(scenario);
}

// ─── Encounter System Tests ─────────────────

#[test]
fun test_encounter_generation() {
    let mut scenario = ts::begin(PLAYER1);
    let clock = sui::clock::create_for_testing(ts::ctx(&mut scenario));

    let mut enemies = encounter_sys::generate_encounter(
        3, 2, &clock, ts::ctx(&mut scenario),
    );

    assert!(enemies.length() == 2);

    // Check floor scaling: hp = 20 + 3*10 = 50, dmg = 5 + 3*3 = 14
    let e1 = enemies.borrow(0);
    let hp = health::borrow(e1);
    assert!(hp.max() == 50);
    let atk = attack::borrow(e1);
    assert!(atk.damage() == 14);

    // Cleanup: destroy each enemy
    while (!enemies.is_empty()) {
        let mut e = enemies.pop_back();
        let _ = position::remove(&mut e);
        let _ = identity::remove(&mut e);
        let _ = health::remove(&mut e);
        let _ = attack::remove(&mut e);
        e.destroy();
    };
    enemies.destroy_empty();

    clock.destroy_for_testing();
    ts::end(scenario);
}

// ─── Reward System Tests ────────────────────

#[test]
fun test_reward_gold() {
    let mut scenario = ts::begin(PLAYER1);
    let mut e = entity::new_for_testing(ts::ctx(&mut scenario));

    gold::add(&mut e, gold::new(50));
    reward_sys::grant_gold(&mut e, 30);

    let g = gold::borrow(&e);
    assert!(g.amount() == 80);

    // Cleanup
    let _ = gold::remove(&mut e);
    e.destroy();
    ts::end(scenario);
}

#[test]
fun test_reward_card() {
    let mut scenario = ts::begin(PLAYER1);
    let mut e = entity::new_for_testing(ts::ctx(&mut scenario));

    deck::add(&mut e, deck::new(vector[]));
    let card = deck::new_card(ascii::string(b"Fireball"), 2, 0, 0, 15);
    reward_sys::grant_card(&mut e, card);

    let d = deck::borrow(&e);
    assert!(d.draw_pile_size() == 1);

    let _ = deck::remove(&mut e);
    e.destroy();
    ts::end(scenario);
}

// ─── Shop System Tests ──────────────────────

#[test]
fun test_shop_buy_card() {
    let mut scenario = ts::begin(PLAYER1);
    let mut e = entity::new_for_testing(ts::ctx(&mut scenario));

    gold::add(&mut e, gold::new(100));
    deck::add(&mut e, deck::new(vector[]));

    let card = deck::new_card(ascii::string(b"Lightning"), 2, 0, 0, 20);
    shop_sys::buy_card(&mut e, card, 50);

    let g = gold::borrow(&e);
    assert!(g.amount() == 50);

    let d = deck::borrow(&e);
    assert!(d.draw_pile_size() == 1);

    let _ = gold::remove(&mut e);
    let _ = deck::remove(&mut e);
    e.destroy();
    ts::end(scenario);
}

#[test]
fun test_shop_buy_relic() {
    let mut scenario = ts::begin(PLAYER1);
    let mut e = entity::new_for_testing(ts::ctx(&mut scenario));

    gold::add(&mut e, gold::new(100));
    inventory::add(&mut e, inventory::new(5));

    shop_sys::buy_relic(&mut e, 1, 10, 30);

    let g = gold::borrow(&e);
    assert!(g.amount() == 70);

    let inv = inventory::borrow(&e);
    assert!(inv.count() == 1);

    let _ = gold::remove(&mut e);
    let _ = inventory::remove(&mut e);
    e.destroy();
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 0)] // ENotEnoughGold
fun test_shop_not_enough_gold() {
    let mut scenario = ts::begin(PLAYER1);
    let mut e = entity::new_for_testing(ts::ctx(&mut scenario));

    gold::add(&mut e, gold::new(10));
    deck::add(&mut e, deck::new(vector[]));

    let card = deck::new_card(ascii::string(b"Expensive"), 3, 0, 0, 50);
    shop_sys::buy_card(&mut e, card, 100); // only have 10

    abort 99
}

// ─── Map System Tests ───────────────────────

#[test]
fun test_map_progression() {
    let mut scenario = ts::begin(PLAYER1);
    let mut e = entity::new_for_testing(ts::ctx(&mut scenario));

    map_progress::add(&mut e, map_progress::new());

    assert!(map_sys::current_floor(&e) == 0);

    map_sys::choose_path(&mut e, 2);
    assert!(map_sys::current_node(&e) == 2);

    map_sys::advance_floor(&mut e);
    assert!(map_sys::current_floor(&e) == 1);
    assert!(map_sys::current_node(&e) == 0); // reset after floor advance

    // Cleanup
    let _ = map_progress::remove(&mut e);
    e.destroy();
    ts::end(scenario);
}

// ─── Relic System Tests ─────────────────────

#[test]
fun test_relic_flat_bonus() {
    let mut scenario = ts::begin(PLAYER1);
    let mut e = entity::new_for_testing(ts::ctx(&mut scenario));

    stats::add(&mut e, stats::new(10, 10, 10));
    relic_sys::add_relic(&mut e, 0, 0, 5); // flat +5

    let bonus = relic_sys::apply_relic_bonus(&mut e);
    assert!(bonus == 5);

    let s = stats::borrow(&e);
    assert!(s.strength() == 15);

    // Cleanup
    relic_sys::remove_relic(&mut e);
    let _ = stats::remove(&mut e);
    e.destroy();
    ts::end(scenario);
}

#[test]
fun test_relic_percent_bonus() {
    let mut scenario = ts::begin(PLAYER1);
    let mut e = entity::new_for_testing(ts::ctx(&mut scenario));

    stats::add(&mut e, stats::new(100, 10, 10));
    relic_sys::add_relic(&mut e, 0, 1, 20); // 20% strength

    let bonus = relic_sys::apply_relic_bonus(&mut e);
    assert!(bonus == 20); // 100 * 20 / 100

    let s = stats::borrow(&e);
    assert!(s.strength() == 120);

    relic_sys::remove_relic(&mut e);
    let _ = stats::remove(&mut e);
    e.destroy();
    ts::end(scenario);
}
