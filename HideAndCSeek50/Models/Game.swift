//
//  GameModels.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import Foundation
import Firebase
import FirebaseDatabase

// MARK: - Game Models

struct Game: Codable {
    let info: GameInfo
    var teams: GameTeams
    var locations: [String: PlayerLocation] = [:]
    var messages: [String: GameMessage] = [:]
    var questions: [String: GameQuestion] = [:]
    var events: [String: GameEvent] = [:]
}

struct GameInfo: Codable {
    let gameId: String
    let gameCode: String
    let name: String
    let hostUID: String
    var state: GameState
    let gameMode: GameMode
    let maxPlayers: Int
    var currentPlayers: Int
    let createdAt: Date
    var startedAt: Date?
    var endedAt: Date?
    var duration: TimeInterval = 0
    var winner: Team?
    let settings: GameSettings
}

struct GameSettings: Codable {
    let timeLimit: TimeInterval        // Game time limit (0 = no limit)
    let hidingTime: TimeInterval       // Initial hiding time
    let boundaryRadius: Double         // Game area radius in meters
    let centerLatitude: Double         // Game area center
    let centerLongitude: Double
    let allowPhotos: Bool
    let allowVoiceChat: Bool
    let questionCategories: [String]
    let bonusPoints: Bool
}

struct GameTeams: Codable {
    var hiders: TeamInfo = TeamInfo()
    var seekers: TeamInfo = TeamInfo()
}

struct TeamInfo: Codable {
    var members: [String: TeamMember] = [:]
    var teamScore: Int = 0
    var membersFound: Int = 0           // For hiders team
    var totalHidersFound: Int = 0       // For seekers team
    var averageHidingTime: TimeInterval = 0  // For hiders team
    var averageFindTime: TimeInterval = 0    // For seekers team
}

struct TeamMember: Codable {
    let uid: String
    let displayName: String
    var isReady: Bool = false
    let joinedAt: Date
    var isOnline: Bool = true
    var score: Int = 0
    var isAlive: Bool = true           // For hiders - still hiding
    var hidersFound: Int = 0           // For seekers - individual count
}

struct PlayerLocation: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let timestamp: Date
    var isVisible: Bool = false
    var locationHistory: [String: LocationPoint] = [:]
}

struct LocationPoint: Codable {
    let lat: Double
    let lng: Double
    let timestamp: Date
}

struct GameMessage: Codable {
    let id: String
    let senderUID: String
    let senderName: String
    let content: String
    let type: MessageType
    let timestamp: Date
    let team: MessageTarget
    let attachments: MessageAttachments?
    let questionData: QuestionData?
    var reactions: [String: String] = [:]  // userUID: emoji
}

struct MessageAttachments: Codable {
    let photoURL: String?
    let audioURL: String?
    let duration: TimeInterval?
}

struct QuestionData: Codable {
    let questionId: String
    let questionText: String
    var isAnswered: Bool = false
    let correctAnswer: String?
    var playerAnswer: String?
}

struct GameQuestion: Codable {
    let id: String
    let type: QuestionType
    let question: String
    let askedBy: String               // Seeker UID
    let askedAt: Date
    var answeredBy: String?           // Hider UID
    var answeredAt: Date?
    var answer: String?
    var isCorrect: Bool = false
    var pointsAwarded: Int = 0
    let attachments: QuestionAttachments?
    let mapUpdate: MapUpdate?
}

struct QuestionAttachments: Codable {
    let photoURL: String?
    let coordinates: Coordinates?
}

struct Coordinates: Codable {
    let lat: Double
    let lng: Double
}

struct MapUpdate: Codable {
    let eliminatedAreas: [MapArea]     // Areas to black out
    let revealedAreas: [MapArea]       // Areas to reveal
}

struct MapArea: Codable {
    let centerLat: Double
    let centerLng: Double
    let radius: Double
}

struct GameEvent: Codable {
    let type: EventType
    let timestamp: Date
    let playerUID: String?
    let details: String
    let data: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case type, timestamp, playerUID, details
    }
    
    // Custom encoding/decoding for data field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(EventType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        playerUID = try container.decodeIfPresent(String.self, forKey: .playerUID)
        details = try container.decode(String.self, forKey: .details)
        data = nil // Handle separately if needed
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(playerUID, forKey: .playerUID)
        try container.encode(details, forKey: .details)
    }
}


// MARK: - Enums

enum PlayerRole: String, Codable, CaseIterable {
    case hider = "hider"
    case seeker = "seeker"
    case any = "any"
    
    var displayName: String {
        switch self {
        case .hider: return "Hider"
        case .seeker: return "Seeker"
        case .any: return "Any"
        }
    }
}

