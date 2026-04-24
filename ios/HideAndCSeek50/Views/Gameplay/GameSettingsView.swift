//
//  GameSettingsView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/7/25.
//

import SwiftUI
import FirebaseAuth

struct GameSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var gameManager: GameManager
    
    let gameId: String
    let lobbyCode: String
    let playerTeam: Team
    let onLeaveGame: () -> Void
    
    @State private var isLeavingGame = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Leave Game", role: .destructive) {
                        leaveGame()
                    }
                    .disabled(isLeavingGame)
                }
                
                Section("Game Info") {
                    HStack {
                        Text("Team")
                            .foregroundColor(.primary)
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: playerTeam.iconName)
                                .font(.caption)
                            Text(playerTeam.displayName)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(playerTeam.swiftUIColor)
                    }
                    
                    Text("Game ID: \(gameId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Lobby Code: \(lobbyCode)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if isLeavingGame {
                    Section {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            Text("Leaving game...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Game Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func leaveGame() {
        guard let currentUser = authManager.currentUser else { return }
        
        isLeavingGame = true
        
        Task {
            do {
                // Leave both game and lobby
                try await gameManager.leaveGame(
                    gameId: gameId,
                    playerUID: currentUser.uid,
                    playerName: currentUser.displayName,
                    lobbyCode: lobbyCode
                )
                
                await MainActor.run {
                    isLeavingGame = false
                    dismiss()
                    onLeaveGame()
                }
            } catch {
                await MainActor.run {
                    isLeavingGame = false
                    print("Error leaving game: \(error.localizedDescription)")
                }
            }
        }
    }
}
