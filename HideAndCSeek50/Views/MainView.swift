//
//  MainView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct MainView: View {
    let user: User?
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var databaseManager = DatabaseManager.shared
    @State private var showingSignOut = false
    @State private var showingCreateGame = false
    @State private var showingJoinGame = false
    @State private var showingQuickMatch = false
    @State private var showingProfile = false
    @State private var activeLobbyCode: String?
    @State private var isLobbyHost = false
    @State private var isLoading = false
    
    // MARK: - Helper Properties
    
    private var lobbyDestination: Binding<LobbyDestination?> {
        Binding(
            get: { activeLobbyCode.map(LobbyDestination.init) },
            set: { activeLobbyCode = $0?.code }
        )
    }
    
    // Will present the GameView once set
    @State private var rejoinGameDestination: RejoinGameDestination?
    
    @State private var rejoinGameData: (game: Game, lobbyCode: String, playerTeam: Team)?
    @State private var showingRejoinGame = false
    @State private var isCheckingForRejoin = true
    
    private var displayName: String {
        if let displayName = user?.displayName, !displayName.isEmpty {
            return displayName
        } else if let email = user?.email {
            return String(email.prefix(while: { $0 != "@" })).capitalized
        } else {
            return "Guest"
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
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
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        headerSection
                        
                        // Main Action Buttons
                        actionButtons
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                // Loading Overlay
                if isLoading || isCheckingForRejoin {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        if isCheckingForRejoin {
                            Text("Checking for previous game...")
                                .foregroundColor(.white)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if isCheckingForRejoin {
                    checkForRejoinableGame()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingProfile = true }) {
                        profileButton
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Settings") {
                            // Handle settings
                        }
                        
                        Button("Help") {
                            // Handle help
                        }
                        
                        Divider()
                        
                        Button("Sign Out", role: .destructive) {
                            showingSignOut = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateGame) {
            CreateLobbyView { lobbyCode in
                showingCreateGame = false
                activeLobbyCode = lobbyCode
                isLobbyHost = true
            }
        }
        .sheet(isPresented: $showingJoinGame) {
            JoinLobbyView { lobbyCode in
                showingJoinGame = false
                activeLobbyCode = lobbyCode
                isLobbyHost = false
            }
        }
        .sheet(isPresented: $showingQuickMatch) {
            QuickMatchView { lobbyCode in
                showingQuickMatch = false
                activeLobbyCode = lobbyCode
                isLobbyHost = false
            }
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView(user: user, stats: nil)
        }
        .fullScreenCover(item: lobbyDestination) { destination in
            LobbyView(lobbyCode: destination.code, isHost: isLobbyHost)
        }
        .fullScreenCover(item: $rejoinGameDestination) { destination in
            GameView(
                gameId: destination.gameData.game.info.gameId,
                lobbyCode: destination.gameData.lobbyCode,
                playerTeam: destination.gameData.playerTeam,
                onReturnToMain: {
                    rejoinGameData = nil
                }
            )
        }
        .confirmationDialog("Rejoin Game?", isPresented: $showingRejoinGame, titleVisibility: .visible) {
            Button("Rejoin") {
                showingRejoinGame = false
                rejoinGameDestination = rejoinGameData.map(RejoinGameDestination.init)
            }
            
            Button("No thanks", role: .destructive) {
                // Clear the rejoin data and stay on main menu
                showingRejoinGame = false
                databaseManager.clearGamePersistence()
                rejoinGameData = nil
            }
        } message: {
            if let gameData = rejoinGameData {
                Text("You were in a game as a \(gameData.playerTeam.playerName). The game state is \(gameData.game.info.state.displayName). Would you like to rejoin?")
                    .frame(minWidth: 300)
            }
        }
        .confirmationDialog("Sign Out", isPresented: $showingSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                handleSignOut()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App Icon and Title
            HStack {
                Image(systemName: "map.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hide and CSeek50")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Ready to play?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Welcome Message
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back, \(displayName)!")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if user?.isAnonymous == true {
                        HStack(spacing: 6) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.caption)
                            Text("Guest Account")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                    }
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Primary Actions
            HStack(spacing: 16) {
                ActionButton(
                    title: "Create Game",
                    subtitle: "Start a new adventure",
                    icon: "plus.circle.fill",
                    color: .blue,
                    isPrimary: true
                ) {
                    showingCreateGame = true
                }
                
                ActionButton(
                    title: "Join Game",
                    subtitle: "Enter a game code",
                    icon: "arrow.right.circle.fill",
                    color: .green,
                    isPrimary: true
                ) {
                    showingJoinGame = true
                }
            }
            
            // Secondary Actions
            HStack(spacing: 16) {
                ActionButton(
                    title: "Quick Match",
                    subtitle: "Find active games",
                    icon: "bolt.circle.fill",
                    color: .orange,
                    isPrimary: false
                ) {
                    showingQuickMatch = true
                }
            }
        }
    }
    
    // MARK: - Profile Button
    
    private var profileButton: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(displayName.prefix(1)))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let email = user?.email {
                    Text(email)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
    
    // MARK: - Methods
    
    private func handleSignOut() {
        do {
            try authManager.signOut()
        } catch {
            print("Sign out error: \(error.localizedDescription)")
        }
    }
    
    private func checkForRejoinableGame() {
        
        Task {
            let gameData = await databaseManager.rejoinGame()
            isCheckingForRejoin = false
            await MainActor.run {
                if let gameData = gameData {
                    rejoinGameData = gameData
                    showingRejoinGame = true
                }
            }
        }
    }
}

struct LobbyDestination: Identifiable {
    let code: String
    
    var id: String { code }
}

struct RejoinGameDestination: Identifiable {
    let gameData: (game: Game, lobbyCode: String, playerTeam: Team)
    
    var id: String { gameData.game.info.gameId }
}

#Preview {
    MainView(user: nil)
        .environmentObject(AuthenticationManager.shared)
}
