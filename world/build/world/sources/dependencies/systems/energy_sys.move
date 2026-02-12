/// EnergySystem — Spend and regenerate action energy.
module systems::energy_sys;

use sui::event;
use entity::entity::Entity;

// Components
use components::energy;

// ─── Error Constants ────────────────────────

const ENotEnoughEnergy: u64 = 0;

// ─── Events ─────────────────────────────────

public struct EnergySpentEvent has copy, drop {
    entity_id: ID,
    cost: u8,
    remaining: u8,
}

public struct EnergyRegenEvent has copy, drop {
    entity_id: ID,
    amount: u8,
    current: u8,
}

// ─── Entry Functions ────────────────────────

/// Spend energy. Aborts if insufficient.
public fun spend_energy(entity: &mut Entity, cost: u8) {
    let e = energy::borrow(entity);
    assert!(e.has_enough(cost), ENotEnoughEnergy);

    let e_mut = energy::borrow_mut(entity);
    e_mut.spend(cost);

    let remaining = energy::borrow(entity).current();

    event::emit(EnergySpentEvent {
        entity_id: object::id(entity),
        cost,
        remaining,
    });
}

/// Regenerate energy based on the entity's regen stat.
public fun regenerate_energy(entity: &mut Entity) {
    let e = energy::borrow(entity);
    let regen_amount = e.regen();

    let e_mut = energy::borrow_mut(entity);
    e_mut.regenerate();

    let current = energy::borrow(entity).current();

    event::emit(EnergyRegenEvent {
        entity_id: object::id(entity),
        amount: regen_amount,
        current,
    });
}

/// Check if entity has enough energy for a cost.
public fun has_enough_energy(entity: &Entity, cost: u8): bool {
    let e = energy::borrow(entity);
    e.has_enough(cost)
}