enum GameState: String, Codable {
    case waiting = "waiting"
    case starting = "starting"
    case inProgress = "inProgress"
    case paused = "paused"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .waiting: return "Waiting for Players"
        case .starting: return "Starting Soon"
        case .inProgress: return "In Progress"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var isActive: Bool {
        return self == .inProgress || self == .starting
    }
}

enum GameMode: String, Codable {
    case classic = "classic"
    case timed = "timed"
    case challenge = "challenge"
    
    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .timed: return "Timed"
        case .challenge: return "Challenge"
        }
    }
    
    var description: String {
        switch self {
        case .classic: return "Traditional hide and seek with no time limit"
        case .timed: return "Fast-paced game with time constraints"
        case .challenge: return "Special challenges and bonus objectives"
        }
    }
}

enum Team: String, Codable {
    case hiders = "hiders"
    case seekers = "seekers"
    
    var displayName: String {
        switch self {
        case .hiders: return "Hiders"
        case .seekers: return "Seekers"
        }
    }
}

enum GameResult: String, Codable {
    case won = "won"
    case lost = "lost"
    case draw = "draw"
}

enum MessageType: String, Codable {
    case text = "text"
    case photo = "photo"
    case voice = "voice"
    case system = "system"
    case question = "question"
    case answer = "answer"
}

enum MessageTarget: String, Codable {
    case hiders = "hiders"
    case seekers = "seekers"
    case all = "all"
}

enum QuestionType: String, Codable {
    case location = "location"         // "Are you near X location?"
    case photo = "photo"               // "Take a photo of your surroundings"
    case distance = "distance"         // "How far are you from X?"
    case landmark = "landmark"         // "What landmark can you see?"
    case direction = "direction"       // "Which direction is X from you?"
    
    var displayName: String {
        switch self {
        case .location: return "Location"
        case .photo: return "Photo"
        case .distance: return "Distance"
        case .landmark: return "Landmark"
        case .direction: return "Direction"
        }
    }
}

enum EventType: String, Codable {
    case gameStarted = "gameStarted"
    case playerJoined = "playerJoined"
    case playerLeft = "playerLeft"
    case hiderFound = "hiderFound"
    case questionAsked = "questionAsked"
    case questionAnswered = "questionAnswered"
    case gameEnded = "gameEnded"
    case teamSwitched = "teamSwitched"
    case gamePaused = "gamePaused"
    case gameResumed = "gameResumed"
}

// MARK: - Database Extensions

extension Game {
    var isActive: Bool {
        return info.state.isActive
    }
    
    var totalPlayers: Int {
        return teams.hiders.members.count + teams.seekers.members.count
    }
    
    var hidersRemaining: Int {
        return teams.hiders.members.values.filter { $0.isAlive }.count
    }
    
    var canStart: Bool {
        let minPlayers = 2
        let allReady = teams.hiders.members.values.allSatisfy { $0.isReady } &&
                      teams.seekers.members.values.allSatisfy { $0.isReady }
        return totalPlayers >= minPlayers && allReady && info.state == .waiting
    }
}

extension GameInfo {
    var elapsedTime: TimeInterval {
        guard let startTime = startedAt else { return 0 }
        let endTime = endedAt ?? Date()
        return endTime.timeIntervalSince(startTime)
    }
    
    var remainingTime: TimeInterval? {
        guard settings.timeLimit > 0, let startTime = startedAt else { return nil }
        let elapsed = Date().timeIntervalSince(startTime)
        return max(0, settings.timeLimit - elapsed)
    }
    
    var isTimeUp: Bool {
        guard let remaining = remainingTime else { return false }
        return remaining <= 0
    }
}

// MARK: - Firebase Database Reference Extensions

extension DatabaseReference {
    
    // User references
    static func users() -> DatabaseReference {
        return Database.database().reference().child("users")
    }
    
    static func user(_ uid: String) -> DatabaseReference {
        return users().child(uid)
    }
    
    // Game references
    static func games() -> DatabaseReference {
        return Database.database().reference().child("games")
    }
    
    static func game(_ gameId: String) -> DatabaseReference {
        return games().child(gameId)
    }
    
    // Lobby references
    static func lobbies() -> DatabaseReference {
        return Database.database().reference().child("lobbies")
    }
    
    static func lobby(_ code: String) -> DatabaseReference {
        return lobbies().child(code)
    }
    
    // Active games references
    static func activeGames() -> DatabaseReference {
        return Database.database().reference().child("activeGames")
    }
}

// MARK: - Date Formatting

extension Date {
    func toFirebaseTimestamp() -> Int64 {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
    
    static func fromFirebaseTimestamp(_ timestamp: Int64) -> Date {
        return Date(timeIntervalSince1970: Double(timestamp) / 1000)
    }
}
