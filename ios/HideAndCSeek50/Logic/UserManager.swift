//
//  UserManager.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/11/25.
//

import Firebase
import FirebaseDatabase

final class UserManager {
    static let shared = UserManager()
    
    private init() {}
    
    // MARK: - User Management
    func createUser(profile: UserProfile) async throws {
        let userRef = DatabaseReference.user(profile.uid)
        let userData: [String: Any] = [
            "profile": try profile.toDictionary(),
            "stats": try UserStats().toDictionary(),
            "preferences": try UserPreferences().toDictionary()
        ]
        try await userRef.setValue(userData)
    }
    
    func updateUserProfile(_ profile: UserProfile) async throws {
        let userRef = DatabaseReference.user(profile.uid).child("profile")
        try await userRef.setValue(try profile.toDictionary())
    }
    
    func getUserProfile(uid: String) async throws -> UserProfile {
        let snapshot = try await DatabaseReference.user(uid).child("profile").getData()
        guard let data = snapshot.value as? [String: Any] else {
            throw DatabaseError.userNotFound
        }
        return try UserProfile.fromDictionary(data)
    }

    // MARK: - FCM Token Management

    func saveFCMToken(uid: String, token: String) async throws {
        let userRef = DatabaseReference.user(uid)
        try await userRef.child("fcmToken").setValue(token)
        try await userRef.child("fcmTokenUpdatedAt").setValue(Date().timeIntervalSince1970)
    }

    // MARK: - Stats Management

    func updateUserStats(uid: String, stats: UserStats) async throws {
        let statsRef = DatabaseReference.user(uid).child("stats")
        try await statsRef.setValue(try stats.toDictionary())
    }
    
    func getUserStats(uid: String) async throws -> UserStats {
        let snapshot = try await DatabaseReference.user(uid).child("stats").getData()
        guard let data = snapshot.value as? [String: Any] else {
            return UserStats() // Return default stats if none exist
        }
        return try UserStats.fromDictionary(data)
    }
    
    // MARK: - Game History Management
    func saveGameHistory(uid: String, entry: GameHistoryEntry) async throws {
        let historyRef = DatabaseReference.user(uid).child("gameHistory").child(entry.gameId)
        try await historyRef.setValue(try entry.toDictionary())
    }

    func getGameHistory(uid: String, limit: Int = 10) async throws -> [GameHistoryEntry] {
        let historyRef = DatabaseReference.user(uid).child("gameHistory")
        let snapshot = try await historyRef.queryOrdered(byChild: "datePlayed")
            .queryLimited(toLast: UInt(limit))
            .getData()

        guard let data = snapshot.value as? [String: [String: Any]] else {
            return []
        }

        var history: [GameHistoryEntry] = []
        for (_, entryData) in data {
            if let entry = try? GameHistoryEntry.fromDictionary(entryData) {
                history.append(entry)
            }
        }

        // Sort by date (most recent first)
        return history.sorted { $0.datePlayed > $1.datePlayed }
    }

    // MARK: - Question Sets

    private func questionSetsRef(uid: String) -> DatabaseReference {
        return DatabaseReference.user(uid).child("questionSets")
    }

    /// Creates the seeded "Default" question set if it doesn't already exist for this user.
    /// Idempotent — safe to call on every app launch.
    func seedDefaultQuestionSetIfNeeded(uid: String) async throws {
        let ref = questionSetsRef(uid: uid).child(QuestionSet.defaultId)
        let snapshot = try await ref.getData()
        if snapshot.exists() {
            return
        }
        let defaultSet = QuestionSet.makeDefault()
        try await ref.setValue(try defaultSet.toDictionary())
    }

