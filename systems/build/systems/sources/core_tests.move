#[test_only]
module systems::core_tests;

use sui::test_scenario::{Self as ts};
use std::ascii;

use entity::entity;
use components::position;
use components::identity;
use components::health;
use components::attack;
use components::team;
use components::marker;
use components::movement;
use components::zone;
use components::objective;

use systems::spawn_sys;
use systems::grid_sys;
use systems::turn_sys;
use systems::win_condition_sys;
use systems::movement_sys;
use systems::swap_sys;
use systems::capture_sys;
use systems::objective_sys;
use systems::territory_sys;

const PLAYER1: address = @0x1;

// ─── Spawn System Tests ─────────────────────

#[test]
fun test_spawn_player() {
    let mut scenario = ts::begin(PLAYER1);
    let clock = sui::clock::create_for_testing(ts::ctx(&mut scenario));

    let mut e = spawn_sys::spawn_player(
        ascii::string(b"hero"),
        5, 3, 100, 1,
        &clock, ts::ctx(&mut scenario),
    );

    // Verify components
    let p = position::borrow(&e);
    assert!(p.x() == 5 && p.y() == 3);
    let h = health::borrow(&e);
    assert!(h.max() == 100);
    let t = team::borrow(&e);
    assert!(t.team_id() == 1);

    // Cleanup
    let _ = position::remove(&mut e);
    let _ = identity::remove(&mut e);
    let _ = health::remove(&mut e);
    let _ = team::remove(&mut e);
    e.destroy();
    clock.destroy_for_testing();
    ts::end(scenario);
}

#[test]
fun test_spawn_npc() {
    let mut scenario = ts::begin(PLAYER1);
    let clock = sui::clock::create_for_testing(ts::ctx(&mut scenario));

    let mut e = spawn_sys::spawn_npc(
        ascii::string(b"goblin"),
        2, 4, 50, 10, 1,
        &clock, ts::ctx(&mut scenario),
    );

    let a = attack::borrow(&e);
    assert!(a.damage() == 10 && a.range() == 1);

    let _ = position::remove(&mut e);
    let _ = identity::remove(&mut e);
    let _ = health::remove(&mut e);
    let _ = attack::remove(&mut e);
    e.destroy();
    clock.destroy_for_testing();
    ts::end(scenario);
}

#[test]
fun test_spawn_tile() {
    let mut scenario = ts::begin(PLAYER1);
    let clock = sui::clock::create_for_testing(ts::ctx(&mut scenario));

    let mut e = spawn_sys::spawn_tile(1, 1, 88, &clock, ts::ctx(&mut scenario));

    let m = marker::borrow(&e);
    assert!(m.symbol() == 88);

    let _ = position::remove(&mut e);
    let _ = marker::remove(&mut e);
    e.destroy();
    clock.destroy_for_testing();
    ts::end(scenario);
}

// ─── Grid System Tests ──────────────────────

#[test]
fun test_grid_place_and_query() {
    let mut scenario = ts::begin(PLAYER1);
    let mut grid = grid_sys::create_for_testing(3, 3, ts::ctx(&mut scenario));
    let entity = entity::new_for_testing(ts::ctx(&mut scenario));
    let eid = object::id(&entity);

    grid_sys::place(&mut grid, eid, 1, 2);
    assert!(grid_sys::is_occupied(&grid, 1, 2));
    assert!(!grid_sys::is_occupied(&grid, 0, 0));
    assert!(grid_sys::get_entity_at(&grid, 1, 2) == eid);
    assert!(grid_sys::occupied_count(&grid) == 1);

    let removed = grid_sys::remove(&mut grid, 1, 2);
    assert!(removed == eid);
    assert!(!grid_sys::is_occupied(&grid, 1, 2));
    assert!(grid_sys::occupied_count(&grid) == 0);

    entity.destroy();
    grid_sys::destroy_empty(grid);
    ts::end(scenario);
}

