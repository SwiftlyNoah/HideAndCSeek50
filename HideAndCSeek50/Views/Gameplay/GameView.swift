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
internal import Combine

struct GameView: View {
    let gameId: String
    let lobbyCode: String
    let playerTeam: Team
    
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var databaseManager = DatabaseManager.shared
    @StateObject private var chatViewModel = ChatViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var cancellables = Set<AnyCancellable>()
    @State private var region = MKCoordinateRegion()
    @State private var playerLocations: [String: CLLocation] = [:]
    @State private var playerTeams: [String: Team] = [:] // Add player team tracking
    @State private var playerNames: [String: String] = [:] // Add player names tracking
    @State private var showingChat = false
    @State private var showingQuestionView = false
    @State private var showingSettings = false
    @State private var showingTimerView = false
    @State private var showingSeekingTimerView = false
    @State private var showingMapToolsView = false
    @State private var selectedRegions: Set<String> = []
    @State private var visibleRegions: Set<String> = [] // Track which regions are actually rendered
    @State private var regionColors: [String: Bool] = [:] // Track color per region (true = red, false = green)
    @State private var gameState: GameState = .inProgress
    @State private var timeRemaining: TimeInterval = 0
    @State private var gameCity: GameCity = .boston
    @State private var circleItems: [CircleOverlayItem] = []
    
    private var currentUser: User? {
        authManager.currentUser
    }
    
    private let hidableRegions = MassachusettsRegions.hidableAreas
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen Map View
                GameMapView(
                    region: $region,
                    playerLocations: playerLocations,
                    playerTeams: playerTeams,
                    playerNames: playerNames,
                    currentUserUID: currentUser?.uid ?? "",
                    currentUserTeam: playerTeam,
                    hidableRegions: hidableRegions,
                    circleItems: circleItems,
                    selectedRegions: visibleRegions, // Use visibleRegions instead of selectedRegions
                    regionColors: regionColors // Pass colors
                )
                .ignoresSafeArea(.all) // Make map take up entire screen
                .onAppear {
                    setupMapRegion()
                    requestLocationPermission()
                    startLocationUpdates()
                    loadGameData()
                    // Start monitoring chat messages
                    chatViewModel.startMonitoring(gameId: gameId)
                    
                    // Upload initial location for simulators
                    uploadInitialLocation()
                }
                .onChange(of: locationManager.location) { _, location in
                    updatePlayerLocation(location)
                }
                
