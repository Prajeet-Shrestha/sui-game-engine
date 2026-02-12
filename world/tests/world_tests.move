#[test_only]
module world::world_tests;

use std::ascii;
use sui::test_scenario as ts;
use sui::clock;
use world::world;

// Component imports for cleanup
use components::position;
use components::identity;
use components::health;
use components::attack;
use components::team;
use components::marker;

const CREATOR: address = @0xC0FFEE;
const OTHER: address = @0xBEEF;

// ─── Helper: destroy a player entity ────────

fun destroy_player(mut e: entity::entity::Entity) {
    let _ = position::remove(&mut e);
    let _ = identity::remove(&mut e);
    let _ = health::remove(&mut e);
    let _ = team::remove(&mut e);
    e.destroy();
}

fun destroy_npc(mut e: entity::entity::Entity) {
    let _ = position::remove(&mut e);
    let _ = identity::remove(&mut e);
    let _ = health::remove(&mut e);
    let _ = attack::remove(&mut e);
    e.destroy();
}

fun destroy_tile(mut e: entity::entity::Entity) {
    let _ = position::remove(&mut e);
    let _ = marker::remove(&mut e);
    e.destroy();
}

// ─── World Creation ─────────────────────────

#[test]
fun test_create_world() {
    let mut scenario = ts::begin(CREATOR);
    let name = ascii::string(b"TestGame");
    let w = world::create_for_testing(name, 100, ts::ctx(&mut scenario));
    
    assert!(world::name(&w) == ascii::string(b"TestGame"));
    assert!(world::version(&w) == 1);
    assert!(world::creator(&w) == CREATOR);
    assert!(!world::is_paused(&w));
    assert!(world::entity_count(&w) == 0);
    assert!(world::max_entities(&w) == 100);
    
    world::destroy(w, ts::ctx(&mut scenario));
    ts::end(scenario);
}

// ─── Pause / Resume ─────────────────────────

#[test]
fun test_pause_resume() {
    let mut scenario = ts::begin(CREATOR);
    let mut w = world::create_for_testing(ascii::string(b"PauseTest"), 10, ts::ctx(&mut scenario));
    
    assert!(!world::is_paused(&w));
    
    world::pause(&mut w, ts::ctx(&mut scenario));
    assert!(world::is_paused(&w));
    
    world::resume(&mut w, ts::ctx(&mut scenario));
    assert!(!world::is_paused(&w));
    
    world::destroy(w, ts::ctx(&mut scenario));
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 2)] // ENotCreator
fun test_pause_non_creator_fails() {
    let mut scenario = ts::begin(CREATOR);
    let mut w = world::create_for_testing(ascii::string(b"PauseTest"), 10, ts::ctx(&mut scenario));
    
    // Switch to a different sender
    ts::next_tx(&mut scenario, OTHER);
    world::pause(&mut w, ts::ctx(&mut scenario));
    
    abort 99 // unreachable
}

// ─── Spawn Through World ────────────────────

#[test]
fun test_spawn_player_increments_count() {
    let mut scenario = ts::begin(CREATOR);
    let mut w = world::create_for_testing(ascii::string(b"SpawnTest"), 10, ts::ctx(&mut scenario));
    let clk = clock::create_for_testing(ts::ctx(&mut scenario));
    
    assert!(world::entity_count(&w) == 0);
    
    let e = world::spawn_player(
        &mut w,
        ascii::string(b"Hero"),
        0, 0, 100, 1,
        &clk, ts::ctx(&mut scenario),
    );
    
    assert!(world::entity_count(&w) == 1);
    
    destroy_player(e);
    clock::destroy_for_testing(clk);
    world::destroy(w, ts::ctx(&mut scenario));
    ts::end(scenario);
}

