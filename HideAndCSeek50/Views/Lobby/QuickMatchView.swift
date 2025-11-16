//
//  QuickMatchView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import SwiftUI
import FirebaseAuth

struct QuickMatchView: View {
    let onLobbyJoined: (String) -> Void
    
    @StateObject private var databaseManager = DatabaseManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedLobby: Lobby?
    
    private var currentUser: User? {
        Auth.auth().currentUser
    }
    
    private var displayName: String {
        currentUser?.displayName ?? "Anonymous Player"
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
                
                if databaseManager.publicLobbies.isEmpty && !isLoading {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(databaseManager.publicLobbies, id: \.code) { lobby in
                                lobbyCard(lobby: lobby)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    .refreshable {
                        // Refresh handled automatically by the listener
                    }
                }
                
                // Loading overlay
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("Quick Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await refreshLobbies()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                startListening()
            }
            .onDisappear {
                stopListening()
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
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Public Games")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("There are no public lobbies available right now. Create your own or check back later!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task {
                    await refreshLobbies()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Lobby Card
    
    private func lobbyCard(lobby: Lobby) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lobby.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Code: \(lobby.code)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fontDesign(.monospaced)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(lobby.totalPlayers)/\(lobby.maxPlayers)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("players")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Teams breakdown
            HStack(spacing: 20) {
                teamIndicator(
                    title: "Hiders",
                    count: lobby.hidersCount,
                    maxCount: lobby.maxHiders,
                    color: .blue
                )
                
                teamIndicator(
                    title: "Seekers",
                    count: lobby.seekersCount,
                    maxCount: lobby.maxSeekers,
                    color: .red
                )
            }
            
            // Join button
            Button(action: {
                Task {
                    await joinLobby(lobby)
                }
            }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Join Game")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(!lobby.canJoin || isLoading)
        }
        .padding(20)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private func teamIndicator(title: String, count: Int, maxCount: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(count)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                
                Text("/\(maxCount)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Actions
    
    private func startListening() {
        databaseManager.startListeningToPublicLobbies()
    }
    
    private func stopListening() {
        databaseManager.stopListeningToPublicLobbies()
    }
    
    private func refreshLobbies() async {
        isLoading = true
        
        // Add a small delay for user feedback
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        do {
            let lobbies = try await databaseManager.getPublicLobbies()
            await MainActor.run {
                // The listener will update the UI automatically
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func joinLobby(_ lobby: Lobby) async {
        guard let currentUID = currentUser?.uid else {
            errorMessage = "Please sign in to join a lobby"
            return
        }
        
        isLoading = true
        
        do {
            let joinedLobby = try await databaseManager.joinLobby(
                code: lobby.code,
                playerUID: currentUID,
                displayName: displayName
            )
            
            await MainActor.run {
                onLobbyJoined(lobby.code)
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
    QuickMatchView { _ in }
}
