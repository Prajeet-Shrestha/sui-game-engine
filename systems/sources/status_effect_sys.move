/// StatusEffectSystem — Apply, tick, and expire status effects.
module systems::status_effect_sys;

use sui::event;
use entity::entity::Entity;

// Components
use components::status_effect;
use components::health;

// ─── Events ─────────────────────────────────

public struct EffectAppliedEvent has copy, drop {
    entity_id: ID,
    effect_type: u8,
    stacks: u64,
    duration: u8,
}

public struct EffectTickEvent has copy, drop {
    entity_id: ID,
    effect_type: u8,
    damage: u64,
}

public struct EffectExpiredEvent has copy, drop {
    entity_id: ID,
    effect_type: u8,
}

// ─── Effect Constants (mirrors component) ───

const EFFECT_POISON: u8 = 0;
const EFFECT_REGEN: u8 = 5;

// ─── Entry Functions ────────────────────────

/// Apply a new status effect to an entity.
/// If the entity already has a status effect, this overwrites it.
/// For multi-effect support, the game module should manage a vector.
public fun apply_effect(
    entity: &mut Entity,
    effect_type: u8,
    stacks: u64,
    duration: u8,
) {
    let effect = status_effect::new(effect_type, stacks, duration);

    if (entity.has_component(entity::status_effect_bit())) {
        // Overwrite existing effect
        let existing = status_effect::borrow_mut(entity);
        existing.set_stacks(stacks);
        existing.set_duration(duration);
    } else {
        status_effect::add(entity, effect);
    };

    event::emit(EffectAppliedEvent {
        entity_id: object::id(entity),
        effect_type,
        stacks,
        duration,
    });
}

/// Tick the status effect by one turn.
/// Applies damage for poison, healing for regen, and decrements duration.
/// Returns the amount of damage/healing applied.
public fun tick_effects(entity: &mut Entity): u64 {
    let se = status_effect::borrow(entity);
    let etype = se.effect_type();
    let stacks = se.stacks();

    let amount = if (etype == EFFECT_POISON) {
        // Poison deals damage equal to stacks
        let hp = health::borrow_mut(entity);
        hp.take_damage(stacks);
        event::emit(EffectTickEvent {
            entity_id: object::id(entity),
            effect_type: etype,
            damage: stacks,
        });
        stacks
    } else if (etype == EFFECT_REGEN) {
        // Regen heals equal to stacks
        let hp = health::borrow_mut(entity);
        hp.heal(stacks);
        stacks
    } else {
        0
    };

    // Decrement duration
    let se_mut = status_effect::borrow_mut(entity);
    se_mut.tick();

    amount
}

/// Remove expired status effects from an entity.
/// Returns true if the effect was removed.
public fun remove_expired(entity: &mut Entity): bool {
    let se = status_effect::borrow(entity);
    if (se.is_expired()) {
        let etype = se.effect_type();
        let _ = status_effect::remove(entity);

        event::emit(EffectExpiredEvent {
            entity_id: object::id(entity),
            effect_type: etype,
        });
        true
    } else {
        false
    }
}

use entity::entity;
