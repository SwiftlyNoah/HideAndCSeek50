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
            "teams": try teams.toDictionary()
        ]
        
        // Add messages if they exist
        if !messages.isEmpty {
            var messagesDict: [String: Any] = [:]
            for (key, message) in messages {
                messagesDict[key] = try message.toDictionary()
            }
            dict["messages"] = messagesDict
        }
        
        // Add questions if they exist
        if !questions.isEmpty {
            var questionsDict: [String: Any] = [:]
            for (key, question) in questions {
                questionsDict[key] = try question.toDictionary()
            }
            dict["questions"] = questionsDict
        }
        
        // Add events if they exist
        if !events.isEmpty {
            var eventsDict: [String: Any] = [:]
            for (key, event) in events {
                eventsDict[key] = try event.toDictionary()
            }
            dict["events"] = eventsDict
        }
        
        return dict
    }
    
    static func fromDictionary(_ dictionary: [String: Any]) throws -> Game {
        // Parse required info
        guard let infoDict = dictionary["info"] as? [String: Any] else {
            throw DatabaseError.invalidData
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
        
        // Parse questions
        var questions: [String: GameQuestion] = [:]
        if let questionsDict = dictionary["questions"] as? [String: [String: Any]] {
            for (key, questionDict) in questionsDict {
                questions[key] = try GameQuestion.fromDictionary(questionDict)
            }
        }
        
        // Parse events
        var events: [String: GameEvent] = [:]
        if let eventsDict = dictionary["events"] as? [String: [String: Any]] {
            for (key, eventDict) in eventsDict {
                events[key] = try GameEvent.fromDictionary(eventDict)
            }
        }
        
        return Game(
            info: info,
            teams: teams,
            messages: messages,
            questions: questions,
            events: events
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
            "hidingElapsed": hidingElapsed,
            "seekingElapsed": seekingElapsed
        ]
        
        dict["startedAt"] = startedAt?.toFirebaseTimestamp() ?? NSNull()
        dict["endedAt"] = endedAt?.toFirebaseTimestamp() ?? NSNull()
        dict["winner"] = winner?.rawValue ?? NSNull()
        
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
            throw DatabaseError.invalidData
        }
        
        // Required timestamp
        let createdAt = Date.fromFirebaseTimestamp(createdAtInt)
        
        // Optional timestamps
        let startedAt: Date? = (dictionary["startedAt"] as? Int64).map(Date.fromFirebaseTimestamp)
        let endedAt: Date? = (dictionary["endedAt"] as? Int64).map(Date.fromFirebaseTimestamp)
        
        // Primitive numeric
        let duration = dictionary["duration"] as? TimeInterval ?? 0
        
        // Optional winner
        let winner: Team? = (dictionary["winner"] as? String).flatMap(Team.init(rawValue:))
        
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
            winner: winner,
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
            "isReady": isReady
        ]
        
        if let location = location {
            dict["location"] = try location.toDictionary()
        }
        
        return dict
    }
    
    static func fromDictionary(_ dictionary: [String: Any]) throws -> Player {
        guard let uid = dictionary["uid"] as? String,
              let displayName = dictionary["displayName"] as? String else {
            throw DatabaseError.invalidData
        }
        
        let isReady = dictionary["isReady"] as? Bool ?? false
        
        let location: PlayerLocation?
        if let locationDict = dictionary["location"] as? [String: Any] {
            location = try PlayerLocation.fromDictionary(locationDict)
        } else {
            location = nil
        }
        
        return Player(
            uid: uid,
            displayName: displayName,
            isReady: isReady,
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
            throw DatabaseError.invalidData
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
              let team = Team(rawValue: teamRaw) else {
            throw DatabaseError.invalidData
        }
        
        let timestamp = Date.fromFirebaseTimestamp(timestampInt)
        
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
            attachments: attachments,
            questionData: questionData,
            team: team
        )
    }
}

extension GameQuestion {
    func toDictionary() throws -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "type": type.rawValue,
            "question": question,
            "askedBy": askedBy,
            "askedAt": askedAt.toFirebaseTimestamp()
        ]
        
        if let answeredBy = answeredBy {
            dict["answeredBy"] = answeredBy
        }
        
        if let answeredAt = answeredAt {
            dict["answeredAt"] = answeredAt.toFirebaseTimestamp()
        }
        
        if let answer = answer {
            dict["answer"] = answer
        }
        
        return dict
    }
    
    static func fromDictionary(_ dictionary: [String: Any]) throws -> GameQuestion {
        guard let id = dictionary["id"] as? String,
              let typeRaw = dictionary["type"] as? String,
              let type = QuestionType(rawValue: typeRaw),
              let question = dictionary["question"] as? String,
              let askedBy = dictionary["askedBy"] as? String,
              let askedAtInt = dictionary["askedAt"] as? Int64 else {
            throw DatabaseError.invalidData
        }
        
        let askedAt = Date.fromFirebaseTimestamp(askedAtInt)
        let answeredBy = dictionary["answeredBy"] as? String
        let answeredAt: Date? = (dictionary["answeredAt"] as? Int64).map(Date.fromFirebaseTimestamp)
        let answer = dictionary["answer"] as? String
        
        return GameQuestion(
            id: id,
            type: type,
            question: question,
            askedBy: askedBy,
            askedAt: askedAt,
            answeredBy: answeredBy,
            answeredAt: answeredAt,
            answer: answer
        )
    }
}

extension GameEvent {
    func toDictionary() throws -> [String: Any] {
        return [
            "type": type.rawValue,
            "timestamp": timestamp.toFirebaseTimestamp(),
            "playerUID": playerUID as Any,
            "details": details
        ]
    }
    
    static func fromDictionary(_ dictionary: [String: Any]) throws -> GameEvent {
        guard let typeRaw = dictionary["type"] as? String,
              let type = EventType(rawValue: typeRaw),
              let timestampInt = dictionary["timestamp"] as? Int64,
              let details = dictionary["details"] as? String else {
            throw DatabaseError.invalidData
        }
        
        let timestamp = Date.fromFirebaseTimestamp(timestampInt)
        let playerUID = dictionary["playerUID"] as? String
        
        return GameEvent(
            type: type,
            timestamp: timestamp,
            playerUID: playerUID,
            details: details,
            data: nil
        )
    }
}

extension GameSettings {
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