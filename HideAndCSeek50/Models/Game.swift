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
    
    // Add hiding timer fields
    var hidingTimerState: TimerState = .notStarted
    var hidingTimerStartedAt: Date?
    var hidingTimerPausedAt: Date?
    var hidingTimerElapsed: TimeInterval = 0
    
    // Add seeking timer fields
    var seekingTimerState: TimerState = .notStarted
    var seekingTimerStartedAt: Date?
    var seekingTimerPausedAt: Date?
    var seekingTimerElapsed: TimeInterval = 0
}

enum TimerState: String, Codable {
    case notStarted
    case running
    case paused
    case completed
    case skipped
}

extension GameInfo {
    func toDictionary() throws -> [String: Any] {
        var dict: [String: Any] = [
            "gameId": gameId,
            "gameCode": gameCode,
            "name": name,
            "hostUID": hostUID,
            "state": state.rawValue,
            "gameMode": gameMode.rawValue,
            "maxPlayers": maxPlayers,
            "currentPlayers": currentPlayers,
            "createdAt": createdAt.toFirebaseTimestamp(),
            "duration": duration,
            "settings": [
                "hidingTime": settings.hidingTime,
                "city": settings.city.rawValue,
                "timeLimit": settings.timeLimit,
                "boundaryRadius": settings.boundaryRadius,
                "centerLatitude": settings.centerLatitude,
                "centerLongitude": settings.centerLongitude,
                "allowPhotos": settings.allowPhotos,
                "allowVoiceChat": settings.allowVoiceChat,
                "questionCategories": settings.questionCategories,
                "bonusPoints": settings.bonusPoints
            ],
            "hidingTimerState": hidingTimerState.rawValue,
            "hidingTimerElapsed": hidingTimerElapsed,
            "seekingTimerState": seekingTimerState.rawValue,
            "seekingTimerElapsed": seekingTimerElapsed
        ]
        dict["startedAt"] = startedAt?.toFirebaseTimestamp() ?? NSNull()
        dict["endedAt"] = endedAt?.toFirebaseTimestamp() ?? NSNull()
        dict["winner"] = winner?.rawValue ?? NSNull()
        if let hidingTimerStartedAt = hidingTimerStartedAt { dict["hidingTimerStartedAt"] = hidingTimerStartedAt.toFirebaseTimestamp() }
        if let hidingTimerPausedAt = hidingTimerPausedAt { dict["hidingTimerPausedAt"] = hidingTimerPausedAt.toFirebaseTimestamp() }
        if let seekingTimerStartedAt = seekingTimerStartedAt { dict["seekingTimerStartedAt"] = seekingTimerStartedAt.toFirebaseTimestamp() }
        if let seekingTimerPausedAt = seekingTimerPausedAt { dict["seekingTimerPausedAt"] = seekingTimerPausedAt.toFirebaseTimestamp() }
        
        return dict
    }
    static func fromDictionary(_ dictionary: [String: Any]) throws -> GameInfo {
        // Validate required primitive & enum fields
        guard let gameId = dictionary["gameId"] as? String,
              let gameCode = dictionary["gameCode"] as? String,
              let name = dictionary["name"] as? String,
              let hostUID = dictionary["hostUID"] as? String,
              let stateRaw = dictionary["state"] as? String,
              let state = GameState(rawValue: stateRaw),
              let gameModeRaw = dictionary["gameMode"] as? String,
              let gameMode = GameMode(rawValue: gameModeRaw),
              let maxPlayers = dictionary["maxPlayers"] as? Int,
              let currentPlayers = dictionary["currentPlayers"] as? Int,
              let createdAtInt = dictionary["createdAt"] as? Int64,
              let settingsDict = dictionary["settings"] as? [String: Any] else {
            throw DatabaseError.invalidData
        }
        
        // Required timestamp
        let createdAt = Date.fromFirebaseTimestamp(createdAtInt)
        
        // Optional timestamps
        let startedAt: Date? = (dictionary["startedAt"] as? Int64).map(Date.fromFirebaseTimestamp)
        let endedAt: Date?   = (dictionary["endedAt"] as? Int64).map(Date.fromFirebaseTimestamp)
        
        // Primitive numeric
        let duration = dictionary["duration"] as? TimeInterval ?? 0
        
        // Optional winner
        let winner: Team? = (dictionary["winner"] as? String).flatMap(Team.init(rawValue:))
        
        // Settings (delegate)
        let settings = try GameSettings.fromDictionary(settingsDict)
        
        // Timer fields
        let hidingTimerState = TimerState(rawValue: dictionary["hidingTimerState"] as? String ?? "") ?? .notStarted
        let hidingTimerElapsed = dictionary["hidingTimerElapsed"] as? TimeInterval ?? 0
        let hidingTimerStartedAt: Date? = (dictionary["hidingTimerStartedAt"] as? Int64).map(Date.fromFirebaseTimestamp)
        let hidingTimerPausedAt: Date?  = (dictionary["hidingTimerPausedAt"] as? Int64).map(Date.fromFirebaseTimestamp)
        
        // Seeking timer (new)
        let seekingTimerState = TimerState(rawValue: dictionary["seekingTimerState"] as? String ?? "") ?? .notStarted
        let seekingTimerElapsed = dictionary["seekingTimerElapsed"] as? TimeInterval ?? 0
        let seekingTimerStartedAt: Date? = (dictionary["seekingTimerStartedAt"] as? Int64).map(Date.fromFirebaseTimestamp)
        let seekingTimerPausedAt: Date?  = (dictionary["seekingTimerPausedAt"] as? Int64).map(Date.fromFirebaseTimestamp)
    
        // Base instance
        var info = GameInfo(
            gameId: gameId,
            gameCode: gameCode,
            name: name,
            hostUID: hostUID,
            state: state,
            gameMode: gameMode,
            maxPlayers: maxPlayers,
            currentPlayers: currentPlayers,
            createdAt: createdAt,
            startedAt: startedAt,
            endedAt: endedAt,
            duration: duration,
            winner: winner,
            settings: settings
        )
        
        // Override timer fields using parsed database values
        info.hidingTimerState = hidingTimerState
        info.hidingTimerStartedAt = hidingTimerStartedAt
        info.hidingTimerPausedAt = hidingTimerPausedAt
        info.hidingTimerElapsed = hidingTimerElapsed
        
        info.seekingTimerState = seekingTimerState
        info.seekingTimerElapsed = seekingTimerElapsed
        info.seekingTimerStartedAt = seekingTimerStartedAt
        info.seekingTimerPausedAt = seekingTimerPausedAt
        
        return info
    }
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
    
