//
//  GameModels.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import Foundation
import Firebase
import FirebaseDatabase
import MapKit
import SwiftUI

// MARK: - Game Models
struct Game: Codable {
    let info: GameInfo
    var teams: GameTeams
    var messages: [String: GameMessage] = [:]
    var events: [String: GameEvent] = [:]
}

struct GameInfo: Codable {
    let gameId: String
    let gameCode: String
    let name: String
    let hostUID: String
    var state: GameState
    let maxPlayers: Int
    var currentPlayers: Int
    let createdAt: Date
    var startedAt: Date?
    var endedAt: Date?
    var duration: TimeInterval = 0
    var winner: Team?
    let settings: GameSettings
    
    // Simplified timer fields - just track when each phase started and elapsed time
    var hidingStartedAt: Date?
    var hidingElapsed: TimeInterval = 0
    var seekingStartedAt: Date?
    var seekingElapsed: TimeInterval = 0
}


struct GameTeams: Codable {
    var hiders: [String: Player] = [:]
    var seekers: [String: Player] = [:]
}

struct Player: Codable {
    let uid: String
    let displayName: String
    var isReady: Bool = false
    var location: PlayerLocation?
}

struct PlayerLocation: Codable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

struct GameMessage: Codable, Identifiable {
    let id: String
    let senderUID: String
    let senderName: String
    let content: String
    let type: MessageType
    let timestamp: Date
    let attachments: MessageAttachments?
    let questionData: QuestionData?
    let team: Team
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
}

struct GameSettings: Codable {
    var hidingTime: Int // minutes
    var city: GameCity
    var timeLimit: TimeInterval = 0        // Game time limit (0 = no limit) - kept for compatibility
    var boundaryRadius: Double = 1000         // Game area radius in meters - kept for compatibility
    var centerLatitude: Double = 0         // Game area center - kept for compatibility
    var centerLongitude: Double = 0
    var allowPhotos: Bool = true
    var allowVoiceChat: Bool = true
    var questionCategories: [String] = []
    var bonusPoints: Bool = false
    
    init(hidingTime: Int, city: GameCity) {
        self.hidingTime = hidingTime
        self.city = city
    }
}

struct MessageAttachments: Codable {
    let photoURL: String?
    let audioURL: String?
    let duration: TimeInterval?
}

struct QuestionData: Codable {
    let questionId: String
    let questionText: String
    let questionType: QuestionType
    var isAnswered: Bool = false
    let correctAnswer: String?
    var playerAnswer: String?
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
    
    // Add memberwise initializer
    init(type: EventType, timestamp: Date, playerUID: String?, details: String, data: [String: Any]?) {
        self.type = type
        self.timestamp = timestamp
        self.playerUID = playerUID
        self.details = details
        self.data = data
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

enum GameState: String, Codable {
    case waiting = "waiting"
    case starting = "starting"
    case preHiding = "preHiding"
    case hiding = "hiding"
    case hidingPaused = "hidingPaused"
    case preSeeking = "preSeeking"
    case seeking = "seeking"
    case seekingPaused = "seekingPaused"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .waiting: return "Waiting for Players"
        case .starting: return "Starting Soon"
        case .preHiding: return "Hiding Starting Soon"
        case .hiding: return "Hiding"
        case .hidingPaused: return "Hiding Paused"
        case .preSeeking: return "Seeking Starting Soon"
        case .seeking: return "Seeking"
        case .seekingPaused: return "Seeking Paused"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .preHiding, .hiding, .hidingPaused, .preSeeking, .seeking, .seekingPaused:
            return true
        default:
            return false
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
    
    var playerName: String {
        switch self {
        case .hiders: return "Hider"
        case .seekers: return "Seeker"
        }
    }
    
    var iconName: String {
        switch self {
        case .hiders: return "eye.slash.fill"
        case .seekers: return "magnifyingglass"
        }
    }
    
    var color: UIColor {
        switch self {
        case .hiders: return .systemBlue
        case .seekers: return .systemRed
        }
    }
    
    var swiftUIColor: Color {
        switch self {
        case .hiders: return .blue
        case .seekers: return .red
        }
    }
}

enum GameCity: String, Codable, CaseIterable {
    case boston = "boston"
    case newYork = "newYork"
    
    var displayName: String {
        switch self {
        case .boston: return "Boston"
        case .newYork: return "New York"
        }
    }
    
    var shortCode: String {
        switch self {
        case .boston: return "BOS"
        case .newYork: return "NYC"
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
    case question = "question"
    case answer = "answer"
}

enum QuestionType: String, Codable {
    case yesNo = "yesNo"               // Yes/No questions
    case closerFurther = "closerFurther" // Closer/Further questions
    case hotterColder = "hotterColder" // Hotter/Colder questions
    case photo = "photo"               // Photo questions
    case text = "text"                 // Open text questions
    
    var displayName: String {
        switch self {
        case .yesNo: return "Yes/No"
        case .closerFurther: return "Closer/Further"
        case .hotterColder: return "Hotter/Colder"
        case .photo: return "Photo"
        case .text: return "Text"
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
    case gamePaused = "gamePaused"
    case gameResumed = "gameResumed"
}

extension Game {
    var isActive: Bool {
        return info.state.isActive
    }
    
    var totalPlayers: Int {
        return teams.hiders.count + teams.seekers.count
    }
    
    var canStart: Bool {
        let minPlayers = 2
        let allReady = teams.hiders.values.allSatisfy { $0.isReady } &&
                      teams.seekers.values.allSatisfy { $0.isReady }
        return totalPlayers >= minPlayers && allReady && info.state == .waiting
    }
}

extension GameInfo {
    var elapsedTime: TimeInterval {
        guard let startTime = startedAt else { return 0 }
        let endTime = endedAt ?? Date()
        return endTime.timeIntervalSince(startTime)
    }
    
    var currentHidingTime: TimeInterval {
        guard let hidingStartTime = hidingStartedAt else { return hidingElapsed }
        switch state {
        case .hiding:
            return hidingElapsed + Date().timeIntervalSince(hidingStartTime)
        default:
            return hidingElapsed
        }
    }
    
    var currentSeekingTime: TimeInterval {
        guard let seekingStartTime = seekingStartedAt else { return seekingElapsed }
        switch state {
        case .seeking:
            return seekingElapsed + Date().timeIntervalSince(seekingStartTime)
        default:
            return seekingElapsed
        }
    }
    
    var hidingTimeRemaining: TimeInterval {
        let totalHidingTime = TimeInterval(settings.hidingTime * 60)
        return max(0, totalHidingTime - currentHidingTime)
    }
}