#[test]
fun test_grid_move_on_grid() {
    let mut scenario = ts::begin(PLAYER1);
    let mut grid = grid_sys::create_for_testing(5, 5, ts::ctx(&mut scenario));
    let entity = entity::new_for_testing(ts::ctx(&mut scenario));
    let eid = object::id(&entity);

    grid_sys::place(&mut grid, eid, 0, 0);
    grid_sys::move_on_grid(&mut grid, eid, 0, 0, 3, 4);

    assert!(!grid_sys::is_occupied(&grid, 0, 0));
    assert!(grid_sys::is_occupied(&grid, 3, 4));
    assert!(grid_sys::get_entity_at(&grid, 3, 4) == eid);

    grid_sys::remove(&mut grid, 3, 4);
    entity.destroy();
    grid_sys::destroy_empty(grid);
    ts::end(scenario);
}

#[test]
fun test_grid_is_full() {
    let mut scenario = ts::begin(PLAYER1);
    let mut grid = grid_sys::create_for_testing(2, 1, ts::ctx(&mut scenario));
    let e1 = entity::new_for_testing(ts::ctx(&mut scenario));
    let e2 = entity::new_for_testing(ts::ctx(&mut scenario));
    let eid1 = object::id(&e1);
    let eid2 = object::id(&e2);

    assert!(!grid_sys::is_full(&grid));

    grid_sys::place(&mut grid, eid1, 0, 0);
    assert!(!grid_sys::is_full(&grid));

    grid_sys::place(&mut grid, eid2, 1, 0);
    assert!(grid_sys::is_full(&grid));

    grid_sys::remove(&mut grid, 0, 0);
    grid_sys::remove(&mut grid, 1, 0);
    e1.destroy();
    e2.destroy();
    grid_sys::destroy_empty(grid);
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 0)] // EOutOfBounds
fun test_grid_out_of_bounds() {
    let mut scenario = ts::begin(PLAYER1);
    let mut grid = grid_sys::create_for_testing(3, 3, ts::ctx(&mut scenario));
    let entity = entity::new_for_testing(ts::ctx(&mut scenario));

    grid_sys::place(&mut grid, object::id(&entity), 5, 5); // out of bounds

    abort 99 // should not reach
}

// ─── Turn System Tests ──────────────────────

#[test]
fun test_turn_simple_mode() {
    let mut scenario = ts::begin(PLAYER1);
    let mut state = turn_sys::create_for_testing(2, turn_sys::mode_simple(), ts::ctx(&mut scenario));

    assert!(turn_sys::current_player(&state) == 0);
    assert!(turn_sys::turn_number(&state) == 0);

    turn_sys::end_turn(&mut state);
    assert!(turn_sys::current_player(&state) == 1);
    assert!(turn_sys::turn_number(&state) == 1);

    turn_sys::end_turn(&mut state);
    assert!(turn_sys::current_player(&state) == 0);
    assert!(turn_sys::turn_number(&state) == 2);

    turn_sys::destroy(state);
    ts::end(scenario);
}

#[test]
fun test_turn_phase_mode() {
    let mut scenario = ts::begin(PLAYER1);
    let mut state = turn_sys::create_for_testing(2, turn_sys::mode_phase(), ts::ctx(&mut scenario));

    assert!(turn_sys::phase(&state) == turn_sys::phase_draw());

    turn_sys::advance_phase(&mut state);
    assert!(turn_sys::phase(&state) == turn_sys::phase_play());

    turn_sys::advance_phase(&mut state);
    assert!(turn_sys::phase(&state) == turn_sys::phase_combat());

    turn_sys::advance_phase(&mut state);
    assert!(turn_sys::phase(&state) == turn_sys::phase_end());

    // Now end_turn should work (phase == END)
    turn_sys::end_turn(&mut state);
    assert!(turn_sys::current_player(&state) == 1);
    assert!(turn_sys::phase(&state) == turn_sys::phase_draw()); // reset to draw

    turn_sys::destroy(state);
    ts::end(scenario);
}

