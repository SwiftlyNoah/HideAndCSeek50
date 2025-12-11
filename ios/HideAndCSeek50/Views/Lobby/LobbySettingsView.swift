//
//  LobbySettingsView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import SwiftUI

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
               selectedCity != lobby.city
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
                city: selectedCity
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
