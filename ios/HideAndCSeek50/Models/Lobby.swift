//
//  Lobby.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import Foundation

struct Lobby: Codable, Equatable {
    let code: String
    let hostUID: String
    var gameId: String?
    let name: String
    var isPublic: Bool = true
    var maxHiders: Int = 2
    var maxSeekers: Int = 2
    var hidingTime: Int = 30 // 30 minutes default
    var city: GameCity = .boston
    let createdAt: Date
    let expiresAt: Date
    var isActive: Bool = true
    var players: [String: LobbyPlayer] = [:]
    var bannedUsers: [String] = [] // List of banned user IDs
    var questionSetId: String? = nil
    var questionSetName: String? = nil
    var cardDeckId: String? = nil
    var cardDeckName: String? = nil
    var maxHandSize: Int = 5

    var totalPlayers: Int {
        return players.count
    }
    
    var maxPlayers: Int {
        return maxHiders + maxSeekers
    }
    
    var hidersCount: Int {
        return players.values.filter(\.isHider).count
    }
    
    var seekersCount: Int {
        return players.values.filter(\.isSeeker).count
    }
    
    var canJoin: Bool {
        return isActive && totalPlayers < maxPlayers
    }
    
    func canUserJoin(uid: String) -> Bool {
        return canJoin && !bannedUsers.contains(uid)
    }
    
    var canStart: Bool {
        return hidersCount > 0 && seekersCount > 0 && players.values.allSatisfy { $0.isReady }
    }
    
    static func == (lhs: Lobby, rhs: Lobby) -> Bool {
        return lhs.code == rhs.code
    }
}


struct LobbyPlayer: Codable, Equatable {
    let uid: String
    let displayName: String
    var team: Team
    var isReady: Bool = false
    let joinedAt: Date
    var isOnline: Bool = true
    
    static func == (lhs: LobbyPlayer, rhs: LobbyPlayer) -> Bool {
        return lhs.uid == rhs.uid
    }
    
    var isHider: Bool { team == .hiders }
    var isSeeker: Bool { team == .seekers }
}

struct ActiveGame: Codable {
    let gameId: String
    var state: GameState
    var playerCount: Int
    var lastActivity: Date
    let hostUID: String
}

extension LobbyPlayer {
    func toDictionary() throws -> [String: Any] {
        return [
            "uid": uid,
            "displayName": displayName,
            "team": team.rawValue,
            "isReady": isReady,
            "joinedAt": joinedAt.toFirebaseTimestamp(),
            "isOnline": isOnline
        ]
    }
    
    static func fromDictionary(_ dictionary: [String: Any]) throws -> LobbyPlayer {
        guard let uid = dictionary["uid"] as? String,
              let displayName = dictionary["displayName"] as? String,
              let teamString = dictionary["team"] as? String,
              let team = Team(rawValue: teamString),
              let joinedAtTimestamp = dictionary["joinedAt"] as? Int64 else {
            throw DatabaseError.invalidData("LobbyPlayer.fromDictionary")
        }
        
        let isReady = dictionary["isReady"] as? Bool ?? false
        let isOnline = dictionary["isOnline"] as? Bool ?? true
        let joinedAt = Date.fromFirebaseTimestamp(joinedAtTimestamp)
        
        return LobbyPlayer(
            uid: uid,
            displayName: displayName,
            team: team,
            isReady: isReady,
            joinedAt: joinedAt,
            isOnline: isOnline
        )
    }
}

extension Lobby {
    func toDictionary() throws -> [String: Any] {
        var dict: [String: Any] = [
            "code": code,
            "hostUID": hostUID,
            "name": name,
            "isPublic": isPublic,
            "maxHiders": maxHiders,
            "maxSeekers": maxSeekers,
            "hidingTime": hidingTime,
            "city": city.rawValue,
            "createdAt": createdAt.toFirebaseTimestamp(),
            "expiresAt": expiresAt.toFirebaseTimestamp(),
            "isActive": isActive,
            "bannedUsers": bannedUsers,
            "maxHandSize": maxHandSize
        ]
        
        if let gameId = gameId {
            dict["gameId"] = gameId
        }

        if let questionSetId = questionSetId {
            dict["questionSetId"] = questionSetId
        }
        if let questionSetName = questionSetName {
            dict["questionSetName"] = questionSetName
        }
        if let cardDeckId = cardDeckId {
            dict["cardDeckId"] = cardDeckId
        }
        if let cardDeckName = cardDeckName {
            dict["cardDeckName"] = cardDeckName
        }

        // Convert players dictionary
        var playersDict: [String: [String: Any]] = [:]
        for (uid, player) in players {
            playersDict[uid] = try player.toDictionary()
        }
        dict["players"] = playersDict
        
        return dict
    }
    