#[test]
fun test_spawn_npc_increments_count() {
    let mut scenario = ts::begin(CREATOR);
    let mut w = world::create_for_testing(ascii::string(b"SpawnTest"), 10, ts::ctx(&mut scenario));
    let clk = clock::create_for_testing(ts::ctx(&mut scenario));
    
    let e = world::spawn_npc(
        &mut w,
        ascii::string(b"Goblin"),
        1, 1, 50, 10, 1,
        &clk, ts::ctx(&mut scenario),
    );
    
    assert!(world::entity_count(&w) == 1);
    
    destroy_npc(e);
    clock::destroy_for_testing(clk);
    world::destroy(w, ts::ctx(&mut scenario));
    ts::end(scenario);
}

#[test]
fun test_spawn_tile_increments_count() {
    let mut scenario = ts::begin(CREATOR);
    let mut w = world::create_for_testing(ascii::string(b"SpawnTest"), 10, ts::ctx(&mut scenario));
    let clk = clock::create_for_testing(ts::ctx(&mut scenario));
    
    let e = world::spawn_tile(&mut w, 0, 0, 1, &clk, ts::ctx(&mut scenario));
    
    assert!(world::entity_count(&w) == 1);
    
    destroy_tile(e);
    clock::destroy_for_testing(clk);
    world::destroy(w, ts::ctx(&mut scenario));
    ts::end(scenario);
}

#[test]
fun test_multiple_spawns() {
    let mut scenario = ts::begin(CREATOR);
    let mut w = world::create_for_testing(ascii::string(b"SpawnTest"), 10, ts::ctx(&mut scenario));
    let clk = clock::create_for_testing(ts::ctx(&mut scenario));
    
    let e1 = world::spawn_player(&mut w, ascii::string(b"P1"), 0, 0, 100, 1, &clk, ts::ctx(&mut scenario));
    let e2 = world::spawn_player(&mut w, ascii::string(b"P2"), 1, 0, 100, 2, &clk, ts::ctx(&mut scenario));
    let e3 = world::spawn_npc(&mut w, ascii::string(b"NPC"), 2, 0, 50, 10, 1, &clk, ts::ctx(&mut scenario));
    
    assert!(world::entity_count(&w) == 3);
    
    destroy_player(e1);
    destroy_player(e2);
    destroy_npc(e3);
    clock::destroy_for_testing(clk);
    world::destroy(w, ts::ctx(&mut scenario));
    ts::end(scenario);
}

// ─── Max Entities ───────────────────────────

#[test]
#[expected_failure(abort_code = 1)] // EMaxEntities
fun test_max_entities_exceeded() {
    let mut scenario = ts::begin(CREATOR);
    let mut w = world::create_for_testing(ascii::string(b"MaxTest"), 2, ts::ctx(&mut scenario));
    let clk = clock::create_for_testing(ts::ctx(&mut scenario));
    
    let _e1 = world::spawn_player(&mut w, ascii::string(b"P1"), 0, 0, 100, 1, &clk, ts::ctx(&mut scenario));
    let _e2 = world::spawn_player(&mut w, ascii::string(b"P2"), 1, 0, 100, 2, &clk, ts::ctx(&mut scenario));
    // This should abort — max = 2
    let _e3 = world::spawn_player(&mut w, ascii::string(b"P3"), 2, 0, 100, 1, &clk, ts::ctx(&mut scenario));
    
    abort 99 // unreachable
}

// ─── Pause Blocks Operations ────────────────

#[test]
#[expected_failure(abort_code = 0)] // EWorldPaused
fun test_spawn_while_paused_fails() {
    let mut scenario = ts::begin(CREATOR);
    let mut w = world::create_for_testing(ascii::string(b"PauseTest"), 10, ts::ctx(&mut scenario));
    let clk = clock::create_for_testing(ts::ctx(&mut scenario));
    
    world::pause(&mut w, ts::ctx(&mut scenario));
    
    // This should abort — world is paused
    let _e = world::spawn_player(&mut w, ascii::string(b"P1"), 0, 0, 100, 1, &clk, ts::ctx(&mut scenario));
    
    abort 99 // unreachable
}

#[test]
#[expected_failure(abort_code = 0)] // EWorldPaused
fun test_grid_while_paused_fails() {
    let mut scenario = ts::begin(CREATOR);
    let mut w = world::create_for_testing(ascii::string(b"PauseTest"), 10, ts::ctx(&mut scenario));
    
    world::pause(&mut w, ts::ctx(&mut scenario));
    
    // This should abort — world is paused
    let _grid = world::create_grid(&w, 4, 4, ts::ctx(&mut scenario));
    
    abort 99 // unreachable
}

