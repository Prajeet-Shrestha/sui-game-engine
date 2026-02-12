/// RelicSystem — Passive bonus management.
module systems::relic_sys;

use sui::event;
use entity::entity::Entity;

// Components
use components::relic;
use components::stats;

// ─── Error Constants ────────────────────────

const ENoRelic: u64 = 0;

// ─── Modifier Type Constants ────────────────

const MODIFIER_FLAT: u8 = 0;
const MODIFIER_PERCENT: u8 = 1;

// ─── Events ─────────────────────────────────

public struct RelicAddedEvent has copy, drop {
    entity_id: ID,
    relic_type: u8,
    modifier_value: u64,
}

public struct RelicRemovedEvent has copy, drop {
    entity_id: ID,
    relic_type: u8,
}

public struct RelicBonusAppliedEvent has copy, drop {
    entity_id: ID,
    relic_type: u8,
    bonus: u64,
}

// ─── Entry Functions ────────────────────────

/// Add a relic to an entity (sets the relic component).
public fun add_relic(
    entity: &mut Entity,
    relic_type: u8,
    modifier_type: u8,
    modifier_value: u64,
) {
    let r = relic::new(relic_type, modifier_type, modifier_value);
    relic::add(entity, r);

    event::emit(RelicAddedEvent {
        entity_id: object::id(entity),
        relic_type,
        modifier_value,
    });
}

/// Remove the relic from an entity.
public fun remove_relic(entity: &mut Entity) {
    assert!(entity.has_component(entity::relic_bit()), ENoRelic);

    let r = relic::remove(entity);

    event::emit(RelicRemovedEvent {
        entity_id: object::id(entity),
        relic_type: r.relic_type(),
    });
}

/// Apply the relic's passive bonus to the entity's stats (strength).
/// For flat modifiers: adds directly.
/// For percent modifiers: adds (value * current_strength / 100).
/// Returns the bonus applied.
public fun apply_relic_bonus(entity: &mut Entity): u64 {
    let r = relic::borrow(entity);
    let mod_type = r.modifier_type();
    let mod_value = r.modifier_value();
    let rtype = r.relic_type();

    let bonus = if (mod_type == MODIFIER_FLAT) {
        mod_value
    } else if (mod_type == MODIFIER_PERCENT) {
        let s = stats::borrow(entity);
        (s.strength() * mod_value) / 100
    } else {
        0
    };

    if (bonus > 0) {
        let s_mut = stats::borrow_mut(entity);
        s_mut.add_strength(bonus);
    };

    event::emit(RelicBonusAppliedEvent {
        entity_id: object::id(entity),
        relic_type: rtype,
        bonus,
    });

    bonus
}

use entity::entity;
