//
//  CreateLobbyView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import SwiftUI
import FirebaseAuth

struct CreateLobbyView: View {
    let onLobbyCreated: (String) -> Void
    
    @StateObject private var databaseManager = DatabaseManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var gameName = ""
    @State private var maxHiders = 2
    @State private var maxSeekers = 2
    @State private var isPublic = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var currentUser: User? {
        Auth.auth().currentUser
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
            // Set default game name
            if gameName.isEmpty {
                gameName = "\(displayName)'s Game"
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
            let lobbyCode = try await databaseManager.createLobby(
                hostUID: currentUID,
                hostName: displayName,
                gameName: trimmedName,
                isPublic: isPublic,
                maxHiders: maxHiders,
                maxSeekers: maxSeekers
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
}
