//
//  DatabaseManager.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import Foundation
import Firebase
import FirebaseDatabase
import FirebaseAuth
internal import Combine

enum DatabaseError: LocalizedError {
    case userNotFound
    case lobbyNotFound
    case gameNotFound
    case gameNotJoinable
    case invalidData(String)
    case invalidOperation
    case networkError
    case permissionDenied
    case emptyQuestionSet
    case emptyCardDeck

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
        case .invalidData(let endpoint):
            return "Invalid data received in \(endpoint)"
        case .invalidOperation:
            return "Invalid operation"
        case .networkError:
            return "Network error occurred"
        case .permissionDenied:
            return "Permission denied"
        case .emptyQuestionSet:
            return "The selected question set has no questions. Add at least one category with one question before starting."
        case .emptyCardDeck:
            return "The selected card deck has no valid cards. Add at least one card before starting."
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

@MainActor
class GameManager: ObservableObject {
    private let database = Database.database()
    private var gameListeners: [String: DatabaseHandle] = [:]
    private var lobbyListeners: [String: DatabaseHandle] = [:]
    
    @Published var currentGame: Game?
    @Published var currentLobby: Lobby?
    @Published var publicLobbies: [Lobby] = []
    @Published var isConnected = false
    
    // MARK: - Game Persistence Keys
    private enum PersistenceKeys {
        static let lastGameId = "lastGameId"
        static let lastLobbyCode = "lastLobbyCode"
        static let lastPlayerTeam = "lastPlayerTeam"
        static let lastGameTimestamp = "lastGameTimestamp"
    }
    