    func getQuestionSets(uid: String) async throws -> [QuestionSet] {
        let snapshot = try await questionSetsRef(uid: uid).getData()
        guard let data = snapshot.value as? [String: [String: Any]] else {
            return []
        }
        var sets: [QuestionSet] = []
        for (_, setData) in data {
            if let set = try? QuestionSet.fromDictionary(setData) {
                sets.append(set)
            }
        }
        return sets.sorted { lhs, rhs in
            // Default first, then most recently updated
            if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    func getQuestionSet(uid: String, id: String) async throws -> QuestionSet {
        let snapshot = try await questionSetsRef(uid: uid).child(id).getData()
        guard let data = snapshot.value as? [String: Any] else {
            throw DatabaseError.invalidData("getQuestionSet")
        }
        return try QuestionSet.fromDictionary(data)
    }

    /// Saves (creates or replaces) a question set. Bumps `updatedAt`.
    func saveQuestionSet(uid: String, set: QuestionSet) async throws {
        var stamped = set
        stamped.updatedAt = Date()
        let ref = questionSetsRef(uid: uid).child(stamped.id)
        try await ref.setValue(try stamped.toDictionary())
    }

    func deleteQuestionSet(uid: String, id: String) async throws {
        guard id != QuestionSet.defaultId else {
            throw DatabaseError.invalidOperation
        }
        try await questionSetsRef(uid: uid).child(id).removeValue()
    }

    func renameQuestionSet(uid: String, id: String, to newName: String) async throws {
        guard id != QuestionSet.defaultId else {
            throw DatabaseError.invalidOperation
        }
        let ref = questionSetsRef(uid: uid).child(id)
        try await ref.updateChildValues([
            "name": newName,
            "updatedAt": Date().toFirebaseTimestamp()
        ])
    }

    // MARK: - Card Decks

    private func cardDecksRef(uid: String) -> DatabaseReference {
        return DatabaseReference.user(uid).child("cardDecks")
    }

    func seedDefaultCardDeckIfNeeded(uid: String) async throws {
        let ref = cardDecksRef(uid: uid).child(CardDeck.defaultId)
        let snapshot = try await ref.getData()
        if snapshot.exists(),
           let data = snapshot.value as? [String: Any],
           let storedVersion = data["defaultVersion"] as? Int,
           storedVersion >= CardDeck.defaultVersion {
            return
        }
        let defaultDeck = CardDeck.makeDefault()
        var dict = try defaultDeck.toDictionary()
        dict["defaultVersion"] = CardDeck.defaultVersion
        try await ref.setValue(dict)
    }

    func getCardDecks(uid: String) async throws -> [CardDeck] {
        let snapshot = try await cardDecksRef(uid: uid).getData()
        guard let data = snapshot.value as? [String: [String: Any]] else {
            return []
        }
        var decks: [CardDeck] = []
        for (_, deckData) in data {
            if let deck = try? CardDeck.fromDictionary(deckData) {
                decks.append(deck)
            }
        }
        return decks.sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    func getCardDeck(uid: String, id: String) async throws -> CardDeck {
        let snapshot = try await cardDecksRef(uid: uid).child(id).getData()
        guard let data = snapshot.value as? [String: Any] else {
            throw DatabaseError.invalidData("getCardDeck(\(id)): not found")
        }
        return try CardDeck.fromDictionary(data)
    }

    func saveCardDeck(uid: String, deck: CardDeck) async throws {
        var stamped = deck
        stamped.updatedAt = Date()
        let ref = cardDecksRef(uid: uid).child(stamped.id)
        try await ref.setValue(try stamped.toDictionary())
    }

    func deleteCardDeck(uid: String, id: String) async throws {
        guard id != CardDeck.defaultId else {
            throw DatabaseError.invalidOperation
        }
        try await cardDecksRef(uid: uid).child(id).removeValue()
    }

    func renameCardDeck(uid: String, id: String, to newName: String) async throws {
        guard id != CardDeck.defaultId else {
            throw DatabaseError.invalidOperation
        }
        let ref = cardDecksRef(uid: uid).child(id)
        try await ref.updateChildValues([
            "name": newName,
            "updatedAt": Date().toFirebaseTimestamp()
        ])
    }
}
