#[test_only]
module entity::entity_tests;

use sui::test_scenario::{Self as ts};
use sui::clock;
use std::ascii;

use entity::entity;

// ─── Test-only dummy component ──────────────────────────────────

public struct DummyComponent has store, copy, drop {
    value: u64,
}

public struct AnotherComponent has store, copy, drop {
    flag: bool,
}

// ─── Constants ──────────────────────────────────────────────────

const PLAYER1: address = @0x1;

// Component bits (mirror the constants from entity.move)
const BIT_POSITION: u256 = 1;
const BIT_HEALTH: u256 = 2;
const BIT_ATTACK: u256 = 4;

// ─── Tests ──────────────────────────────────────────────────────

#[test]
fun test_create_entity() {
    let mut scenario = ts::begin(PLAYER1);
    let clock = clock::create_for_testing(ts::ctx(&mut scenario));

    let entity = entity::new(
        ascii::string(b"player"),
        &clock,
        ts::ctx(&mut scenario),
    );

    // Verify initial state
    assert!(entity.entity_type() == ascii::string(b"player"));
    assert!(entity.component_mask() == 0);
    assert!(entity.created_at() == 0); // test clock starts at 0

    // Clean up
    entity.destroy();
    clock.destroy_for_testing();
    ts::end(scenario);
}

#[test]
fun test_add_and_borrow_component() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    let comp = DummyComponent { value: 42 };
    entity.add_component(BIT_POSITION, ascii::string(b"position"), comp);

    // Bitmask should now have bit 0 set
    assert!(entity.component_mask() == BIT_POSITION);

    // Borrow and verify
    let borrowed: &DummyComponent = entity.borrow_component(ascii::string(b"position"));
    assert!(borrowed.value == 42);

    // has_component should return true
    assert!(entity.has_component(BIT_POSITION));

    // has_component_by_key should return true
    assert!(entity.has_component_by_key(ascii::string(b"position")));

    // Clean up: remove component before destroy
    let _removed: DummyComponent = entity.remove_component(BIT_POSITION, ascii::string(b"position"));
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_borrow_mut_component() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    let comp = DummyComponent { value: 10 };
    entity.add_component(BIT_HEALTH, ascii::string(b"health"), comp);

    // Mutate
    let health: &mut DummyComponent = entity.borrow_mut_component(ascii::string(b"health"));
    health.value = 75;

    // Verify the mutation persisted
    let health_ref: &DummyComponent = entity.borrow_component(ascii::string(b"health"));
    assert!(health_ref.value == 75);

    // Clean up
    let _: DummyComponent = entity.remove_component(BIT_HEALTH, ascii::string(b"health"));
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_remove_component() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    entity.add_component(BIT_POSITION, ascii::string(b"position"), DummyComponent { value: 99 });
    assert!(entity.has_component(BIT_POSITION));

    let removed: DummyComponent = entity.remove_component(BIT_POSITION, ascii::string(b"position"));
    assert!(removed.value == 99);

    // Bitmask should be cleared
    assert!(!entity.has_component(BIT_POSITION));
    assert!(entity.component_mask() == 0);

    // Dynamic field should be gone
    assert!(!entity.has_component_by_key(ascii::string(b"position")));

    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_has_component_returns_false_when_absent() {
    let mut scenario = ts::begin(PLAYER1);
    let entity = entity::new_for_testing(ts::ctx(&mut scenario));

    assert!(!entity.has_component(BIT_POSITION));
    assert!(!entity.has_component(BIT_HEALTH));
    assert!(!entity.has_component_by_key(ascii::string(b"health")));

    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_multiple_components() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    // Add three components
    entity.add_component(BIT_POSITION, ascii::string(b"position"), DummyComponent { value: 1 });
    entity.add_component(BIT_HEALTH, ascii::string(b"health"), DummyComponent { value: 2 });
    entity.add_component(BIT_ATTACK, ascii::string(b"attack"), AnotherComponent { flag: true });

    // Verify all bits set
    assert!(entity.has_component(BIT_POSITION));
    assert!(entity.has_component(BIT_HEALTH));
    assert!(entity.has_component(BIT_ATTACK));

    // Multi-bit check (has BOTH position AND health)
    assert!(entity.has_component(BIT_POSITION | BIT_HEALTH));

    // Mask should be 1 | 2 | 4 = 7
    assert!(entity.component_mask() == 7);

    // Remove one
    let _: DummyComponent = entity.remove_component(BIT_HEALTH, ascii::string(b"health"));

    // Health gone, others remain
    assert!(!entity.has_component(BIT_HEALTH));
    assert!(entity.has_component(BIT_POSITION));
    assert!(entity.has_component(BIT_ATTACK));
    assert!(entity.component_mask() == 5); // 1 | 4

    // Clean up remaining
    let _: DummyComponent = entity.remove_component(BIT_POSITION, ascii::string(b"position"));
    let _: AnotherComponent = entity.remove_component(BIT_ATTACK, ascii::string(b"attack"));
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_destroy_entity() {
    let mut scenario = ts::begin(PLAYER1);
    let entity = entity::new_for_testing(ts::ctx(&mut scenario));

    // Destroying an entity with no components should not abort
    entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_entity_type_accessors() {
    // Verify the type constant accessors return expected values
    assert!(entity::player_type() == b"player");
    assert!(entity::npc_type() == b"npc");
    assert!(entity::item_type() == b"item");
    assert!(entity::tile_type() == b"tile");
    assert!(entity::grid_type() == b"grid");
    assert!(entity::projectile_type() == b"projectile");
}

#[test]
fun test_component_bit_accessors() {
    // Verify the bit constant accessors return expected values
    assert!(entity::position_bit() == 1);
    assert!(entity::health_bit() == 2);
    assert!(entity::attack_bit() == 4);
    assert!(entity::identity_bit() == 8);
    assert!(entity::movement_bit() == 16);
    assert!(entity::defense_bit() == 32);
    assert!(entity::team_bit() == 64);
    assert!(entity::zone_bit() == 128);
    assert!(entity::objective_bit() == 256);
    assert!(entity::energy_bit() == 512);
    assert!(entity::status_effect_bit() == 1024);
    assert!(entity::stats_bit() == 2048);
    assert!(entity::deck_bit() == 4096);
    assert!(entity::inventory_bit() == 8192);
    assert!(entity::relic_bit() == 16384);
    assert!(entity::gold_bit() == 32768);
    assert!(entity::map_progress_bit() == 65536);
    assert!(entity::marker_bit() == 131072);
}

#[test]
#[expected_failure(abort_code = 0, location = entity)]
fun test_add_duplicate_component_aborts() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    entity.add_component(BIT_POSITION, ascii::string(b"position"), DummyComponent { value: 1 });
    // Adding the same component bit again should abort
    entity.add_component(BIT_POSITION, ascii::string(b"position"), DummyComponent { value: 2 });

    // unreachable — clean up for compiler
    let _: DummyComponent = entity.remove_component(BIT_POSITION, ascii::string(b"position"));
    entity.destroy();
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 1, location = entity)]
fun test_remove_absent_component_aborts() {
    let mut scenario = ts::begin(PLAYER1);
    let mut entity = entity::new_for_testing(ts::ctx(&mut scenario));

    // Removing a component that was never added should abort
    let _: DummyComponent = entity.remove_component(BIT_POSITION, ascii::string(b"position"));

    entity.destroy();
    ts::end(scenario);
}
