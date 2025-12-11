//
//  JoinLobbyView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import SwiftUI
import FirebaseAuth

struct JoinLobbyView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var gameManager: GameManager

    @Environment(\.dismiss) private var dismiss
    
    @State private var lobbyCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let onLobbyJoined: (String) -> Void
    
    private var currentUser: User? {
        authManager.currentUser
    }
    
    private var displayName: String {
        currentUser?.displayName ?? "Anonymous Player"
    }
    
    private var formattedLobbyCode: String {
        lobbyCode.uppercased().prefix(6).description
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(spacing: 8) {
                        Text("Join a Game")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Enter the 6-digit game code to join a lobby")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Code input
                VStack(spacing: 16) {
                    TextField("Game Code", text: $lobbyCode)
                        .textInputAutocapitalization(.characters)
                        .keyboardType(.asciiCapable)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .onChange(of: lobbyCode) { oldValue, newValue in
                            // Limit to 6 characters and make uppercase
                            let filtered = String(newValue.uppercased().prefix(6))
                                .filter { $0.isLetter || $0.isNumber }
                            if filtered != newValue {
                                lobbyCode = filtered
                            }
                        }
                        .submitLabel(.join)
                        .onSubmit {
                            if formattedLobbyCode.count == 6 {
                                Task {
                                    await joinLobby()
                                }
                            }
                        }
                    
                    // Code display
                    if !lobbyCode.isEmpty {
                        Text(formattedLobbyCode)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                }
                
                // Join button
                Button(action: {
                    Task {
                        await joinLobby()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "person.badge.plus")
                        }
                        Text("Join Lobby")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(isLoading || formattedLobbyCode.count != 6)
                .controlSize(.large)
                
                Spacer()
                
                // Alternative actions
                VStack(spacing: 12) {
                    Text("or")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Browse Public Games") {
                        dismiss()
                        // The parent view should handle showing QuickMatchView
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 30)
            .navigationTitle("Join Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private func joinLobby() async {
        guard let currentUID = currentUser?.uid else {
            errorMessage = "Please sign in to join a lobby"
            return
        }
        
        guard formattedLobbyCode.count == 6 else {
            errorMessage = "Please enter a valid 6-digit game code"
            return
        }
        
        isLoading = true
        
        do {
            _ = try await gameManager.joinLobby(
                code: formattedLobbyCode,
                playerUID: currentUID,
                displayName: displayName
            )
            
            await MainActor.run {
                onLobbyJoined(formattedLobbyCode)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                if case .lobbyNotFound = error as? DatabaseError {
                    errorMessage = "Game not found. Check the code and try again."
                } else {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        }
    }
}

#Preview {
    JoinLobbyView { _ in }
        .environmentObject(AuthenticationManager())
}
