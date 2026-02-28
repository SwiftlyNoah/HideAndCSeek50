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
    var deck: DeckState
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
    let settings: GameSettings
    
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
    var isOnline: Bool = true
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
    var eventType: EventType? = nil
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
    let locationData: LocationData?
}

struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
    let locationName: String?
}

struct QuestionData: Codable, Equatable {
    let questionId: String
    let questionText: String
    var isAnswered: Bool = false
    var playerAnswer: String?
    var questionCategory: QuestionCategory
    var reward: String
    var isRewarded: Bool = false
    
    static func parseDrawAction(from rewardText: String) -> DrawAction {
        // Parse "Draw X, Keep Y" format
        let components = rewardText.components(separatedBy: ", ")
        
        var drawCount = 1
        var keepCount = 1
        
        if components.count >= 2 {
            // Extract numbers from "Draw X" and "Keep Y"
            if let drawString = components.first?.components(separatedBy: " ").last,
               let draw = Int(drawString) {
                drawCount = draw
            }
            
            if let keepString = components.last?.components(separatedBy: " ").last,
               let keep = Int(keepString) {
                keepCount = keep
            }
        }
        
        return DrawAction(drawCount: drawCount, keepCount: keepCount)
    }
}

struct MapArea: Codable {
    let centerLat: Double
    let centerLng: Double
    let radius: Double
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
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .boston: return "Boston"
        case .newYork: return "New York"
        case .custom: return "Custom"
        }
    }
    
    var shortCode: String {
        switch self {
        case .boston: return "BOS"
        case .newYork: return "NYC"
        case .custom: return "CUS"
        }
    }
    
    var region: MKCoordinateRegion {
        switch self {
        case .boston:
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589),
                latitudinalMeters: 10000,
                longitudinalMeters: 10000
            )
        case .newYork:
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                latitudinalMeters: 15000,
                longitudinalMeters: 15000
            )
        case .custom:
            // Default region for custom - can be overridden
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589),
                latitudinalMeters: 10000,
                longitudinalMeters: 10000
            )
        }
    }
    
    var hidableAreas: [MKPolygon] {
        switch self {
        case .boston:
            return MassachusettsRegions.hidableAreas
        case .newYork:
            return NewYorkRegions.hidableAreas
        case .custom:
            // No predefined hideable areas for custom cities
            return []
        }
    }
    
    var regionsByName: [String: MKPolygon] {
        switch self {
        case .boston:
            return MassachusettsRegions.regionsByName
        case .newYork:
            return NewYorkRegions.regionsByName
        case .custom:
            return [:]
        }
    }
    
    var allRegionNames: [String] {
        switch self {
        case .boston:
            return MassachusettsRegions.allRegionNames
        case .newYork:
            return NewYorkRegions.allRegionNames
        case .custom:
            return []
        }
    }
    
    var trainLines: [MKPolyline] {
        switch self {
        case .boston:
            return MassachusettsRegions.mbtaLineOverlays
        case .newYork:
            return NewYorkRegions.subwayLineOverlays
        case .custom:
            return []
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
    case event = "event"
    case location = "location"
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
    case hidingStarted = "hidingStarted"
    case seekingStarted = "seekingStarted"
    
    var displayName: String {
        switch self {
        case .gameStarted: return "Game Started"
        case .playerJoined: return "Player Joined"
        case .playerLeft: return "Player Left"
        case .hiderFound: return "Hider Found"
        case .questionAsked: return "Question Asked"
        case .questionAnswered: return "Question Answered"
        case .gameEnded: return "Game Ended"
        case .gamePaused: return "Game Paused"
        case .gameResumed: return "Game Resumed"
        case .hidingStarted: return "Hiding Started"
        case .seekingStarted: return "Seeking Started"
        }
    }
}

extension Game {
    var isActive: Bool {
        return info.state.isActive
    }
    
    var totalPlayers: Int {
        return teams.hiders.count + teams.seekers.count
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
