//
//  TimerActionsView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/7/25.
//

import SwiftUI

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
