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
    /// Bump this whenever the default deck entries change so the seed
    /// logic overwrites stale copies stored in Firebase.
    static let defaultVersion = 2

    var cardCount: Int { entries.reduce(0) { $0 + $1.multiplier } }
    var uniqueCardCount: Int { entries.count }
}

struct CardDeckEntry: Codable, Identifiable, Equatable {
    let id: String
    var card: CustomCard
    var multiplier: Int
}

struct CustomCard: Codable, Equatable, Identifiable {
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
            entry.multiplier >= 1 && entry.multiplier <= 50 && entry.card.isValid()
        }
    }
}

private enum DefaultDeckSeed {
    static func entries() -> [CardDeckEntry] {
        [
            // MARK: Time Bonuses (55 cards)
            CardDeckEntry(
                id: "default-time-red",
                card: CustomCard(
                    id: "time-bonus-3",
                    type: .timeBonus,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: nil, powerupDescription: nil,
                    timeBonusMinutes: 3
                ),
                multiplier: 25
            ),
            CardDeckEntry(
                id: "default-time-orange",
                card: CustomCard(
                    id: "time-bonus-6",
                    type: .timeBonus,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: nil, powerupDescription: nil,
                    timeBonusMinutes: 6
                ),
                multiplier: 15
            ),
            CardDeckEntry(
                id: "default-time-yellow",
                card: CustomCard(
                    id: "time-bonus-9",
                    type: .timeBonus,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: nil, powerupDescription: nil,
                    timeBonusMinutes: 9
                ),
                multiplier: 10
            ),
            CardDeckEntry(
                id: "default-time-green",
                card: CustomCard(
                    id: "time-bonus-12",
                    type: .timeBonus,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: nil, powerupDescription: nil,
                    timeBonusMinutes: 12
                ),
                multiplier: 3
            ),
            CardDeckEntry(
                id: "default-time-blue",
                card: CustomCard(
                    id: "time-bonus-18",
                    type: .timeBonus,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: nil, powerupDescription: nil,
                    timeBonusMinutes: 18
                ),
                multiplier: 2
            ),

            // MARK: Power Ups (21 cards)
            CardDeckEntry(
                id: "default-powerup-randomize",
                card: CustomCard(
                    id: "powerup-randomize",
                    type: .powerup,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: "Randomize",
                    powerupDescription: "Play instead of answering a question. A new unasked question from the same category is chosen, at random, which you answer instead.",
                    timeBonusMinutes: nil
                ),
                multiplier: 4
            ),
            CardDeckEntry(
                id: "default-powerup-veto",
                card: CustomCard(
                    id: "powerup-veto",
                    type: .powerup,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: "Veto",
                    powerupDescription: "Play instead of answering a question. No answer is given, and no reward is earned.",
                    timeBonusMinutes: nil
                ),
                multiplier: 4
            ),
            CardDeckEntry(
                id: "default-powerup-duplicate",
                card: CustomCard(
                    id: "powerup-duplicate",
                    type: .powerup,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: "Duplicate",
                    powerupDescription: "Play this card as a copy of any other card in your hand. This may be used to duplicate a time bonus at the end of your round.",
                    timeBonusMinutes: nil
                ),
                multiplier: 2
            ),
            CardDeckEntry(
                id: "default-powerup-move",
                card: CustomCard(
                    id: "powerup-move",
                    type: .powerup,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: "Move",
                    powerupDescription: "Discard your hand and send the hiders the location of your transit station. This card grants a 20 minute period to establish a new hiding zone somewhere else on the game map. The seekers are frozen and your hiding timer is paused until this new hiding period has concluded. This card cannot be played during the endgame.",
                    timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-powerup-discard1-draw2",
                card: CustomCard(
                    id: "powerup-discard1-draw2",
                    type: .powerup,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: "Discard 1 Draw 2",
                    powerupDescription: "Discard this and one other card from your hand. Then, draw and keep two cards from the hider deck.",
                    timeBonusMinutes: nil
                ),
                multiplier: 4
            ),
            CardDeckEntry(
                id: "default-powerup-discard2-draw3",
                card: CustomCard(
                    id: "powerup-discard2-draw3",
                    type: .powerup,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: "Discard 2 Draw 3",
                    powerupDescription: "Discard this and two other cards from your hand. Then, draw and keep three cards from the hider deck.",
                    timeBonusMinutes: nil
                ),
                multiplier: 4
            ),
            CardDeckEntry(
                id: "default-powerup-draw1-expand1",
                card: CustomCard(
                    id: "powerup-draw1-expand1",
                    type: .powerup,
                    curseTitle: nil, curseDescription: nil, castingCost: nil,
                    powerupTitle: "Draw 1 Expand 1",
                    powerupDescription: "Draw one card from the hider deck. For the rest of the round, you can hold one additional card in your hand.",
                    timeBonusMinutes: nil
                ),
                multiplier: 2
            ),

            // MARK: Curses (24 cards)
            CardDeckEntry(
                id: "default-curse-1",
                card: CustomCard(
                    id: "curse-the-zoologist",
                    type: .curse,
                    curseTitle: "Curse of The Zoologist",
                    curseDescription: "Take a photo of a wild fish, bird, mammal, reptile, amphibian or bug. The seeker(s) must take a picture of a wild animal in the same category before asking another question.",
                    castingCost: "A photo of an animal",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-2",
                card: CustomCard(
                    id: "curse-the-unguided-tourist",
                    type: .curse,
                    curseTitle: "Curse of The Unguided Tourist",
                    curseDescription: "Send the seeker(s) an unzoomed Google Street View image from a street within 500ft (152m) of where they are now. The shot has to be parallel to the horizon and include at least one human-built structure other than a road. Without using the internet for research, they must find what you sent them in real life before they can use transportation or ask another question. They must send a picture to the hiders for verification.",
                    castingCost: "Seeker(s) must be outside",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-3",
                card: CustomCard(
                    id: "curse-the-endless-tumble",
                    type: .curse,
                    curseTitle: "Curse of The Endless Tumble",
                    curseDescription: "Seekers must roll a die at least 100ft (30m) and have it land on a 5 or a 6 before they can ask another question. The die must roll the full distance, unaided, using only the momentum from the initial throw and gravity to travel the 100ft (30m). If the seekers accidentally hit someone with a die you are awarded a bonus.",
                    castingCost: "Roll a die. If it's 5 or 6 this card has no effect.",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-4",
                card: CustomCard(
                    id: "curse-the-hidden-hangman",
                    type: .curse,
                    curseTitle: "Curse of The Hidden Hangman",
                    curseDescription: "Before asking another question or boarding another form of transportation, seeker(s) must be the hider(s) in a game of hangman.",
                    castingCost: "Discard 2 cards",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-5",
                card: CustomCard(
                    id: "curse-the-overflowing-chalice",
                    type: .curse,
                    curseTitle: "Curse of The Overflowing Chalice",
                    curseDescription: "For the next three questions, you may draw (not keep) an additional card when drawing from the hider deck.",
                    castingCost: "Discard a card",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-6",
                card: CustomCard(
                    id: "curse-the-mediocre-travel-agent",
                    type: .curse,
                    curseTitle: "Curse of The Mediocre Travel Agent",
                    curseDescription: "Choose any publicly-accessible place near the seeker(s) current location. They cannot currently be on transit. They must go there and spend at least 5 minutes there before asking another question. They must send you at least three photos of them enjoying their vacation, and procure an object to bring you as a souvenir.",
                    castingCost: "N/A",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-7",
                card: CustomCard(
                    id: "curse-the-luxury-car",
                    type: .curse,
                    curseTitle: "Curse of The Luxury Car",
                    curseDescription: "Take a photo of a car. The seekers must take a photo of a more expensive car before asking another question.",
                    castingCost: "A photo of a car",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-8",
                card: CustomCard(
                    id: "curse-the-u-turn",
                    type: .curse,
                    curseTitle: "Curse of The U-Turn",
                    curseDescription: "Seeker(s) must disembark their current mode of transportation at the next station (as long as that station is served by another form of transit in the next 0.5 hours).",
                    castingCost: "Seekers must be heading the wrong way. (Their next station is further from you than they are.)",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-9",
                card: CustomCard(
                    id: "curse-the-bridge-troll",
                    type: .curse,
                    curseTitle: "Curse of The Bridge Troll",
                    curseDescription: "The seekers must ask their next question from under a bridge.",
                    castingCost: "Seekers must be at least 1 mi (1.6 km) from you",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-10",
                card: CustomCard(
                    id: "curse-water-weight",
                    type: .curse,
                    curseTitle: "Curse of Water Weight",
                    curseDescription: "Seeker(s) must acquire and carry at least 2 liters of liquid per seeker for the rest of your run. They cannot ask another question until they have acquired the liquid. The water may be distributed between seekers as they see fit. If the liquid is lost or abandoned at any point the hider is awarded a bonus.",
                    castingCost: "Seekers must be within 1,000ft (300 meters) of a body of water",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-11",
                card: CustomCard(
                    id: "curse-the-jammed-door",
                    type: .curse,
                    curseTitle: "Curse of The Jammed Door",
                    curseDescription: "For the next 0.5 hours, whenever the seeker(s) want to pass through a doorway into a building, business, train, or other vehicle they must first roll 2 dice. If they do not roll a 7 or higher they cannot enter that space (including through other doorways). Any given doorway can be reattempted after 5 minutes.",
                    castingCost: "Discard 2 cards",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-12",
                card: CustomCard(
                    id: "curse-the-cairn",
                    type: .curse,
                    curseTitle: "Curse of The Cairn",
                    curseDescription: "You have one attempt to stack as many rocks on top of each other as you can in a freestanding tower. Each rock may only touch one other rock. Once you have added a rock to the tower it may not be removed. Before adding another rock, the tower must stand for at least 5 seconds. If at any point any rock other than the base rock touches the ground, your tower has fallen. Tell the seekers how many rocks high your tower was. The seekers must then construct a rock tower of the same height under the same rules before asking another question.",
                    castingCost: "Build a rock tower",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-13",
                card: CustomCard(
                    id: "curse-the-urban-explorer",
                    type: .curse,
                    curseTitle: "Curse of The Urban Explorer",
                    curseDescription: "For the rest of the run seekers cannot ask questions when they are on transit or in a train station.",
                    castingCost: "Discard 2 cards",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-14",
                card: CustomCard(
                    id: "curse-the-impressionable-consumer",
                    type: .curse,
                    curseTitle: "Curse of The Impressionable Consumer",
                    curseDescription: "Seekers must enter and gain admission (if applicable) to a location or buy a product that they saw an advertisement for before asking another question. This advertisement must be found out in the world and must be at least 100ft (30m) from the product or location itself.",
                    castingCost: "The seekers' next question is free",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-15",
                card: CustomCard(
                    id: "curse-the-egg-partner",
                    type: .curse,
                    curseTitle: "Curse of The Egg Partner",
                    curseDescription: "Seeker(s) must acquire an egg before asking another question. This egg is now treated as an official team member of the seekers. If any team members are abandoned or killed (defined as a crack in the egg's case) before the end of your run you are awarded extra time. This curse cannot be played during the endgame.",
                    castingCost: "Discard two cards",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-16",
                card: CustomCard(
                    id: "curse-the-distant-cuisine",
                    type: .curse,
                    curseTitle: "Curse of The Distant Cuisine",
                    curseDescription: "Find a restaurant within your zone that explicitly serves food from a specific foreign country. The seekers must visit a restaurant serving food from a country that is an equal or greater distance away before asking another question.",
                    castingCost: "You must be at the restaurant",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-17",
                card: CustomCard(
                    id: "curse-the-right-turn",
                    type: .curse,
                    curseTitle: "Curse of The Right Turn",
                    curseDescription: "For the next 20 minutes the seekers can only turn right at any street intersection. If at any point they find themselves in a dead end where they cannot continue forward or turn right for another 1,000ft (304m) they must do a full 180. A right turn is defined as a road at any angle that veers to the right of the seekers.",
                    castingCost: "Discard a card",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-18",
                card: CustomCard(
                    id: "curse-the-labyrinth",
                    type: .curse,
                    curseTitle: "Curse of The Labyrinth",
                    curseDescription: "Spend up to 10 minutes drawing a solvable maze and send a photo of it to the seekers. You cannot use the internet to research maze designs. The seekers must solve the maze before asking another question.",
                    castingCost: "Draw a maze",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-19",
                card: CustomCard(
                    id: "curse-the-bird-guide",
                    type: .curse,
                    curseTitle: "Curse of The Bird Guide",
                    curseDescription: "You have one chance to film a bird for as long as possible. Up to 5 minutes straight — if at any point the bird leaves the frame your timer is stopped. The seekers must then film a bird for the same amount of time or longer.",
                    castingCost: "Film a bird",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-20",
                card: CustomCard(
                    id: "curse-spotty-memory",
                    type: .curse,
                    curseTitle: "Curse of Spotty Memory",
                    curseDescription: "For the rest of the run, one random category of questions will be disabled at all times. After this curse is played seeker(s) must roll a die to determine the category of questions to be disabled. The category remains disabled until the next question is asked at which point a die is rolled again to choose a new category. The same category can be disabled multiple times in a row.",
                    castingCost: "Discard a time bonus card",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-21",
                card: CustomCard(
                    id: "curse-the-lemon-phylactery",
                    type: .curse,
                    curseTitle: "Curse of The Lemon Phylactery",
                    curseDescription: "Before asking another question the seeker(s) must each find a lemon and affix it to their outermost layer of clothes or skin. If at any point one of these lemons is no longer touching a seeker you are awarded bonus time. This curse cannot be played during the endgame.",
                    castingCost: "Discard a powerup card",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-22",
                card: CustomCard(
                    id: "curse-the-drained-brain",
                    type: .curse,
                    curseTitle: "Curse of The Drained Brain",
                    curseDescription: "Choose three questions in different categories. The seekers cannot ask those questions for the rest of the run.",
                    castingCost: "Discard your hand",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-23",
                card: CustomCard(
                    id: "curse-the-ransom-note",
                    type: .curse,
                    curseTitle: "Curse of The Ransom Note",
                    curseDescription: "The next question that the seekers ask must be composed of words and letters cut out of any printed material. The question must be coherent and include at least 5 words.",
                    castingCost: "Spell out \"Ransom Note\" as a ransom note (without using this card)",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            ),
            CardDeckEntry(
                id: "default-curse-24",
                card: CustomCard(
                    id: "curse-the-gamblers-feet",
                    type: .curse,
                    curseTitle: "Curse of The Gambler's Feet",
                    curseDescription: "For the next 20 minutes seekers must roll a die before they take any steps in any direction. They may take that many steps before rolling again.",
                    castingCost: "Roll a die. If it's an even number this curse has no effect.",
                    powerupTitle: nil, powerupDescription: nil, timeBonusMinutes: nil
                ),
                multiplier: 1
            )
        ]
    }
}
