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
    @StateObject private var mapSearchViewModel = MapSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var cancellables = Set<AnyCancellable>()
    @State private var region = MKCoordinateRegion()
    @State private var showingChat = false
    @State private var showingQuestionView = false
    @State private var showingSettings = false
    @State private var showingSkipConfirmation = false
    @State private var showingFoundConfirmation = false
    @State private var showingTimerActions = false
    @State private var timerUpdater: Timer?
    
    @State private var showingSearch = false
    
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
                    hidableRegions: hidableRegions,
                    searchResults: mapSearchViewModel.results,
                    selectedSearchItem: mapSearchViewModel.selectedItem
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
                VStack(spacing: 12) {
                    VStack {
                        HStack {
                            Button(action: { showingSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            timerUI
                            
                            Spacer()
                        }
                        
                        // Search bar (when visible)
                        if showingSearch {
                            searchBarView
                        }
                        
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 12) {
                            // Timer Actions Button (only show when timer is running)
                            if gameState == .hiding || gameState == .seeking {
                                Button(action: { showingTimerActions = true }) {
                                    ZStack {
                                        Circle()
                                            .fill((gameState == .hiding ? Color.blue : Color.red).opacity(0.9))
                                            .frame(width: 56, height: 56)
                                        
                                        Image(systemName: "timer")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                    }
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
                            
                            // Search button
                            Button(action: { 
                                if showingSearch {
                                    mapSearchViewModel.clearSearch()
                                    showingSearch = false
                                } else {
                                    showingSearch = true
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.purple.opacity(0.7))
                                        .frame(width: 56, height: 56)
                                    
                                    Image(systemName: showingSearch ? "xmark.circle.fill" : "magnifyingglass")
                                        .font(.title2)
                                        .foregroundColor(.white)
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
                        .padding(.trailing, 20)
                        .padding(.bottom, 40)
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
                        playerTeam: playerTeam,
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
                .sheet(isPresented: $showingTimerActions) {
                    TimerActionsView(
                        gameState: gameState,
                        onPause: {
                            if gameState == .hiding {
                                pauseHidingPhase()
                            } else if gameState == .seeking {
                                pauseSeekingPhase()
                            }
                            showingTimerActions = false
                        },
                        onSkip: {
                            showingTimerActions = false
                            showingSkipConfirmation = true
                        },
                        onFound: {
                            showingTimerActions = false
                            showingFoundConfirmation = true
                        }
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
    }
    

    
    private func setupMapRegion() {
        let newRegion: MKCoordinateRegion
        switch gameCity {
        case .boston:
            newRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589),
                latitudinalMeters: 10000,
                longitudinalMeters: 10000
            )
        case .newYork:
            newRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                latitudinalMeters: 15000,
                longitudinalMeters: 15000
            )
        }
        
        region = newRegion
        mapSearchViewModel.region = newRegion
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
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Color.black.opacity(0.7))
                .clipShape(Capsule())
                
        case .preHiding:
            Button("Start Hiding Timer") {
                startHidingPhase()
            }
            .font(.headline)
            .frame(height: 40)
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            
        case .hiding:
            // Compact circular progress
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 6)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .trim(from: 0, to: hidingProgress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-90))
                }
                
                Text(formatTime(hidingTimeRemaining))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color.black.opacity(0.7))
            .clipShape(Capsule())
            
        case .hidingPaused:
            HStack(spacing: 8) {
                Image(systemName: "pause.fill")
                    .foregroundColor(.orange)
                    .font(.caption2)
                
                Text(formatTime(hidingTimeRemaining))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color.black.opacity(0.7))
            .clipShape(Capsule())
            
            Button("Resume") {
                resumeHidingPhase()
            }
            .font(.headline)
            .frame(height: 40)
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            
        case .preSeeking:
            Button("Start Seeking Timer") {
                startSeekingPhase()
            }
            .font(.headline)
            .frame(height: 40)
            .buttonStyle(.borderedProminent)
            .tint(.red)
            
        case .seeking:
            Text("Seeking: " + formatTime(currentSeekingTime))
                .font(.system(.title3, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Color.black.opacity(0.7))
                .clipShape(Capsule())
            
        case .seekingPaused:
            HStack(spacing: 8) {
                Image(systemName: "pause.fill")
                    .foregroundColor(.orange)
                    .font(.caption2)
                
                Text(formatTime(currentSeekingTime))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color.black.opacity(0.7))
            .clipShape(Capsule())
            
            Button("Resume") {
                resumeSeekingPhase()
            }
            .font(.headline)
            .frame(height: 40)
            .buttonStyle(.borderedProminent)
            .tint(.red)
            
        case .completed:
            Text("Complete")
                .font(.title3)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Color.green.opacity(0.8))
                .clipShape(Capsule())
                
        case .cancelled:
            Text("Cancelled")
                .font(.title3)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Color.red.opacity(0.8))
                .clipShape(Capsule())
        }
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

