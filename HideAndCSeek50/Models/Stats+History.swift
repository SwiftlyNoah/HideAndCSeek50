//
//  Stats+History.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import Foundation
import Firebase
import FirebaseDatabase

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
    var hiderStats: HiderStats = HiderStats()
    var seekerStats: SeekerStats = SeekerStats()
    var achievements: Achievements = Achievements()
}

struct HiderStats: Codable {
    var gamesPlayed: Int = 0
    var averageHidingTime: TimeInterval = 0
    var bestHidingTime: TimeInterval = 0
}

struct SeekerStats: Codable {
    var gamesPlayed: Int = 0
    var averageFindTime: TimeInterval = 0
    var bestFindTime: TimeInterval = 0
}

struct Achievements: Codable {
    var quickSeeker: Bool = false      // Found hider in under 5 minutes
    var masterHider: Bool = false      // Hidden for over 30 minutes
    var teamPlayer: Bool = false       // Won 10 team games
    var veteran: Bool = false          // Played 100+ games
}

struct GameHistoryEntry: Codable, Identifiable {
    let id: String // gameId
    let gameId: String
    let gameName: String
    let team: Team
    let hidingTime: TimeInterval
    let seekingTime: TimeInterval
    let duration: TimeInterval
    let datePlayed: Date
    let city: GameCity
    let playerCount: Int
    let wasHost: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, gameId, gameName, team, hidingTime, seekingTime, duration, datePlayed, city, playerCount, wasHost
    }
}

struct UserPreferences: Codable {
    var allowLocationSharing: Bool = true
    var receiveNotifications: Bool = true
}

// MARK: - Dictionary Conversion Extensions for Stats & History

extension GameHistoryEntry {
    func toDictionary() throws -> [String: Any] {
        return [
            "id": id,
            "gameId": gameId,
            "gameName": gameName,
            "team": team.rawValue,
            "hidingTime": hidingTime,
            "seekingTime": seekingTime,
            "duration": duration,
            "datePlayed": datePlayed.toFirebaseTimestamp(),
            "city": city.rawValue,
            "playerCount": playerCount,
            "wasHost": wasHost
        ]
    }
    
    static func fromDictionary(_ dictionary: [String: Any]) throws -> GameHistoryEntry {
        guard let id = dictionary["id"] as? String,
              let gameId = dictionary["gameId"] as? String,
              let gameName = dictionary["gameName"] as? String,
              let teamRaw = dictionary["team"] as? String,
              let team = Team(rawValue: teamRaw),
              let hidingTime = dictionary["hidingTime"] as? TimeInterval,
              let seekingTime = dictionary["seekingTime"] as? TimeInterval,
              let duration = dictionary["duration"] as? TimeInterval,
              let datePlayedInt = dictionary["datePlayed"] as? Int64,
              let cityRaw = dictionary["city"] as? String,
              let city = GameCity(rawValue: cityRaw),
              let playerCount = dictionary["playerCount"] as? Int,
              let wasHost = dictionary["wasHost"] as? Bool else {
            throw DatabaseError.invalidData
        }
        
        let datePlayed = Date.fromFirebaseTimestamp(datePlayedInt)
        
        return GameHistoryEntry(
            id: id,
            gameId: gameId,
            gameName: gameName,
            team: team,
            hidingTime: hidingTime,
            seekingTime: seekingTime,
            duration: duration,
            datePlayed: datePlayed,
            city: city,
            playerCount: playerCount,
            wasHost: wasHost
        )
    }
}
