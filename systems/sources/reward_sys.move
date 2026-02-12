/// RewardSystem — Post-combat loot distribution.
module systems::reward_sys;

use sui::event;
use entity::entity::Entity;

// Components
use components::gold;
use components::deck;
use components::inventory;

// ─── Events ─────────────────────────────────

public struct RewardEvent has copy, drop {
    entity_id: ID,
    reward_type: u8,    // 0=gold, 1=card, 2=relic
    value: u64,
}

// ─── Reward Type Constants ──────────────────

const REWARD_GOLD: u8 = 0;
const REWARD_CARD: u8 = 1;
const REWARD_RELIC: u8 = 2;

// ─── Entry Functions ────────────────────────

/// Grant gold to an entity.
public fun grant_gold(entity: &mut Entity, amount: u64) {
    let g = gold::borrow_mut(entity);
    g.earn(amount);

    event::emit(RewardEvent {
        entity_id: object::id(entity),
        reward_type: REWARD_GOLD,
        value: amount,
    });
}

/// Grant a card to an entity's deck (added to draw pile).
public fun grant_card(
    entity: &mut Entity,
    card: deck::CardData,
) {
    let d = deck::borrow_mut(entity);
    d.add_to_draw_pile(card);

    event::emit(RewardEvent {
        entity_id: object::id(entity),
        reward_type: REWARD_CARD,
        value: 1,
    });
}

/// Grant a relic (item) to an entity's inventory.
public fun grant_relic(
    entity: &mut Entity,
    item_type: u8,
    value: u64,
) {
    let inv = inventory::borrow_mut(entity);
    inv.add_item(inventory::new_item(item_type, value));

    event::emit(RewardEvent {
        entity_id: object::id(entity),
        reward_type: REWARD_RELIC,
        value,
    });
}

// ─── Reward Type Accessors ──────────────────

public fun reward_gold(): u8 { REWARD_GOLD }
public fun reward_card(): u8 { REWARD_CARD }
public fun reward_relic(): u8 { REWARD_RELIC }
