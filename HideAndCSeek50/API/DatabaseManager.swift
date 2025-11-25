//
//  DatabaseManager.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import Foundation
import Firebase
import FirebaseDatabase
import CoreLocation
internal import Combine

enum DatabaseError: LocalizedError {
    case userNotFound
    case lobbyNotFound
    case gameNotFound
    case gameNotJoinable
    case invalidData
    case invalidOperation
    case networkError
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .lobbyNotFound:
            return "Lobby not found"
        case .gameNotFound:
            return "Game not found"
        case .gameNotJoinable:
            return "Game cannot be joined"
        case .invalidData:
            return "Invalid data received"
        case .invalidOperation:
            return "Invalid operation"
        case .networkError:
            return "Network error occurred"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}

extension DatabaseReference {
    static var root: DatabaseReference {
        return Database.database().reference()
    }
    
    static func user(_ uid: String) -> DatabaseReference {
        return root.child("users").child(uid)
    }
    
    static func lobby(_ code: String) -> DatabaseReference {
        return root.child("lobbies").child(code)
    }
    
    static func lobbies() -> DatabaseReference {
        return root.child("lobbies")
    }
    
    static func game(_ gameId: String) -> DatabaseReference {
        return root.child("games").child(gameId)
    }
    
    static func activeGames() -> DatabaseReference {
        return root.child("activeGames")
    }
    
    static func games() -> DatabaseReference {
        return root.child("games")
    }
}

extension Date {
    // Pure helpers – keep them nonisolated
    nonisolated static func fromFirebaseTimestamp(_ timestamp: Int64) -> Date {
        Date(timeIntervalSince1970: Double(timestamp))
    }
    
    nonisolated func toFirebaseTimestamp() -> Int64 {
        Int64(timeIntervalSince1970.rounded())
    }
}

