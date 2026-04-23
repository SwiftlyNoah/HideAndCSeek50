//
//  QuestionSet.swift
//  HideAndCSeek50
//
//  Custom question sets for in-game questions. Each user owns a collection
//  of QuestionSet under their account; the host's chosen set is snapshotted
//  onto the game at start so all players read from a stable copy.
//

import Foundation

struct QuestionSet: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date
    var categories: [QuestionCategoryDef]

    static let defaultId = "default"
    static let defaultName = "Default"
    /// Bump this whenever the default set content or storage format changes.
    /// Mirrors the pattern used by CardDeck so the seed logic can detect stale data.
    static let defaultVersion = 2

    var questionCount: Int {
        categories.reduce(0) { $0 + $1.questions.count }
    }
}

struct QuestionCategoryDef: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var iconName: String
    var drawCount: Int
    var keepCount: Int
    var timeLimitSeconds: Int
    var questions: [CustomQuestion]

    var rewardPreview: String {
        "Draw \(drawCount), Keep \(keepCount)"
    }
}

struct CustomQuestion: Codable, Identifiable, Equatable {
    let id: String
    var text: String
    var questionType: QuestionType
    var choices: [String]
}

enum QuestionType: String, Codable, CaseIterable {
    case multipleChoice
    case shortAnswer
    case photo

    var displayName: String {
        switch self {
        case .multipleChoice: return "Multiple Choice"
        case .shortAnswer: return "Short Answer"
        case .photo: return "Photo"
        }
    }

    var iconName: String {
        switch self {
        case .multipleChoice: return "checklist"
        case .shortAnswer: return "text.bubble"
        case .photo: return "camera.fill"
        }
    }
}

// MARK: - Default Set Builder

extension QuestionSet {
    /// Builds the seeded "Default" question set. Mirrors today's six categories so
    /// gameplay is unchanged for users who never open the editor.
    static func makeDefault(now: Date = Date()) -> QuestionSet {
        QuestionSet(
            id: defaultId,
            name: defaultName,
            isDefault: true,
            createdAt: now,
            updatedAt: now,
            categories: DefaultSetSeed.categories()
        )
    }
}

private enum DefaultSetSeed {
    static func categories() -> [QuestionCategoryDef] {
        [
            QuestionCategoryDef(
                id: "matching",
                name: "Matching",
                iconName: "questionmark.circle.fill",
                drawCount: 3,
                keepCount: 1,
                timeLimitSeconds: 300,
                questions: matchingPrompts.map {
                    CustomQuestion(
                        id: UUID().uuidString,
                        text: "Is your nearest \($0) the same as mine?",
                        questionType: .multipleChoice,
                        choices: ["Yes", "No"]
                    )
                }
            ),
            QuestionCategoryDef(
                id: "measuring",
                name: "Measuring",
                iconName: "ruler.fill",
                drawCount: 3,
                keepCount: 1,
                timeLimitSeconds: 300,
                questions: measuringPrompts.map {
                    CustomQuestion(
                        id: UUID().uuidString,
                        text: "Compared to me, are you closer or further from \($0)?",
                        questionType: .multipleChoice,
                        choices: ["Closer", "Further"]
                    )
                }
            ),
            QuestionCategoryDef(
                id: "thermometer",
                name: "Thermometer",
                iconName: "thermometer.medium",
                drawCount: 2,
                keepCount: 1,
                timeLimitSeconds: 300,
                questions: thermometerPrompts.map {
                    CustomQuestion(
                        id: UUID().uuidString,
                        text: "I've traveled \($0), am I hotter or colder?",
                        questionType: .multipleChoice,
                        choices: ["Hotter", "Colder"]
                    )
                }
            ),
            QuestionCategoryDef(
                id: "radar",
                name: "Radar",
                iconName: "dot.radiowaves.left.and.right",
                drawCount: 2,
                keepCount: 1,
                timeLimitSeconds: 300,
                questions: radarPrompts.map {
                    CustomQuestion(
                        id: UUID().uuidString,
                        text: "Are you within \($0) of me?",
                        questionType: .multipleChoice,
                        choices: ["Yes", "No"]
                    )
                }
            ),
            QuestionCategoryDef(
                id: "tentacles",
                name: "Tentacles",
                iconName: "figure.walk",
                drawCount: 4,
                keepCount: 2,
                timeLimitSeconds: 300,
                questions: tentaclesPrompts.map {
                    CustomQuestion(
                        id: UUID().uuidString,
                        text: "Of all the \($0) within 1 mile, which one are you closest to?",
                        questionType: .shortAnswer,
                        choices: []
                    )
                }
            ),
            QuestionCategoryDef(
                id: "photos",
                name: "Photos",
                iconName: "camera.fill",
                drawCount: 1,
                keepCount: 1,
                timeLimitSeconds: 600,
                questions: photosPrompts.map {
                    CustomQuestion(
                        id: UUID().uuidString,
                        text: "Send a photo of \($0) within 10 minutes.",
                        questionType: .photo,
                        choices: []
                    )
                }
            )
        ]
    }

    static let matchingPrompts: [String] = [
        "Commercial Airport",
        "Transit Line",
        "Station's Name Length",
        "Street or Path",
        "1st Level Administrative Division",
        "2nd Level Administrative Division",
        "3rd Level Administrative Division",
        "Mountain",
        "Landmass",
        "Park",
        "Amusement Park",
        "Zoo",
        "Aquarium",
        "Golf Course",
        "Museum",
        "Movie Theater",
        "Hospital",
        "Library",
        "Foreign Consulate"
    ]

    static let measuringPrompts: [String] = [
        "A Commercial Airport",
        "A High Speed Train Line",
        "A Transit Station",
        "A 1st Level Administrative Division Border",
        "A 2nd Level Administrative Division Border",
        "Sea Level",
        "A Body of Water",
        "A Coastline",
        "A Mountain",
        "A Park",
        "An Amusement Park",
        "A Zoo",
        "An Aquarium",
        "A Golf Course",
        "A Museum",
        "A Movie Theater",
        "A Hospital",
        "A Library",
        "A Foreign Consulate"
    ]

    static let thermometerPrompts: [String] = [
        "0.25 miles",
        "0.5 miles",
        "1 mile?",
        "3 miles",
        "5 miles",
        "10 miles",
        "25 miles",
        "50 miles",
        "100 miles",
        "Custom Distance"
    ]

    static let radarPrompts: [String] = [
        "0.25 miles",
        "0.5 miles",
        "1 mile?",
        "3 miles",
        "5 miles",
        "10 miles",
        "25 miles",
        "50 miles",
        "100 miles"
    ]

    static let tentaclesPrompts: [String] = [
        "Museums",
        "Libraries",
        "Movie Theaters",
        "Hospitals",
        "Parks",
        "Bodies of Water"
    ]

    static let photosPrompts: [String] = [
        "A Tree",
        "The Sky",
        "You",
        "Widest Street",
        "Tallest Structure in Your Sightline",
        "Any Building Visible from Station",
        "Tallest Building Visible from Station",
        "Trace Nearest Street/Path",
        "Two Buildings",
        "Restaurant Interior",
        "Train Platform",
        "Park",
        "Grocery Store Aisle",
        "Place of Worship"
    ]
}