// ─── Win Condition System Tests ─────────────

#[test]
fun test_win_condition_elimination() {
    let mut scenario = ts::begin(PLAYER1);
    let mut e = entity::new_for_testing(ts::ctx(&mut scenario));

    health::add(&mut e, health::new(50));

    // Alive — not eliminated
    assert!(!win_condition_sys::check_elimination(&e));

    // Take fatal damage
    let h = health::borrow_mut(&mut e);
    h.take_damage(50);
    assert!(win_condition_sys::check_elimination(&e));

    let _ = health::remove(&mut e);
    e.destroy();
    ts::end(scenario);
}

// ─── Movement System Tests ──────────────────

#[test]
fun test_movement_walk() {
    let mut scenario = ts::begin(PLAYER1);
    let mut grid = grid_sys::create_for_testing(5, 5, ts::ctx(&mut scenario));
    let mut e = entity::new_for_testing(ts::ctx(&mut scenario));

    position::add(&mut e, position::new(0, 0));
    movement::add(&mut e, movement::new(3, movement::pattern_walk()));
    grid_sys::place(&mut grid, object::id(&e), 0, 0);

    movement_sys::move_entity(&mut e, &mut grid, 2, 1);

    let p = position::borrow(&e);
    assert!(p.x() == 2 && p.y() == 1);
    assert!(grid_sys::is_occupied(&grid, 2, 1));
    assert!(!grid_sys::is_occupied(&grid, 0, 0));

    // Cleanup
    grid_sys::remove(&mut grid, 2, 1);
    let _ = position::remove(&mut e);
    let _ = movement::remove(&mut e);
    e.destroy();
    grid_sys::destroy_empty(grid);
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 0)] // EOutOfRange
fun test_movement_out_of_range() {
    let mut scenario = ts::begin(PLAYER1);
    let mut grid = grid_sys::create_for_testing(10, 10, ts::ctx(&mut scenario));
    let mut e = entity::new_for_testing(ts::ctx(&mut scenario));

    position::add(&mut e, position::new(0, 0));
    movement::add(&mut e, movement::new(2, movement::pattern_walk())); // speed=2
    grid_sys::place(&mut grid, object::id(&e), 0, 0);

    movement_sys::move_entity(&mut e, &mut grid, 5, 5); // distance=10, speed=2

    abort 99
}

// ─── Swap System Tests ──────────────────────

#[test]
fun test_swap() {
    let mut scenario = ts::begin(PLAYER1);
    let mut grid = grid_sys::create_for_testing(5, 5, ts::ctx(&mut scenario));
    let mut e1 = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut e2 = entity::new_for_testing(ts::ctx(&mut scenario));

    position::add(&mut e1, position::new(1, 1));
    position::add(&mut e2, position::new(3, 3));
    grid_sys::place(&mut grid, object::id(&e1), 1, 1);
    grid_sys::place(&mut grid, object::id(&e2), 3, 3);

    swap_sys::swap(&mut e1, &mut e2, &mut grid);

    let p1 = position::borrow(&e1);
    assert!(p1.x() == 3 && p1.y() == 3);
    let p2 = position::borrow(&e2);
    assert!(p2.x() == 1 && p2.y() == 1);

    // Cleanup
    grid_sys::remove(&mut grid, 1, 1);
    grid_sys::remove(&mut grid, 3, 3);
    let _ = position::remove(&mut e1);
    let _ = position::remove(&mut e2);
    e1.destroy();
    e2.destroy();
    grid_sys::destroy_empty(grid);
    ts::end(scenario);
}

// ─── Capture System Tests ───────────────────

