//
//  LobbyView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import SwiftUI
import FirebaseAuth

struct LobbyView: View {
    let lobbyCode: String
    let isHost: Bool
    @StateObject private var databaseManager = DatabaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var showingSettings = false
    @State private var showingLeaveLobby = false
    @State private var isLoading = false
    @State private var gameId: String?
    @State private var navigateToGame = false
    @State private var errorMessage: String?
    @State private var isGameStarting = false
    
    private var currentUser: User? {
        authManager.currentUser
    }
    
    private var lobby: Lobby? {
        databaseManager.currentLobby
    }
    
    private var canStartGame: Bool {
        guard let lobby = lobby else { return false }
        return isHost && lobby.canStart
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.1),
                        Color.purple.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if let lobby = lobby {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header with game code
                            headerSection(lobby: lobby)
                            
                            // Lobby settings (host only)
                            if isHost {
                                lobbySettingsSection(lobby: lobby)
                            }
                            
                            // Teams section
                            teamsSection(lobby: lobby)
                            
                            // Action buttons
                            actionButtonsSection(lobby: lobby)
                            
                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                } else {
                    ProgressView("Loading lobby...")
                        .font(.headline)
                }
                
                // Loading overlay
                if isLoading || isGameStarting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text(isGameStarting ? "Game Starting..." : "Loading...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Lobby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Leave") {
                        showingLeaveLobby = true
                    }
                    .foregroundColor(.red)
                }
                
                if isHost {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Settings") {
                            showingSettings = true
                        }
                    }
                }
            }
            .onAppear {
                startListening()
            }
            .onDisappear {
                stopListening()
            }
            .onChange(of: lobby?.gameId) { _, newGameId in
                // Monitor for game start - when gameId is set and lobby becomes inactive
                handleGameStart()
            }
            .onChange(of: lobby?.isActive) { _, isActive in
                // Also monitor isActive status changes
                if isActive == false {
                    handleGameStart()
                }
            }
            .fullScreenCover(isPresented: $navigateToGame) {
                Group {
                    if let gameId = gameId,
                       let lobby = lobby,
                       let currentUID = currentUser?.uid,
                       let currentPlayer = lobby.players[currentUID] {
                        GameView(
                            gameId: gameId,
                            lobbyCode: lobbyCode,
                            playerTeam: currentPlayer.team
                        )
                    }
                    else {
                        Color.red
                    }
                }
        }
        .sheet(isPresented: $showingSettings) {
                if let lobby = lobby {
                    LobbySettingsView(lobby: lobby, lobbyCode: lobbyCode)
                }
            }
            .confirmationDialog("Leave Lobby", isPresented: $showingLeaveLobby, titleVisibility: .visible) {
                Button("Leave Lobby", role: .destructive) {
                    Task { await leaveLobby() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(isHost ? "As the host, leaving will transfer ownership or close the lobby if empty." : "Are you sure you want to leave this lobby?")
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
    
    // MARK: - Header Section
    
    private func headerSection(lobby: Lobby) -> some View {
        VStack(spacing: 20) {
            // Game code
            VStack(spacing: 12) {
                Text("Game Code")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(lobbyCode)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .glassEffect(.regular.tint(.blue.opacity(0.1)), in: .rect(cornerRadius: 16))
                    .onTapGesture {
                        UIPasteboard.general.string = lobbyCode
                        // TODO: Add haptic feedback
                    }
                
                Text("Tap to copy")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Game name and info
            VStack(spacing: 8) {
                Text(lobby.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("\(lobby.totalPlayers)/\(lobby.maxPlayers) players")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    if lobby.isPublic {
                        Label("Public Lobby", systemImage: "globe")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .glassEffect(.regular.tint(.green.opacity(0.2)), in: .capsule)
                    } else {
                        Label("Private Lobby", systemImage: "lock")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .glassEffect(.regular.tint(.orange.opacity(0.2)), in: .capsule)
                    }
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Lobby Settings Section
    
    private func lobbySettingsSection(lobby: Lobby) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lobby Settings")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max Hiders: \(lobby.maxHiders)")
                        .font(.subheadline)
                    Text("Max Seekers: \(lobby.maxSeekers)")
                        .font(.subheadline)
                }
                
                Spacer()
                
                Button("Edit") {
                    showingSettings = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Teams Section
    
    private func teamsSection(lobby: Lobby) -> some View {
        VStack(spacing: 16) {
            // Hiders Team
            teamCard(
                title: "Hiders",
                players: lobby.players.values.filter { $0.team == .hiders }.sorted { $0.joinedAt < $1.joinedAt },
                maxPlayers: lobby.maxHiders,
                color: .blue,
                lobby: lobby
            )
            
            // Seekers Team
            teamCard(
                title: "Seekers",
                players: lobby.players.values.filter { $0.team == .seekers }.sorted { $0.joinedAt < $1.joinedAt },
                maxPlayers: lobby.maxSeekers,
                color: .red,
                lobby: lobby
            )
        }
    }
    
    private func teamCard(title: String, players: [LobbyPlayer], maxPlayers: Int, color: Color, lobby: Lobby) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                
                Spacer()
                
                Text("\(players.count)/\(maxPlayers)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if players.isEmpty {
                HStack {
                    Spacer()
                    Text("No players yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ForEach(players, id: \.uid) { player in
                    playerRow(player: player, lobby: lobby)
                }
            }
            
            // Join team button for current user if not in this team
            if let currentUID = currentUser?.uid,
               let currentPlayer = lobby.players[currentUID],
               currentPlayer.team != (title == "Hiders" ? .hiders : .seekers),
               players.count < maxPlayers {
                
                Button("Switch to \(title)") {
                    Task {
                        await moveToTeam(title == "Hiders" ? .hiders : .seekers)
                    }
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }
        }
        .padding(20)
        .glassEffect(.regular.tint(color.opacity(0.1)), in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func playerRow(player: LobbyPlayer, lobby: Lobby) -> some View {
        HStack {
            // Player info
            HStack(spacing: 8) {
                Circle()
                    .fill(player.isOnline ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                
                Text(player.displayName)
                    .font(.subheadline)
                    .fontWeight(player.uid == lobby.hostUID ? .semibold : .regular)
                
                if player.uid == lobby.hostUID {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
            
            Spacer()
            
            // Ready status
            HStack(spacing: 4) {
                if player.isReady {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Ready")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "clock.circle")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Not Ready")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // Host controls
            if isHost && player.uid != currentUser?.uid {
                Menu {
                    Button("Move to Hiders") {
                        Task { await movePlayerToTeam(player.uid, team: .hiders) }
                    }
                    Button("Move to Seekers") {
                        Task { await movePlayerToTeam(player.uid, team: .seekers) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Action Buttons
    
    private func actionButtonsSection(lobby: Lobby) -> some View {
        VStack(spacing: 16) {
            // Ready/Unready button
            if let currentUID = currentUser?.uid,
               let currentPlayer = lobby.players[currentUID] {
                Button(action: {
                    Task { await toggleReady() }
                }) {
                    HStack {
                        Image(systemName: currentPlayer.isReady ? "checkmark.circle.fill" : "circle")
                        Text(currentPlayer.isReady ? "Ready!" : "Mark as Ready")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(currentPlayer.isReady ? .green : .blue)
            }
            
            // Start game button (host only)
            if isHost {
                Button(action: {
                    Task { await startGame() }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Game")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(!canStartGame)
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleGameStart() {
        // Check if game has started (lobby has gameId and is inactive)
        guard let currentLobby = lobby,
              let lobbyGameId = currentLobby.gameId,
              !currentLobby.isActive,
              !navigateToGame else {
            return
        }
        
        // Show loading state for non-host players
        if !isHost {
            isGameStarting = true
        }
        
        gameId = lobbyGameId
        navigateToGame = true
    }
    
    private func startListening() {
        databaseManager.startListeningToLobby(code: lobbyCode)
    }
    
    private func stopListening() {
        databaseManager.stopListeningToLobby(code: lobbyCode)
    }
    
    private func leaveLobby() async {
        guard let currentUID = currentUser?.uid else { return }
        
        isLoading = true
        do {
            try await databaseManager.leaveLobby(code: lobbyCode, playerUID: currentUID)
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
    
    private func toggleReady() async {
        guard let currentUID = currentUser?.uid else { return }
        
        do {
            try await databaseManager.togglePlayerReady(code: lobbyCode, playerUID: currentUID)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func moveToTeam(_ team: Team) async {
        guard let currentUID = currentUser?.uid else { return }
        
        do {
            try await databaseManager.switchPlayerTeam(code: lobbyCode, playerUID: currentUID, team: team)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func movePlayerToTeam(_ playerUID: String, team: Team) async {
        do {
            try await databaseManager.switchPlayerTeam(code: lobbyCode, playerUID: playerUID, team: team)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func startGame() async {
        guard lobby != nil else { return }
        
        isLoading = true
        do {
            // Start the game - this will update the lobby's gameId and isActive status
            // All players monitoring the lobby will automatically navigate to the game
            let _ = try await databaseManager.startGameFromLobby(lobbyCode: lobbyCode)
            
            await MainActor.run {
                isLoading = false
                // Don't navigate here - let the onChange handler do it
                // This ensures all players (including host) follow the same path
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
    LobbyView(lobbyCode: "ABC123", isHost: true)
        .environmentObject(AuthenticationManager.shared)
}
