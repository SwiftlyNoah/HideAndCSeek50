//
//  QuestionView.swift
//  HideAndCSeek50
//
//  Created by Ryan Eto on 11/20/25.
//

import SwiftUI
import FirebaseAuth

struct GameQuestionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var gameManager: GameManager
    @EnvironmentObject private var authManager: AuthenticationManager
    
    let gameId: String
    
    @State private var selectedCategory: QuestionCategory = .matching
    @State private var selectedQuestion: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var successMessage: String?
    @State private var showingSuccess = false
    @State private var showingCategorySelector = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
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
                    // Header
                    VStack(spacing: 12) {
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
                            
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(20)
                    }
                    .background(Color(.systemBackground))
                    .border(Color(.systemGray5), width: 1)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // Category Selection
                            categorySelector
                            
                            // Question Selection - only show when category is selected
                            if !showingCategorySelector, let questions = questionsForCategory(selectedCategory) {
                                questionSelector(questions: questions)
                            }
                            
                            Spacer()
                        }
                        .padding(20)
                    }
                    
                    // Action Buttons
                    if selectedQuestion != nil {
                        VStack(spacing: 12) {
                            Button(action: { Task { await sendQuestion() } }) {
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
                            
                            Button(action: { dismiss() }) {
                                Text("Cancel")
                                    .frame(maxWidth: .infinity)
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
                }
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                if let successMessage = successMessage {
                    Text(successMessage)
                }
            }
        }
    }
    
    // MARK: - Category Selector
    
    private var categorySelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Question Category")
                .font(.headline)
                .fontWeight(.semibold)

            if showingCategorySelector {
                // Show all categories
                VStack(spacing: 8) {
                    ForEach(QuestionCategory.allCases, id: \.self) { category in
                        let isDisabled = restrictedCategories.contains(category)

                        Button(action: {
                            selectedCategory = category
                            selectedQuestion = nil
                            showingCategorySelector = false
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: category.iconName)
                                            .font(.headline)
                                        Text(category.displayName)
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
                                    Text(category.description)
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
                        .disabled(isDisabled)
                        .foregroundColor(.primary)
                    }
                }
            } else {
                // Show selected category with change button
                HStack {
                    HStack {
                        Image(systemName: selectedCategory.iconName)
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedCategory.displayName)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(selectedCategory.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showingCategorySelector = true
                        selectedQuestion = nil
                    }) {
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
    
    // MARK: - Question Selector
    
    private func questionSelector(questions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select a Question")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Legend
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
                ForEach(questions, id: \.self) { question in
                    let fullQuestionText = selectedCategory.writeQuestion(arg: question)
                    let hasBeenAsked = checkIfQuestionAskedBefore(fullQuestionText)
                    
                    Button(action: { selectedQuestion = question }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(question)
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
                            
                            if selectedQuestion == question {
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
                            selectedQuestion == question ?
                            Color.red.opacity(0.05) :
                                (hasBeenAsked ? Color.orange.opacity(0.05) : Color(.systemGray6))
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    selectedQuestion == question ?
                                    Color.red.opacity(0.3) :
                                        (hasBeenAsked ? Color.orange.opacity(0.2) : Color.clear),
                                    lineWidth: 1
                                )
                        )
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func sendQuestion() async {
        guard let currentUID = authManager.currentUser?.uid,
              let selectedQuestion = selectedQuestion else {
            errorMessage = "Unable to send question"
            showingError = true
            return
        }

        // Safety check: prevent sending if restricted (race protection)
        if restrictedCategories.contains(selectedCategory) {
            errorMessage = "You can't ask two questions in a row from the same category."
            showingError = true
            return
        }

        isLoading = true

        do {
            // Compose question without reward text
            let baseQuestion = selectedCategory.writeQuestion(arg: selectedQuestion)
            
            // Calculate reward (double if asked before)
            let hasBeenAskedBefore = checkIfQuestionAskedBefore(baseQuestion)
            let drawCount = selectedCategory.drawCount * (hasBeenAskedBefore ? 2 : 1)
            let keepCount = selectedCategory.keepCount * (hasBeenAskedBefore ? 2 : 1)
            let reward = "Draw \(drawCount), Keep \(keepCount)"
            
            let questionId = UUID().uuidString

            // Create question data with reward fields
            let questionData = QuestionData(
                questionId: questionId,
                questionText: baseQuestion,
                isAnswered: false,
                playerAnswer: nil,
                questionCategory: selectedCategory,
                reward: reward
            )
            
            print(questionData)
            
            let message = GameMessage(
                id: UUID().uuidString,
                senderUID: currentUID,
                senderName: "Seekers",
                content: baseQuestion,  // Just the question, no reward text
                type: .question,
                timestamp: Date(),
                attachments: nil,
                questionData: questionData,
                team: .seekers
            )

            try await GameManager.sendMessage(gameId: gameId, message: message)
            
            await MainActor.run {
                if hasBeenAskedBefore {
                    successMessage = "Question sent! Reward doubled since this was asked before."
                } else {
                    successMessage = "Question sent to hiders!"
                }
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
    
    // Check if a question with the same text has been asked before
    private func checkIfQuestionAskedBefore(_ questionText: String) -> Bool {
        guard let messages = gameManager.currentGame?.messages.values else {
            return false
        }
        
        return messages.contains { message in
            message.type == .question &&
            message.questionData?.questionText == questionText &&
            message.timestamp < Date() // Make sure it's not the current message
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
    
    // Categories disabled for the next question
    private var restrictedCategories: Set<QuestionCategory> {
        if let lastCat = lastQuestionMessage?.questionData?.questionCategory {
            return [lastCat]
        }
        return []
    }

    // MARK: - Helpers
    
    private func questionsForCategory(_ category: QuestionCategory) -> [String]? {
        switch category {
        case .matching:
            return [
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
            
        case .measuring:
            return [
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
            
        case .thermometer:
            return [
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
            
        case .radar:
            return [
                "0.25 miles",
                "0.5 miles",
                "1 mile?",
                "3 miles",
                "5 miles",
                "10 miles",
                "25 miles",
                "50 miles",
                "100 miles",
            ]
            
        case .tentacles:
            return [
                "Museums",
                "Libraries",
                "Movie Theaters",
                "Hospitals",
                "Parks",
                "Bodies of Water",
            ]
            
        case .photos:
            return [
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
                "Place of Worship",
            ]
        }
    }
}