#[test]
fun test_capture() {
    let mut scenario = ts::begin(PLAYER1);
    let mut grid = grid_sys::create_for_testing(5, 5, ts::ctx(&mut scenario));
    let mut capturer = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut target = entity::new_for_testing(ts::ctx(&mut scenario));

    position::add(&mut capturer, position::new(0, 0));
    position::add(&mut target, position::new(1, 0));
    grid_sys::place(&mut grid, object::id(&capturer), 0, 0);
    grid_sys::place(&mut grid, object::id(&target), 1, 0);

    capture_sys::capture(&capturer, &target, &mut grid);

    assert!(!grid_sys::is_occupied(&grid, 1, 0));
    assert!(grid_sys::is_occupied(&grid, 0, 0));

    // Cleanup
    grid_sys::remove(&mut grid, 0, 0);
    let _ = position::remove(&mut capturer);
    let _ = position::remove(&mut target);
    capturer.destroy();
    target.destroy();
    grid_sys::destroy_empty(grid);
    ts::end(scenario);
}

// ─── Objective System Tests ─────────────────

#[test]
fun test_objective_lifecycle() {
    let mut scenario = ts::begin(PLAYER1);
    let carrier = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut flag = entity::new_for_testing(ts::ctx(&mut scenario));

    objective::add(&mut flag, objective::new(objective::flag_type(), 5, 5));

    // Pick up
    objective_sys::pick_up(&carrier, &mut flag);
    let obj = objective::borrow(&flag);
    assert!(obj.is_held());

    // Drop
    objective_sys::drop_flag(&carrier, &mut flag);
    let obj2 = objective::borrow(&flag);
    assert!(!obj2.is_held());

    // Pick up + score
    objective_sys::pick_up(&carrier, &mut flag);
    objective_sys::score(&carrier, &mut flag, 1);
    let obj3 = objective::borrow(&flag);
    assert!(!obj3.is_held()); // cleared after scoring

    // Cleanup
    let _ = objective::remove(&mut flag);
    carrier.destroy();
    flag.destroy();
    ts::end(scenario);
}

// ─── Territory System Tests ─────────────────

#[test]
fun test_territory_claim() {
    let mut scenario = ts::begin(PLAYER1);
    let mut claimer = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut zone_entity = entity::new_for_testing(ts::ctx(&mut scenario));

    team::add(&mut claimer, team::new(1));
    zone::add(&mut zone_entity, zone::new(zone::zone_control_point()));

    territory_sys::claim(&claimer, &mut zone_entity);

    let z = zone::borrow(&zone_entity);
    assert!(z.is_controlled());
    assert!(z.controlled_by() == 1);

    // Cleanup
    let _ = team::remove(&mut claimer);
    let _ = zone::remove(&mut zone_entity);
    claimer.destroy();
    zone_entity.destroy();
    ts::end(scenario);
}

#[test]
fun test_territory_contest() {
    let mut scenario = ts::begin(PLAYER1);
    let mut contester = entity::new_for_testing(ts::ctx(&mut scenario));
    let mut zone_entity = entity::new_for_testing(ts::ctx(&mut scenario));

    team::add(&mut contester, team::new(2));
    zone::add(&mut zone_entity, zone::new(zone::zone_control_point()));

    territory_sys::contest(&contester, &mut zone_entity, 40);
    let z = zone::borrow(&zone_entity);
    assert!(z.capture_progress() == 40);

    territory_sys::contest(&contester, &mut zone_entity, 80);
    let z2 = zone::borrow(&zone_entity);
    assert!(z2.capture_progress() == 100); // capped at 100

    // Finalize capture
    territory_sys::capture_zone(&mut zone_entity, 2);
    let z3 = zone::borrow(&zone_entity);
    assert!(z3.controlled_by() == 2);

    // Cleanup
    let _ = team::remove(&mut contester);
    let _ = zone::remove(&mut zone_entity);
    contester.destroy();
    zone_entity.destroy();
    ts::end(scenario);
}
