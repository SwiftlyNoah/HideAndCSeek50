//
//  GameView.swift
//  HideAndCSeek50
//
//  Created by Assistant on 11/17/25.
//

import SwiftUI
import MapKit
import CoreLocation
import FirebaseAuth

struct GameView: View {
    let gameId: String
    let lobbyCode: String
    let playerTeam: Team
    
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var databaseManager = DatabaseManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var region = MKCoordinateRegion()
    @State private var playerLocations: [String: CLLocation] = [:]
    @State private var showingChat = false
    @State private var showingSettings = false
    @State private var gameState: GameState = .inProgress
    @State private var timeRemaining: TimeInterval = 0
    @State private var gameCity: GameCity = .boston
    
    private var currentUser: User? {
        Auth.auth().currentUser
    }
    
    private var hidableRegions: [MKPolygon] {
        switch gameCity {
        case .boston:
            return BostonRegions.hidableAreas
        case .newYork:
            return NewYorkRegions.hidableAreas
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Map View
                GameMapView(
                    region: $region,
                    playerLocations: playerLocations,
                    currentUserTeam: playerTeam,
                    hidableRegions: hidableRegions,
                    showAllPlayers: playerTeam == .seekers
                )
                .onAppear {
                    setupMapRegion()
                    requestLocationPermission()
                    startLocationUpdates()
                    loadGameData()
                }
                .onChange(of: locationManager.location) { location in
                    updatePlayerLocation(location)
                }
                
                // Overlay UI
                VStack {
                    // Top HUD
                    GameHUDView(
                        timeRemaining: timeRemaining,
                        playerTeam: playerTeam,
                        gameState: gameState,
                        onSettingsPressed: { showingSettings = true }
                    )
                    
                    Spacer()
                    
                    // Bottom Controls
                    HStack {
                        Spacer()
                        
                        // Chat Button
                        Button(action: { showingChat = true }) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.7))
                                    .frame(width: 56, height: 56)
                                
                                Image(systemName: "message.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingChat) {
                NavigationStack {
                    GameChatView(
                        gameId: gameId,
                        currentUser: currentUser,
                        currentPlayerTeam: playerTeam
                    )
                    .navigationTitle("Game Chat")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingChat = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingSettings) {
                GameSettingsView(
                    gameId: gameId,
                    onLeaveGame: {
                        dismiss()
                    }
                )
            }
        }
    }
    
    private func setupMapRegion() {
        switch gameCity {
        case .boston:
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589),
                latitudinalMeters: 10000,
                longitudinalMeters: 10000
            )
        case .newYork:
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                latitudinalMeters: 15000,
                longitudinalMeters: 15000
            )
        }
    }
    
    private func requestLocationPermission() {
        locationManager.requestLocationPermission()
    }
    
    private func startLocationUpdates() {
        locationManager.startLocationUpdates()
    }
    
    private func updatePlayerLocation(_ location: CLLocation?) {
        guard let location = location,
              let currentUID = currentUser?.uid else { return }
        
        // Update local state
        playerLocations[currentUID] = location
        
        // Update database
        Task {
            try? await databaseManager.updatePlayerLocation(
                gameId: gameId,
                playerUID: currentUID,
                location: location
            )
        }
    }
    
    private func loadGameData() {
        Task {
            do {
                let gameInfo = try await databaseManager.getGameInfo(gameId: gameId)
                await MainActor.run {
                    gameState = gameInfo.state
                    gameCity = gameInfo.settings.city
                    setupMapRegion()
                }
                
                // Start observing game updates
                observeGameUpdates()
                observePlayerLocations()
            } catch {
                // Handle error
            }
        }
    }
    
    private func observeGameUpdates() {
        // Set up real-time game state listener
        databaseManager.observeGame(gameId: gameId) { gameInfo in
            DispatchQueue.main.async {
                self.gameState = gameInfo.state
                // Calculate time remaining based on game start time and hiding time
                if let startTime = gameInfo.startedAt {
                    let elapsed = Date().timeIntervalSince(startTime)
                    self.timeRemaining = max(0, TimeInterval(gameInfo.settings.hidingTime * 60) - elapsed)
                }
            }
        }
    }
    
    private func observePlayerLocations() {
        // Set up real-time player location listener
        databaseManager.observePlayerLocations(gameId: gameId) { locations in
            DispatchQueue.main.async {
                self.playerLocations = locations
            }
        }
    }
}

struct GameHUDView: View {
    let timeRemaining: TimeInterval
    let playerTeam: Team
    let gameState: GameState
    let onSettingsPressed: () -> Void
    
    private var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        HStack {
            // Settings Button
            Button(action: onSettingsPressed) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Game Status
            VStack(spacing: 4) {
                Text(playerTeam.displayName)
                    .font(.headline)
                    .foregroundColor(playerTeam == .hiders ? .blue : .red)
                
                if gameState == .inProgress {
                    Text(timeString)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            // Team indicator
            Circle()
                .fill(playerTeam == .hiders ? Color.blue : Color.red)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: playerTeam == .hiders ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
}

struct GameSettingsView: View {
    let gameId: String
    let onLeaveGame: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Leave Game", role: .destructive) {
                        onLeaveGame()
                        dismiss()
                    }
                }
                
                Section("Game Info") {
                    Text("Game ID: \(gameId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
}