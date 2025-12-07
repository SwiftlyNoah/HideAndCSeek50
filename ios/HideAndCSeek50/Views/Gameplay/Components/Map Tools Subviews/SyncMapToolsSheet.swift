//
//  SyncMapToolsSheet.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/7/25.
//

import SwiftUI

struct SyncMapToolsSheet: View {
    @ObservedObject var viewModel: MapToolsViewModel
    let gameId: String
    let playerTeam: Team
    let playerUID: String

    @Environment(\.dismiss) private var dismiss
    @State private var teammateMapTools: [(uid: String, info: SavedMapToolsInfo)] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var isImporting = false

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading teammate map tools...")
                        .padding()
                } else if let error = loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            Task {
                                await loadTeammateMapTools()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if teammateMapTools.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "map")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No teammate map tools found")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(teammateMapTools, id: \.uid) { item in
                            Button {
                                Task {
                                    await importMapTools(from: item.uid)
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.info.savedByName)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(timeAgoString(from: item.info.savedAt))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if isImporting {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "arrow.down.circle")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .disabled(isImporting)
                        }
                    }
                }
            }
            .navigationTitle("Sync Map Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadTeammateMapTools()
            }
        }
    }

    private func loadTeammateMapTools() async {
        isLoading = true
        loadError = nil

        do {
            teammateMapTools = try await DatabaseManager.shared.getAllTeammateMapTools(
                gameId: gameId,
                playerTeam: playerTeam
            )
        } catch {
            loadError = "Failed to load: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func importMapTools(from uid: String) async {
        isImporting = true

        do {
            if let mapToolsData = try await DatabaseManager.shared.loadMapTools(gameId: gameId, playerUID: uid) {
                await MainActor.run {
                    viewModel.importMapTools(from: mapToolsData)
                    dismiss()
                }
            }
        } catch {
            loadError = "Failed to import: \(error.localizedDescription)"
        }

        isImporting = false
    }

    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

