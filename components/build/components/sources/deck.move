/// Deck — Card deck with draw pile, hand, and discard pile.
/// CardData is an inline struct (not a separate entity).
module components::deck;

use std::ascii::{Self, String};
use entity::entity::{Self, Entity};

// ─── Card Data (inline struct) ──────────────

public struct CardData has store, copy, drop {
    name: String,
    cost: u8,
    card_type: u8,      // 0=attack, 1=skill, 2=power
    effect_type: u8,    // game-specific effect identifier
    value: u64,         // effect magnitude
}

// ─── Card Type Constants ────────────────────

const CARD_TYPE_ATTACK: u8 = 0;
const CARD_TYPE_SKILL: u8 = 1;
const CARD_TYPE_POWER: u8 = 2;

// ─── Deck Struct ────────────────────────────

public struct Deck has store, drop {
    draw_pile: vector<CardData>,
    hand: vector<CardData>,
    discard: vector<CardData>,
}

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"deck") }

// ─── Card Constructors ──────────────────────

public fun new_card(
    name: String,
    cost: u8,
    card_type: u8,
    effect_type: u8,
    value: u64,
): CardData {
    CardData { name, cost, card_type, effect_type, value }
}

// ─── Card Getters ───────────────────────────

public fun card_name(card: &CardData): String { card.name }
public fun card_cost(card: &CardData): u8 { card.cost }
public fun card_type(card: &CardData): u8 { card.card_type }
public fun card_effect_type(card: &CardData): u8 { card.effect_type }
public fun card_value(card: &CardData): u64 { card.value }

// ─── Card Type Accessors ────────────────────

public fun card_type_attack(): u8 { CARD_TYPE_ATTACK }
public fun card_type_skill(): u8 { CARD_TYPE_SKILL }
public fun card_type_power(): u8 { CARD_TYPE_POWER }

// ─── Deck Constructor ───────────────────────

public fun new(initial_cards: vector<CardData>): Deck {
    Deck {
        draw_pile: initial_cards,
        hand: vector[],
        discard: vector[],
    }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, deck: Deck) {
    entity.add_component(entity::deck_bit(), key(), deck);
}

public fun remove(entity: &mut Entity): Deck {
    entity.remove_component(entity::deck_bit(), key())
}

public fun borrow(entity: &Entity): &Deck {
    entity.borrow_component<Deck>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut Deck {
    entity.borrow_mut_component<Deck>(key())
}

// ─── Getters ────────────────────────────────

public fun draw_pile(self: &Deck): &vector<CardData> { &self.draw_pile }
public fun hand(self: &Deck): &vector<CardData> { &self.hand }
public fun discard(self: &Deck): &vector<CardData> { &self.discard }
public fun draw_pile_size(self: &Deck): u64 { self.draw_pile.length() }
public fun hand_size(self: &Deck): u64 { self.hand.length() }
public fun discard_size(self: &Deck): u64 { self.discard.length() }

// ─── Mutations ──────────────────────────────

/// Draw the top card from draw pile into hand.
/// Returns false if draw pile is empty.
public fun draw(self: &mut Deck): bool {
    if (self.draw_pile.is_empty()) { return false };
    let card = self.draw_pile.pop_back();
    self.hand.push_back(card);
    true
}

/// Play a card from hand by index → moves to discard.
public fun play_card(self: &mut Deck, hand_index: u64): CardData {
    self.hand.swap_remove(hand_index)
}

/// Discard a card from hand by index.
public fun discard_card(self: &mut Deck, hand_index: u64) {
    let card = self.hand.swap_remove(hand_index);
    self.discard.push_back(card);
}

/// Move all discard into draw pile (caller should shuffle afterward).
public fun reshuffle(self: &mut Deck) {
    while (!self.discard.is_empty()) {
        let card = self.discard.pop_back();
        self.draw_pile.push_back(card);
    };
}

/// Add a card to draw pile.
public fun add_to_draw_pile(self: &mut Deck, card: CardData) {
    self.draw_pile.push_back(card);
}

/// Add a card to discard pile.
public fun add_to_discard(self: &mut Deck, card: CardData) {
    self.discard.push_back(card);
}

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): Deck {
    let cards = vector[
        CardData {
            name: ascii::string(b"Strike"),
            cost: 1,
            card_type: 0,
            effect_type: 0,
            value: 6,
        },
        CardData {
            name: ascii::string(b"Defend"),
            cost: 1,
            card_type: 1,
            effect_type: 1,
            value: 5,
        },
    ];
    Deck { draw_pile: cards, hand: vector[], discard: vector[] }
}