    static func fromDictionary(_ dictionary: [String: Any]) throws -> Lobby {
        guard let code = dictionary["code"] as? String,
              let hostUID = dictionary["hostUID"] as? String,
              let name = dictionary["name"] as? String,
              let createdAtTimestamp = dictionary["createdAt"] as? Int64,
              let expiresAtTimestamp = dictionary["expiresAt"] as? Int64 else {
            print("invalid", dictionary)
            throw DatabaseError.invalidData("Lobby.fromDictionary")
        }
        
        let gameId = dictionary["gameId"] as? String // Now optional
        let isPublic = dictionary["isPublic"] as? Bool ?? true
        let maxHiders = dictionary["maxHiders"] as? Int ?? 2
        let maxSeekers = dictionary["maxSeekers"] as? Int ?? 2
        let hidingTime = dictionary["hidingTime"] as? Int ?? 30 // 30 minutes default
        let cityRaw = dictionary["city"] as? String ?? "boston"
        let city = GameCity(rawValue: cityRaw) ?? .boston
        let isActive = dictionary["isActive"] as? Bool ?? true
        let bannedUsers = dictionary["bannedUsers"] as? [String] ?? []
        let maxHandSize = dictionary["maxHandSize"] as? Int ?? 5
        
        let createdAt = Date.fromFirebaseTimestamp(createdAtTimestamp)
        let expiresAt = Date.fromFirebaseTimestamp(expiresAtTimestamp)
        
        var players: [String: LobbyPlayer] = [:]
        if let playersData = dictionary["players"] as? [String: [String: Any]] {
            for (uid, playerData) in playersData {
                if let player = try? LobbyPlayer.fromDictionary(playerData) {
                    players[uid] = player
                }
            }
        }
        
        let questionSetId = dictionary["questionSetId"] as? String
        let questionSetName = dictionary["questionSetName"] as? String
        let cardDeckId = dictionary["cardDeckId"] as? String
        let cardDeckName = dictionary["cardDeckName"] as? String

        return Lobby(
            code: code,
            hostUID: hostUID,
            gameId: gameId,
            name: name,
            isPublic: isPublic,
            maxHiders: maxHiders,
            maxSeekers: maxSeekers,
            hidingTime: hidingTime,
            city: city,
            createdAt: createdAt,
            expiresAt: expiresAt,
            isActive: isActive,
            players: players,
            bannedUsers: bannedUsers,
            questionSetId: questionSetId,
            questionSetName: questionSetName,
            cardDeckId: cardDeckId,
            cardDeckName: cardDeckName,
            maxHandSize: maxHandSize
        )
    }
}

extension ActiveGame {
    func toDictionary() throws -> [String: Any] {
        return [
            "gameId": gameId,
            "state": state.rawValue,
            "playerCount": playerCount,
            "lastActivity": lastActivity.toFirebaseTimestamp(),
            "hostUID": hostUID
        ]
    }
    
    static func fromDictionary(_ dictionary: [String: Any]) throws -> ActiveGame {
        guard let gameId = dictionary["gameId"] as? String,
              let stateString = dictionary["state"] as? String,
              let state = GameState(rawValue: stateString),
              let playerCount = dictionary["playerCount"] as? Int,
              let lastActivityTimestamp = dictionary["lastActivity"] as? Int64,
              let hostUID = dictionary["hostUID"] as? String else {
            throw DatabaseError.invalidData("ActiveGame.fromDictionary")
        }
        
        let lastActivity = Date.fromFirebaseTimestamp(lastActivityTimestamp)
        
        return ActiveGame(
            gameId: gameId,
            state: state,
            playerCount: playerCount,
            lastActivity: lastActivity,
            hostUID: hostUID
        )
    }
}
