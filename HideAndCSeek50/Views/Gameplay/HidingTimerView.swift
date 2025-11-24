//
//  SeekingTimerView.swift
//  HideAndCSeek50
//
//  Created by Ryan Eto on 11/24/25.
//

import SwiftUI
import FirebaseDatabase // Added for DatabaseReference

struct HidingTimerView: View {
    let gameId: String
    let playerTeam: Team
    
    @StateObject private var databaseManager = DatabaseManager.shared
    @State private var currentElapsed: TimeInterval = 0
    @State private var tickTimer: Timer?
    @State private var pendingAction: TimerAction?
    @State private var showingConfirm = false
    
    private var game: Game? { databaseManager.currentGame }
    private var info: GameInfo? { game?.info }
    
    private var hidingMinutes: Int { info?.settings.hidingTime ?? 0 }
    private var timerState: TimerState { info?.hidingTimerState ?? .notStarted }
    private var startedAt: Date? { info?.hidingTimerStartedAt }
    private var remoteElapsed: TimeInterval { info?.hidingTimerElapsed ?? 0 }
    
    private var totalDuration: TimeInterval { TimeInterval(hidingMinutes * 60) }
    private var remaining: TimeInterval { max(0, totalDuration - currentElapsed) }
    private var progress: Double { totalDuration == 0 ? 0 : min(1, currentElapsed / totalDuration) }
    
    enum TimerAction { case skip, reset }
    
    var body: some View {
        VStack(spacing: 28) {
            timerCircle
            controls
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .onAppear {
            databaseManager.startListeningToGame(gameId: gameId)
            syncElapsed()
            startTicking()
        }
        .onDisappear { stopTicking() }
        // Changed to single-parameter form for broader deployment compatibility
        .onChange(of: info?.hidingTimerState) { _, _ in
            syncElapsed()
        }
        .onChange(of: info?.hidingTimerStartedAt) { _, _ in
            syncElapsed()
        }
        .confirmationDialog(confirmTitle, isPresented: $showingConfirm, titleVisibility: .visible) {
            Button(confirmButtonLabel, role: destructiveRole) { executePending() }
            Button("Cancel", role: .cancel) { pendingAction = nil }
        } message: {
            Text(confirmMessage)
        }
    }
    
    private var timerCircle: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 20)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(circleColor,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: progress)
            VStack(spacing: 4) {
                Text(timeString(remaining))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 220, height: 220)
    }
    
    private var controls: some View { // Fixed Button label syntax
        Group {
            switch timerState {
            case .notStarted:
                Button {
                    Task { try? await databaseManager.startHidingTimer(gameId: gameId) }
                } label: { actionLabel("play.fill", "Start Hiding Timer") }
                .buttonStyle(.borderedProminent)

            case .running:
                HStack(spacing: 12) {
                    Button {
                        Task { try? await databaseManager.pauseHidingTimer(gameId: gameId, elapsed: currentElapsed) }
                    } label: { actionLabel("pause.fill", "Pause") }
                    .buttonStyle(.bordered)
                    Button { confirm(.skip) } label: { actionLabel("forward.fill", "Skip") }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                }

            case .paused:
                HStack(spacing: 12) {
                    Button {
                        Task { try? await databaseManager.resumeHidingTimer(gameId: gameId) }
                    } label: { actionLabel("play.fill", "Resume") }
                    .buttonStyle(.borderedProminent)

                    Button { confirm(.skip) } label: { actionLabel("forward.fill", "Skip") }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                }

            case .completed, .skipped:
                Button { confirm(.reset) } label: { actionLabel("arrow.clockwise", "Reset Hiding Timer") }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
            }
        }
    }
    
    private func actionLabel(_ system: String, _ text: String) -> some View {
        HStack {
            Image(systemName: system)
            Text(text)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var statusText: String {
        switch timerState {
        case .notStarted: return "Ready to begin hiding"
        case .running: return "Hiders are hiding..."
        case .paused: return "Timer paused"
        case .completed: return playerTeam == .seekers ? "Ready to seek" : "Hiding complete"
        case .skipped: return playerTeam == .seekers ? "Ready to seek" : "Hiding skipped"
        }
    }
    
    private var circleColor: Color {
        switch timerState {
        case .running: return .purple
        case .paused: return .orange
        case .completed, .skipped: return .green
        case .notStarted: return .blue
        }
    }
    
    // MARK: - Elapsed Logic
    
    private func startTicking() {
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            if timerState == .running { syncElapsed() }
        }
    }
    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }
    
    private func syncElapsed() {
        switch timerState {
        case .notStarted:
            currentElapsed = 0
        case .running:
            if let started = startedAt {
                currentElapsed = remoteElapsed + Date().timeIntervalSince(started)
                if currentElapsed >= totalDuration {
                    Task {
                        do {
                            try await databaseManager.completeHidingTimer(gameId: gameId, totalElapsed: totalDuration)
                        } catch {
                            print("Failed to mark hiding timer complete: \(error)")
                        }
                    }
                }
            }
        case .paused:
            currentElapsed = remoteElapsed
        case .completed, .skipped:
            currentElapsed = totalDuration
        }
    }
    
    private func timeString(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    // MARK: - Confirmation
    
    private func confirm(_ action: TimerAction) {
        pendingAction = action
        showingConfirm = true
    }
    
    private var confirmTitle: String {
        switch pendingAction {
        case .skip: return "Skip Hiding Timer"
        case .reset: return "Reset Hiding Timer"
        case .none: return ""
        }
    }
    private var confirmMessage: String {
        switch pendingAction {
        case .skip: return "End hiding immediately for both teams"
        case .reset: return "Reset the hiding timer"
        case .none: return ""
        }
    }
    private var confirmButtonLabel: String {
        switch pendingAction {
        case .skip: return "Skip"
        case .reset: return "Reset"
        case .none: return "Confirm"
        }
    }
    private var destructiveRole: ButtonRole? {
        switch pendingAction {
        case .skip: return .destructive
        case .reset, .none: return nil
        }
    }
    
    private func executePending() {
        guard let action = pendingAction else { return }
        switch action {
        case .skip:
            Task { try? await databaseManager.skipHidingTimer(gameId: gameId) }
        case .reset:
            Task { try? await databaseManager.resetHidingTimer(gameId: gameId) }
        }
        pendingAction = nil
    }
}
