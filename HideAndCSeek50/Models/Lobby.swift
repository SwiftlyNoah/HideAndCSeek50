//
//  Lobby.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import Foundation

struct Lobby: Codable {
    let code: String
    let hostUID: String
    let gameId: String
    let name: String
    var isPublic: Bool = true
    var maxHiders: Int = 2
    var maxSeekers: Int = 2
    let createdAt: Date
    let expiresAt: Date
    var isActive: Bool = true
    var players: [String: LobbyPlayer] = [:]
    
    var totalPlayers: Int {
        return players.count
    }
    
    var maxPlayers: Int {
        return maxHiders + maxSeekers
    }
    
    var hidersCount: Int {
        return players.values.filter { $0.team == .hiders }.count
    }
    
    var seekersCount: Int {
        return players.values.filter { $0.team == .seekers }.count
    }
    
    var canJoin: Bool {
        return isActive && totalPlayers < maxPlayers
    }
    
    var canStart: Bool {
        return hidersCount > 0 && seekersCount > 0 && players.values.allSatisfy { $0.isReady }
    }
}

extension Lobby {
    func toDictionary() throws -> [String: Any] {
        var dict: [String: Any] = [
            "code": code,
            "hostUID": hostUID,
            "gameId": gameId,
            "name": name,
            "isPublic": isPublic,
            "maxHiders": maxHiders,
            "maxSeekers": maxSeekers,
            "createdAt": createdAt.toFirebaseTimestamp(),
            "expiresAt": expiresAt.toFirebaseTimestamp(),
            "isActive": isActive
        ]
        
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
              let gameId = dictionary["gameId"] as? String,
              let name = dictionary["name"] as? String,
              let createdAtTimestamp = dictionary["createdAt"] as? Int64,
              let expiresAtTimestamp = dictionary["expiresAt"] as? Int64 else {
            throw DatabaseError.invalidData
        }
        
        let isPublic = dictionary["isPublic"] as? Bool ?? true
        let maxHiders = dictionary["maxHiders"] as? Int ?? 2
        let maxSeekers = dictionary["maxSeekers"] as? Int ?? 2
        let isActive = dictionary["isActive"] as? Bool ?? true
        
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
        
        return Lobby(
            code: code,
            hostUID: hostUID,
            gameId: gameId,
            name: name,
            isPublic: isPublic,
            maxHiders: maxHiders,
            maxSeekers: maxSeekers,
            createdAt: createdAt,
            expiresAt: expiresAt,
            isActive: isActive,
            players: players
        )
    }
}

struct LobbyPlayer: Codable {
    let uid: String
    let displayName: String
    var team: Team
    var isReady: Bool = false
    let joinedAt: Date
    var isOnline: Bool = true
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
            throw DatabaseError.invalidData
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

struct ActiveGame: Codable {
    let gameId: String
    var state: GameState
    var playerCount: Int
    var lastActivity: Date
    let hostUID: String
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
            throw DatabaseError.invalidData
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
