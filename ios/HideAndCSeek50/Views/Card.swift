//
//  Card.swift
//  HideAndCSeek50
//
//  Created by Assistant on 12/9/25.
//

import Foundation
import SwiftUI

// MARK: - Card Models

struct Card: Identifiable, Codable, Equatable {
    let suit: Suit
    let rank: Rank
    
    init(suit: Suit, rank: Rank) {
        self.suit = suit
        self.rank = rank
    }
    
    var displayName: String {
        "\(rank.displayValue)\(suit.symbol)"
    }
    
    var color: Color {
        suit.color
    }
    
    var id: String {
        "\(suit.rawValue)_\(rank.rawValue)"
    }
}

enum Suit: String, Codable, CaseIterable {
    case hearts = "hearts"
    case diamonds = "diamonds"
    case clubs = "clubs"
    case spades = "spades"
    
    var symbol: String {
        switch self {
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        case .spades: return "♠"
        }
    }
    
    var color: Color {
        switch self {
        case .hearts, .diamonds: return .red
        case .clubs, .spades: return .black
        }
    }
    
    var iconName: String {
        switch self {
        case .hearts: return "suit.heart.fill"
        case .diamonds: return "suit.diamond.fill"
        case .clubs: return "suit.club.fill"
        case .spades: return "suit.spade.fill"
        }
    }
}

enum Rank: String, Codable, CaseIterable {
    case ace = "A"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
    case eight = "8"
    case nine = "9"
    case ten = "10"
    case jack = "J"
    case queen = "Q"
    case king = "K"
    
    var displayValue: String {
        return rawValue
    }
}

// MARK: - Deck State

struct DeckState: Codable {
    var deck: [Card]
    var hand: [Card]
    var discardPile: [Card]
    
    init(deck: [Card], hand: [Card], discardPile: [Card]) {
        self.deck = deck
        self.hand = hand
        self.discardPile = discardPile
    }
    
    init(shouldPopulate: Bool = false) {
        if shouldPopulate {
            // Create a standard 52-card deck
            var cards: [Card] = []
            for suit in Suit.allCases {
                for rank in Rank.allCases {
                    cards.append(Card(suit: suit, rank: rank))
                }
            }
            
            // Shuffle the deck
            self.deck = cards.shuffled()
        }
        else {
            self.deck = []
        }
        self.hand = []
        self.discardPile = []
    }
    
    mutating func drawCards(_ count: Int) -> [Card] {
        var drawnCards: [Card] = []
        
        for _ in 0..<count {
            // If deck is empty, reshuffle discard pile back into deck
            if deck.isEmpty {
                deck = discardPile.shuffled()
                discardPile.removeAll()
            }
            
            // If deck is still empty, can't draw
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

// MARK: - Draw Action

struct DrawAction: Equatable {
    let drawCount: Int
    let keepCount: Int
    
    var description: String {
        "Draw \(drawCount), Keep \(keepCount)"
    }
}
