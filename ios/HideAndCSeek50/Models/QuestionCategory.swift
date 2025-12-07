//
//  QuestionCategory.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/7/25.
//

enum QuestionCategory: String, CaseIterable, Codable {
    case matching = "matching"
    case measuring = "measuring"
    case thermometer = "thermometer"
    case radar = "radar"
    case tentacles = "tentacles"
    case photos = "photos"
    
    var displayName: String {
        switch self {
        case .matching: return "Matching"
        case .measuring: return "Measuring"
        case .thermometer: return "Thermometer"
        case .radar: return "Radar"
        case .tentacles: return "Tentacles"
        case .photos: return "Photos"
        }
    }
    
    var description: String {
        switch self {
        case .matching:
            return "Is your nearest [place] the same as mine?"
        case .measuring:
            return "Compared to me, are you closer or further from a [place]?"
        case .thermometer:
            return "I've traveled [distance], am I hotter or colder?"
        case .radar:
            return "Are you within [distance] of me?"
        case .tentacles:
            return "Of all the [places] within 1 mile, which one are you closest to?"
        case .photos:
            return "Send a photo of [object] within 10 minutes."
        }
    }
    
    var iconName: String {
        switch self {
        case .matching: return "checkmark.circle"
        case .measuring: return "ruler"
        case .thermometer: return "thermometer"
        case .radar: return "dot.radiowaves.right"
        case .tentacles: return "ant"
        case .photos: return "camera.fill"
        }
    }
    
    var questionType: QuestionType {
        switch self {
        case .matching: .yesNo
        case .measuring: .closerFurther
        case .thermometer: .hotterColder
        case .radar: .yesNo
        case .tentacles: .text
        case .photos: .photo
        }
    }
    
    func writeQuestion(arg: String) -> String {
        switch self {
        case .matching:
            return "Is your nearest \(arg) the same as mine?"
        case .measuring:
            return "Compared to me, are you closer or further from \(arg)?"
        case .thermometer:
            return "I've traveled \(arg), am I hotter or colder?"
        case .radar:
            return "Are you within \(arg) of me?"
        case .tentacles:
            return "Of all the \(arg) within 1 mile, which one are you closest to?"
        case .photos:
            return "Send a photo of \(arg) within 10 minutes."
        }
    }
    
    var categoryReward: String {
        switch self {
        case .matching:
            return "Draw 3, Keep 1"
        case .measuring:
            return "Draw 3, Keep 1"
        case .thermometer:
            return "Draw 2, Keep 1"
        case .radar:
            return "Draw 2, Keep 1"
        case .tentacles:
            return "Draw 4, Keep 2"
        case .photos:
            return "Draw 1, Keep 1"
        }
    }
}
