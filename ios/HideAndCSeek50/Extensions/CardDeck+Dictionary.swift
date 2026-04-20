//
//  CardDeck+Dictionary.swift
//  HideAndCSeek50
//
//  RTDB conversion for CardDeck / CardDeckEntry / CustomCard.
//  Entries are stored as keyed dictionaries with an `orderIndex` field
//  so user-defined ordering survives a round trip.
//

import Foundation

extension CardDeck {
    func toDictionary() throws -> [String: Any] {
        var entriesDict: [String: [String: Any]] = [:]
        for (index, entry) in entries.enumerated() {
            entriesDict[entry.id] = try entry.toDictionary(orderIndex: index)
        }

        return [
            "id": id,
            "name": name,
            "isDefault": isDefault,
            "createdAt": createdAt.toFirebaseTimestamp(),
            "updatedAt": updatedAt.toFirebaseTimestamp(),
            "entries": entriesDict
        ]
    }

    static func fromDictionary(_ dict: [String: Any]) throws -> CardDeck {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String,
              let createdAtTimestamp = dict["createdAt"] as? Int64,
              let updatedAtTimestamp = dict["updatedAt"] as? Int64 else {
            throw DatabaseError.invalidData("CardDeck.fromDictionary: missing required fields")
        }

        let isDefault = dict["isDefault"] as? Bool ?? false

        var entries: [CardDeckEntry] = []
        if let entriesDict = dict["entries"] as? [String: [String: Any]] {
            var indexed: [(Int, CardDeckEntry)] = []
            for (_, entryData) in entriesDict {
                if let pair = try? CardDeckEntry.fromDictionaryWithOrder(entryData) {
                    indexed.append(pair)
                }
            }
            entries = indexed.sorted { $0.0 < $1.0 }.map { $0.1 }
        }

        return CardDeck(
            id: id,
            name: name,
            isDefault: isDefault,
            createdAt: Date.fromFirebaseTimestamp(createdAtTimestamp),
            updatedAt: Date.fromFirebaseTimestamp(updatedAtTimestamp),
            entries: entries
        )
    }
}

extension CardDeckEntry {
    func toDictionary(orderIndex: Int) throws -> [String: Any] {
        return [
            "id": id,
            "card": try card.toDictionary(),
            "multiplier": multiplier,
            "orderIndex": orderIndex
        ]
    }

    static func fromDictionaryWithOrder(_ dict: [String: Any]) throws -> (Int, CardDeckEntry) {
        guard let id = dict["id"] as? String,
              let cardDict = dict["card"] as? [String: Any],
              let multiplier = dict["multiplier"] as? Int else {
            throw DatabaseError.invalidData("CardDeckEntry.fromDictionary: missing required fields")
        }

        let card = try CustomCard.fromDictionary(cardDict)
        let orderIndex = dict["orderIndex"] as? Int ?? 0

        return (orderIndex, CardDeckEntry(id: id, card: card, multiplier: multiplier))
    }
}

extension CustomCard {
    func toDictionary() throws -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "type": type.rawValue
        ]

        switch type {
        case .curse:
            if let v = curseTitle { dict["curseTitle"] = v }
            if let v = curseDescription { dict["curseDescription"] = v }
            if let v = castingCost { dict["castingCost"] = v }
        case .powerup:
            if let v = powerupTitle { dict["powerupTitle"] = v }
            if let v = powerupDescription { dict["powerupDescription"] = v }
        case .timeBonus:
            if let v = timeBonusMinutes { dict["timeBonusMinutes"] = v }
        }

        return dict
    }

    static func fromDictionary(_ dict: [String: Any]) throws -> CustomCard {
        guard let id = dict["id"] as? String,
              let typeRaw = dict["type"] as? String,
              let type = CardType(rawValue: typeRaw) else {
            throw DatabaseError.invalidData("CustomCard.fromDictionary: missing id or type (dict=\(dict))")
        }

        return CustomCard(
            id: id,
            type: type,
            curseTitle: dict["curseTitle"] as? String,
            curseDescription: dict["curseDescription"] as? String,
            castingCost: dict["castingCost"] as? String,
            powerupTitle: dict["powerupTitle"] as? String,
            powerupDescription: dict["powerupDescription"] as? String,
            timeBonusMinutes: dict["timeBonusMinutes"] as? Int
        )
    }
}
