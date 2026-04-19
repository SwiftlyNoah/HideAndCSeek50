//
//  QuestionSetsViewModel.swift
//  HideAndCSeek50
//
//  Owns the live list of the current user's question sets and exposes CRUD.
//  Backed by a single RTDB observer on `users/{uid}/questionSets`.
//

import SwiftUI
internal import Combine
import Firebase
import FirebaseDatabase

@MainActor
final class QuestionSetsViewModel: ObservableObject {
    @Published private(set) var sets: [QuestionSet] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private var listenerHandle: DatabaseHandle?
    private var listenerRef: DatabaseReference?
    private var currentUid: String?

    func startListening(uid: String) {
        if currentUid == uid, listenerHandle != nil { return }
        stopListening()
        currentUid = uid
        isLoading = true

        // Show the default set immediately while Firebase loads.
        sets = [QuestionSet.makeDefault()]

        // Seed the default into Firebase, then attach the listener so the
        // first snapshot always includes it.
        Task {
            try? await UserManager.shared.seedDefaultQuestionSetIfNeeded(uid: uid)
            let ref = DatabaseReference.user(uid).child("questionSets")
            self.listenerRef = ref
            self.listenerHandle = ref.observe(.value) { [weak self] snapshot in
                let parsed = Self.parse(snapshot: snapshot)
                Task { @MainActor in
                    self?.sets = parsed
                    self?.isLoading = false
                }
            }
        }
    }

    func stopListening() {
        if let handle = listenerHandle, let ref = listenerRef {
            ref.removeObserver(withHandle: handle)
        }
        listenerHandle = nil
        listenerRef = nil
        currentUid = nil
    }

    private static func parse(snapshot: DataSnapshot) -> [QuestionSet] {
        var parsed: [QuestionSet] = []
        if let data = snapshot.value as? [String: [String: Any]] {
            for (_, setData) in data {
                if let set = try? QuestionSet.fromDictionary(setData) {
                    parsed.append(set)
                }
            }
        }
        // Guarantee the default set is always present.
        if !parsed.contains(where: { $0.id == QuestionSet.defaultId }) {
            parsed.append(QuestionSet.makeDefault())
        }
        return parsed.sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    // MARK: - CRUD

    func createSet(name: String) async throws -> QuestionSet {
        guard let uid = currentUid else { throw DatabaseError.invalidOperation }
        let now = Date()
        let newSet = QuestionSet(
            id: UUID().uuidString,
            name: name,
            isDefault: false,
            createdAt: now,
            updatedAt: now,
            categories: []
        )
        try await UserManager.shared.saveQuestionSet(uid: uid, set: newSet)
        return newSet
    }

    func updateSet(_ set: QuestionSet) async throws {
        guard let uid = currentUid else { throw DatabaseError.invalidOperation }
        guard !set.isDefault else { throw DatabaseError.invalidOperation }
        try await UserManager.shared.saveQuestionSet(uid: uid, set: set)
    }

    func deleteSet(id: String) async throws {
        guard let uid = currentUid else { throw DatabaseError.invalidOperation }
        try await UserManager.shared.deleteQuestionSet(uid: uid, id: id)
    }

    func renameSet(id: String, to newName: String) async throws {
        guard let uid = currentUid else { throw DatabaseError.invalidOperation }
        try await UserManager.shared.renameQuestionSet(uid: uid, id: id, to: newName)
    }

    /// Duplicates an existing set into a new editable, non-default copy.
    /// New ids are minted for the set and every category/question so updates
    /// to the source don't bleed into the copy.
    func duplicateSet(_ source: QuestionSet, newName: String) async throws -> QuestionSet {
        guard let uid = currentUid else { throw DatabaseError.invalidOperation }
        let now = Date()
        let copiedCategories = source.categories.map { category in
            QuestionCategoryDef(
                id: UUID().uuidString,
                name: category.name,
                iconName: category.iconName,
                drawCount: category.drawCount,
                keepCount: category.keepCount,
                timeLimitSeconds: category.timeLimitSeconds,
                questions: category.questions.map { question in
                    CustomQuestion(
                        id: UUID().uuidString,
                        text: question.text,
                        questionType: question.questionType,
                        choices: question.choices
                    )
                }
            )
        }
        let copy = QuestionSet(
            id: UUID().uuidString,
            name: newName,
            isDefault: false,
            createdAt: now,
            updatedAt: now,
            categories: copiedCategories
        )
        try await UserManager.shared.saveQuestionSet(uid: uid, set: copy)
        return copy
    }
}
