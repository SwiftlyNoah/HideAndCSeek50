//
//  SeekingTimerView.swift
//  HideAndCSeek50
//
//  Created by Ryan Eto on 11/24/25.
//

import SwiftUI
import FirebaseDatabase

struct SeekingTimerView: View {
    let gameId: String
    let playerTeam: Team
    
    @StateObject private var databaseManager = DatabaseManager.shared
    @State private var currentElapsed: TimeInterval = 0
    @State private var tickTimer: Timer?
    @State private var pendingAction: TimerAction?
    @State private var showingConfirm = false
    
    private var game: Game? { databaseManager.currentGame }
    private var info: GameInfo? { game?.info }
    
    private var timerState: TimerState { info?.seekingTimerState ?? .notStarted }
    private var startedAt: Date? { info?.seekingTimerStartedAt }
    private var remoteElapsed: TimeInterval { info?.seekingTimerElapsed ?? 0 }
    
    enum TimerAction { case pause, stop }
    
    var body: some View {
        VStack(spacing: 28) {
            header
            elapsedDisplay
            controls
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .onAppear {
            databaseManager.startListeningToGame(gameId: gameId)
            syncElapsed()
            startTicking()
        }
        .onDisappear { stopTicking() }
        .onChange(of: info?.seekingTimerState) { _, _ in syncElapsed() }
        .onChange(of: info?.seekingTimerStartedAt) { _, _ in syncElapsed() }
        .confirmationDialog(confirmTitle, isPresented: $showingConfirm, titleVisibility: .visible) {
            Button(confirmButtonLabel, role: pendingAction == .stop ? .destructive : nil) { executePending() }
            Button("Cancel", role: .cancel) { pendingAction = nil }
        } message: {
            Text(confirmMessage)
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Seeking Timer")
                    .font(.title2).fontWeight(.bold)
                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    private var elapsedDisplay: some View {
        VStack(spacing: 8) {
            Text(timeString(currentElapsed))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("elapsed")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 220, height: 160)
    }
    
    private func actionLabel(_ system: String, _ text: String) -> some View {
        HStack {
            Image(systemName: system)
            Text(text)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var controls: some View {
        Group {
            switch timerState {
            case .notStarted:
                Button {
                    Task { try? await databaseManager.startSeekingTimer(gameId: gameId) }
                } label: { actionLabel("play.fill", "Start Seeking Timer") }
                .buttonStyle(.borderedProminent)
            case .running:
                HStack(spacing: 12) {
                    Button { confirm(.pause) } label: { actionLabel("pause.fill", "Pause") }
                        .buttonStyle(.bordered)
                    Button { confirm(.stop) } label: { actionLabel("stop.fill", "Hiders Found / Stop") }
                        .buttonStyle(.bordered)
                        .tint(.red)
                }
            case .paused:
                HStack(spacing: 12) {
                    Button {
                        Task { try? await databaseManager.resumeSeekingTimer(gameId: gameId) }
                    } label: { actionLabel("play.fill", "Resume") }
                    .buttonStyle(.borderedProminent)
                    
                    Button { confirm(.stop) } label: { actionLabel("stop.fill", "Hiders Found / Stop") }
                        .buttonStyle(.bordered)
                        .tint(.red)
                }
            case .completed, .skipped:
                Text("Seeking complete.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var statusText: String {
        switch timerState {
        case .notStarted: return "Ready to begin seeking"
        case .running: return "Seekers searching..."
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .skipped: return "Completed"
        }
    }
    
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
            }
        case .paused:
            currentElapsed = remoteElapsed
        case .completed, .skipped:
            currentElapsed = remoteElapsed
        }
    }
    
    private func timeString(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    // Confirmation
    private func confirm(_ action: TimerAction) {
        pendingAction = action
        showingConfirm = true
    }
    private var confirmTitle: String {
        switch pendingAction {
        case .pause: return "Pause Seeking Timer"
        case .stop: return "Stop Seeking Timer"
        case .none: return ""
        }
    }
    private var confirmMessage: String {
        switch pendingAction {
        case .pause: return "All players will see the timer paused."
        case .stop: return "Record final seeking time and end seeking."
        case .none: return ""
        }
    }
    private var confirmButtonLabel: String {
        switch pendingAction {
        case .pause: return "Pause"
        case .stop: return "Stop"
        case .none: return "Confirm"
        }
    }
    
    private func executePending() {
        guard let action = pendingAction else { return }
        switch action {
        case .pause:
            Task { try? await databaseManager.pauseSeekingTimer(gameId: gameId, elapsed: currentElapsed) }
        case .stop:
            Task { try? await databaseManager.completeSeekingTimer(gameId: gameId, totalElapsed: currentElapsed) }
        }
        pendingAction = nil
    }
}
