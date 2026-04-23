//
//  LobbySettingsView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import SwiftUI
import FirebaseAuth

struct LobbySettingsView: View {
    @EnvironmentObject private var gameManager: GameManager

    @Environment(\.dismiss) private var dismiss

    let lobby: Lobby
    let lobbyCode: String

    @State private var maxHiders: Int
    @State private var maxSeekers: Int
    @State private var isPublic: Bool
    @State private var hidingTime: Int
    @State private var selectedCity: GameCity
    @State private var selectedQuestionSetId: String
    @State private var availableSets: [QuestionSet] = []
    @State private var selectedCardDeckId: String
    @State private var availableDecks: [CardDeck] = []
    @State private var maxHandSize: Int
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(lobby: Lobby, lobbyCode: String) {
        self.lobby = lobby
        self.lobbyCode = lobbyCode
        self._maxHiders = State(initialValue: lobby.maxHiders)
        self._maxSeekers = State(initialValue: lobby.maxSeekers)
        self._isPublic = State(initialValue: lobby.isPublic)
        self._hidingTime = State(initialValue: lobby.hidingTime)
        self._selectedCity = State(initialValue: lobby.city)
        self._selectedQuestionSetId = State(initialValue: lobby.questionSetId ?? QuestionSet.defaultId)
        self._selectedCardDeckId = State(initialValue: lobby.cardDeckId ?? CardDeck.defaultId)
        self._maxHandSize = State(initialValue: lobby.maxHandSize)
    }

    private var selectedSetName: String {
        availableSets.first { $0.id == selectedQuestionSetId }?.name ?? QuestionSet.defaultName
    }

    private var selectedDeckName: String {
        availableDecks.first { $0.id == selectedCardDeckId }?.name ?? CardDeck.defaultName
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Game Location") {
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
                                    .toolbar {
                                        ToolbarItemGroup(placement: .keyboard) {
                                            Spacer()
                                            Button("Done") {
                                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                            }
                                        }
                                    }
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
                
                Section("Current Players") {
                    Text("Hiders: \(lobby.hidersCount)/\(maxHiders)")
                        .foregroundColor(lobby.hidersCount > maxHiders ? .red : .primary)
                    
                    Text("Seekers: \(lobby.seekersCount)/\(maxSeekers)")
                        .foregroundColor(lobby.seekersCount > maxSeekers ? .red : .primary)
                    
                    if lobby.hidersCount > maxHiders || lobby.seekersCount > maxSeekers {
                        Text("⚠️ Some players will need to switch teams or leave")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Lobby Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveSettings()
                        }
                    }
                    .disabled(isLoading || !hasChanges)
                }
            }
            .disabled(isLoading)
            .onAppear {
                loadQuestionSets()
                loadCardDecks()
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
    }
    
    private var hasChanges: Bool {
        return maxHiders != lobby.maxHiders ||
               maxSeekers != lobby.maxSeekers ||
               isPublic != lobby.isPublic ||
               hidingTime != lobby.hidingTime ||
               selectedCity != lobby.city ||
               selectedQuestionSetId != (lobby.questionSetId ?? QuestionSet.defaultId) ||
               selectedCardDeckId != (lobby.cardDeckId ?? CardDeck.defaultId) ||
               maxHandSize != lobby.maxHandSize
    }

    private func loadQuestionSets() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
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
        guard let uid = Auth.auth().currentUser?.uid else { return }
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

    private func saveSettings() async {
        isLoading = true

        do {
            try await gameManager.updateLobbySettings(
                code: lobbyCode,
                maxHiders: maxHiders,
                maxSeekers: maxSeekers,
                isPublic: isPublic,
                hidingTime: hidingTime,
                city: selectedCity,
                questionSetId: selectedQuestionSetId,
                questionSetName: selectedSetName,
                cardDeckId: selectedCardDeckId,
                cardDeckName: selectedDeckName,
                maxHandSize: maxHandSize
            )

            await MainActor.run {
                dismiss()
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
    let sampleLobby = Lobby(
        code: "ABC123",
        hostUID: "host123",
        gameId: "game123",
        name: "Test Game",
        isPublic: true,
        maxHiders: 2,
        maxSeekers: 2,
        hidingTime: 30,
        city: .boston,
        createdAt: Date(),
        expiresAt: Date().addingTimeInterval(3600),
        players: [:]
    )
    
    return LobbySettingsView(lobby: sampleLobby, lobbyCode: "ABC123")
}
