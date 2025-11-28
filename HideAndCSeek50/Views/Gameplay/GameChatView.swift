//
//  GameChat.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/17/25.
//

import SwiftUI
import FirebaseAuth
internal import Combine

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
