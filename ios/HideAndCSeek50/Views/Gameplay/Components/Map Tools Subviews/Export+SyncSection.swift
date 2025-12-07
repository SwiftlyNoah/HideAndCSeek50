//
//  Export+SyncSection.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/7/25.
//

import SwiftUI

struct ExportSyncSectionView: View {
    @ObservedObject var viewModel: MapToolsViewModel
    let gameId: String
    let playerTeam: Team
    let playerUID: String
    let playerName: String

    @State private var showingSyncSheet = false
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportSuccess = false

    var body: some View {
        VStack(spacing: 12) {
            // Export Button
            Button {
                Task {
                    await exportMapTools()
                }
            } label: {
                HStack {
                    if isExporting {
                        ProgressView()
                            .tint(.primary)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.primary.opacity(0.8))
                    }
                    Text("Export to Database")
                        .foregroundColor(.primary)
                    Spacer()
                    if exportSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(isExporting)

            // Sync Button
            Button {
                showingSyncSheet = true
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.primary.opacity(0.8))
                    Text("Sync from Database")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.5))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color.green.opacity(0.15))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            if let error = exportError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
            }
        }
        .sheet(isPresented: $showingSyncSheet) {
            SyncMapToolsSheet(
                viewModel: viewModel,
                gameId: gameId,
                playerTeam: playerTeam,
                playerUID: playerUID
            )
        }
    }

    private func exportMapTools() async {
        isExporting = true
        exportError = nil
        exportSuccess = false

        do {
            try await viewModel.exportMapTools(
                gameId: gameId,
                playerUID: playerUID,
                playerName: playerName
            )
            exportSuccess = true
            // Reset success indicator after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            exportSuccess = false
        } catch {
            exportError = "Failed to export: \(error.localizedDescription)"
        }

        isExporting = false
    }
}