                // Minimal overlay controls
                VStack {
                    // Top minimal HUD
                    HStack {
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // Timer and team indicator
                        VStack(spacing: 4) {
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
                            .fill(playerTeam.swiftUIColor)
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: playerTeam.iconName)
                                    .foregroundColor(.white)
                                    .font(.title3)
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 12) {
                            // Hiding Timer button
                            Button(action: { showingTimerView = true }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.purple.opacity(0.9))
                                        .frame(width: 56, height: 56)
                                    
                                    Image(systemName: "timer")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // Seeking timer button (new, both teams)
                            Button(action: { showingSeekingTimerView = true }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.9))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: "stopwatch")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // Map Tools button
                            Button(action: { showingMapToolsView = true }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.9))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: "map.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // Question button (for seekers only)
                            if playerTeam == .seekers {
                                Button(action: { showingQuestionView = true }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.orange.opacity(0.9))
                                            .frame(width: 56, height: 56)
                                        
                                        Image(systemName: "questionmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            
                            // Chat button
                            Button(action: { showingChat = true }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.8))
                                        .frame(width: 56, height: 56)
                                    
                                    Image(systemName: "message.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    // Unread message indicator
                                    if chatViewModel.hasUnreadMessages {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 16, height: 16)
                                            .offset(x: 20, y: -20)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 50)
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
                    .environmentObject(chatViewModel)
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
            .onChange(of: showingChat) { _, isShowing in
                chatViewModel.setViewVisibility(isShowing)
            }
            .sheet(isPresented: $showingSettings) {
                GameSettingsView(
                    gameId: gameId,
                    onLeaveGame: {
                        dismiss()
                    }
                )
            }
            .sheet(isPresented: $showingQuestionView) {
                GameQuestionView(
                    gameId: gameId,
                    currentUser: currentUser
                )
            }
            .sheet(isPresented: $showingTimerView) {
                NavigationStack {
                    HidingTimerView(
                        gameId: gameId,
                        playerTeam: playerTeam
                    )
                    .navigationTitle("Hiding Timer")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingTimerView = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingSeekingTimerView) {
                NavigationStack {
                    SeekingTimerView(
                        gameId: gameId,
                        playerTeam: playerTeam
                    )
                    .navigationTitle("Seeking Timer")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingSeekingTimerView = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingMapToolsView) {
                NavigationStack {
                    MapToolsView(
                        selectedRegions: $selectedRegions,
                        visibleRegions: $visibleRegions,
                        regionColors: $regionColors,
                        mapCenter: Binding(get: { region.center }, set: { region.center = $0 }),
                        circleItems: $circleItems
                    )
                        .navigationTitle("Map Tools")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showingMapToolsView = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
    
    private var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
    
    private func uploadInitialLocation() {
        // For simulators, try to upload current location immediately
        Task {
            // Wait a moment for location to be available
            try? await Task.sleep(for: .seconds(1))
            
            if let currentLocation = locationManager.location {
                updatePlayerLocation(currentLocation)
            } else {
                // Fallback: Use map center as initial location for simulators
                let fallbackLocation = CLLocation(
                    latitude: region.center.latitude,
                    longitude: region.center.longitude
                )
                updatePlayerLocation(fallbackLocation)
            }
        }
    }
    
    private func loadGameData() {
        Task {
            do {
                // Start listening to game updates
                databaseManager.startListeningToGame(gameId: gameId)
                
                let gameInfo = try await databaseManager.getGameInfo(gameId: gameId)
                await MainActor.run {
                    gameState = gameInfo.state
                    gameCity = gameInfo.settings.city
                    setupMapRegion()
                }
                
                // Load player teams from the current game
                if let currentGame = databaseManager.currentGame {
                    for (uid, member) in currentGame.teams.hiders.members {
                        playerTeams[uid] = .hiders
                        playerNames[uid] = member.displayName
                    }
                    for (uid, member) in currentGame.teams.seekers.members {
                        playerTeams[uid] = .seekers
                        playerNames[uid] = member.displayName
                    }
                }
                
                observePlayerLocations()
            } catch {
                print("Error loading game data: \(error)")
            }
        }
    }

    private func observeGameUpdates() {
        // Set up real-time game state listener
        databaseManager.startListeningToGame(gameId: gameId)
        
        // Listen to changes in currentGame to update player teams
        databaseManager.$currentGame
            .sink { game in
                guard let game = game else { return }
                
                DispatchQueue.main.async {
                    gameState = game.info.state
                    
                    // Update player teams and names
                    var updatedTeams: [String: Team] = [:]
                    var updatedNames: [String: String] = [:]
                    
                    for (uid, member) in game.teams.hiders.members {
                        updatedTeams[uid] = .hiders
                        updatedNames[uid] = member.displayName
                    }
                    for (uid, member) in game.teams.seekers.members {
                        updatedTeams[uid] = .seekers
                        updatedNames[uid] = member.displayName
                    }
                    
                    playerTeams = updatedTeams
                    playerNames = updatedNames
                    
                    // Calculate time remaining based on game start time and hiding time
                    if let startTime = game.info.startedAt {
                        let elapsed = Date().timeIntervalSince(startTime)
                        timeRemaining = max(0, TimeInterval(game.info.settings.hidingTime * 60) - elapsed)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func observePlayerLocations() {
        // Set up real-time player location listener
        databaseManager.observePlayerLocations(gameId: gameId) { locations in
            DispatchQueue.main.async {
                playerLocations = locations
            }
        }
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