    init() {
        // Monitor connection status
        let connectedRef = Database.database().reference(withPath: ".info/connected")
        connectedRef.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                self?.isConnected = snapshot.value as? Bool ?? false
            }
        }
    }
    
    // MARK: - Lobby Management
    func createLobby(hostUID: String, hostName: String, gameName: String, isPublic: Bool = true, maxHiders: Int = 2, maxSeekers: Int = 2, hidingTime: Int = 30, city: GameCity = .boston, questionSetId: String? = nil, questionSetName: String? = nil, cardDeckId: String? = nil, cardDeckName: String? = nil) async throws -> String {
        let code = generateLobbyCode()

        var lobby = Lobby(
            code: code,
            hostUID: hostUID,
            gameId: nil,
            name: gameName,
            isPublic: isPublic,
            maxHiders: maxHiders,
            maxSeekers: maxSeekers,
            hidingTime: hidingTime,
            city: city,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            questionSetId: questionSetId,
            questionSetName: questionSetName,
            cardDeckId: cardDeckId,
            cardDeckName: cardDeckName
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
                
        return code
    }
    
    func joinLobby(code: String, playerUID: String, displayName: String) async throws -> Lobby {
        let lobbyRef = DatabaseReference.lobby(code)
        let snapshot = try await lobbyRef.getData()
        
        guard let lobbyData = extractLobbyData(from: snapshot, code: code),
              var lobby = try? Lobby.fromDictionary(lobbyData),
              lobby.canUserJoin(uid: playerUID) else {
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
                    players: lobby.players,
                    bannedUsers: lobby.bannedUsers,
                    questionSetId: lobby.questionSetId,
                    questionSetName: lobby.questionSetName,
                    cardDeckId: lobby.cardDeckId,
                    cardDeckName: lobby.cardDeckName
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
    
    func updateLobbySettings(code: String, maxHiders: Int, maxSeekers: Int, isPublic: Bool, hidingTime: Int, city: GameCity, questionSetId: String? = nil, questionSetName: String? = nil, cardDeckId: String? = nil, cardDeckName: String? = nil) async throws {
        let lobbyRef = DatabaseReference.lobby(code)
        var updates: [String: Any] = [
            "maxHiders": maxHiders,
            "maxSeekers": maxSeekers,
            "isPublic": isPublic,
            "hidingTime": hidingTime,
            "city": city.rawValue
        ]
        if let questionSetId {
            updates["questionSetId"] = questionSetId
        }
        if let questionSetName {
            updates["questionSetName"] = questionSetName
        }
        if let cardDeckId {
            updates["cardDeckId"] = cardDeckId
        }
        if let cardDeckName {
            updates["cardDeckName"] = cardDeckName
        }
        try await lobbyRef.updateChildValues(updates)
    }
    
    func removePlayerFromLobby(code: String, playerUID: String) async throws {
        let lobbyRef = DatabaseReference.lobby(code)
        try await lobbyRef.child("players/\(playerUID)").removeValue()
    }
    
    func banPlayerFromLobby(code: String, playerUID: String) async throws {
        let lobbyRef = DatabaseReference.lobby(code)
        let snapshot = try await lobbyRef.getData()
        
        guard let lobbyData = extractLobbyData(from: snapshot, code: code),
              var lobby = try? Lobby.fromDictionary(lobbyData) else {
            throw DatabaseError.lobbyNotFound
        }
        
        // Add to banned list if not already there
        if !lobby.bannedUsers.contains(playerUID) {
            lobby.bannedUsers.append(playerUID)
        }
        
        // Remove from players
        lobby.players.removeValue(forKey: playerUID)
        
        // Update lobby
        try await lobbyRef.setValue(try lobby.toDictionary())
    }
        
    func closeLobby(code: String) async throws {
        try await DatabaseReference.lobby(code).removeValue()
    }

    // MARK: - Event Messages

    static func sendMessage(gameId: String, message: GameMessage) async throws {
        let messageRef = DatabaseReference.game(gameId).child("messages").child(message.id)
        try await messageRef.setValue(try message.toDictionary())
    }
    
    /// Sends an event as a message in the game chat
    private func sendEventMessage(gameId: String, type: EventType, details: String) async throws {
        let message = GameMessage(
            id: UUID().uuidString,
            senderUID: "system",
            senderName: "System",
            content: details,
            type: .event,
            timestamp: Date(),
            attachments: nil,
            questionData: nil,
            team: .hiders, // Events are visible to both teams
            eventType: type
        )
        try await Self.sendMessage(gameId: gameId, message: message)
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
    
    // MARK: - Game Management
    func startGame() async throws {
        guard let lobby = currentLobby, lobby.canStart else {
            throw DatabaseError.invalidOperation
        }

        let gameId = UUID().uuidString
        let lobbyCode = lobby.code

        // Snapshot the host's chosen question set onto the game so every
        // player reads from a stable copy and mid-game source edits don't
        // bleed in. Only the host has read access to their own questionSets
        // node, and startGame runs on the host's device.
        let questionSetId = lobby.questionSetId ?? QuestionSet.defaultId
        try? await UserManager.shared.seedDefaultQuestionSetIfNeeded(uid: lobby.hostUID)
        let snapshotSet: QuestionSet
        do {
            snapshotSet = try await UserManager.shared.getQuestionSet(uid: lobby.hostUID, id: questionSetId)
        } catch {
            snapshotSet = QuestionSet.makeDefault()
        }

        let hasQuestions = snapshotSet.categories.contains { !$0.questions.isEmpty }
        guard !snapshotSet.categories.isEmpty, hasQuestions else {
            throw DatabaseError.emptyQuestionSet
        }

        // Snapshot the host's chosen card deck onto the game.
        let cardDeckId = lobby.cardDeckId ?? CardDeck.defaultId
        try? await UserManager.shared.seedDefaultCardDeckIfNeeded(uid: lobby.hostUID)
        let snapshotDeck: CardDeck
        do {
            snapshotDeck = try await UserManager.shared.getCardDeck(uid: lobby.hostUID, id: cardDeckId)
        } catch {
            snapshotDeck = CardDeck.makeDefault()
        }
        guard snapshotDeck.isValidForGame() else {
            throw DatabaseError.emptyCardDeck
        }

        var settings = GameSettings(
            hidingTime: lobby.hidingTime,
            city: lobby.city
        )
        settings.questionSetId = questionSetId
        settings.questionSet = snapshotSet
        settings.cardDeckId = cardDeckId
        settings.cardDeck = snapshotDeck

        let info = GameInfo(
            gameId: gameId,
            gameCode: lobbyCode,
            name: lobby.name,
            hostUID: lobby.hostUID,
            state: .starting,
            maxPlayers: lobby.maxPlayers,
            currentPlayers: lobby.totalPlayers,
            createdAt: Date(),
            startedAt: Date(),
            settings: settings
        )
        
        // Convert lobby players to game players
        var hiders: [String: Player] = [:]
        var seekers: [String: Player] = [:]
        
        for (uid, lobbyPlayer) in lobby.players {
            let player = Player(
                uid: lobbyPlayer.uid,
                displayName: lobbyPlayer.displayName,
                location: nil
            )
            
            if lobbyPlayer.isHider {
                hiders[uid] = player
            } else if lobbyPlayer.isSeeker {
                seekers[uid] = player
            }
        }

        let gameRef = DatabaseReference.game(gameId)
        
        // Initialize deck from the snapshotted card deck
        let initialDeck = DeckState.makeShuffled(from: snapshotDeck)
        let game = Game(info: info, teams: GameTeams(hiders: hiders, seekers: seekers), deck: initialDeck)
        
        try await gameRef.setValue(try game.toDictionary())
        
        // Add to active games
        let activeGame = ActiveGame(
            gameId: info.gameId,
            state: info.state,
            playerCount: lobby.totalPlayers,
            lastActivity: Date(),
            hostUID: info.hostUID
        )
        
        try await DatabaseReference.activeGames().child(info.gameId).setValue(try activeGame.toDictionary())
        
        let lobbyRef = DatabaseReference.lobby(lobbyCode)
        try await lobbyRef.updateChildValues([
            "gameId": gameId,
            "isActive": false
        ])
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
        
        // Clear game persistence when leaving
        clearGamePersistence()
        
        // Log leave event
        try await sendEventMessage(
            gameId: gameId,
            type: .playerLeft,
            details: "A player left the game"
        )
    }
    
    /// Attempt to rejoin the last game the user was in
    /// Returns the game data and player info if successful, nil otherwise
    func rejoinGame() async -> (game: Game, lobbyCode: String, playerTeam: Team)? {
        let userDefaults = UserDefaults.standard
        
        // Check if we have saved game data
        guard let gameId = userDefaults.string(forKey: PersistenceKeys.lastGameId),
              let lobbyCode = userDefaults.string(forKey: PersistenceKeys.lastLobbyCode),
              let teamRawValue = userDefaults.string(forKey: PersistenceKeys.lastPlayerTeam),
              let playerTeam = Team(rawValue: teamRawValue) else {
            return nil
        }
        
        let timestamp = userDefaults.double(forKey: PersistenceKeys.lastGameTimestamp)
        let lastGameDate = Date(timeIntervalSince1970: timestamp)
        
        // Only try to rejoin if the game was saved within the last 24 hours
        let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)
        guard lastGameDate > twentyFourHoursAgo else {
            clearGamePersistence()
            return nil
        }
        
        do {
            // Try to fetch the game from the database
            let gameRef = DatabaseReference.game(gameId)
            let snapshot = try await gameRef.getData()
            
            guard let gameData = snapshot.value as? [String: Any],
                  let game = try? Game.fromDictionary(gameData) else {
                // Game no longer exists
                clearGamePersistence()
                return nil
            }
            
            // Check if the game is still joinable (not completed or cancelled)
            guard game.info.state != .completed && game.info.state != .cancelled else {
                // Game is over
                clearGamePersistence()
                return nil
            }
            
            // Check if the current user is still in the game
            guard let currentUID = Auth.auth().currentUser?.uid else {
                clearGamePersistence()
                return nil
            }
            
            let isInHiders = game.teams.hiders[currentUID] != nil
            let isInSeekers = game.teams.seekers[currentUID] != nil
            
            guard isInHiders || isInSeekers else {
                // Player is no longer in the game
                clearGamePersistence()
                return nil
            }
            
            // Verify the player is in the correct team
            let actualTeam: Team = isInHiders ? .hiders : .seekers
            guard actualTeam == playerTeam else {
                // Team mismatch, update the saved team
                saveGamePersistence(gameId: gameId, lobbyCode: lobbyCode, playerTeam: actualTeam)
                return (game: game, lobbyCode: lobbyCode, playerTeam: actualTeam)
            }
            
            return (game: game, lobbyCode: lobbyCode, playerTeam: playerTeam)
            
        } catch {
            print("Error attempting to rejoin game: \(error.localizedDescription)")
            clearGamePersistence()
            return nil
        }
    }
    
    func endGame(gameId: String) async throws {
        let gameRef = DatabaseReference.game(gameId)
        let now = Date()

        let updates: [String: Any] = [
            "info/state": GameState.completed.rawValue,
            "info/endedAt": now.toFirebaseTimestamp()
        ]

        try await gameRef.updateChildValues(updates)

        // Note: Player stats are now updated automatically by Cloud Functions
        // when the game state changes to 'completed'

        // Log end event
        try await sendEventMessage(
            gameId: gameId,
            type: .gameEnded,
            details: "Game has ended"
        )

        // Remove from active games (but keep the full game data for history)
        try await DatabaseReference.activeGames().child(gameId).removeValue()

        // Clear game persistence since the game is over
        clearGamePersistence()
    }
    
    // MARK: - Game Persistence
    
    /// Save the current game information for later rejoining
    func saveGamePersistence(gameId: String, lobbyCode: String, playerTeam: Team) {
        let userDefaults = UserDefaults.standard
        userDefaults.set(gameId, forKey: PersistenceKeys.lastGameId)
        userDefaults.set(lobbyCode, forKey: PersistenceKeys.lastLobbyCode)
        userDefaults.set(playerTeam.rawValue, forKey: PersistenceKeys.lastPlayerTeam)
        userDefaults.set(Date().timeIntervalSince1970, forKey: PersistenceKeys.lastGameTimestamp)
    }
    
    /// Clear saved game persistence data
    func clearGamePersistence() {
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: PersistenceKeys.lastGameId)
        userDefaults.removeObject(forKey: PersistenceKeys.lastLobbyCode)
        userDefaults.removeObject(forKey: PersistenceKeys.lastPlayerTeam)
        userDefaults.removeObject(forKey: PersistenceKeys.lastGameTimestamp)
    }
    
    // MARK: - Game State Management
    
    func updateGameState(
        gameId: String,
        state: GameState,
        hidingStartedAt: Date? = nil,
        hidingElapsed: TimeInterval? = nil,
        seekingStartedAt: Date? = nil,
        seekingElapsed: TimeInterval? = nil
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
        
        // Clear game persistence if the game is ended
        if state == .completed || state == .cancelled {
            clearGamePersistence()
        }
        
        // Log state change events
        if state == .hiding {
            try await sendEventMessage(
                gameId: gameId,
                type: .hidingStarted,
                details: "Hiding phase has started"
            )
        } else if state == .seeking {
            try await sendEventMessage(
                gameId: gameId,
                type: .seekingStarted,
                details: "Seeking phase has started"
            )
        } else if state == .hidingPaused || state == .seekingPaused {
            try await sendEventMessage(
                gameId: gameId,
                type: .gamePaused,
                details: "Game has been paused"
            )
        } else if (state == .hiding && hidingStartedAt != nil) || (state == .seeking && seekingStartedAt != nil) {
            // Resuming from pause
            try await sendEventMessage(
                gameId: gameId,
                type: .gameResumed,
                details: "Game has been resumed"
            )
        }
    }
    
    // MARK: - Location Management
    
    func updatePlayerLocation(gameId: String, playerUID: String, team: Team, location: PlayerLocation) async throws {
        let playerLocationRef = DatabaseReference.game(gameId).child("teams/\(team.rawValue)/\(playerUID)/location")
        try await playerLocationRef.setValue(try location.toDictionary())

        // Update last activity
        try await DatabaseReference.activeGames().child(gameId).child("lastActivity").setValue(Date().toFirebaseTimestamp())
    }
    
    
    // MARK: - Question Answering
    
    /// Updates a question message with the hider's answer
    func answerQuestion(
        gameId: String,
        questionMessageId: String,
        answer: String,
        answeredBy: String
    ) async throws {
        // Get the current message
        guard let currentGame = self.currentGame,
              let questionMessage = currentGame.messages[questionMessageId],
              questionMessage.type == .question,
              var questionData = questionMessage.questionData else {
            throw DatabaseError.invalidData("answerQuestion")
        }
        
        // Update the question data
        questionData.isAnswered = true
        questionData.playerAnswer = answer
        
        // Update the message with the answer
        let updatedMessage = GameMessage(
            id: questionMessage.id,
            senderUID: questionMessage.senderUID,
            senderName: questionMessage.senderName,
            content: questionMessage.content,
            type: .question,
            timestamp: questionMessage.timestamp,
            attachments: questionMessage.attachments,
            questionData: questionData,
            team: questionMessage.team,
            eventType: nil
        )
        
        // Update in database
        let messageRef = DatabaseReference.game(gameId).child("messages").child(questionMessageId)
        try await messageRef.setValue(try updatedMessage.toDictionary())
    }
    
    /// Updates a question message with a photo answer
    func answerQuestionWithPhoto(
        gameId: String,
        questionMessageId: String,
        photoURL: String,
        answeredBy: String
    ) async throws {
        // Get the current message
        guard let currentGame = self.currentGame,
              let questionMessage = currentGame.messages[questionMessageId],
              questionMessage.type == .question,
              var questionData = questionMessage.questionData else {
            throw DatabaseError.invalidData("answerQuestionWithPhoto")
        }
        
        // Update the question data
        questionData.isAnswered = true
        questionData.playerAnswer = "Photo attached"
        
        // Create attachments for the photo
        let attachments = MessageAttachments(
            photoURL: photoURL,
            audioURL: nil,
            duration: nil,
             locationData: nil
        )
        
        // Update the message with the answer and photo
        let updatedMessage = GameMessage(
            id: questionMessage.id,
            senderUID: questionMessage.senderUID,
            senderName: questionMessage.senderName,
            content: questionMessage.content,
            type: .question,
            timestamp: questionMessage.timestamp,
            attachments: attachments,
            questionData: questionData,
            team: questionMessage.team,
            eventType: nil
        )
        
        // Update in database
        let messageRef = DatabaseReference.game(gameId).child("messages").child(questionMessageId)
        try await messageRef.setValue(try updatedMessage.toDictionary())
    }
    
    /// Marks a question as rewarded
    func markQuestionRewarded(gameId: String, questionMessageId: String) async throws {
        let messageRef = DatabaseReference.game(gameId).child("messages").child(questionMessageId).child("questionData/isRewarded")
        try await messageRef.setValue(true)
    }
    
    // MARK: - Deck Management
    
    /// Updates the deck state for a game
    func updateDeckState(gameId: String, deckState: DeckState) async throws {
        let deckRef = DatabaseReference.game(gameId).child("deck")
        try await deckRef.setValue(try deckState.toDictionary())
    }
    
    // MARK: - Real-time Listeners
    func startListeningToGame(gameId: String) {
        stopListeningToGame(gameId: gameId)
        let ref = DatabaseReference.game(gameId)
        let handle = ref.observe(.value) { [weak self] snapshot in
            guard let data = snapshot.value as? [String: Any] else {
                Task { @MainActor in
                    self?.currentGame = nil
                }
                return
            }
            
            do {
                let game = try Game.fromDictionary(data)
                Task { @MainActor in
                    self?.currentGame = game
                }
            } catch {
                print("Error parsing game data: \(error.localizedDescription)")
                // Fallback if only info exists
                if let infoDict = data["info"] as? [String: Any],
                   let info = try? GameInfo.fromDictionary(infoDict) {
                    Task { @MainActor in
                        self?.currentGame = Game(info: info, teams: GameTeams(), deck: DeckState())
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
            Task { @MainActor in
                guard let self,
                      let lobbyData = self.extractLobbyData(from: snapshot, code: code),
                      let lobby = try? Lobby.fromDictionary(lobbyData) else {
                    self?.currentLobby = nil
                    return
                }
                self.currentLobby = lobby
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
                Task { @MainActor in
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
            
            Task { @MainActor in
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
    
    private func generateLobbyCode() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
    // MARK: - Map Tools Management

    static func saveMapTools(gameId: String, playerUID: String, mapToolsData: MapToolsData) async throws {
        let mapToolsRef = DatabaseReference.game(gameId).child("mapTools").child(playerUID)
        try await mapToolsRef.setValue(try mapToolsData.toDictionary())
    }

    func loadMapTools(gameId: String, playerUID: String) async throws -> MapToolsData? {
        let mapToolsRef = DatabaseReference.game(gameId).child("mapTools").child(playerUID)
        let snapshot = try await mapToolsRef.getData()

        guard snapshot.exists() else {
            return nil
        }
        
        // Firebase sometimes returns the entire game object instead of just the child
        // Check if we got the entire game or just the player's mapTools
        var playerMapToolsDict: [String: Any]?
        
        if let snapshotDict = snapshot.value as? [String: Any] {
            // Check if this is the entire game object (has "info", "teams", etc.)
            if snapshotDict["mapTools"] != nil {
                // We got the entire game, extract this player's mapTools
                if let allMapTools = snapshotDict["mapTools"] as? [String: Any] {
                    playerMapToolsDict = allMapTools[playerUID] as? [String: Any]
                }
            } else if snapshotDict[playerUID] != nil {
                // We got the mapTools node, extract this player's data
                playerMapToolsDict = snapshotDict[playerUID] as? [String: Any]
            } else {
                // We got just the player's mapTools directly
                playerMapToolsDict = snapshotDict
            }
        }
        
        guard let dict = playerMapToolsDict else {
            return nil
        }

        return try MapToolsData.fromDictionary(dict)
    }

    func getAllTeammateMapTools(gameId: String, playerTeam: Team) async throws -> [(uid: String, info: SavedMapToolsInfo)] {
        guard let game = currentGame else {
            throw DatabaseError.gameNotFound
        }

        // Get all teammates from the same team
        let teammates: [String: Player]
        switch playerTeam {
        case .hiders:
            teammates = game.teams.hiders
        case .seekers:
            teammates = game.teams.seekers
        }

        var mapToolsInfoList: [(uid: String, info: SavedMapToolsInfo)] = []

        // Fetch map tools info for each teammate
        let mapToolsRef = DatabaseReference.game(gameId).child("mapTools")
        let snapshot = try await mapToolsRef.getData()
        
        guard snapshot.exists() else {
            return [] // No map tools saved yet
        }
        
        // Firebase sometimes returns the entire game object instead of just the child
        // Check if we got the entire game or just mapTools
        var allMapToolsDict: [String: Any]?
        
        if let snapshotDict = snapshot.value as? [String: Any] {
            // Check if this is the entire game object (has "info", "teams", etc.)
            if snapshotDict["mapTools"] != nil {
                // We got the entire game, extract mapTools
                allMapToolsDict = snapshotDict["mapTools"] as? [String: Any]
            } else {
                // We got just the mapTools node
                allMapToolsDict = snapshotDict
            }
        }
        
        guard let mapToolsDict = allMapToolsDict else {
            return [] // No map tools data found
        }
        
        for (uid, _) in teammates {
            // Check if this teammate has saved map tools
            if let playerMapTools = mapToolsDict[uid] as? [String: Any],
               let savedBy = playerMapTools["savedBy"] as? String,
               let savedByName = playerMapTools["savedByName"] as? String {
                
                // Handle savedAt as either String or TimeInterval
                let savedAtTimestamp: TimeInterval
                if let timestampString = playerMapTools["savedAt"] as? String,
                   let timestamp = Double(timestampString) {
                    savedAtTimestamp = timestamp
                } else if let timestamp = playerMapTools["savedAt"] as? TimeInterval {
                    savedAtTimestamp = timestamp
                } else {
                    continue // Skip if we can't parse the timestamp
                }

                let info = SavedMapToolsInfo(
                    savedBy: savedBy,
                    savedByName: savedByName,
                    savedAt: Date(timeIntervalSince1970: savedAtTimestamp)
                )
                mapToolsInfoList.append((uid: uid, info: info))
            }
        }

        // Sort by most recent first
        mapToolsInfoList.sort { $0.info.savedAt > $1.info.savedAt }

        return mapToolsInfoList
    }
}



// MARK: - Codable Extensions

extension Encodable {
    func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.toFirebaseTimestamp())
        }
        
        let data = try encoder.encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw DatabaseError.invalidData("Encodable.toDictionary")
        }
        return dictionary
    }
}

extension Decodable {
    static func fromDictionary(_ dictionary: [String: Any]) throws -> Self {
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let timestamp = try container.decode(Int64.self)
            return Date.fromFirebaseTimestamp(timestamp)
        }
        
        return try decoder.decode(Self.self, from: data)
    }
}
