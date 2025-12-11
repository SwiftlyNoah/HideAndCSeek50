//
//  GameEndView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/2/25.
//

import SwiftUI

struct GameEndView: View {
    let game: Game
    let lobbyCode: String
    let onReturnToLobby: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private var questionCount: Int {
        game.messages.values.filter { $0.type == .question }.count
    }
    
    private var hidingTimeFormatted: String {
        formatTime(game.info.hidingElapsed)
    }
    
    private var seekingTimeFormatted: String {
        formatTime(game.info.seekingElapsed)
    }
    
    private var totalGameTime: String {
        formatTime(game.info.elapsedTime)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    // Title
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.green)
                        
                        Text("Game Complete!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(game.info.name)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 16)
                    
                    // Game Stats Card
                    VStack(spacing: 0) {
                        // Hiding Stats
                        StatRow(
                            icon: "eye.slash.fill",
                            label: "Hiding Time",
                            value: hidingTimeFormatted,
                            color: .blue
                        )
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Seeking Stats
                        StatRow(
                            icon: "magnifyingglass",
                            label: "Seeking Time",
                            value: seekingTimeFormatted,
                            color: .red
                        )
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Questions
                        StatRow(
                            icon: "questionmark.circle.fill",
                            label: "Questions Asked",
                            value: "\(questionCount)",
                            color: .orange
                        )
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Total Time
                        StatRow(
                            icon: "clock.fill",
                            label: "Total Game Time",
                            value: totalGameTime,
                            color: .purple
                        )
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Players
                        StatRow(
                            icon: "person.2.fill",
                            label: "Players",
                            value: "\(game.totalPlayers)",
                            color: .green
                        )
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // City
                        StatRow(
                            icon: "mappin.circle.fill",
                            label: "Location",
                            value: game.info.settings.city.displayName,
                            color: .teal
                        )
                    }
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: onReturnToLobby) {
                            HStack {
                                Image(systemName: "rectangle.portrait.on.rectangle.portrait.fill")
                                Text("Return to Lobby")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Text("Lobby Code: \(lobbyCode)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)
            
            Text(label)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

#Preview {
    GameEndView(
        game: Game(
            info: GameInfo(
                gameId: "preview-game",
                gameCode: "ABC123",
                name: "Test Game",
                hostUID: "host123",
                state: .completed,
                maxPlayers: 6,
                currentPlayers: 4,
                createdAt: Date(),
                startedAt: Date().addingTimeInterval(-1800),
                endedAt: Date(),
                settings: GameSettings(hidingTime: 30, city: .boston)
            ),
            teams: GameTeams(
                hiders: ["user1": Player(uid: "user1", displayName: "Player 1")],
                seekers: ["user2": Player(uid: "user2", displayName: "Player 2")]
            ),
            deck: DeckState(shouldPopulate: true)
        ),
        lobbyCode: "ABC123",
        onReturnToLobby: {}
    )
}
