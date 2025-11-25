//
//  GameChat-Views.swift
//  HideAndCSeek50
//
//  Created by Assistant on 11/17/25.
//

import Foundation
import SwiftUI
import FirebaseAuth
internal import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [GameMessage] = []
    @Published var hasUnreadMessages = false
    @Published var isLoading = false
    
    private let databaseManager = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var lastReadMessageId: String?
    private var isViewVisible = false
    
    func startMonitoring(gameId: String) {
        // Subscribe to the unified game observation
        databaseManager.$currentGame
            .compactMap { $0 } // Filter out nil values
            .map { game -> [GameMessage] in
                return Array(game.messages.values).sorted { $0.timestamp < $1.timestamp }
            }
            .sink { [weak self] newMessages in
                guard let self = self else { return }
                
                // Check for unread messages before updating self.messages
                if !self.isViewVisible,
                   let lastMessage = newMessages.last,
                   lastMessage.id != self.lastReadMessageId {
                    self.hasUnreadMessages = true
                }
                
                self.messages = newMessages
            }
            .store(in: &cancellables)
    }
    
    func markAsRead() {
        hasUnreadMessages = false
        lastReadMessageId = messages.last?.id
    }
    
    func setViewVisibility(_ isVisible: Bool) {
        isViewVisible = isVisible
        if isVisible {
            markAsRead()
        }
    }
    
    func sendMessage(
        gameId: String,
        content: String,
        currentUser: User?,
        currentUserName: String,
        currentPlayerTeam: Team
    ) async {
        guard let currentUID = currentUser?.uid,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isLoading = true
        
        let message = GameMessage(
            id: UUID().uuidString,
            senderUID: currentUID,
            senderName: currentUserName,
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            type: .text,
            timestamp: Date(),
            attachments: nil,
            questionData: nil,
            team: currentPlayerTeam,
        )
        
        do {
            try await databaseManager.sendMessage(gameId: gameId, message: message)
        } catch {
            // Handle error silently or show alert
        }
        
        isLoading = false
    }
}

struct GameChatView: View {
    let gameId: String
    let currentUser: User? // FirebaseAuth.User
    let currentPlayerTeam: Team
    
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @State private var messageText = ""
    
    private var currentUserName: String {
        currentUser?.displayName ?? "Anonymous"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(chatViewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                isCurrentUser: message.senderUID == currentUser?.uid
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: chatViewModel.messages.count) {
                    if let lastMessage = chatViewModel.messages.last {
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
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                        .clipShape(Circle())
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatViewModel.isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // View visibility is handled by GameView's onChange modifier
        }
        .onDisappear {
            // View visibility is handled by GameView's onChange modifier  
        }
    }
    
    private func sendMessage() {
        Task {
            await chatViewModel.sendMessage(
                gameId: gameId,
                content: messageText,
                currentUser: currentUser,
                currentUserName: currentUserName,
                currentPlayerTeam: currentPlayerTeam
            )
            messageText = ""
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
