#[test_only]
module components::components_tests;

use sui::test_scenario::{Self as ts};
use std::ascii;

use entity::entity;
use components::position;
use components::identity;
use components::health;
use components::marker;
use components::movement;
use components::defense;
use components::team;
use components::zone;
use components::objective;
use components::attack;
use components::energy;
use components::status_effect;
use components::stats;
use components::deck;
use components::inventory;
use components::relic;
use components::gold;
use components::map_progress;

// ─── Constants ──────────────────────────────

const PLAYER1: address = @0x1;

// ─── Tier 1 Tests ───────────────────────────

#[test]
fun test_position() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    let pos = position::new(3, 7);
    position::add(&mut entity, pos);

    assert!(entity.has_component(entity::position_bit()));
    let p = position::borrow(&entity);
    assert!(p.x() == 3);
    assert!(p.y() == 7);

    // Mutate
    let pm = position::borrow_mut(&mut entity);
    pm.set(10, 20);
    let p2 = position::borrow(&entity);
    assert!(p2.x() == 10 && p2.y() == 20);

    let _ = position::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_identity() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    let id = identity::new(ascii::string(b"hero"), 0);
    identity::add(&mut entity, id);

    let i = identity::borrow(&entity);
    assert!(i.name() == ascii::string(b"hero"));
    assert!(i.get_entity_type() == 0);

    let _ = identity::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_health() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    health::add(&mut entity, health::new(100));
    let h = health::borrow_mut(&mut entity);
    assert!(h.current() == 100 && h.max() == 100);
    assert!(h.is_alive());

    h.take_damage(30);
    assert!(h.current() == 70);
    h.heal(10);
    assert!(h.current() == 80);
    h.take_damage(200); // overkill
    assert!(h.current() == 0);
    assert!(!h.is_alive());

    let _ = health::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_marker() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    marker::add(&mut entity, marker::new(1));
    let m = marker::borrow(&entity);
    assert!(m.symbol() == 1);

    let _ = marker::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

// ─── Tier 2 Tests ───────────────────────────

#[test]
fun test_movement() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    movement::add(&mut entity, movement::new(3, movement::pattern_walk()));
    let m = movement::borrow(&entity);
    assert!(m.speed() == 3);
    assert!(m.move_pattern() == 0);

    let _ = movement::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_defense() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    defense::add(&mut entity, defense::new(10, 5));
    let d = defense::borrow(&entity);
    // 20 damage → block 5 → 15 → armor absorbs 10 → 5 through
    assert!(d.reduce_damage(20) == 5);
    // 3 damage → block 3 → 0 through
    assert!(d.reduce_damage(3) == 0);

    let _ = defense::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_team() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    team::add(&mut entity, team::new(1));
    let t = team::borrow(&entity);
    assert!(t.team_id() == 1);

    let t2 = team::new(1);
    let t3 = team::new(2);
    assert!(team::same_team(t, &t2));
    assert!(!team::same_team(t, &t3));

    let _ = team::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_zone() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    zone::add(&mut entity, zone::new(zone::zone_control_point()));
    let z = zone::borrow_mut(&mut entity);
    assert!(!z.is_controlled());
    z.set_controlled_by(1);
    z.set_capture_progress(50);
    assert!(z.is_controlled());
    assert!(z.capture_progress() == 50);

    let _ = zone::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_objective() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    objective::add(&mut entity, objective::new(objective::flag_type(), 5, 5));
    let o = objective::borrow_mut(&mut entity);
    assert!(!o.is_held());
    assert!(o.origin_x() == 5 && o.origin_y() == 5);

    let _ = objective::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

// ─── Tier 3 Tests ───────────────────────────

