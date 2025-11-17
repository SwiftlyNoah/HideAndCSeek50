//
//  GameChat-Views.swift
//  HideAndCSeek50
//
//  Created by Assistant on 11/17/25.
//

import Foundation
import SwiftUI
import FirebaseAuth

struct GameChatView: View {
    let gameId: String
    let currentUser: User? // FirebaseAuth.User
    let currentPlayerTeam: Team
    
    @StateObject private var databaseManager = DatabaseManager.shared
    @State private var messages: [GameMessage] = []
    @State private var messageText = ""
    @State private var isLoading = false
    
    private var currentUserName: String {
        currentUser?.displayName ?? "Anonymous"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            MessageBubble(
                                message: message,
                                isCurrentUser: message.senderUID == currentUser?.uid
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message Input
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                        .clipShape(Circle())
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadMessages()
            observeMessages()
        }
    }
    
    private func sendMessage() {
        guard let currentUID = currentUser?.uid,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isLoading = true
        
        // Create GameMessage using the struct from Game.swift with all required parameters
        let message = GameMessage(
            id: UUID().uuidString,
            senderUID: currentUID,
            senderName: currentUserName,
            content: messageText.trimmingCharacters(in: .whitespacesAndNewlines),
            type: .text,
            timestamp: Date(),
            team: currentPlayerTeam == .hiders ? .hiders : .seekers,
            attachments: nil,
            questionData: nil,
            reactions: [:]
        )
        
        Task {
            do {
                try await databaseManager.sendGameMessage(gameId: gameId, message: message)
                await MainActor.run {
                    messageText = ""
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    // Handle error silently or show alert
                    isLoading = false
                }
            }
        }
    }
    
    private func loadMessages() {
        // Load initial messages
        Task {
            do {
                let loadedMessages = try await databaseManager.getGameMessages(gameId: gameId)
                await MainActor.run {
                    messages = loadedMessages.sorted { $0.timestamp < $1.timestamp }
                }
            } catch {
                // Handle error
            }
        }
    }
    
    private func observeMessages() {
        // Set up real-time message listener
        databaseManager.observeGameMessages(gameId: gameId) { newMessages in
            DispatchQueue.main.async {
                self.messages = newMessages.sorted { $0.timestamp < $1.timestamp }
            }
        }
    }
}

struct MessageBubble: View {
    let message: GameMessage
    let isCurrentUser: Bool
    
    private var teamColor: Color {
        switch message.team {
        case .hiders: return .blue
        case .seekers: return .red
        case .all: return .gray
        }
    }
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(teamColor)
                            .frame(width: 8, height: 8)
                        
                        Text(message.senderName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
}