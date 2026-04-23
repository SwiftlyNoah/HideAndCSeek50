//
//  CreateLobbyView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import SwiftUI
import FirebaseAuth

struct CreateLobbyView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var gameManager: GameManager

    @Environment(\.dismiss) private var dismiss
    
    let onLobbyCreated: (String) -> Void
    
    @State private var gameName = ""
    @State private var maxHiders = 2
    @State private var maxSeekers = 2
    @State private var isPublic = true
    @State private var hidingTime: Int = 30 // 30 minutes
    @State private var selectedCity: GameCity = .boston
    @State private var availableSets: [QuestionSet] = []
    @State private var selectedQuestionSetId: String = QuestionSet.defaultId
    @State private var availableDecks: [CardDeck] = []
    @State private var selectedCardDeckId: String = CardDeck.defaultId
    @State private var maxHandSize: Int = 5
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isHidingTimeFieldFocused: Bool

    private var selectedSetName: String {
        availableSets.first { $0.id == selectedQuestionSetId }?.name ?? QuestionSet.defaultName
    }

    private var selectedDeckName: String {
        availableDecks.first { $0.id == selectedCardDeckId }?.name ?? CardDeck.defaultName
    }
    
    private var currentUser: User? {
        authManager.currentUser
    }
    
    private var displayName: String {
        currentUser?.displayName ?? "Anonymous Player"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Game Details") {
                    TextField("Game Name", text: $gameName)
                        .textInputAutocapitalization(.words)
                    
                    Picker("City", selection: $selectedCity) {
                        ForEach(GameCity.allCases, id: \.self) { city in
                            HStack {
                                Text(city.displayName)
                                Spacer()
                                Text(city.shortCode)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(city)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Game Timing") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Hiding Time")
                            Spacer()
                            HStack(spacing: 4) {
                                TextField("", value: $hidingTime, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                                    .frame(width: 50)
                                    .focused($isHidingTimeFieldFocused)
                                Text("min")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Slider(value: Binding(
                            get: { Double(hidingTime) },
                            set: { hidingTime = Int($0) }
                        ), in: 1...120, step: 1)
                            .accentColor(.blue)
                    }
                }
                
                Section("Team Sizes") {
                    HStack {
                        Text("Maximum Hiders")
                        Spacer()
                        Stepper(
                            value: $maxHiders,
                            in: 1...8
                        ) {
                            Text("\(maxHiders)")
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    HStack {
                        Text("Maximum Seekers")
                        Spacer()
                        Stepper(
                            value: $maxSeekers,
                            in: 1...8
                        ) {
                            Text("\(maxSeekers)")
                                .foregroundColor(.red)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    HStack {
                        Text("Total Players")
                        Spacer()
                        Text("\(maxHiders + maxSeekers)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Questions") {
                    Picker("Question Set", selection: $selectedQuestionSetId) {
                        ForEach(availableSets) { set in
                            Text(set.name).tag(set.id)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Cards") {
                    Picker("Card Deck", selection: $selectedCardDeckId) {
                        ForEach(availableDecks) { deck in
                            Text(deck.name).tag(deck.id)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Text("Max Hand Size")
                        Spacer()
                        Stepper(
                            value: $maxHandSize,
                            in: 1...20
                        ) {
                            Text("\(maxHandSize)")
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                }

                Section("Privacy") {
                    Toggle(isOn: $isPublic) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Public Lobby")
                            Text(isPublic ? "Anyone can join from Quick Match" : "Only players with the code can join")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            await createLobby()
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text("Create Lobby")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(isLoading || gameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Create Lobby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isHidingTimeFieldFocused = false
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
        .onAppear {
            if gameName.isEmpty {
                gameName = "\(displayName)'s Game"
            }
            loadQuestionSets()
            loadCardDecks()
        }
    }

    private func loadQuestionSets() {
        guard let uid = currentUser?.uid else { return }
        Task {
            try? await UserManager.shared.seedDefaultQuestionSetIfNeeded(uid: uid)
            let sets = (try? await UserManager.shared.getQuestionSets(uid: uid)) ?? []
            await MainActor.run {
                if sets.contains(where: { $0.id == QuestionSet.defaultId }) {
                    availableSets = sets
                } else {
                    availableSets = [QuestionSet.makeDefault()] + sets
                }
                if !availableSets.contains(where: { $0.id == selectedQuestionSetId }) {
                    selectedQuestionSetId = availableSets.first?.id ?? QuestionSet.defaultId
                }
            }
        }
    }

    private func loadCardDecks() {
        guard let uid = currentUser?.uid else { return }
        Task {
            try? await UserManager.shared.seedDefaultCardDeckIfNeeded(uid: uid)
            let decks = (try? await UserManager.shared.getCardDecks(uid: uid)) ?? []
            await MainActor.run {
                if decks.contains(where: { $0.id == CardDeck.defaultId }) {
                    availableDecks = decks
                } else {
                    availableDecks = [CardDeck.makeDefault()] + decks
                }
                if !availableDecks.contains(where: { $0.id == selectedCardDeckId }) {
                    selectedCardDeckId = availableDecks.first?.id ?? CardDeck.defaultId
                }
            }
        }
    }
    
    private func createLobby() async {
        guard let currentUID = currentUser?.uid else {
            errorMessage = "Please sign in to create a lobby"
            return
        }
        
        let trimmedName = gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a game name"
            return
        }
        
        isLoading = true
        
        do {
            let lobbyCode = try await gameManager.createLobby(
                hostUID: currentUID,
                hostName: displayName,
                gameName: trimmedName,
                isPublic: isPublic,
                maxHiders: maxHiders,
                maxSeekers: maxSeekers,
                hidingTime: hidingTime,
                city: selectedCity,
                questionSetId: selectedQuestionSetId,
                questionSetName: selectedSetName,
                cardDeckId: selectedCardDeckId,
                cardDeckName: selectedDeckName,
                maxHandSize: maxHandSize
            )
            
            await MainActor.run {
                onLobbyCreated(lobbyCode)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

#Preview {
    CreateLobbyView { _ in }
        .environmentObject(AuthenticationManager())
}
