/// ShopSystem — Buy cards, relics, and remove cards from deck.
module systems::shop_sys;

use sui::event;
use entity::entity::Entity;

// Components
use components::gold;
use components::deck;
use components::inventory;

// ─── Error Constants ────────────────────────

const ENotEnoughGold: u64 = 0;
const EInventoryFull: u64 = 1;

// ─── Events ─────────────────────────────────

public struct ShopPurchaseEvent has copy, drop {
    entity_id: ID,
    item_type: u8,  // 0=card, 1=relic, 2=card_removal
    cost: u64,
}

// ─── Item Type Constants ────────────────────

const SHOP_CARD: u8 = 0;
const SHOP_RELIC: u8 = 1;
const SHOP_CARD_REMOVAL: u8 = 2;

// ─── Entry Functions ────────────────────────

/// Buy a card and add it to draw pile. Deducts gold.
public fun buy_card(
    entity: &mut Entity,
    card: deck::CardData,
    cost: u64,
) {
    // Check and spend gold
    let g = gold::borrow(entity);
    assert!(g.has_enough(cost), ENotEnoughGold);
    let g_mut = gold::borrow_mut(entity);
    g_mut.spend(cost);

    // Add card to deck
    let d = deck::borrow_mut(entity);
    d.add_to_draw_pile(card);

    event::emit(ShopPurchaseEvent {
        entity_id: object::id(entity),
        item_type: SHOP_CARD,
        cost,
    });
}

/// Buy a relic (item) and add it to inventory. Deducts gold.
public fun buy_relic(
    entity: &mut Entity,
    item_type: u8,
    value: u64,
    cost: u64,
) {
    let g = gold::borrow(entity);
    assert!(g.has_enough(cost), ENotEnoughGold);

    let inv = inventory::borrow(entity);
    assert!(!inv.is_full(), EInventoryFull);

    let g_mut = gold::borrow_mut(entity);
    g_mut.spend(cost);

    let inv_mut = inventory::borrow_mut(entity);
    inv_mut.add_item(inventory::new_item(item_type, value));

    event::emit(ShopPurchaseEvent {
        entity_id: object::id(entity),
        item_type: SHOP_RELIC,
        cost,
    });
}

/// Remove a card from draw pile by index (pay gold to thin deck).
public fun remove_card(
    entity: &mut Entity,
    draw_pile_index: u64,
    cost: u64,
) {
    let g = gold::borrow(entity);
    assert!(g.has_enough(cost), ENotEnoughGold);
    let g_mut = gold::borrow_mut(entity);
    g_mut.spend(cost);

    // Remove card from draw pile using component function
    let d = deck::borrow_mut(entity);
    let _ = d.remove_from_draw_pile(draw_pile_index);

    event::emit(ShopPurchaseEvent {
        entity_id: object::id(entity),
        item_type: SHOP_CARD_REMOVAL,
        cost,
    });
}