#[test]
fun test_attack() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    attack::add(&mut entity, attack::new(15, 2, 1000));
    let a = attack::borrow(&entity);
    assert!(a.damage() == 15);
    assert!(a.range() == 2);
    assert!(a.cooldown_ms() == 1000);

    let _ = attack::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_energy() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    energy::add(&mut entity, energy::new(3, 1));
    let e = energy::borrow_mut(&mut entity);
    assert!(e.current() == 3 && e.max() == 3);
    assert!(e.has_enough(2));

    e.spend(2);
    assert!(e.current() == 1);
    e.regenerate();
    assert!(e.current() == 2);

    let _ = energy::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_status_effect() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    status_effect::add(&mut entity, status_effect::new(status_effect::poison(), 3, 2));
    let se = status_effect::borrow_mut(&mut entity);
    assert!(se.effect_type() == 0);
    assert!(se.stacks() == 3);
    assert!(se.duration() == 2);
    assert!(!se.is_expired());

    se.tick();
    assert!(se.duration() == 1);
    se.tick();
    assert!(se.is_expired());

    let _ = status_effect::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_stats() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    stats::add(&mut entity, stats::new(10, 8, 5));
    let s = stats::borrow_mut(&mut entity);
    assert!(s.strength() == 10);
    s.add_strength(5);
    assert!(s.strength() == 15);

    let _ = stats::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

// ─── Tier 4 Tests ───────────────────────────

#[test]
fun test_deck() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    let cards = vector[
        deck::new_card(ascii::string(b"Strike"), 1, 0, 0, 6),
        deck::new_card(ascii::string(b"Defend"), 1, 1, 1, 5),
    ];
    deck::add(&mut entity, deck::new(cards));

    let d = deck::borrow_mut(&mut entity);
    assert!(d.draw_pile_size() == 2);
    assert!(d.hand_size() == 0);

    // Draw
    assert!(d.draw());
    assert!(d.hand_size() == 1);
    assert!(d.draw_pile_size() == 1);

    // Play card from hand
    let played = d.play_card(0);
    assert!(played.card_name() == ascii::string(b"Defend"));
    assert!(d.hand_size() == 0);

    // Add to discard and reshuffle
    d.add_to_discard(played);
    assert!(d.discard_size() == 1);
    d.reshuffle();
    assert!(d.discard_size() == 0);
    assert!(d.draw_pile_size() == 2); // original 1 + reshuffled 1

    let _ = deck::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_inventory() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    inventory::add(&mut entity, inventory::new(3));
    let inv = inventory::borrow_mut(&mut entity);
    assert!(inv.count() == 0);
    assert!(!inv.is_full());

    inv.add_item(inventory::new_item(0, 10));
    inv.add_item(inventory::new_item(1, 20));
    assert!(inv.count() == 2);

    let removed = inv.remove_item(0);
    assert!(removed.item_value() == 10);
    assert!(inv.count() == 1);

    let _ = inventory::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_relic() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    relic::add(&mut entity, relic::new(1, 0, 10));
    let r = relic::borrow(&entity);
    assert!(r.relic_type() == 1);
    assert!(r.modifier_value() == 10);

    let _ = relic::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_gold() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    gold::add(&mut entity, gold::new(50));
    let g = gold::borrow_mut(&mut entity);
    assert!(g.amount() == 50);
    assert!(g.has_enough(30));

    g.earn(20);
    assert!(g.amount() == 70);
    g.spend(70);
    assert!(g.amount() == 0);

    let _ = gold::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_map_progress() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    map_progress::add(&mut entity, map_progress::new());
    let mp = map_progress::borrow_mut(&mut entity);
    assert!(mp.current_floor() == 0);
    assert!(mp.current_node() == 0);

    mp.choose_path(2);
    assert!(mp.current_node() == 2);
    mp.advance_floor();
    assert!(mp.current_floor() == 1);
    assert!(mp.current_node() == 0);

    let _ = map_progress::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}

// ─── Multi-Component Integration Test ───────

#[test]
fun test_full_player_entity() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    // Attach core components
    position::add(&mut entity, position::new(0, 0));
    health::add(&mut entity, health::new(100));
    attack::add(&mut entity, attack::new(10, 1, 0));
    defense::add(&mut entity, defense::new(5, 0));
    team::add(&mut entity, team::new(1));
    stats::add(&mut entity, stats::new(10, 10, 10));

    // Verify mask has all bits
    let expected = entity::position_bit()
        | entity::health_bit()
        | entity::attack_bit()
        | entity::defense_bit()
        | entity::team_bit()
        | entity::stats_bit();
    assert!(entity.has_component(expected));

    // Clean up
    let _ = position::remove(&mut entity);
    let _ = health::remove(&mut entity);
    let _ = attack::remove(&mut entity);
    let _ = defense::remove(&mut entity);
    let _ = team::remove(&mut entity);
    let _ = stats::remove(&mut entity);
    entity.destroy();
    ts::end(scenario);
}