class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()
    
    private let database = Database.database()
    private var gameListeners: [String: DatabaseHandle] = [:]
    private var lobbyListeners: [String: DatabaseHandle] = [:]
    
    @Published var currentGame: Game?
    @Published var currentLobby: Lobby?
    @Published var publicLobbies: [Lobby] = []
    @Published var isConnected = false
    
    private init() {
        // Monitor connection status
        let connectedRef = Database.database().reference(withPath: ".info/connected")
        connectedRef.observe(.value) { [weak self] snapshot in
            self?.isConnected = snapshot.value as? Bool ?? false
        }
    }
    
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
    
    // MARK: - Lobby Management
    
    func createLobby(hostUID: String, hostName: String, gameName: String, isPublic: Bool = true, maxHiders: Int = 2, maxSeekers: Int = 2, hidingTime: Int = 30, city: GameCity = .boston) async throws -> String {
        let code = generateGameCode()
        
        var lobby = Lobby(
            code: code,
            hostUID: hostUID,
            gameId: nil, // No gameId until game is started
            name: gameName,
            isPublic: isPublic,
            maxHiders: maxHiders,
            maxSeekers: maxSeekers,
            hidingTime: hidingTime,
            city: city,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600) // Expire in 1 hour
        )
        
        // Add host as first player (default to hiders)
        let hostPlayer = LobbyPlayer(
            uid: hostUID,
            displayName: hostName,
            team: .hiders,
            isReady: false,
            joinedAt: Date()
        )
        lobby.players[hostUID] = hostPlayer
        
        let lobbyRef = DatabaseReference.lobby(code)
        try await lobbyRef.setValue(try lobby.toDictionary())
        
        // Auto-delete after expiration
        schedulelobbyCleanup(code: code, expirationDate: lobby.expiresAt)
        
        return code
    }
    
    func getLobby(code: String) async throws -> Lobby {
        let snapshot = try await DatabaseReference.lobby(code).getData()
        
        guard let lobbyData = extractLobbyData(from: snapshot, code: code),
              let lobby = try? Lobby.fromDictionary(lobbyData),
              lobby.isActive else {
            throw DatabaseError.lobbyNotFound
        }
        return lobby
    }
    
    func joinLobby(code: String, playerUID: String, displayName: String) async throws -> Lobby {
        let lobbyRef = DatabaseReference.lobby(code)
        let snapshot = try await lobbyRef.getData()
        
        guard let lobbyData = extractLobbyData(from: snapshot, code: code),
              var lobby = try? Lobby.fromDictionary(lobbyData),
              lobby.canJoin else {
            throw DatabaseError.lobbyNotFound
        }
        
        // Determine which team to join (prefer team with fewer players)
        let team: Team = lobby.hidersCount <= lobby.seekersCount ? .hiders : .seekers
        
        let player = LobbyPlayer(
            uid: playerUID,
            displayName: displayName,
            team: team,
            isReady: false,
            joinedAt: Date()
        )
        
        lobby.players[playerUID] = player
        
        try await lobbyRef.setValue(try lobby.toDictionary())
        return lobby
    }
    
    func leaveLobby(code: String, playerUID: String) async throws {
        let lobbyRef = DatabaseReference.lobby(code)
        let snapshot = try await lobbyRef.getData()
        
        guard let lobbyData = extractLobbyData(from: snapshot, code: code),
              var lobby = try? Lobby.fromDictionary(lobbyData) else {
            throw DatabaseError.lobbyNotFound
        }
        
        lobby.players.removeValue(forKey: playerUID)
        
        // If the host leaves, transfer to another player or close lobby
        if playerUID == lobby.hostUID {
            if let newHost = lobby.players.values.first {
                let updatedLobby = Lobby(
                    code: lobby.code,
                    hostUID: newHost.uid,
                    gameId: lobby.gameId,
                    name: lobby.name,
                    isPublic: lobby.isPublic,
                    maxHiders: lobby.maxHiders,
                    maxSeekers: lobby.maxSeekers,
                    hidingTime: lobby.hidingTime,
                    city: lobby.city,
                    createdAt: lobby.createdAt,
                    expiresAt: lobby.expiresAt,
                    isActive: lobby.isActive,
                    players: lobby.players
                )
                try await lobbyRef.setValue(try updatedLobby.toDictionary())
            } else {
                // No players left, close lobby
                try await closeLobby(code: code)
                return
            }
        } else {
            try await lobbyRef.setValue(try lobby.toDictionary())
        }
    }
    
    func updateLobbySettings(code: String, maxHiders: Int, maxSeekers: Int, isPublic: Bool, hidingTime: Int, city: GameCity) async throws {
        let lobbyRef = DatabaseReference.lobby(code)
        let updates: [String: Any] = [
            "maxHiders": maxHiders,
            "maxSeekers": maxSeekers,
            "isPublic": isPublic,
            "hidingTime": hidingTime,
            "city": city.rawValue
        ]
        try await lobbyRef.updateChildValues(updates)
    }
    
    func startGameFromLobby(lobbyCode: String) async throws -> String {
        guard let lobby = currentLobby,
              lobby.code == lobbyCode,
              lobby.canStart else {
            throw DatabaseError.invalidOperation
        }
        
        let gameId = UUID().uuidString
        
        let gameInfo = GameInfo(
            gameId: gameId,
            gameCode: lobbyCode,
            name: lobby.name,
            hostUID: lobby.hostUID,
            state: .starting,
            maxPlayers: lobby.maxPlayers,
            currentPlayers: lobby.totalPlayers,
            createdAt: Date(),
            startedAt: Date(),
            settings: GameSettings(
                hidingTime: lobby.hidingTime,
                city: lobby.city
            )
        )
        
        // Create game in database with initial game structure
        let gameRef = DatabaseReference.game(gameId)
        try await gameRef.child("info").setValue(try gameInfo.toDictionary())
        
        // Initialize empty teams structure
        let teamsData: [String: Any] = [
            "hiders": [:],
            "seekers": [:]
        ]
        try await gameRef.child("teams").setValue(teamsData)
        
        // Add all lobby players to the game teams
        for (uid, player) in lobby.players {
            let teamMember: [String: Any] = [
                "uid": uid,
                "displayName": player.displayName,
                "isReady": true // All players are ready when game starts
            ]
            
            let teamPath = "teams/\(player.team.rawValue)/\(uid)"
            try await gameRef.child(teamPath).setValue(teamMember)
        }
        
        // Update lobby to point to game and mark as inactive
        // This change will trigger navigation for all players monitoring the lobby
        let lobbyRef = DatabaseReference.lobby(lobbyCode)
        try await lobbyRef.updateChildValues([
            "gameId": gameId,
            "isActive": false
        ])
        
        return gameId
    }

    func sendMessage(gameId: String, message: GameMessage) async throws {
        let messageRef = DatabaseReference.game(gameId).child("messages").child(message.id)
        try await messageRef.setValue(try message.toDictionary())
    }
    
    func observeGame(gameId: String, completion: @escaping (Game?) -> Void) {
        let gameRef = DatabaseReference.game(gameId)
        gameRef.observe(.value) { snapshot in
            guard let data = snapshot.value as? [String: Any] else {
                completion(nil)
                return
            }
            
            do {
                let game = try Game.fromDictionary(data)
                completion(game)
            } catch {
                print("Error parsing game data: \(error)")
                // Fallback if only info exists
                if let infoDict = data["info"] as? [String: Any],
                   let info = try? GameInfo.fromDictionary(infoDict) {
                    completion(Game(info: info, teams: GameTeams()))
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    func switchPlayerTeam(code: String, playerUID: String, team: Team) async throws {
        let lobbyRef = DatabaseReference.lobby(code)
        try await lobbyRef.child("players/\(playerUID)/team").setValue(team.rawValue)
    }
    
    func togglePlayerReady(code: String, playerUID: String) async throws {
        let lobbyRef = DatabaseReference.lobby(code)
        let playerRef = lobbyRef.child("players/\(playerUID)")
        
        let snapshot = try await playerRef.child("isReady").getData()
        let currentReady = snapshot.value as? Bool ?? false
        
        try await playerRef.child("isReady").setValue(!currentReady)
    }
    
    func getPublicLobbies() async throws -> [Lobby] {
        let snapshot = try await DatabaseReference.lobbies().getData()
        guard let data = snapshot.value as? [String: [String: Any]] else {
            return []
        }
        
        var lobbies: [Lobby] = []
        for (_, lobbyData) in data {
            if let lobby = try? Lobby.fromDictionary(lobbyData),
               lobby.isActive && lobby.isPublic && lobby.canJoin {
                lobbies.append(lobby)
            }
        }
        
        return lobbies.sorted { $0.createdAt > $1.createdAt }
    }
    
    func closeLobby(code: String) async throws {
        try await DatabaseReference.lobby(code).removeValue()
    }
    
    private func schedulelobbyCleanup(code: String, expirationDate: Date) {
        // In production, use Cloud Functions for this
        DispatchQueue.global().asyncAfter(deadline: .now() + expirationDate.timeIntervalSinceNow) {
            Task {
                try? await self.closeLobby(code: code)
            }
        }
    }
    
    // MARK: - Game Management
    func createGame(info: GameInfo) async throws -> String {
        let gameRef = DatabaseReference.game(info.gameId)
        let game = Game(info: info, teams: GameTeams())
        
        try await gameRef.setValue(try game.toDictionary())
        
        // Add to active games
        let activeGame = ActiveGame(
            gameId: info.gameId,
            state: info.state,
            playerCount: 0,
            lastActivity: Date(),
            hostUID: info.hostUID
        )
        try await DatabaseReference.activeGames().child(info.gameId).setValue(try activeGame.toDictionary())
        
        return info.gameId
    }
    
    func joinGame(gameId: String, playerUID: String, displayName: String, team: Team) async throws {
        let gameRef = DatabaseReference.game(gameId)
        
        // Check if game exists and is joinable
        let snapshot = try await gameRef.child("info").getData()
        guard let infoData = snapshot.value as? [String: Any],
              let gameInfo = try? GameInfo.fromDictionary(infoData),
              gameInfo.state == .waiting else {
            throw DatabaseError.gameNotJoinable
        }
        
        // Add player to team
        let member = Player(
            uid: playerUID,
            displayName: displayName,
            isReady: false,
            location: nil
        )
        
        let teamPath = "teams/\(team.rawValue)/\(playerUID)"
        try await gameRef.child(teamPath).setValue(try member.toDictionary())
        
        // Update player count
        let newCount = gameInfo.currentPlayers + 1
        try await gameRef.child("info/currentPlayers").setValue(newCount)
        
        // Log join event
        try await logGameEvent(
            gameId: gameId,
            type: .playerJoined,
            playerUID: playerUID,
            details: "\(displayName) joined as \(team.displayName)"
        )
    }
    
    func leaveGame(gameId: String, playerUID: String, lobbyCode: String? = nil) async throws {
        let gameRef = DatabaseReference.game(gameId)
        
        // Remove from both teams (in case they switched)
        try await gameRef.child("teams/hiders/\(playerUID)").removeValue()
        try await gameRef.child("teams/seekers/\(playerUID)").removeValue()
        
        // Update player count
        let snapshot = try await gameRef.child("info/currentPlayers").getData()
        if let currentCount = snapshot.value as? Int, currentCount > 0 {
            try await gameRef.child("info/currentPlayers").setValue(currentCount - 1)
        }
        
        // If lobby code is provided, also leave the lobby
        if let lobbyCode = lobbyCode {
            try await leaveLobby(code: lobbyCode, playerUID: playerUID)
        }
        
        // Log leave event
        try await logGameEvent(
            gameId: gameId,
            type: .playerLeft,
            playerUID: playerUID,
            details: "Player left the game"
        )
    }
    
    func startGame(gameId: String) async throws {
        let gameRef = DatabaseReference.game(gameId)
        let now = Date()
        
        let updates: [String: Any] = [
            "info/state": GameState.preHiding.rawValue,
            "info/startedAt": now.toFirebaseTimestamp()
        ]
        
        try await gameRef.updateChildValues(updates)
        
        // Log start event
        try await logGameEvent(
            gameId: gameId,
            type: .gameStarted,
            playerUID: nil,
            details: "Game started"
        )
    }
    
    func endGame(gameId: String, winner: Team?) async throws {
        let gameRef = DatabaseReference.game(gameId)
        let now = Date()
        
        var updates: [String: Any] = [
            "info/state": GameState.completed.rawValue,
            "info/endedAt": now.toFirebaseTimestamp()
        ]
        
        if let winner = winner {
            updates["info/winner"] = winner.rawValue
        }
        
        try await gameRef.updateChildValues(updates)
        
        // Remove from active games
        try await DatabaseReference.activeGames().child(gameId).removeValue()
        
        // Update player stats
        try await updateGameStatistics(gameId: gameId)
        
        // Log end event
        try await logGameEvent(
            gameId: gameId,
            type: .gameEnded,
            playerUID: nil,
            details: winner != nil ? "\(winner!.displayName) won!" : "Game ended"
        )
    }
    
    // MARK: - Game State Management
    
    func updateGameState(
        gameId: String, 
        state: GameState, 
        hidingStartedAt: Date? = nil,
        hidingElapsed: TimeInterval? = nil,
        seekingStartedAt: Date? = nil,
        seekingElapsed: TimeInterval? = nil,
        winner: Team? = nil
    ) async throws {
        let ref = DatabaseReference.game(gameId).child("info")
        
        var updates: [String: Any] = [
            "state": state.rawValue
        ]
        
        if let hidingStartedAt = hidingStartedAt {
            updates["hidingStartedAt"] = hidingStartedAt.toFirebaseTimestamp()
        }
        
        if let hidingElapsed = hidingElapsed {
            updates["hidingElapsed"] = hidingElapsed
        }
        
        if let seekingStartedAt = seekingStartedAt {
            updates["seekingStartedAt"] = seekingStartedAt.toFirebaseTimestamp()
        }
        
        if let seekingElapsed = seekingElapsed {
            updates["seekingElapsed"] = seekingElapsed
        }
        
        if let winner = winner {
            updates["winner"] = winner.rawValue
        }
        
        // Auto-transition: hiding timer complete -> preSeeking
        if state == .hiding, let hidingElapsed = hidingElapsed {
            // Check if hiding time is complete
            let snapshot = try await ref.child("settings/hidingTime").getData()
            if let hidingTimeMinutes = snapshot.value as? Int {
                let totalHidingTime = TimeInterval(hidingTimeMinutes * 60)
                if hidingElapsed >= totalHidingTime {
                    updates["state"] = GameState.preSeeking.rawValue
                }
            }
        }
        
        try await ref.updateChildValues(updates)
    }
    
    // MARK: - Location Management
    
    func updatePlayerLocation(gameId: String, playerUID: String, team: Team, location: PlayerLocation) async throws {
        let playerLocationRef = DatabaseReference.game(gameId).child("teams/\(team.rawValue)/\(playerUID)/location")
        try await playerLocationRef.setValue(try location.toDictionary())

        // Update last activity
        try await DatabaseReference.activeGames().child(gameId).child("lastActivity").setValue(Date().toFirebaseTimestamp())
    }
    
    
    // MARK: - Questions
    func sendQuestion(gameId: String, question: GameQuestion) async throws {
        let questionRef = DatabaseReference.game(gameId).child("questions").child(question.id)
        try await questionRef.setValue(try question.toDictionary())
        
        // Also send as message
        let message = GameMessage(
            id: UUID().uuidString,
            senderUID: question.askedBy,
            senderName: "Seekers",
            content: question.question,
            type: .question,
            timestamp: question.askedAt,
            attachments: nil,
            questionData: QuestionData(
                questionId: question.id,
                questionText: question.question,
                correctAnswer: nil,
                playerAnswer: nil
            ),
            team: .seekers
        )
        
        try await sendMessage(gameId: gameId, message: message)
        
        // Don't log question events - questions are stored separately under questions node
    }
    
    func answerQuestion(gameId: String, questionId: String, answer: String, answeredBy: String) async throws {
        let questionRef = DatabaseReference.game(gameId).child("questions").child(questionId)
        let updates: [String: Any] = [
            "answeredBy": answeredBy,
            "answeredAt": Date().toFirebaseTimestamp(),
            "answer": answer
        ]
        
        try await questionRef.updateChildValues(updates)
    }
    
    
    // MARK: - Real-time Listeners
    func startListeningToGame(gameId: String) {
        stopListeningToGame(gameId: gameId)
        let ref = DatabaseReference.game(gameId)
        let handle = ref.observe(.value) { [weak self] snapshot in
            guard let data = snapshot.value as? [String: Any] else {
                DispatchQueue.main.async {
                    self?.currentGame = nil
                }
                return
            }
            
            do {
                let game = try Game.fromDictionary(data)
                DispatchQueue.main.async {
                    self?.currentGame = game
                }
            } catch {
                print("Error parsing game data: \(error)")
                // Fallback if only info exists
                if let infoDict = data["info"] as? [String: Any],
                   let info = try? GameInfo.fromDictionary(infoDict) {
                    DispatchQueue.main.async {
                        self?.currentGame = Game(info: info, teams: GameTeams())
                    }
                }
            }
        }
        gameListeners[gameId] = handle
    }
    
    func stopListeningToGame(gameId: String) {
        if let handle = gameListeners[gameId] {
            DatabaseReference.game(gameId).removeObserver(withHandle: handle)
            gameListeners.removeValue(forKey: gameId)
        }
    }
    
    // MARK: - Lobby Listeners
    
    func startListeningToLobby(code: String) {
        stopListeningToLobby(code: code)
        
        let lobbyRef = DatabaseReference.lobby(code)
        let handle = lobbyRef.observe(.value) { [weak self] snapshot in
            guard let lobbyData = self?.extractLobbyData(from: snapshot, code: code),
                  let lobby = try? Lobby.fromDictionary(lobbyData) else {
                DispatchQueue.main.async {
                    self?.currentLobby = nil
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.currentLobby = lobby
            }
        }
        
        lobbyListeners[code] = handle
    }
    
    func stopListeningToLobby(code: String) {
        if let handle = lobbyListeners[code] {
            DatabaseReference.lobby(code).removeObserver(withHandle: handle)
            lobbyListeners.removeValue(forKey: code)
        }
    }
    
    func startListeningToPublicLobbies() {
        let lobbiesRef = DatabaseReference.lobbies()
        let handle = lobbiesRef.observe(.value) { [weak self] snapshot in
            guard let data = snapshot.value as? [String: [String: Any]] else {
                DispatchQueue.main.async {
                    self?.publicLobbies = []
                }
                return
            }
            
            var lobbies: [Lobby] = []
            for (_, lobbyData) in data {
                if let lobby = try? Lobby.fromDictionary(lobbyData),
                   lobby.isActive && lobby.isPublic && lobby.canJoin {
                    lobbies.append(lobby)
                }
            }
            
            DispatchQueue.main.async {
                self?.publicLobbies = lobbies.sorted { $0.createdAt > $1.createdAt }
            }
        }
        
        lobbyListeners["public"] = handle
    }
    
    func stopListeningToPublicLobbies() {
        if let handle = lobbyListeners["public"] {
            DatabaseReference.lobbies().removeObserver(withHandle: handle)
            lobbyListeners.removeValue(forKey: "public")
        }
    }
    
    func startGameFromLobby(lobby: Lobby) async throws -> String {
        let gameId = UUID().uuidString
        let info = GameInfo(
            gameId: gameId,
            gameCode: lobby.code,
            name: lobby.name,
            hostUID: lobby.hostUID,
            state: .waiting,
            maxPlayers: lobby.maxPlayers,
            currentPlayers: lobby.totalPlayers,
            createdAt: lobby.createdAt,
            settings: GameSettings(
                hidingTime: lobby.hidingTime,
                city: lobby.city
            )
        )
        
        _ = try await createGame(info: info)
        
        for (uid, player) in lobby.players {
            try await joinGame(gameId: gameId, playerUID: uid, displayName: player.displayName, team: player.team)
        }
        
        try await startGame(gameId: gameId)
        return gameId
    }
    
    // MARK: - Helper Methods
    
    private func extractLobbyData(from snapshot: DataSnapshot, code: String) -> [String: Any]? {
        // Handle both cases: direct lobby data or wrapped in code key
        if let wrappedData = snapshot.value as? [String: [String: Any]],
            let innerData = wrappedData[code] {
            return innerData
        } else if let directData = snapshot.value as? [String: Any] {
            return directData
        }
        return nil
    }
    
    private func generateGameCode() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
    
    private func logGameEvent(gameId: String, type: EventType, playerUID: String?, details: String) async throws {
        // Create GameEvent with a dictionary since it uses custom Codable
        let eventData: [String: Any] = [
            "type": type.rawValue,
            "timestamp": Date().toFirebaseTimestamp(),
            "playerUID": playerUID as Any,
            "details": details
        ]
        
        let eventRef = DatabaseReference.game(gameId).child("events").childByAutoId()
        try await eventRef.setValue(eventData)
    }
    
    private func updateGameStatistics(gameId: String) async throws {
        // Get final game state
        let snapshot = try await DatabaseReference.game(gameId).getData()
        guard let gameData = snapshot.value as? [String: Any],
              let game = try? Game.fromDictionary(gameData) else { return }
        
        // Update stats for all players
        for (uid, _) in game.teams.hiders {
            var stats = try await getUserStats(uid: uid)
            stats.totalGamesPlayed += 1
            stats.hiderStats.gamesPlayed += 1
            
            if game.info.winner == .hiders {
                stats.totalGamesWon += 1
                stats.hiderStats.gamesWon += 1
            }
            
            // Update other hider-specific stats
            if let duration = game.info.endedAt?.timeIntervalSince(game.info.startedAt ?? Date()) {
                stats.hiderStats.averageHidingTime =
                (stats.hiderStats.averageHidingTime * Double(stats.hiderStats.gamesPlayed - 1) + duration) /
                Double(stats.hiderStats.gamesPlayed)
                
                if duration > stats.hiderStats.bestHidingTime {
                    stats.hiderStats.bestHidingTime = duration
                }
            }
            
            try await updateUserStats(uid: uid, stats: stats)
        }
        
        // Similar logic for seekers
        for (uid, _) in game.teams.seekers {
            var stats = try await getUserStats(uid: uid)
            stats.totalGamesPlayed += 1
            stats.seekerStats.gamesPlayed += 1
            
            if game.info.winner == .seekers {
                stats.totalGamesWon += 1
                stats.seekerStats.gamesWon += 1
            }
                        
            try await updateUserStats(uid: uid, stats: stats)
        }
    }
}



// MARK: - Codable Extensions

extension Encodable {
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw DatabaseError.invalidData
        }
        return dictionary
    }
}

extension Decodable {
    static func fromDictionary(_ dictionary: [String: Any]) throws -> Self {
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        return try JSONDecoder().decode(Self.self, from: data)
    }
}
