//
//  QuestionSet+Dictionary.swift
//  HideAndCSeek50
//
//  RTDB conversion for QuestionSet / QuestionCategoryDef / CustomQuestion.
//  Categories and questions are stored as keyed dictionaries with an
//  `orderIndex` field so user-defined ordering survives a round trip
//  (RTDB does not preserve dictionary key order).
//

import Foundation

extension QuestionSet {
    func toDictionary() throws -> [String: Any] {
        var categoriesDict: [String: [String: Any]] = [:]
        for (index, category) in categories.enumerated() {
            categoriesDict[category.id] = try category.toDictionary(orderIndex: index)
        }

        return [
            "id": id,
            "name": name,
            "isDefault": isDefault,
            "createdAt": createdAt.toFirebaseTimestamp(),
            "updatedAt": updatedAt.toFirebaseTimestamp(),
            "categories": categoriesDict
        ]
    }

    static func fromDictionary(_ dict: [String: Any]) throws -> QuestionSet {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String,
              let createdAtTimestamp = dict["createdAt"] as? Int64,
              let updatedAtTimestamp = dict["updatedAt"] as? Int64 else {
            throw DatabaseError.invalidData("QuestionSet.fromDictionary")
        }

        let isDefault = dict["isDefault"] as? Bool ?? false

        var categories: [QuestionCategoryDef] = []
        if let categoriesDict = dict["categories"] as? [String: [String: Any]] {
            var indexed: [(Int, QuestionCategoryDef)] = []
            for (_, categoryData) in categoriesDict {
                if let pair = try? QuestionCategoryDef.fromDictionaryWithOrder(categoryData) {
                    indexed.append(pair)
                }
            }
            categories = indexed.sorted { $0.0 < $1.0 }.map { $0.1 }
        }

        return QuestionSet(
            id: id,
            name: name,
            isDefault: isDefault,
            createdAt: Date.fromFirebaseTimestamp(createdAtTimestamp),
            updatedAt: Date.fromFirebaseTimestamp(updatedAtTimestamp),
            categories: categories
        )
    }
}

extension QuestionCategoryDef {
    func toDictionary(orderIndex: Int) throws -> [String: Any] {
        var questionsDict: [String: [String: Any]] = [:]
        for (index, question) in questions.enumerated() {
            questionsDict[question.id] = try question.toDictionary(orderIndex: index)
        }

        return [
            "id": id,
            "name": name,
            "iconName": iconName,
            "drawCount": drawCount,
            "keepCount": keepCount,
            "timeLimitSeconds": timeLimitSeconds,
            "orderIndex": orderIndex,
            "questions": questionsDict
        ]
    }

    static func fromDictionaryWithOrder(_ dict: [String: Any]) throws -> (Int, QuestionCategoryDef) {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String,
              let iconName = dict["iconName"] as? String,
              let drawCount = dict["drawCount"] as? Int,
              let keepCount = dict["keepCount"] as? Int else {
            throw DatabaseError.invalidData("QuestionCategoryDef.fromDictionary")
        }

        let timeLimitSeconds = dict["timeLimitSeconds"] as? Int ?? 300
        let orderIndex = dict["orderIndex"] as? Int ?? 0

        var questions: [CustomQuestion] = []
        if let questionsDict = dict["questions"] as? [String: [String: Any]] {
            var indexed: [(Int, CustomQuestion)] = []
            for (_, questionData) in questionsDict {
                if let pair = try? CustomQuestion.fromDictionaryWithOrder(questionData) {
                    indexed.append(pair)
                }
            }
            questions = indexed.sorted { $0.0 < $1.0 }.map { $0.1 }
        }

        let category = QuestionCategoryDef(
            id: id,
            name: name,
            iconName: iconName,
            drawCount: drawCount,
            keepCount: keepCount,
            timeLimitSeconds: timeLimitSeconds,
            questions: questions
        )
        return (orderIndex, category)
    }
}

extension CustomQuestion {
    func toDictionary(orderIndex: Int) throws -> [String: Any] {
        return [
            "id": id,
            "text": text,
            "questionType": questionType.rawValue,
            "choices": choices,
            "orderIndex": orderIndex
        ]
    }

    static func fromDictionaryWithOrder(_ dict: [String: Any]) throws -> (Int, CustomQuestion) {
        guard let id = dict["id"] as? String,
              let text = dict["text"] as? String,
              let typeRaw = dict["questionType"] as? String,
              let questionType = QuestionType(rawValue: typeRaw) else {
            throw DatabaseError.invalidData("CustomQuestion.fromDictionary")
        }

        let choices = dict["choices"] as? [String] ?? []
        let orderIndex = dict["orderIndex"] as? Int ?? 0

        let question = CustomQuestion(
            id: id,
            text: text,
            questionType: questionType,
            choices: choices
        )
        return (orderIndex, question)
    }
}