// MARK: - Search Bar View
extension GameView {
    private var searchBarView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.leading, 12)
                
                TextField("Search for places...", text: $mapSearchViewModel.query)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .submitLabel(.search)
                    .onSubmit {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        mapSearchViewModel.search()
                    }
                
                if !mapSearchViewModel.query.isEmpty {
                    Button(action: { mapSearchViewModel.clearSearch() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.trailing, 8)
                }
                
                Button(action: {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    mapSearchViewModel.search()
                }) {
                    if mapSearchViewModel.isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Search")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
                .disabled(mapSearchViewModel.query.isEmpty || mapSearchViewModel.isSearching)
                .padding(.trailing, 12)
            }
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
            
            // Search results list (if any)
            if !mapSearchViewModel.results.isEmpty {
                searchResultsList
            }
            
            // Error message
            if let error = mapSearchViewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
            }
        }
    }
    
    private var searchResultsList: some View {
        ScrollView {
            Spacer()
                .frame(height: 4)
            
            VStack(spacing: 8) {
                ForEach(mapSearchViewModel.results, id: \.self) { item in
                    Button(action: {
                        mapSearchViewModel.selectItem(item)
                        // Region will automatically update via the observer
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "Unknown")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                if let address = formatAddress(item.placemark) {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            
                            Spacer()
                            
                            if mapSearchViewModel.selectedItem == item {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(12)
                        .background(
                            mapSearchViewModel.selectedItem == item ?
                            Color.blue.opacity(0.3) :
                                Color.black.opacity(0.7)
                        )
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            Spacer()
                .frame(height: 4)
        }
        .frame(maxHeight: 200)
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
    }
    
    // MARK: - Search Methods
    
    private func formatAddress(_ placemark: MKPlacemark) -> String? {
        var components: [String] = []
        
        if let street = placemark.thoroughfare {
            components.append(street)
        }
        if let city = placemark.locality {
            components.append(city)
        }
        if let state = placemark.administrativeArea {
            components.append(state)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}

struct GameSettingsView: View {
    let gameId: String
    let lobbyCode: String
    let playerTeam: Team
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

struct TimerActionsView: View {
    let gameState: GameState
    let onPause: () -> Void
    let onSkip: () -> Void
    let onFound: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Timer Actions")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    if gameState == .hiding || gameState == .seeking {
                        Button(action: onPause) {
                            Label("Pause Timer", systemImage: "pause.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .controlSize(.large)
                    }
                    
                    if gameState == .hiding {
                        Button(action: onSkip) {
                            Label("Skip Hiding Phase", systemImage: "forward.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.large)
                    }
                    
                    if gameState == .seeking {
                        Button(action: onFound) {
                            Label("All Hiders Found", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                        .controlSize(.large)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(300), .medium])
        .presentationDragIndicator(.visible)
    }
}
