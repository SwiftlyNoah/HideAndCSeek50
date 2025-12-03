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
    @State private var showingRemovedAlert = false
    @State private var showingBannedAlert = false
    @State private var wasInLobby = false
    
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
            .onChange(of: lobby) { oldLobby, newLobby in
                // Set wasInLobby flag when lobby first loads and we're in it
                if !wasInLobby, let currentUID = currentUser?.uid, let newLobby = newLobby {
                    if newLobby.players[currentUID] != nil {
                        wasInLobby = true
                    }
                }
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
            .onChange(of: lobby?.players) { oldPlayers, newPlayers in
                // Check if current user was removed or banned
                checkIfRemovedOrBanned(oldPlayers: oldPlayers, newPlayers: newPlayers)
            }
            .onChange(of: lobby?.bannedUsers) { _, bannedUsers in
                // Check if current user was banned
                checkIfBanned(bannedUsers: bannedUsers)
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
                            playerTeam: currentPlayer.team,
                            city: lobby.city,
                            onReturnToMain: {
                                // Dismiss the lobby view to return to main
                                dismiss()
                            }
                        )
                    }
                    else {
                        Color.clear
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
            .alert("Removed from Lobby", isPresented: $showingRemovedAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("You have been removed from the lobby by the host.")
            }
            .alert("Banned from Lobby", isPresented: $showingBannedAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("You have been banned from this lobby by the host.")
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
                
                Text("Tap to copy")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .onTapGesture {
                UIPasteboard.general.string = lobbyCode
                // TODO: Add haptic feedback
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
            HStack {
                Text("Lobby Settings")
                    .font(.headline)
                
                Spacer()
                
                Button("Edit") {
                    showingSettings = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("City:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(lobby.city.displayName)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    Text("Hiding Time:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(lobby.hidingTime) minutes")
                        .fontWeight(.medium)
                }
            }
            .font(.subheadline)
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
                team: .hiders,
                players: lobby.players.values.filter { $0.team == .hiders }.sorted { $0.joinedAt < $1.joinedAt },
                maxPlayers: lobby.maxHiders,
                color: .blue,
                lobby: lobby
            )
            
            // Seekers Team
            teamCard(
                title: "Seekers",
                team: .seekers,
                players: lobby.players.values.filter { $0.team == .seekers }.sorted { $0.joinedAt < $1.joinedAt },
                maxPlayers: lobby.maxSeekers,
                color: .red,
                lobby: lobby
            )
        }
    }
    
    private func teamCard(title: String, team: Team, players: [LobbyPlayer], maxPlayers: Int, color: Color, lobby: Lobby) -> some View {
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
            if let currentUID = currentUser?.uid,
               let me = lobby.players[currentUID],
               me.team != team {
                let isTargetFull = players.count >= maxPlayers
                Button(action: {
                    Task { await moveToTeam(team) }
                }) {
                    HStack {
                        Text("Switch to \(team.displayName)")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .disabled(isTargetFull)
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
            
            // Menu for host (all players) or for current player (only themselves)
            if isHost || player.uid == currentUser?.uid {
                Menu {
                    if isHost && player.uid != currentUser?.uid {
                        // Host options for other players
                        Button {
                            Task {
                                let targetTeam: Team = player.team == .hiders ? .seekers : .hiders
                                await movePlayerToTeam(player.uid, team: targetTeam)
                            }
                        } label: {
                            Label(
                                player.team == .hiders ? "Move to Seekers" : "Move to Hiders",
                                systemImage: "arrow.left.arrow.right"
                            )
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            Task { await removePlayer(player.uid) }
                        } label: {
                            Label("Remove from Lobby", systemImage: "person.crop.circle.badge.minus")
                        }
                        
                        Button(role: .destructive) {
                            Task { await banPlayer(player.uid) }
                        } label: {
                            Label("Ban from Lobby", systemImage: "hand.raised.slash.fill")
                        }
                    } else {
                        // Current player's own menu
                        Button {
                            Task {
                                let targetTeam: Team = player.team == .hiders ? .seekers : .hiders
                                await moveToTeam(targetTeam)
                            }
                        } label: {
                            Label(
                                player.team == .hiders ? "Move to Seekers" : "Move to Hiders",
                                systemImage: "arrow.left.arrow.right"
                            )
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
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
    
    private func removePlayer(_ playerUID: String) async {
        do {
            try await databaseManager.removePlayerFromLobby(code: lobbyCode, playerUID: playerUID)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func banPlayer(_ playerUID: String) async {
        do {
            try await databaseManager.banPlayerFromLobby(code: lobbyCode, playerUID: playerUID)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Removal/Ban Detection
    
    private func checkIfRemovedOrBanned(oldPlayers: [String: LobbyPlayer]?, newPlayers: [String: LobbyPlayer]?) {
        guard let currentUID = currentUser?.uid else { return }
        
        // Only check if we were previously in the lobby
        guard wasInLobby else { return }
        
        // Check if we were in the old list but not in the new list
        let wasInOldList = oldPlayers?[currentUID] != nil
        let isInNewList = newPlayers?[currentUID] != nil
        
        if wasInOldList && !isInNewList {
            // We were removed - check if banned
            if let bannedUsers = lobby?.bannedUsers, bannedUsers.contains(currentUID) {
                showingBannedAlert = true
            } else {
                showingRemovedAlert = true
            }
            wasInLobby = false // Reset flag
        }
    }
    
    private func checkIfBanned(bannedUsers: [String]?) {
        guard let currentUID = currentUser?.uid,
              let bannedUsers = bannedUsers,
              wasInLobby else { return }
        
        // If current user is in the banned list
        if bannedUsers.contains(currentUID) {
            // Check if they're still in the players list (they shouldn't be, but just in case)
            if lobby?.players[currentUID] == nil {
                showingBannedAlert = true
                wasInLobby = false // Reset flag
            }
        }
    }
}

#Preview {
    LobbyView(lobbyCode: "ABC123", isHost: true)
        .environmentObject(AuthenticationManager.shared)
}
