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
    @StateObject private var authManager = AuthenticationManager.shared
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
                        
                        // Recent Games Section
                        recentGamesSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                // Loading Overlay
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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
                
                ActionButton(
                    title: "Practice",
                    subtitle: "Solo training mode",
                    icon: "target",
                    color: .purple,
                    isPrimary: false
                ) {
                    // Handle practice mode
                }
            }
        }
    }
    
    // MARK: - Recent Games
    
    private var recentGamesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("View All") {
                    // Handle view all
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            // Placeholder for recent games
            VStack(spacing: 12) {
                recentGameItem(
                    name: "Campus Hide & Seek",
                    result: "Won as Hider",
                    timeAgo: "2 hours ago",
                    players: 6,
                    duration: "15:23"
                )
                
                recentGameItem(
                    name: "Park Adventure",
                    result: "Lost as Seeker",
                    timeAgo: "1 day ago",
                    players: 8,
                    duration: "22:45"
                )
            }
        }
        .padding(.horizontal, 4)
    }
    
    private func recentGameItem(name: String, result: String, timeAgo: String, players: Int, duration: String) -> some View {
        HStack(spacing: 12) {
            // Game Icon
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [.blue.opacity(0.8), .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "map")
                        .font(.title3)
                        .foregroundColor(.white)
                )
            
            // Game Details
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(result)
                    .font(.caption)
                    .foregroundColor(result.contains("Won") ? .green : .orange)
                
                Text("\(players) players • \(duration)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(timeAgo)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
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
}

struct LobbyDestination: Identifiable {
    let code: String
    
    var id: String { code }
}

#Preview {
    MainView(user: nil)
}