// ─── Grid Through World ─────────────────────

#[test]
fun test_grid_through_world() {
    let mut scenario = ts::begin(CREATOR);
    let mut w = world::create_for_testing(ascii::string(b"GridTest"), 10, ts::ctx(&mut scenario));
    let clk = clock::create_for_testing(ts::ctx(&mut scenario));
    
    let mut grid = world::create_grid(&w, 4, 4, ts::ctx(&mut scenario));
    let e = world::spawn_player(&mut w, ascii::string(b"P1"), 0, 0, 100, 1, &clk, ts::ctx(&mut scenario));
    
    world::place(&w, &mut grid, object::id(&e), 0, 0);
    
    let removed_id = world::remove_from_grid(&w, &mut grid, 0, 0);
    assert!(removed_id == object::id(&e));
    
    // Cleanup
    systems::grid_sys::destroy_empty(grid);
    destroy_player(e);
    clock::destroy_for_testing(clk);
    world::destroy(w, ts::ctx(&mut scenario));
    ts::end(scenario);
}

// ─── Turn State Through World ───────────────

#[test]
fun test_turns_through_world() {
    let mut scenario = ts::begin(CREATOR);
    let w = world::create_for_testing(ascii::string(b"TurnTest"), 10, ts::ctx(&mut scenario));
    
    let mut state = world::create_turn_state(&w, 2, world::mode_simple(), ts::ctx(&mut scenario));
    
    assert!(systems::turn_sys::current_player(&state) == 0);
    
    world::end_turn(&w, &mut state);
    assert!(systems::turn_sys::current_player(&state) == 1);
    
    world::end_turn(&w, &mut state);
    assert!(systems::turn_sys::current_player(&state) == 0);
    
    // Cleanup
    systems::turn_sys::destroy(state);
    world::destroy(w, ts::ctx(&mut scenario));
    ts::end(scenario);
}

// ─── Combat Through World ───────────────────

#[test]
fun test_combat_through_world() {
    let mut scenario = ts::begin(CREATOR);
    let mut w = world::create_for_testing(ascii::string(b"CombatTest"), 10, ts::ctx(&mut scenario));
    let clk = clock::create_for_testing(ts::ctx(&mut scenario));
    
    // Use two NPCs (they have attack components)
    let attacker = world::spawn_npc(&mut w, ascii::string(b"A"), 0, 0, 100, 20, 1, &clk, ts::ctx(&mut scenario));
    let mut defender = world::spawn_npc(&mut w, ascii::string(b"D"), 1, 0, 50, 5, 1, &clk, ts::ctx(&mut scenario));
    
    let dmg = world::attack(&w, &attacker, &mut defender);
    assert!(dmg == 20);
    
    let hp = health::borrow(&defender);
    assert!(hp.current() == 30);
    
    destroy_npc(attacker);
    destroy_npc(defender);
    clock::destroy_for_testing(clk);
    world::destroy(w, ts::ctx(&mut scenario));
    ts::end(scenario);
}

// ─── Win Condition Through World ────────────

#[test]
fun test_win_condition_through_world() {
    let mut scenario = ts::begin(CREATOR);
    let mut w = world::create_for_testing(ascii::string(b"WinTest"), 10, ts::ctx(&mut scenario));
    let clk = clock::create_for_testing(ts::ctx(&mut scenario));
    
    let e = world::spawn_player(&mut w, ascii::string(b"P1"), 0, 0, 100, 1, &clk, ts::ctx(&mut scenario));
    
    assert!(!world::check_elimination(&e));
    
    // Declare winner
    world::declare_winner(&w, object::id(&e), world::condition_elimination(), &clk);
    
    destroy_player(e);
    clock::destroy_for_testing(clk);
    world::destroy(w, ts::ctx(&mut scenario));
    ts::end(scenario);
}
