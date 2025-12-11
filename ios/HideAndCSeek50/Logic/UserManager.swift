//
//  UserManager.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/11/25.
//

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
}
