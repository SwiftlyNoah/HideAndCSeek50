//
//  GameModels+Dictionary.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/28/25.
//

import Foundation
import Firebase
import FirebaseDatabase

// MARK: - Dictionary Conversion Extensions

extension Game {
    func toDictionary() throws -> [String: Any] {
        var dict: [String: Any] = [
            "info": try info.toDictionary(),
            "teams": try teams.toDictionary(),
            "deck": try deck.toDictionary()
        ]
        
        // Add messages if they exist
        if !messages.isEmpty {
            var messagesDict: [String: Any] = [:]
            for (key, message) in messages {
                messagesDict[key] = try message.toDictionary()
            }
            dict["messages"] = messagesDict
        }
        
        return dict
    }
    
    static func fromDictionary(_ dictionary: [String: Any]) throws -> Game {
        // Parse required info
        guard let infoDict = dictionary["info"] as? [String: Any] else {
            throw DatabaseError.invalidData("Game.fromDictionary: Missing 'info'")
        }
        let info = try GameInfo.fromDictionary(infoDict)
        
        // Parse teams
        let teams: GameTeams
        if let teamsDict = dictionary["teams"] as? [String: Any] {
            teams = try GameTeams.fromDictionary(teamsDict)
        } else {
            teams = GameTeams()
        }
        
        // Parse messages
        var messages: [String: GameMessage] = [:]
        if let messagesDict = dictionary["messages"] as? [String: [String: Any]] {
            for (key, messageDict) in messagesDict {
                messages[key] = try GameMessage.fromDictionary(messageDict)
            }
        }
        
        // Parse deck
        let deck: DeckState
        if let deckDict = dictionary["deck"] as? [String: Any] {
            deck = try DeckState.fromDictionary(deckDict)
        } else {
            deck = DeckState()
        }
        
        return Game(
            info: info,
            teams: teams,
            messages: messages,
            deck: deck
        )
    }
}

extension GameInfo {
    func toDictionary() throws -> [String: Any] {
        var dict: [String: Any] = [
            "gameId": gameId,
            "gameCode": gameCode,
            "name": name,
            "hostUID": hostUID,
            "state": state.rawValue,
            "maxPlayers": maxPlayers,
            "currentPlayers": currentPlayers,
            "createdAt": createdAt.toFirebaseTimestamp(),
            "duration": duration,
            "settings": try settings.toDictionary(),
            "hidingElapsed": hidingElapsed,
            "seekingElapsed": seekingElapsed
        ]
        
        dict["startedAt"] = startedAt?.toFirebaseTimestamp() ?? NSNull()
        dict["endedAt"] = endedAt?.toFirebaseTimestamp() ?? NSNull()
        
        if let hidingStartedAt = hidingStartedAt {
            dict["hidingStartedAt"] = hidingStartedAt.toFirebaseTimestamp()
        }
        if let seekingStartedAt = seekingStartedAt {
            dict["seekingStartedAt"] = seekingStartedAt.toFirebaseTimestamp()
        }
        
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
              let maxPlayers = dictionary["maxPlayers"] as? Int,
              let currentPlayers = dictionary["currentPlayers"] as? Int,
              let createdAtInt = dictionary["createdAt"] as? Int64,
              let settingsDict = dictionary["settings"] as? [String: Any] else {
            throw DatabaseError.invalidData("GameInfo.fromDictionary")
        }
        
        // Required timestamp
        let createdAt = Date.fromFirebaseTimestamp(createdAtInt)
        
        // Optional timestamps
        let startedAt: Date? = (dictionary["startedAt"] as? Int64).map(Date.fromFirebaseTimestamp)
        let endedAt: Date? = (dictionary["endedAt"] as? Int64).map(Date.fromFirebaseTimestamp)
        
        // Primitive numeric
        let duration = dictionary["duration"] as? TimeInterval ?? 0
        
        // Settings (delegate)
        let settings = try GameSettings.fromDictionary(settingsDict)
        
        // Timer fields
        let hidingElapsed = dictionary["hidingElapsed"] as? TimeInterval ?? 0
        let seekingElapsed = dictionary["seekingElapsed"] as? TimeInterval ?? 0
        let hidingStartedAt: Date? = (dictionary["hidingStartedAt"] as? Int64).map(Date.fromFirebaseTimestamp)
        let seekingStartedAt: Date? = (dictionary["seekingStartedAt"] as? Int64).map(Date.fromFirebaseTimestamp)
    
        // Base instance
        var info = GameInfo(
            gameId: gameId,
            gameCode: gameCode,
            name: name,
            hostUID: hostUID,
            state: state,
            maxPlayers: maxPlayers,
            currentPlayers: currentPlayers,
            createdAt: createdAt,
            startedAt: startedAt,
            endedAt: endedAt,
            duration: duration,
            settings: settings
        )
        
        // Override timer fields using parsed database values
        info.hidingStartedAt = hidingStartedAt
        info.hidingElapsed = hidingElapsed
        info.seekingStartedAt = seekingStartedAt
        info.seekingElapsed = seekingElapsed
        
        return info
    }
}

