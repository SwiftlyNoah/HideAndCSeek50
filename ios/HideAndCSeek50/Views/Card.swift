//
//  Card.swift
//  HideAndCSeek50
//

import Foundation
import SwiftUI

// MARK: - Card Models

struct Card: Identifiable, Codable, Equatable {
    let instanceId: String      // "<customCardId>#<copyIndex>" — unique per physical copy
    let definition: CustomCard  // snapshot of card content at game start

    var id: String { instanceId }
}

// MARK: - Deck State

struct DeckState: Codable {
    var deck: [Card]
    var hand: [Card]
    var discardPile: [Card]

    init(deck: [Card] = [], hand: [Card] = [], discardPile: [Card] = []) {
        self.deck = deck
        self.hand = hand
        self.discardPile = discardPile
    }

    mutating func drawCards(_ count: Int) -> [Card] {
        var drawnCards: [Card] = []

        for _ in 0..<count {
            if deck.isEmpty {
                deck = discardPile.shuffled()
                discardPile.removeAll()
            }
            guard !deck.isEmpty else { break }
            let card = deck.removeFirst()
            drawnCards.append(card)
        }

        return drawnCards
    }

    mutating func addToHand(_ cards: [Card]) {
        hand.append(contentsOf: cards)
    }

    mutating func removeFromHand(_ cards: [Card]) {
        for card in cards {
            if let index = hand.firstIndex(where: { $0.id == card.id }) {
                hand.remove(at: index)
            }
        }
    }

    mutating func discardCards(_ cards: [Card]) {
        discardPile.append(contentsOf: cards)
    }
}

extension DeckState {
    static func makeShuffled(from deck: CardDeck) -> DeckState {
        var cards: [Card] = []
        for entry in deck.entries {
            for copyIndex in 0..<max(entry.multiplier, 0) {
                let instanceId = "\(entry.card.id)#\(copyIndex)"
                cards.append(Card(instanceId: instanceId, definition: entry.card))
            }
        }
        cards.shuffle()
        return DeckState(deck: cards, hand: [], discardPile: [])
    }
}

// MARK: - Draw Action

struct DrawAction: Equatable {
    let drawCount: Int
    let keepCount: Int

    var description: String {
        "Draw \(drawCount), Keep \(keepCount)"
    }
}
