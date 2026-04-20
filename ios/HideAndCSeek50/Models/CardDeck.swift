//
//  CardDeck.swift
//  HideAndCSeek50
//
//  Custom card decks for in-game card draws. Each user owns a collection
//  of CardDeck under their account; the host's chosen deck is snapshotted
//  onto the game at start so all players draw from a stable copy.
//

import Foundation
import SwiftUI

// MARK: - Card Deck Models

struct CardDeck: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date
    var entries: [CardDeckEntry]

    static let defaultId = "default"
    static let defaultName = "Default"

    var cardCount: Int { entries.reduce(0) { $0 + $1.multiplier } }
    var uniqueCardCount: Int { entries.count }
}

struct CardDeckEntry: Codable, Identifiable, Equatable {
    let id: String
    var card: CustomCard
    var multiplier: Int
}

struct CustomCard: Codable, Equatable {
    let id: String
    var type: CardType

    // Curse fields
    var curseTitle: String?
    var curseDescription: String?
    var castingCost: String?

    // Powerup fields
    var powerupTitle: String?
    var powerupDescription: String?

    // Time Bonus fields
    var timeBonusMinutes: Int?

    var displayTitle: String {
        switch type {
        case .curse: return curseTitle ?? "Curse"
        case .powerup: return powerupTitle ?? "Powerup"
        case .timeBonus: return "+\(timeBonusMinutes ?? 0) min"
        }
    }

    var displaySubtitle: String {
        switch type {
        case .curse: return curseDescription ?? ""
        case .powerup: return powerupDescription ?? ""
        case .timeBonus: return "Time Bonus"
        }
    }

    func isValid() -> Bool {
        switch type {
        case .curse:
            return !(curseTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !(curseDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !(castingCost ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .powerup:
            return !(powerupTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !(powerupDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .timeBonus:
            return (timeBonusMinutes ?? 0) >= 1 && (timeBonusMinutes ?? 0) <= 120
        }
    }
}

enum CardType: String, Codable, CaseIterable {
    case curse
    case powerup
    case timeBonus

    var displayName: String {
        switch self {
        case .curse: return "Curse"
        case .powerup: return "Powerup"
        case .timeBonus: return "Time Bonus"
        }
    }

    var iconName: String {
        switch self {
        case .curse: return "bolt.trianglebadge.exclamationmark.fill"
        case .powerup: return "sparkles"
        case .timeBonus: return "clock.badge.fill"
        }
    }

    var themeColor: Color {
        switch self {
        case .curse: return .purple
        case .powerup: return Color(red: 0.9, green: 0.7, blue: 0.1)
        case .timeBonus: return .blue
        }
    }
}

// MARK: - Default Deck Builder

extension CardDeck {
    static func makeDefault(now: Date = Date()) -> CardDeck {
        CardDeck(
            id: defaultId,
            name: defaultName,
            isDefault: true,
            createdAt: now,
            updatedAt: now,
            entries: DefaultDeckSeed.entries()
        )
    }

    func isValidForGame() -> Bool {
        guard !entries.isEmpty else { return false }
        guard cardCount >= 1 else { return false }
        return entries.allSatisfy { entry in
            entry.multiplier >= 1 && entry.multiplier <= 20 && entry.card.isValid()
        }
    }
}

private enum DefaultDeckSeed {
    static func entries() -> [CardDeckEntry] {
        [
            CardDeckEntry(
                id: "default-curse-1",
                card: CustomCard(
                    id: "curse-silent-step",
                    type: .curse,
                    curseTitle: "Silent Step",
                    curseDescription: "Seekers can't see hiders' locations for 2 minutes.",
                    castingCost: "Reveal your current region",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 2
            ),
            CardDeckEntry(
                id: "default-curse-2",
                card: CustomCard(
                    id: "curse-blind-radar",
                    type: .curse,
                    curseTitle: "Blind Radar",
                    curseDescription: "The next radar question must be answered with 'Maybe'.",
                    castingCost: "Send a photo of your surroundings",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 2
            ),
            CardDeckEntry(
                id: "default-curse-3",
                card: CustomCard(
                    id: "curse-scenic-route",
                    type: .curse,
                    curseTitle: "Scenic Route",
                    curseDescription: "Seekers must travel in a straight line for the next 3 minutes.",
                    castingCost: "Skip your next card draw",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-powerup-1",
                card: CustomCard(
                    id: "powerup-skip-question",
                    type: .powerup,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: "Skip Question",
                    powerupDescription: "Discard one question without answering.",
                    timeBonusMinutes: nil
                ),
                multiplier: 3
            ),
            CardDeckEntry(
                id: "default-powerup-2",
                card: CustomCard(
                    id: "powerup-double-reward",
                    type: .powerup,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: "Double Reward",
                    powerupDescription: "Your next question gives double card draws.",
                    timeBonusMinutes: nil
                ),
                multiplier: 2
            ),
            CardDeckEntry(
                id: "default-powerup-3",
                card: CustomCard(
                    id: "powerup-truth-serum",
                    type: .powerup,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: "Truth Serum",
                    powerupDescription: "Ask one extra short-answer question immediately.",
                    timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-powerup-4",
                card: CustomCard(
                    id: "powerup-veto",
                    type: .powerup,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: "Veto",
                    powerupDescription: "Cancel a curse cast on you.",
                    timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-time-1",
                card: CustomCard(
                    id: "time-bonus-2",
                    type: .timeBonus,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: nil, powerupDescription: nil,
                    timeBonusMinutes: 2
                ),
                multiplier: 4
            ),
            CardDeckEntry(
                id: "default-time-2",
                card: CustomCard(
                    id: "time-bonus-5",
                    type: .timeBonus,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: nil, powerupDescription: nil,
                    timeBonusMinutes: 5
                ),
                multiplier: 3
            ),
            CardDeckEntry(
                id: "default-time-3",
                card: CustomCard(
                    id: "time-bonus-10",
                    type: .timeBonus,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: nil, powerupDescription: nil,
                    timeBonusMinutes: 10
                ),
                multiplier: 1
            )
        ]
    }
}