extension GameTeams {
    func toDictionary() throws -> [String: Any] {
        var hidersDict: [String: Any] = [:]
        for (key, player) in hiders {
            hidersDict[key] = try player.toDictionary()
        }
        
        var seekersDict: [String: Any] = [:]
        for (key, player) in seekers {
            seekersDict[key] = try player.toDictionary()
        }
        
        return [
            "hiders": hidersDict,
            "seekers": seekersDict
        ]
    }
    
    static func fromDictionary(_ dictionary: [String: Any]) throws -> GameTeams {
        var teams = GameTeams()
        
        if let hidersDict = dictionary["hiders"] as? [String: [String: Any]] {
            for (key, playerDict) in hidersDict {
                teams.hiders[key] = try Player.fromDictionary(playerDict)
            }
        }
        
        if let seekersDict = dictionary["seekers"] as? [String: [String: Any]] {
            for (key, playerDict) in seekersDict {
                teams.seekers[key] = try Player.fromDictionary(playerDict)
            }
        }
        
        return teams
    }
}

extension Player {
    func toDictionary() throws -> [String: Any] {
        var dict: [String: Any] = [
            "uid": uid,
            "displayName": displayName,
            "isOnline": isOnline
        ]
        
        if let location = location {
            dict["location"] = try location.toDictionary()
        }
        
        return dict
    }
    
    static func fromDictionary(_ dictionary: [String: Any]) throws -> Player {
        guard let uid = dictionary["uid"] as? String,
              let displayName = dictionary["displayName"] as? String else {
            throw DatabaseError.invalidData("Player.fromDictionary")
        }
        
        let isOnline = dictionary["isOnline"] as? Bool ?? false
        
        let location: PlayerLocation?
        if let locationDict = dictionary["location"] as? [String: Any] {
            location = try PlayerLocation.fromDictionary(locationDict)
        } else {
            location = nil
        }
        
        return Player(
            uid: uid,
            displayName: displayName,
            isOnline: isOnline,
            location: location
        )
    }
}

extension PlayerLocation {
    func toDictionary() throws -> [String: Any] {
        return [
            "latitude": latitude,
            "longitude": longitude,
            "timestamp": timestamp.toFirebaseTimestamp()
        ]
    }
    
