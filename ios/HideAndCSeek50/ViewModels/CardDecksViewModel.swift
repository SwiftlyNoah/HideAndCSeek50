//
//  CardDecksViewModel.swift
//  HideAndCSeek50
//
//  Owns the live list of the current user's card decks and exposes CRUD.
//  Backed by a single RTDB observer on `users/{uid}/cardDecks`.
//

import SwiftUI
internal import Combine
import Firebase
import FirebaseDatabase

@MainActor
final class CardDecksViewModel: ObservableObject {
    @Published private(set) var decks: [CardDeck] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private var listenerHandle: DatabaseHandle?
    private var listenerRef: DatabaseReference?
    private var currentUid: String?

    func startListening(uid: String) {
        if currentUid == uid, listenerHandle != nil { return }
        stopListening()
        currentUid = uid
        isLoading = true

        decks = [CardDeck.makeDefault()]

        Task {
            try? await UserManager.shared.seedDefaultCardDeckIfNeeded(uid: uid)
            let ref = DatabaseReference.user(uid).child("cardDecks")
            self.listenerRef = ref
            self.listenerHandle = ref.observe(.value) { [weak self] snapshot in
                let parsed = Self.parse(snapshot: snapshot)
                Task { @MainActor in
                    self?.decks = parsed
                    self?.isLoading = false
                }
            }
        }
    }

    func stopListening() {
        if let handle = listenerHandle, let ref = listenerRef {
            ref.removeObserver(withHandle: handle)
        }
        listenerHandle = nil
        listenerRef = nil
        currentUid = nil
    }

    private static func parse(snapshot: DataSnapshot) -> [CardDeck] {
        var parsed: [CardDeck] = []
        if let data = snapshot.value as? [String: [String: Any]] {
            for (_, deckData) in data {
                if let deck = try? CardDeck.fromDictionary(deckData) {
                    parsed.append(deck)
                }
            }
        }
        if !parsed.contains(where: { $0.id == CardDeck.defaultId }) {
            parsed.append(CardDeck.makeDefault())
        }
        return parsed.sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    // MARK: - CRUD

    func createDeck(name: String) async throws -> CardDeck {
        guard let uid = currentUid else { throw DatabaseError.invalidOperation }
        let now = Date()
        let newDeck = CardDeck(
            id: UUID().uuidString,
            name: name,
            isDefault: false,
            createdAt: now,
            updatedAt: now,
            entries: []
        )
        try await UserManager.shared.saveCardDeck(uid: uid, deck: newDeck)
        return newDeck
    }

    func updateDeck(_ deck: CardDeck) async throws {
        guard let uid = currentUid else { throw DatabaseError.invalidOperation }
        guard !deck.isDefault else { throw DatabaseError.invalidOperation }
        try await UserManager.shared.saveCardDeck(uid: uid, deck: deck)
    }

    func deleteDeck(id: String) async throws {
        guard let uid = currentUid else { throw DatabaseError.invalidOperation }
        try await UserManager.shared.deleteCardDeck(uid: uid, id: id)
    }

    func renameDeck(id: String, to newName: String) async throws {
        guard let uid = currentUid else { throw DatabaseError.invalidOperation }
        try await UserManager.shared.renameCardDeck(uid: uid, id: id, to: newName)
    }

    func duplicateDeck(_ source: CardDeck, newName: String) async throws -> CardDeck {
        guard let uid = currentUid else { throw DatabaseError.invalidOperation }
        let now = Date()
        let copiedEntries = source.entries.map { entry in
            CardDeckEntry(
                id: UUID().uuidString,
                card: CustomCard(
                    id: UUID().uuidString,
                    type: entry.card.type,
                    curseTitle: entry.card.curseTitle,
                    curseDescription: entry.card.curseDescription,
                    castingCost: entry.card.castingCost,
                    powerupTitle: entry.card.powerupTitle,
                    powerupDescription: entry.card.powerupDescription,
                    timeBonusMinutes: entry.card.timeBonusMinutes
                ),
                multiplier: entry.multiplier
            )
        }
        let copy = CardDeck(
            id: UUID().uuidString,
            name: newName,
            isDefault: false,
            createdAt: now,
            updatedAt: now,
            entries: copiedEntries
        )
        try await UserManager.shared.saveCardDeck(uid: uid, deck: copy)
        return copy
    }
}
