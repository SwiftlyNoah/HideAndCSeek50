//
//  Stats+History.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import Foundation

struct UserProfile: Codable {
    let uid: String
    let displayName: String
    let email: String?
    let isAnonymous: Bool
    let createdAt: Date
    var lastActive: Date
    let avatarURL: String?
    
    enum CodingKeys: String, CodingKey {
        case uid, displayName, email, isAnonymous, createdAt, lastActive, avatarURL
    }
}

struct UserStats: Codable {
    var totalGamesPlayed: Int = 0
    var totalGamesWon: Int = 0
    var hiderStats: HiderStats = HiderStats()
    var seekerStats: SeekerStats = SeekerStats()
    var achievements: Achievements = Achievements()
    
    var winRate: Double {
        guard totalGamesPlayed > 0 else { return 0.0 }
        return Double(totalGamesWon) / Double(totalGamesPlayed)
    }
}

struct HiderStats: Codable {
    var gamesPlayed: Int = 0
    var gamesWon: Int = 0
    var averageHidingTime: TimeInterval = 0
    var bestHidingTime: TimeInterval = 0
    var timesFound: Int = 0
    
    var hiderWinRate: Double {
        guard gamesPlayed > 0 else { return 0.0 }
        return Double(gamesWon) / Double(gamesPlayed)
    }
}

struct SeekerStats: Codable {
    var gamesPlayed: Int = 0
    var gamesWon: Int = 0
    var averageFindTime: TimeInterval = 0
    var bestFindTime: TimeInterval = 0
    var totalHidersFound: Int = 0
    
    var seekerWinRate: Double {
        guard gamesPlayed > 0 else { return 0.0 }
        return Double(gamesWon) / Double(gamesPlayed)
    }
}

struct Achievements: Codable {
    var quickSeeker: Bool = false      // Found hider in under 5 minutes
    var masterHider: Bool = false      // Hidden for over 30 minutes
    var teamPlayer: Bool = false       // Won 10 team games
    var veteran: Bool = false          // Played 100+ games
}

struct GameHistoryEntry: Codable {
    let gameId: String
    let team: Team
    let result: GameResult
    let duration: TimeInterval
    let datePlayed: Date
}

struct UserPreferences: Codable {
    var allowLocationSharing: Bool = true
    var receiveNotifications: Bool = true
    var defaultTeam: Team = .hiders
}