    static func fromDictionary(_ dictionary: [String: Any]) throws -> PlayerLocation {
        guard let latitude = dictionary["latitude"] as? Double,
              let longitude = dictionary["longitude"] as? Double,
              let timestampInt = dictionary["timestamp"] as? Int64 else {
            throw DatabaseError.invalidData("PlayerLocation.fromDictionary")
        }
        
        let timestamp = Date.fromFirebaseTimestamp(timestampInt)
        
        return PlayerLocation(
            latitude: latitude,
            longitude: longitude,
            timestamp: timestamp
        )
    }
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
            "team": team.rawValue
        ]

        if let attachments = attachments {
            var att: [String: Any] = [:]
            if let photoURL = attachments.photoURL { att["photoURL"] = photoURL }
            if let audioURL = attachments.audioURL { att["audioURL"] = audioURL }
            if let duration = attachments.duration { att["duration"] = duration }
            if let locationData = attachments.locationData {
                att["locationData"] = try locationData.toDictionary()
            }
            dict["attachments"] = att
        }

        if let q = questionData {
            var qd: [String: Any] = [
                "questionId": q.questionId,
                "questionText": q.questionText,
                "isAnswered": q.isAnswered,
                "categoryId": q.categoryId,
                "categoryName": q.categoryName,
                "questionType": q.questionType.rawValue,
                "choices": q.choices,
                "timeLimitSeconds": q.timeLimitSeconds,
                "reward": q.reward,
                "isRewarded": q.isRewarded
            ]
            if let ans = q.playerAnswer {
                qd["playerAnswer"] = ans
            }
            dict["questionData"] = qd
        }

        if let eventType = eventType {
            dict["eventType"] = eventType.rawValue
        }

        if let cardData = cardData {
            dict["cardData"] = try cardData.toDictionary()
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
              let team = Team(rawValue: teamRaw) else {
            throw DatabaseError.invalidData("GameMessage.fromDictionary")
        }
        
        let timestamp = Date.fromFirebaseTimestamp(timestampInt)
        
        var attachments: MessageAttachments?
        if let attachmentsDict = dict["attachments"] as? [String: Any] {
            var locationData: LocationData?
            if let locationDict = attachmentsDict["locationData"] as? [String: Any] {
                locationData = try LocationData.fromDictionary(locationDict)
            }
            
            attachments = MessageAttachments(
                photoURL: attachmentsDict["photoURL"] as? String,
                audioURL: attachmentsDict["audioURL"] as? String,
                duration: attachmentsDict["duration"] as? TimeInterval,
                locationData: locationData
            )
        }
        
        var questionData: QuestionData?
        if let questionDict = dict["questionData"] as? [String: Any],
           let questionId = questionDict["questionId"] as? String,
           let questionText = questionDict["questionText"] as? String,
           let reward = questionDict["reward"] as? String {

            var categoryId: String?
            var categoryName: String?
            var questionType: QuestionType?
            var choices: [String] = []
            var timeLimitSeconds: Int = 300

            if let cid = questionDict["categoryId"] as? String,
               let typeRaw = questionDict["questionType"] as? String,
               let type = QuestionType(rawValue: typeRaw) {
                categoryId = cid
                categoryName = questionDict["categoryName"] as? String ?? cid.capitalized
                questionType = type
                choices = questionDict["choices"] as? [String] ?? []
                timeLimitSeconds = questionDict["timeLimitSeconds"] as? Int ?? 300
            } else if let legacyRaw = questionDict["questionCategory"] as? String,
                      let legacyCategory = QuestionCategory(rawValue: legacyRaw) {
                // Legacy fallback — games started before the snapshot refactor.
                categoryId = legacyRaw
                categoryName = legacyCategory.displayName
                questionType = legacyQuestionType(for: legacyCategory)
                choices = legacyChoices(for: legacyCategory)
                timeLimitSeconds = legacyCategory == .photos ? 600 : 300
            }

            if let categoryId, let categoryName, let questionType {
                questionData = QuestionData(
                    questionId: questionId,
                    questionText: questionText,
                    isAnswered: questionDict["isAnswered"] as? Bool ?? false,
                    playerAnswer: questionDict["playerAnswer"] as? String,
                    categoryId: categoryId,
                    categoryName: categoryName,
                    questionType: questionType,
                    choices: choices,
                    timeLimitSeconds: timeLimitSeconds,
                    reward: reward,
                    isRewarded: questionDict["isRewarded"] as? Bool ?? false
                )
            }
        }
        
        let eventType: EventType? = (dict["eventType"] as? String).flatMap(EventType.init(rawValue:))

        var cardData: CustomCard?
        if let cardDict = dict["cardData"] as? [String: Any] {
            cardData = try? CustomCard.fromDictionary(cardDict)
        }
        
        return GameMessage(
            id: id,
            senderUID: senderUID,
            senderName: senderName,
            content: content,
            type: type,
            timestamp: timestamp,
            attachments: attachments,
            questionData: questionData,
            team: team,
            eventType: eventType,
            cardData: cardData
        )
    }
}

extension GameSettings {
    func toDictionary() throws -> [String: Any] {
        var dict: [String: Any] = [
            "hidingTime": hidingTime,
            "city": city.rawValue,
            "timeLimit": timeLimit,
            "boundaryRadius": boundaryRadius,
            "centerLatitude": centerLatitude,
            "centerLongitude": centerLongitude,
            "allowPhotos": allowPhotos,
            "allowVoiceChat": allowVoiceChat,
            "questionCategories": questionCategories,
            "bonusPoints": bonusPoints
        ]
        if let questionSetId {
            dict["questionSetId"] = questionSetId
        }
        if let questionSet {
            dict["questionSet"] = try questionSet.toDictionary()
        }
        if let cardDeckId {
            dict["cardDeckId"] = cardDeckId
        }
        if let cardDeck {
            dict["cardDeck"] = try cardDeck.toDictionary()
        }
        return dict
    }

