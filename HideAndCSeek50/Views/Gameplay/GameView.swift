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
    let onReturnToMain: (() -> Void)?
    
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var databaseManager = DatabaseManager.shared
    @StateObject private var chatViewModel = ChatViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var cancellables = Set<AnyCancellable>()
    @State private var region = MKCoordinateRegion()
    @State private var showingChat = false
    @State private var showingQuestionView = false
    @State private var showingSettings = false
    @State private var showingSkipConfirmation = false
    @State private var showingFoundConfirmation = false
    @State private var timerUpdater: Timer?
    
    // Local timer state for smooth UI updates
    @State private var localCurrentTime = Date()
    
    private var currentUser: User? {
        authManager.currentUser
    }
    
    private var currentGame: Game? {
        databaseManager.currentGame
    }
    
    private var gameState: GameState {
        currentGame?.info.state ?? .waiting
    }
    
    private var gameCity: GameCity {
        currentGame?.info.settings.city ?? .boston
    }
    

    
    private let hidableRegions = MassachusettsRegions.hidableAreas
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen Map View
                GameMapView(
                    region: $region,
                    game: currentGame,
                    currentUserUID: currentUser?.uid ?? "",
                    currentUserTeam: playerTeam,
                    hidableRegions: hidableRegions
                )
                .ignoresSafeArea(.all) // Make map take up entire screen
                .onAppear {
                    localCurrentTime = Date()
                    setupMapRegion()
                    requestLocationPermission()
                    startLocationUpdates()
                    
                    observeGameUpdates()
                    
                    chatViewModel.startMonitoring(gameId: gameId)
                    
                    // Upload initial location for simulators
                    uploadInitialLocation()
                    
                    // Start timer for UI updates and auto-transitions
                    startTimerUpdater()
                }
                .onDisappear {
                    stopTimerUpdater()
                }
                .onChange(of: locationManager.location) { _, location in
                    updatePlayerLocation(location)
                }
                
                // Minimal overlay controls
                VStack {
                    // Top integrated timer UI
                    VStack(spacing: 12) {
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
                        
                        // Integrated Timer UI based on game state
                        timerUI
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 12) {
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
                    lobbyCode: lobbyCode,
                    onLeaveGame: {
                        dismiss()
                        onReturnToMain?() // Call the callback to return to main
                    }
                )
            }
            .sheet(isPresented: $showingQuestionView) {
                GameQuestionView(
                    gameId: gameId,
                    currentUser: currentUser
                )
            }
            .confirmationDialog("Skip Hiding Phase", isPresented: $showingSkipConfirmation, titleVisibility: .visible) {
                Button("Skip", role: .destructive) {
                    skipHidingPhase()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("End hiding phase immediately and move to seeking?")
            }
            .confirmationDialog("All Hiders Found", isPresented: $showingFoundConfirmation, titleVisibility: .visible) {
                Button("End Game", role: .destructive) {
                    endGame()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Mark all hiders as found and end the game?")
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
        
        // Update database
        Task {
            let playerLocation = PlayerLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timestamp: Date()
            )
            try? await databaseManager.updatePlayerLocation(
                gameId: gameId,
                playerUID: currentUID,
                team: playerTeam,
                location: playerLocation
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
    

    private func observeGameUpdates() {
        databaseManager.startListeningToGame(gameId: gameId)
        
        // Listen to changes in currentGame - this handles all game data
        // including messages, questions, player locations, etc.
        databaseManager.$currentGame
            .sink { game in
                // All UI components will automatically update when currentGame changes
                // GameMapView gets the updated game data
                // Chat and other views can access game.messages
                // Questions can be accessed via game.questions
                
                // Refresh local timer whenever we get database updates
                localCurrentTime = Date()
                
                // Auto-transition from starting to preHiding for the host
                if let game = game,
                   game.info.state == .starting,
                   game.info.hostUID == currentUser?.uid {
                    Task {
                        try? await databaseManager.updateGameState(gameId: gameId, state: .preHiding)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Timer UI
    
    @ViewBuilder
    private var timerUI: some View {
        switch gameState {
        case .waiting, .starting:
            Text(gameState.displayName)
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.7))
                .clipShape(Capsule())
                
        case .preHiding:
            VStack(spacing: 8) {
                Text("Ready to Hide")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Button("Start Hiding Timer") {
                    startHidingPhase()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
        case .hiding:
            hidingTimerUI
            
        case .hidingPaused:
            pausedHidingTimerUI
            
        case .preSeeking:
            VStack(spacing: 8) {
                Text("Ready to Seek")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Button("Start Seeking Timer") {
                    startSeekingPhase()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
        case .seeking:
            seekingTimerUI
            
        case .seekingPaused:
            pausedSeekingTimerUI
            
        case .completed:
            Text("Game Complete")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.green.opacity(0.8))
                .clipShape(Capsule())
                
        case .cancelled:
            Text("Game Cancelled")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.red.opacity(0.8))
                .clipShape(Capsule())
        }
    }
    
    private var hidingTimerUI: some View {
        VStack(spacing: 8) {
            // Blue circular progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: hidingProgress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Text(formatTime(hidingTimeRemaining))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 12) {
                Button("Pause") {
                    pauseHidingPhase()
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                
                Button("Skip") {
                    showingSkipConfirmation = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var pausedHidingTimerUI: some View {
        VStack(spacing: 8) {
            Text("Hiding Paused")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(formatTime(hidingTimeRemaining))
                .font(.system(.title, design: .monospaced))
                .foregroundColor(.blue)
            
            HStack(spacing: 12) {
                Button("Resume") {
                    resumeHidingPhase()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                
                Button("Skip") {
                    showingSkipConfirmation = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var seekingTimerUI: some View {
        VStack(spacing: 8) {
            Text("Seeking")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(formatTime(currentSeekingTime))
                .font(.system(.title, design: .monospaced))
                .foregroundColor(.red)
            
            HStack(spacing: 12) {
                Button("Pause") {
                    pauseSeekingPhase()
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                
                Button("Found") {
                    showingFoundConfirmation = true
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var pausedSeekingTimerUI: some View {
        VStack(spacing: 8) {
            Text("Seeking Paused")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(formatTime(currentSeekingTime))
                .font(.system(.title, design: .monospaced))
                .foregroundColor(.red)
            
            HStack(spacing: 12) {
                Button("Resume") {
                    resumeSeekingPhase()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                Button("Found") {
                    showingFoundConfirmation = true
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Timer Computed Properties
    
    private var hidingProgress: Double {
        guard let game = currentGame else { return 0 }
        let totalTime = TimeInterval(game.info.settings.hidingTime * 60)
        return totalTime > 0 ? min(1.0, currentLocalHidingTime / totalTime) : 0
    }
    
    private var hidingTimeRemaining: TimeInterval {
        guard let game = currentGame else { return 0 }
        let totalTime = TimeInterval(game.info.settings.hidingTime * 60)
        return max(0, totalTime - currentLocalHidingTime)
    }
    
    private var currentSeekingTime: TimeInterval {
        return currentLocalSeekingTime
    }
    
    // Local time calculations based on device timer
    private var currentLocalHidingTime: TimeInterval {
        guard let game = currentGame else { return 0 }
        
        switch game.info.state {
        case .hiding:
            // Timer is running: elapsed time + time since started
            if let startedAt = game.info.hidingStartedAt {
                return game.info.hidingElapsed + localCurrentTime.timeIntervalSince(startedAt)
            }
            return game.info.hidingElapsed
        default:
            // Timer is not running: just return elapsed time
            return game.info.hidingElapsed
        }
    }
    
    private var currentLocalSeekingTime: TimeInterval {
        guard let game = currentGame else { return 0 }
        
        switch game.info.state {
        case .seeking:
            // Timer is running: elapsed time + time since started
            if let startedAt = game.info.seekingStartedAt {
                return game.info.seekingElapsed + localCurrentTime.timeIntervalSince(startedAt)
            }
            return game.info.seekingElapsed
        default:
            // Timer is not running: just return elapsed time
            return game.info.seekingElapsed
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Timer Actions
    
    private func startHidingPhase() {
        Task {
            try? await databaseManager.updateGameState(
                gameId: gameId, 
                state: .hiding, 
                hidingStartedAt: Date(),
                hidingElapsed: 0 // Reset elapsed time when starting fresh
            )
        }
    }
    
    private func pauseHidingPhase() {
        Task {
            guard let game = currentGame else { return }
            let totalElapsed = currentLocalHidingTime
            try? await databaseManager.updateGameState(
                gameId: gameId, 
                state: .hidingPaused, 
                hidingElapsed: totalElapsed
            )
        }
    }
    
    private func resumeHidingPhase() {
        Task {
            guard let game = currentGame else { return }
            // Keep the current elapsed time, just set new start time
            try? await databaseManager.updateGameState(
                gameId: gameId, 
                state: .hiding, 
                hidingStartedAt: Date()
            )
        }
    }
    
    private func skipHidingPhase() {
        Task {
            try? await databaseManager.updateGameState(gameId: gameId, state: .preSeeking)
        }
    }
    
    private func startSeekingPhase() {
        Task {
            try? await databaseManager.updateGameState(
                gameId: gameId, 
                state: .seeking, 
                seekingStartedAt: Date(),
                seekingElapsed: 0 // Reset elapsed time when starting fresh
            )
        }
    }
    
    private func pauseSeekingPhase() {
        Task {
            guard let game = currentGame else { return }
            let totalElapsed = currentLocalSeekingTime
            try? await databaseManager.updateGameState(
                gameId: gameId, 
                state: .seekingPaused, 
                seekingElapsed: totalElapsed
            )
        }
    }
    
    private func resumeSeekingPhase() {
        Task {
            guard let game = currentGame else { return }
            // Keep the current elapsed time, just set new start time
            try? await databaseManager.updateGameState(
                gameId: gameId, 
                state: .seeking, 
                seekingStartedAt: Date()
            )
        }
    }
    
    private func endGame() {
        Task {
            try? await databaseManager.endGame(gameId: gameId, winner: .seekers)
        }
    }
    
    // MARK: - Timer Management
    
    private func startTimerUpdater() {
        timerUpdater = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            localCurrentTime = Date()
            checkForAutoTransitions()
        }
    }
    
    private func stopTimerUpdater() {
        timerUpdater?.invalidate()
        timerUpdater = nil
    }
    
    private func checkForAutoTransitions() {
        guard let game = currentGame else { return }
        
        // Auto-transition from hiding to preSeeking when hiding time is complete
        if game.info.state == .hiding {
            let totalHidingTime = TimeInterval(game.info.settings.hidingTime * 60)
            if currentLocalHidingTime >= totalHidingTime {
                Task {
                    try? await databaseManager.updateGameState(gameId: gameId, state: .preSeeking)
                }
            }
        }
    }
}

struct GameSettingsView: View {
    let gameId: String
    let lobbyCode: String
    let onLeaveGame: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var databaseManager = DatabaseManager.shared
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
                try await databaseManager.leaveGame(
                    gameId: gameId, 
                    playerUID: currentUser.uid,
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
