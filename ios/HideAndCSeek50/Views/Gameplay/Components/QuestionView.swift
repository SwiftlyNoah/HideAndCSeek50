//
//  QuestionView.swift
//  HideAndCSeek50
//
//  Created by Ryan Eto on 11/20/25.
//
//  Drives off the snapshot at `game.info.settings.questionSet` instead of
//  the hardcoded `QuestionCategory` enum. Categories, questions, per-category
//  time limits, reward amounts, question types, and multiple-choice options
//  all come from the snapshot.
//

import SwiftUI
import FirebaseAuth

struct GameQuestionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var gameManager: GameManager
    @EnvironmentObject private var authManager: AuthenticationManager

    let gameId: String

    @State private var selectedCategoryId: String?
    @State private var selectedQuestionId: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var successMessage: String?
    @State private var showingSuccess = false
    @State private var showingCategorySelector = true

    private var categories: [QuestionCategoryDef] {
        gameManager.currentGame?.info.settings.questionSet?.categories ?? []
    }

    private var selectedCategory: QuestionCategoryDef? {
        guard let id = selectedCategoryId else { return nil }
        return categories.first { $0.id == id }
    }

    private var selectedQuestion: CustomQuestion? {
        guard let question = selectedQuestionId,
              let category = selectedCategory else { return nil }
        return category.questions.first { $0.id == question }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.red.opacity(0.1),
                        Color.orange.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    ScrollView {
                        VStack(spacing: 24) {
                            if categories.isEmpty {
                                emptyState
                            } else {
                                categorySelector
                                if !showingCategorySelector, let category = selectedCategory {
                                    questionSelector(category: category)
                                }
                            }
                            Spacer()
                        }
                        .padding(20)
                    }

                    if selectedQuestion != nil {
                        actionButtons
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let errorMessage { Text(errorMessage) }
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") { dismiss() }
            } message: {
                if let successMessage { Text(successMessage) }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ask a Question")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Get clues from the hiders")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .border(Color(.systemGray5), width: 1)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No questions available")
                .font(.headline)
            Text("This game was started without a question set.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    // MARK: - Category Selector

    private var categorySelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Question Category")
                .font(.headline)
                .fontWeight(.semibold)

            if showingCategorySelector {
                VStack(spacing: 8) {
                    ForEach(categories) { category in
                        let isDisabled = restrictedCategoryIds.contains(category.id)
                        Button {
                            selectedCategoryId = category.id
                            selectedQuestionId = nil
                            showingCategorySelector = false
                        } label: {
                            categoryRow(category: category, isDisabled: isDisabled)
                        }
                        .disabled(isDisabled || category.questions.isEmpty)
                        .foregroundColor(.primary)
                    }
                }
            } else if let category = selectedCategory {
                HStack {
                    HStack {
                        Image(systemName: category.iconName)
                            .font(.headline)
                            .foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text(category.rewardPreview)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        showingCategorySelector = true
                        selectedQuestionId = nil
                    } label: {
                        Text("Change Category")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                    }
                }
                .padding(16)
                .background(Color.red.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func categoryRow(category: QuestionCategoryDef, isDisabled: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: category.iconName)
                        .font(.headline)
                    Text(category.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    if isDisabled {
                        Text("Just asked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(6)
                    }
                }
                Text(category.rewardPreview)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .opacity(isDisabled ? 0.5 : 1.0)
    }

    // MARK: - Question Selector

    private func questionSelector(category: QuestionCategoryDef) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select a Question")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Asked")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("2x Reward")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            VStack(spacing: 8) {
                ForEach(category.questions) { question in
                    let hasBeenAsked = checkIfQuestionAskedBefore(question.text)
                    Button {
                        selectedQuestionId = question.id
                    } label: {
                        questionRow(question: question, hasBeenAsked: hasBeenAsked)
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func questionRow(question: CustomQuestion, hasBeenAsked: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(question.text)
                        .font(.body)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if hasBeenAsked {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                if hasBeenAsked {
                    Text("Asked before — Reward will be doubled!")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
            }
            Spacer()
            if selectedQuestionId == question.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.red)
            } else {
                Circle()
                    .stroke(Color(.systemGray3), lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(16)
        .background(
            selectedQuestionId == question.id
                ? Color.red.opacity(0.05)
                : (hasBeenAsked ? Color.orange.opacity(0.05) : Color(.systemGray6))
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    selectedQuestionId == question.id
                        ? Color.red.opacity(0.3)
                        : (hasBeenAsked ? Color.orange.opacity(0.2) : Color.clear),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button { Task { await sendQuestion() } } label: {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Send Question")
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(isLoading || selectedQuestion == nil)

            Button { dismiss() } label: {
                Text("Cancel").frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(12)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .border(Color(.systemGray5), width: 1)
    }

    // MARK: - Send

    private func sendQuestion() async {
        guard let currentUID = authManager.currentUser?.uid,
              let category = selectedCategory,
              let question = selectedQuestion else {
            errorMessage = "Unable to send question"
            showingError = true
            return
        }

        if restrictedCategoryIds.contains(category.id) {
            errorMessage = "You can't ask two questions in a row from the same category."
            showingError = true
            return
        }

        isLoading = true

        do {
            let hasBeenAskedBefore = checkIfQuestionAskedBefore(question.text)
            let multiplier = hasBeenAskedBefore ? 2 : 1
            let drawCount = category.drawCount * multiplier
            let keepCount = category.keepCount * multiplier
            let reward = "Draw \(drawCount), Keep \(keepCount)"

            let questionData = QuestionData(
                questionId: UUID().uuidString,
                questionText: question.text,
                isAnswered: false,
                playerAnswer: nil,
                categoryId: category.id,
                categoryName: category.name,
                questionType: question.questionType,
                choices: question.choices,
                timeLimitSeconds: category.timeLimitSeconds,
                reward: reward
            )

            let message = GameMessage(
                id: UUID().uuidString,
                senderUID: currentUID,
                senderName: "Seekers",
                content: question.text,
                type: .question,
                timestamp: Date(),
                attachments: nil,
                questionData: questionData,
                team: .seekers
            )

            try await GameManager.sendMessage(gameId: gameId, message: message)

            await MainActor.run {
                successMessage = hasBeenAskedBefore
                    ? "Question sent! Reward doubled since this was asked before."
                    : "Question sent to hiders!"
                showingSuccess = true
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
                isLoading = false
            }
        }
    }

    // MARK: - Helpers

    private func checkIfQuestionAskedBefore(_ questionText: String) -> Bool {
        guard let messages = gameManager.currentGame?.messages.values else {
            return false
        }
        return messages.contains { message in
            message.type == .question &&
            message.questionData?.questionText == questionText &&
            message.timestamp < Date()
        }
    }

    private var lastQuestionMessage: GameMessage? {
        gameManager.currentGame?
            .messages
            .values
            .filter { $0.type == .question }
            .sorted(by: { $0.timestamp > $1.timestamp })
            .first
    }

    private var restrictedCategoryIds: Set<String> {
        if let lastId = lastQuestionMessage?.questionData?.categoryId {
            return [lastId]
        }
        return []
    }
}