    static func fromDictionary(_ dictionary: [String: Any]) throws -> GameSettings {
        guard let hidingTime = dictionary["hidingTime"] as? Int,
              let cityRaw = dictionary["city"] as? String,
              let city = GameCity(rawValue: cityRaw) else {
            throw DatabaseError.invalidData("GameSettings.fromDictionary")
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

        settings.questionSetId = dictionary["questionSetId"] as? String
        if let setData = dictionary["questionSet"] as? [String: Any] {
            settings.questionSet = try? QuestionSet.fromDictionary(setData)
        }

        settings.cardDeckId = dictionary["cardDeckId"] as? String
        if let deckData = dictionary["cardDeck"] as? [String: Any] {
            settings.cardDeck = try? CardDeck.fromDictionary(deckData)
        }

        return settings
    }
}
extension LocationData {
    func toDictionary() throws -> [String: Any] {
        var dict: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude
        ]
        
        if let locationName = locationName {
            dict["locationName"] = locationName
        }
        
        return dict
    }
    
    static func fromDictionary(_ dictionary: [String: Any]) throws -> LocationData {
        guard let latitude = dictionary["latitude"] as? Double,
              let longitude = dictionary["longitude"] as? Double else {
            throw DatabaseError.invalidData("LocationData.fromDictionary")
        }
        
        let locationName = dictionary["locationName"] as? String
        
        return LocationData(
            latitude: latitude,
            longitude: longitude,
            locationName: locationName
        )
    }
}

// MARK: - Card Dictionary Extensions
extension Card {
    func toDictionary() throws -> [String: Any] {
        return [
            "instanceId": instanceId,
            "definition": try definition.toDictionary()
        ]
    }

    static func fromDictionary(_ dictionary: [String: Any]) throws -> Card {
        // Current format: {instanceId, definition}
        if let instanceId = dictionary["instanceId"] as? String,
           let defDict = dictionary["definition"] as? [String: Any],
           let definition = try? CustomCard.fromDictionary(defDict) {
            return Card(instanceId: instanceId, definition: definition)
        }

        // Legacy fallback: {suit, rank} from poker-card era
        if let suitRaw = dictionary["suit"] as? String,
           let rankRaw = dictionary["rank"] as? String {
            print("⚠️ Legacy card decoded (suit=\(suitRaw), rank=\(rankRaw)) — will appear as placeholder Powerup")
            let legacyCard = CustomCard(
                id: "legacy-\(suitRaw)-\(rankRaw)",
                type: .powerup,
                curseTitle: nil, curseDescription: nil, castingCost: nil,
                powerupTitle: "\(rankRaw) of \(suitRaw.capitalized)",
                powerupDescription: "Legacy card from a previous game.",
                timeBonusMinutes: nil
            )
            return Card(instanceId: "legacy-\(suitRaw)-\(rankRaw)", definition: legacyCard)
        }

        throw DatabaseError.invalidData("Card.fromDictionary: unrecognized format (keys=\(dictionary.keys.sorted()))")
    }
}

extension DeckState {
    func toDictionary() throws -> [String: Any] {
        return [
            "deck": try deck.map { try $0.toDictionary() },
            "hand": try hand.map { try $0.toDictionary() },
            "discardPile": try discardPile.map { try $0.toDictionary() }
        ]
    }
    
    static func fromDictionary(_ dictionary: [String: Any]) throws -> DeckState {
        let deckArray = dictionary["deck"] as? [[String: Any]] ?? []
        let handArray = dictionary["hand"] as? [[String: Any]] ?? []
        let discardPileArray = dictionary["discardPile"] as? [[String: Any]] ?? []
        
        let deck = try deckArray.map { try Card.fromDictionary($0) }
        let hand = try handArray.map { try Card.fromDictionary($0) }
        let discardPile = try discardPileArray.map { try Card.fromDictionary($0) }

        var deckState = DeckState()
        deckState.deck = deck
        deckState.hand = hand
        deckState.discardPile = discardPile

        return deckState
    }
}

// MARK: - Legacy question-category fallback helpers
// Only hit while decoding games started before the snapshot refactor landed.

private func legacyQuestionType(for category: QuestionCategory) -> QuestionType {
    switch category {
    case .matching, .measuring, .thermometer, .radar: return .multipleChoice
    case .tentacles: return .shortAnswer
    case .photos: return .photo
    }
}

private func legacyChoices(for category: QuestionCategory) -> [String] {
    switch category {
    case .matching, .radar: return ["Yes", "No"]
    case .measuring: return ["Closer", "Further"]
    case .thermometer: return ["Hotter", "Colder"]
    case .tentacles, .photos: return []
    }
}