    static func fromDictionary(_ dictionary: [String: Any]) throws -> GameSettings {
        guard let hidingTime = dictionary["hidingTime"] as? Int,
              let cityRaw = dictionary["city"] as? String,
              let city = GameCity(rawValue: cityRaw) else {
            throw DatabaseError.invalidData
        }
        
        var settings = GameSettings(hidingTime: hidingTime, city: city)
        
        settings.timeLimit = dictionary["timeLimit"] as? TimeInterval ?? 0
        settings.boundaryRadius = dictionary["boundaryRadius"] as? Double ?? 1000
        settings.centerLatitude = dictionary["centerLatitude"] as? Double ?? 0
        settings.centerLongitude = dictionary["centerLongitude"] as? Double ?? 0
        settings.allowPhotos = dictionary["allowPhotos"] as? Bool ?? true
        settings.allowVoiceChat = dictionary["allowVoiceChat"] as? Bool ?? true
        settings.questionCategories = dictionary["questionCategories"] as? [String] ?? []
        settings.bonusPoints = dictionary["bonusPoints"] as? Bool ?? false
        
        return settings
    }
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

extension PlayerLocation {
    func toDictionary() throws -> [String: Any] {
        return [
            "latitude": latitude,
            "longitude": longitude,
            "accuracy": accuracy,
            "timestamp": timestamp.toFirebaseTimestamp(),
            "isVisible": isVisible,
            "locationHistory": locationHistory.mapValues { point in
                [
                    "lat": point.lat,
                    "lng": point.lng,
                    "timestamp": point.timestamp.toFirebaseTimestamp()
                ]
            }
        ]
    }
}

struct LocationPoint: Codable {
    let lat: Double
    let lng: Double
    let timestamp: Date
}

struct GameMessage: Codable, Identifiable {
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

extension GameMessage {
    func toDictionary() throws -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "senderUID": senderUID,
            "senderName": senderName,
            "content": content,
            "type": type.rawValue,
            "timestamp": timestamp.toFirebaseTimestamp(),
            "team": team.rawValue,
            "reactions": reactions
        ]
        
        if let attachments = attachments {
            dict["attachments"] = [
                "photoURL": attachments.photoURL as Any,
                "audioURL": attachments.audioURL as Any,
                "duration": attachments.duration as Any
            ]
        }
        
        if let questionData = questionData {
            dict["questionData"] = [
                "questionId": questionData.questionId,
                "questionText": questionData.questionText,
                "isAnswered": questionData.isAnswered,
                "correctAnswer": questionData.correctAnswer as Any,
                "playerAnswer": questionData.playerAnswer as Any
            ]
        }
        
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any]) throws -> GameMessage {
        guard let id = dict["id"] as? String,
              let senderUID = dict["senderUID"] as? String,
              let senderName = dict["senderName"] as? String,
              let content = dict["content"] as? String,
              let typeRaw = dict["type"] as? String,
              let type = MessageType(rawValue: typeRaw),
              let timestampInt = dict["timestamp"] as? Int64,
              let teamRaw = dict["team"] as? String,
              let team = MessageTarget(rawValue: teamRaw) else {
            throw DatabaseError.invalidData
        }
        
        let timestamp = Date.fromFirebaseTimestamp(timestampInt)
        let reactions = dict["reactions"] as? [String: String] ?? [:]
        
        var attachments: MessageAttachments?
        if let attachmentsDict = dict["attachments"] as? [String: Any] {
            attachments = MessageAttachments(
                photoURL: attachmentsDict["photoURL"] as? String,
                audioURL: attachmentsDict["audioURL"] as? String,
                duration: attachmentsDict["duration"] as? TimeInterval
            )
        }
        
        var questionData: QuestionData?
        if let questionDict = dict["questionData"] as? [String: Any],
           let questionId = questionDict["questionId"] as? String,
           let questionText = questionDict["questionText"] as? String {
            questionData = QuestionData(
                questionId: questionId,
                questionText: questionText,
                isAnswered: questionDict["isAnswered"] as? Bool ?? false,
                correctAnswer: questionDict["correctAnswer"] as? String,
                playerAnswer: questionDict["playerAnswer"] as? String
            )
        }
        
        return GameMessage(
            id: id,
            senderUID: senderUID,
            senderName: senderName,
            content: content,
            type: type,
            timestamp: timestamp,
            team: team,
            attachments: attachments,
            questionData: questionData,
            reactions: reactions
        )
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
