//
//  QuestionView.swift
//  HideAndCSeek50
//
//  Created by Ryan Eto on 11/20/25.
//

import SwiftUI
import FirebaseAuth

struct GameQuestionView: View {
    let gameId: String
    let currentUser: User?
    
    @StateObject private var databaseManager = DatabaseManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: QuestionCategory = .matching
    @State private var selectedQuestion: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var successMessage: String?
    @State private var showingSuccess = false
    
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
                            
                            // Question Selection
                            if let questions = questionsForCategory(selectedCategory) {
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
            
            VStack(spacing: 8) {
                ForEach(QuestionCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                        selectedQuestion = nil
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: category.iconName)
                                        .font(.headline)
                                    
                                    Text(category.displayName)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                
                                Text(category.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedCategory == category {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(16)
                        .background(
                            selectedCategory == category ?
                            Color.red.opacity(0.1) :
                            Color(.systemGray6)
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    selectedCategory == category ?
                                    Color.red.opacity(0.5) :
                                    Color.clear,
                                    lineWidth: 2
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
    
    // MARK: - Question Selector
    
    private func questionSelector(questions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select a Question")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(questions, id: \.self) { question in
                    Button(action: { selectedQuestion = question }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(question)
                                    .font(.body)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
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
                            Color(.systemGray6)
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    selectedQuestion == question ?
                                    Color.red.opacity(0.3) :
                                    Color.clear,
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
    
    // MARK: - Helpers
    
    private func questionsForCategory(_ category: QuestionCategory) -> [String]? {
        // TODO: Replace with actual questions once provided
        switch category {
        case .matching:
            return [
                "Are you hiding near a red building?",
                "Can you see a parking lot?",
                "Are you inside or outside?"
            ]
        case .measuring:
            return [
                "Are you within 100 meters of a street sign?",
                "Is the hiding spot taller than 20 feet?",
                "Are you less than 50 meters from water?"
            ]
        case .thermometer:
            return [
                "Are you in direct sunlight?",
                "Is it warmer where you are than in the open?",
                "Are you in a shaded area?"
            ]
        case .radar:
            return [
                "Can you see the city skyline?",
                "Is there a vehicle nearby?",
                "Are there people within 50 meters?"
            ]
        case .tentacles:
            return [
                "Are you on public property?",
                "Can you reach something metal from where you are?",
                "Are you touching any plants?"
            ]
        case .photos:
            return [
                "Take a photo of your hiding spot",
                "Photograph something red near you",
                "Show us what the ground looks like"
            ]
        }
    }
    
    private func sendQuestion() async {
        guard let currentUID = currentUser?.uid,
              let selectedQuestion = selectedQuestion else {
            errorMessage = "Unable to send question"
            showingError = true
            return
        }
        
        isLoading = true
        
        do {
            let question = GameQuestion(
                id: UUID().uuidString,
                type: selectedCategory.questionType,
                question: selectedQuestion,
                askedBy: currentUID,
                askedAt: Date(),
                answeredBy: nil,
                answeredAt: nil,
                answer: nil,
                isCorrect: false,
                pointsAwarded: 0,
                attachments: nil,
                mapUpdate: nil
            )
            
            try await databaseManager.sendQuestion(gameId: gameId, question: question)
            
            await MainActor.run {
                successMessage = "Question sent to hiders!"
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
}

// MARK: - Question Category Enum

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
            return "Visual matching and landmark questions"
        case .measuring:
            return "Distance and dimension questions"
        case .thermometer:
            return "Temperature and environmental conditions"
        case .radar:
            return "Presence and proximity detection"
        case .tentacles:
            return "Physical interaction and accessibility"
        case .photos:
            return "Photo evidence and visual proof"
        }
    }
    
    var iconName: String {
        switch self {
        case .matching: return "square.2.stack"
        case .measuring: return "ruler"
        case .thermometer: return "thermometer"
        case .radar: return "dot.radiowaves.right"
        case .tentacles: return "hare"
        case .photos: return "camera.fill"
        }
    }
    
    var questionType: QuestionType {
        // Map categories to QuestionType enum
        switch self {
        case .matching, .photos:
            return .photo
        case .measuring:
            return .distance
        case .thermometer:
            return .location
        case .radar:
            return .direction
        case .tentacles:
            return .landmark
        }
    }
}

#Preview {
    GameQuestionView(
        gameId: "game123",
        currentUser: nil
    )
    .environmentObject(DatabaseManager.shared)
}
