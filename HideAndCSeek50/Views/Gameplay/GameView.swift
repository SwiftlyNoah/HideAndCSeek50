//
//  GameView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/17/25.
//

import SwiftUI
import MapKit
import CoreLocation
import FirebaseAuth
import BottomSheet
internal import Combine

struct GameView: View {
    static let CrosshairYOffsetFraction = 0.35
    
    let gameId: String
    let lobbyCode: String
    let playerTeam: Team
    let onReturnToMain: (() -> Void)?
    
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var databaseManager = DatabaseManager.shared
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var mapSearchViewModel = MapSearchViewModel()
    @StateObject private var mapToolsViewModel = MapToolsViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showingSearch = false
    @State private var showingChat = false
    @State private var showingQuestionView = false
    @State private var showingSettings = false
    @State private var showingSkipConfirmation = false
    @State private var showingFoundConfirmation = false
    @State private var showingTimerActions = false
    @State private var showingMapToolsView = false
    @State private var crosshairCoordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)

    @State private var didCenterOnUser = false
    @FocusState private var isSearchFieldFocused: Bool
    
    // Local timer state for smooth UI updates
    @State private var timerUpdater: Timer?
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
            mainContent
        }
    }

    // MARK: - Split main ZStack to reduce type-checking load
    private var mainContent: some View {
        ZStack {
            mapLayer
            topOverlays
            crosshairOverlay
            bottomActions
        }
        .navigationBarHidden(true)
        .modifier(searchResultsSheet())
        .modifier(transportSelectionSheet())
        .modifier(directionsSheet())
        .modifier(mapToolsSheet())
        .modifier(chatSheet())
        .onChange(of: showingChat) { _, isShowing in
            chatViewModel.setViewVisibility(isShowing)
        }
        .sheet(isPresented: $showingSettings) { settingsSheet }
        .sheet(isPresented: $showingQuestionView) { questionSheet }
        .sheet(isPresented: $showingTimerActions) { timerActionsSheet }
        .confirmationDialog("Skip Hiding Phase", isPresented: $showingSkipConfirmation, titleVisibility: .visible) {
            Button("Skip", role: .destructive) { skipHidingPhase() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("End hiding phase immediately and move to seeking?") }
        .confirmationDialog("All Hiders Found", isPresented: $showingFoundConfirmation, titleVisibility: .visible) {
            Button("End Game", role: .destructive) { endGame() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Mark all hiders as found and end the game?") }
    }

    // MARK: - Layers
    private var mapLayer: some View {
        GameMapView(
            region: $mapSearchViewModel.region,
            crosshairCoordinate: $crosshairCoordinate,
            crosshairYOffsetFraction: Self.CrosshairYOffsetFraction,
            game: currentGame,
            currentUserUID: currentUser?.uid ?? "",
            currentUserTeam: playerTeam,
            hidableRegions: hidableRegions,
            circleItems: mapToolsViewModel.circleItems,
            selectedRegions: mapToolsViewModel.visibleRegions,
            regionColors: mapToolsViewModel.regionColors,
            showTrainLines: mapToolsViewModel.showTrainLines,
            mapToolsViewModel: mapToolsViewModel,
            refreshToken: mapToolsViewModel.refreshToken,
            searchResults: mapSearchViewModel.results,
            selectedLandmark: mapSearchViewModel.selectedLandmark,
            route: mapSearchViewModel.route,
            onSearchAnnotationSelected: { mapItem in
                mapSearchViewModel.selectItem(mapItem)
                mapSearchViewModel.showTransportSelection(for: mapItem)
            }
        )
        .ignoresSafeArea(.all)
        .onAppear {
            localCurrentTime = Date()
            setupMapRegion()
            requestLocationPermission()
            startLocationUpdates()
            observeGameUpdates()
            chatViewModel.startMonitoring(gameId: gameId)
            uploadInitialLocation()
            startTimerUpdater()
            databaseManager.saveGamePersistence(
                gameId: gameId,
                lobbyCode: lobbyCode,
                playerTeam: playerTeam
            )
        }
        .onDisappear { stopTimerUpdater() }
        .onChange(of: locationManager.location) { _, location in
            updatePlayerLocation(location)
        }
        .onChange(of: mapSearchViewModel.results) { _, results in
            if !results.isEmpty { mapSearchViewModel.showSearchResults() }
        }
    }

    private var topOverlays: some View {
        VStack {
            ZStack {
                defaultOverlay
                    .opacity(showingSearch ? 0 : 1)
                    .animation(.easeInOut.delay(0.2), value: showingSearch)

                searchBarOverlay
                    .opacity(showingSearch ? 1 : 0)
                    .offset(y: showingSearch ? 0 : -20)
                    .disabled(!showingSearch)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

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

    // MARK: - Locked crosshair overlay
    private var crosshairOverlay: some View {
        Group {
            if mapToolsViewModel.mapToolsBottomSheetPosition != .hidden {
                GeometryReader { proxy in
                    let x = proxy.size.width / 2
                    let y = proxy.size.height * Self.CrosshairYOffsetFraction
                    ZStack {
                        Image(systemName: "scope")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                            .position(x: x, y: y)
                        // Live lat/lon readout
                        Text(String(format: "(%.5f,%.5f)", crosshairCoordinate.latitude, crosshairCoordinate.longitude))
                            .font(.caption2.monospacedDigit())
                            .multilineTextAlignment(.center)
                            .padding(6)
                            .background(Color.black.opacity(0.65))
                            .cornerRadius(6)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                            .position(x: x, y: y + 30)
                    }
                    .allowsHitTesting(false)
                }
                .ignoresSafeArea()
            }
        }
    }

    private var bottomActions: some View {
        Group {
            if !showingSearch {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        actionButtons
                            .padding(.trailing, 20)
                            .ignoresSafeArea(.keyboard)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if playerTeam == .seekers {
                Button(action: { showingQuestionView = true }) {
                    ZStack {
                        Circle().fill(Color.orange.opacity(0.8)).frame(width: 56, height: 56)
                        Image(systemName: "questionmark.circle.fill").font(.title2).foregroundColor(.white)
                    }
                }
            }

            if gameState == .hiding || gameState == .seeking {
                Button(action: { showingTimerActions = true }) {
                    ZStack {
                        Circle().fill(Color.purple.opacity(0.8)).frame(width: 56, height: 56)
                        Image(systemName: "timer").font(.title2).foregroundColor(.white)
                    }
                }
            }

            Button(action: toggleSearch) {
                ZStack {
                    Circle().fill(Color.gray.opacity(0.8)).frame(width: 56, height: 56)
                    Image(systemName: showingSearch ? "xmark.circle.fill" : "magnifyingglass")
                        .font(.title2).foregroundColor(.white)
                }
            }

            Button(action: { mapToolsViewModel.mapToolsBottomSheetPosition = .relative(0.5) }) {
                ZStack {
                    Circle().fill(Color.green.opacity(0.8)).frame(width: 56, height: 56)
                    Image(systemName: "map.fill").font(.title2).foregroundColor(.white)
                }
            }

            Button(action: { showingChat = true }) {
                ZStack {
                    Circle().fill(Color.black.opacity(0.8)).frame(width: 56, height: 56)
                    Image(systemName: "message.fill").font(.title2).foregroundColor(.white)
                    if chatViewModel.hasUnreadMessages {
                        Circle().fill(Color.red).frame(width: 16, height: 16).offset(x: 20, y: -20)
                    }
                }
            }
        }
    }

    private func toggleSearch() {
        withAnimation(.spring()) {
            if showingSearch {
                mapSearchViewModel.clearSearch()
                showingSearch = false
                isSearchFieldFocused = false
            } else {
                showingSearch = true
                isSearchFieldFocused = true
            }
        }
    }

    // MARK: - Bottom sheets split into modifiers
    private func searchResultsSheet() -> some ViewModifier {
        struct Mod: ViewModifier {
            @ObservedObject var vm: MapSearchViewModel
            let userLocation: CLLocation?
            let onItemSelected: (MKMapItem) -> Void
            let onDismiss: () -> Void
            func body(content: Content) -> some View {
                content.bottomSheet(bottomSheetPosition: $vm.searchResultsBottomSheetPosition, switchablePositions: [.relative(0.25), .relative(0.5), .relativeTop(0.975)]) {
                    SearchResultsSheetContent(viewModel: vm, userLocation: userLocation, onItemSelected: onItemSelected, onDismiss: onDismiss)
                }
            }
        }
        return Mod(
            vm: mapSearchViewModel,
            userLocation: locationManager.location,
            onItemSelected: { item in
                mapSearchViewModel.selectItem(item)
                mapSearchViewModel.showTransportSelection(for: item)
            },
            onDismiss: { mapSearchViewModel.searchResultsBottomSheetPosition = .hidden }
        )
    }

    private func transportSelectionSheet() -> some ViewModifier {
        struct Mod: ViewModifier {
            @ObservedObject var vm: MapSearchViewModel
            let userLocation: CLLocation?
            @ObservedObject var mapToolsVM: MapToolsViewModel
            func body(content: Content) -> some View {
                content.bottomSheet(
                    bottomSheetPosition: $vm.transportSelectionBottomSheetPosition,
                    switchablePositions: [.dynamic, .hidden]
                ) {
                    SearchResultDetailSheetContent(
                        destination: vm.selectedDestination ?? MKMapItem(),
                        userLocation: userLocation,
                        onTransportSelected: { transportType in
                            vm.selectTransportAndShowDirections(transportType)
                        },
                        onDismiss: {
                            vm.transportSelectionBottomSheetPosition = .hidden
                        },
                        onOpenMapTools: {
                            if let dest = vm.selectedDestination {
                                vm.openMapToolsForItem(dest)
                                mapToolsVM.mapToolsBottomSheetPosition = .relative(0.5)
                            }
                        },
                        mapToolsViewModel: mapToolsVM
                    )
                }
            }
        }
        return Mod(
            vm: mapSearchViewModel,
            userLocation: locationManager.location,
            mapToolsVM: mapToolsViewModel
        )
    }

    private func directionsSheet() -> some ViewModifier {
        struct Mod: ViewModifier {
            @ObservedObject var vm: MapSearchViewModel
            func body(content: Content) -> some View {
                content.bottomSheet(bottomSheetPosition: $vm.directionsBottomSheetPosition, switchablePositions: [.relative(0.4), .relativeTop(0.975)]) {
                    if let destination = vm.selectedDestination {
                        DirectionsSheetContent(
                            destination: destination,
                            transportType: vm.selectedTransportType,
                            viewModel: vm,
                            onDismiss: { vm.directionsBottomSheetPosition = .hidden },
                            onRecalculate: {
                                vm.showTransportSelection(for: destination)
                            }
                        )
                    }
                }
            }
        }
        return Mod(vm: mapSearchViewModel)
    }

    private func mapToolsSheet() -> some ViewModifier {
        struct Mod: ViewModifier {
            @ObservedObject var vm: MapToolsViewModel
            @ObservedObject var searchVM: MapSearchViewModel
            @Binding var crosshair: CLLocationCoordinate2D
            func body(content: Content) -> some View {
                content.bottomSheet(
                    bottomSheetPosition: $vm.mapToolsBottomSheetPosition,
                    switchablePositions: [.relative(0.5), .relativeTop(0.975)]
                ) {
                    MapToolsSheetContent(
                        viewModel: vm,
                        mapCenter: Binding(
                            get: { crosshair },
                            set: { newCoord in
                                searchVM.region.center = newCoord
                            }
                        ),
                        onDismiss: {
                            vm.mapToolsBottomSheetPosition = .hidden
                            searchVM.clearSearch()
                        },
                        contextItem: searchVM.contextItemForMapTools
                    )
                }
            }
        }
        return Mod(vm: mapToolsViewModel, searchVM: mapSearchViewModel, crosshair: $crosshairCoordinate)
    }

    private func chatSheet() -> some ViewModifier {
        struct Mod: ViewModifier {
            @Binding var showingChat: Bool
            let gameId: String
            let currentUser: User?
            let playerTeam: Team
            let chatVM: ChatViewModel // inject explicitly
            func body(content: Content) -> some View {
                content.sheet(isPresented: $showingChat) {
                    NavigationStack {
                        GameChatView(
                            gameId: gameId,
                            currentUser: currentUser,
                            currentPlayerTeam: playerTeam
                        )
                        .environmentObject(chatVM)
                        .navigationTitle("Game Chat")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showingChat = false }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                }
            }
        }
        return Mod(
            showingChat: $showingChat,
            gameId: gameId,
            currentUser: currentUser,
            playerTeam: playerTeam,
            chatVM: chatViewModel
        )
    }

    // MARK: - Sheets as computed views (explicit types)
    private var settingsSheet: some View {
        NavigationStack {
            GameSettingsView(
                gameId: gameId,
                lobbyCode: lobbyCode,
                playerTeam: playerTeam,
                onLeaveGame: {
                    dismiss()
                    onReturnToMain?()
                }
            )
        }
    }

    private var questionSheet: some View {
        NavigationStack {
            GameQuestionView(
                gameId: gameId,
                currentUser: currentUser
            )
        }
    }

    private var timerActionsSheet: some View {
        NavigationStack {
            TimerActionsView(
                gameState: gameState,
                onPause: {
                    if gameState == .hiding { pauseHidingPhase() }
                    else if gameState == .seeking { pauseSeekingPhase() }
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
    }
    
    private func setupMapRegion() {
        // Fallback: city-based region (unchanged)
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
        
        // Center on user once when first fix arrives; also sync search region
        if !didCenterOnUser {
            let center = location.coordinate
            let userRegion = MKCoordinateRegion(
                center: center,
                latitudinalMeters: 8000,
                longitudinalMeters: 8000
            )
            mapSearchViewModel.region = userRegion
            didCenterOnUser = true
        }
        
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
                    latitude: mapSearchViewModel.region.center.latitude,
                    longitude: mapSearchViewModel.region.center.longitude
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
}

// MARK: - Timer UI
extension GameView {
    private var defaultOverlay: some View {
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
            
            Color.clear
                .frame(width: 40, height: 40)
        }
    }
    
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
                    .font(.system(.title3))
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
                    .font(.system(.title3))
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
                .font(.system(.title3))
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
                    .font(.system(.title3))
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

// MARK: - Search Bar Overlay View
extension GameView {
    private var searchBarOverlay: some View {
        HStack {
            Button(action: {
                withAnimation(.spring()) {
                    showingSearch = false
                    isSearchFieldFocused = false
                    mapSearchViewModel.clearSearch()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
            }
            
            HStack {
                TextField("Search for places...", text: $mapSearchViewModel.query)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .submitLabel(.search)
                    .onSubmit {
                        isSearchFieldFocused = false
                        mapSearchViewModel.search()
                    }
                    .focused($isSearchFieldFocused)
                
                if !mapSearchViewModel.query.isEmpty {
                    Button(action: { mapSearchViewModel.clearSearch() }) {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 40)
            .background(Color.black.opacity(0.7))
            .clipShape(Capsule())
            
            Button(action: {
                    isSearchFieldFocused = false
                    mapSearchViewModel.search()
            }) {
                Group {
                    if mapSearchViewModel.isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.7))
                .clipShape(Circle())
            }
        }
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
