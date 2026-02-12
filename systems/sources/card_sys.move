/// CardSystem — Deck management: draw, play, discard, shuffle.
#[allow(lint(public_random))]
module systems::card_sys;

use std::ascii::String;
use sui::event;
use sui::random::Random;
use entity::entity::Entity;

// Components
use components::deck;
use components::energy;

// ─── Error Constants ────────────────────────

const EDrawPileEmpty: u64 = 0;
const ENotEnoughEnergy: u64 = 1;
const EInvalidHandIndex: u64 = 2;

// ─── Events ─────────────────────────────────

public struct CardDrawnEvent has copy, drop {
    entity_id: ID,
    hand_size: u64,
}

public struct CardPlayedEvent has copy, drop {
    entity_id: ID,
    card_name: String,
    card_cost: u8,
}

public struct DeckShuffledEvent has copy, drop {
    entity_id: ID,
    draw_pile_size: u64,
}

// ─── Entry Functions ────────────────────────

/// Draw `count` cards from draw pile into hand.
/// Stops early if draw pile is exhausted.
/// Returns the actual number of cards drawn.
public fun draw_cards(entity: &mut Entity, count: u64): u64 {
    let d = deck::borrow_mut(entity);
    let mut drawn: u64 = 0;
    let mut i: u64 = 0;

    while (i < count) {
        if (!d.draw()) { break };
        drawn = drawn + 1;
        i = i + 1;
    };

    let hand_size = d.hand_size();

    event::emit(CardDrawnEvent {
        entity_id: object::id(entity),
        hand_size,
    });

    drawn
}

/// Play a card from hand by index. Checks energy cost.
/// Returns the CardData of the played card.
public fun play_card(
    entity: &mut Entity,
    hand_index: u64,
): deck::CardData {
    // Validate hand index
    let d = deck::borrow(entity);
    assert!(hand_index < d.hand_size(), EInvalidHandIndex);

    // Get card cost from hand
    let hand = d.hand();
    let card_ref = hand.borrow(hand_index);
    let cost = card_ref.card_cost();
    let card_name = card_ref.card_name();

    // Check and spend energy
    let e = energy::borrow(entity);
    assert!(e.has_enough(cost), ENotEnoughEnergy);
    let e_mut = energy::borrow_mut(entity);
    e_mut.spend(cost);

    // Play the card (removes from hand)
    let d_mut = deck::borrow_mut(entity);
    let card = d_mut.play_card(hand_index);

    // Discard it
    d_mut.add_to_discard(card);

    event::emit(CardPlayedEvent {
        entity_id: object::id(entity),
        card_name,
        card_cost: cost,
    });

    card
}

/// Discard a card from hand by index without playing it.
public fun discard_card(entity: &mut Entity, hand_index: u64) {
    let d = deck::borrow(entity);
    assert!(hand_index < d.hand_size(), EInvalidHandIndex);

    let d_mut = deck::borrow_mut(entity);
    d_mut.discard_card(hand_index);
}

/// Shuffle: move all discard into draw pile and randomize order.
public fun shuffle_deck(entity: &mut Entity, r: &Random, ctx: &mut TxContext) {
    let d = deck::borrow_mut(entity);
    d.reshuffle();

    // Shuffle using the component's built-in shuffle
    let mut rng = r.new_generator(ctx);
    d.shuffle_draw_pile(&mut rng);

    let pile_size = d.draw_pile_size();

    event::emit(DeckShuffledEvent {
        entity_id: object::id(entity),
        draw_pile_size: pile_size,
    });
}
