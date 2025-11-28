//
//  GameChat.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/17/25.
//

import SwiftUI
import FirebaseAuth
internal import Combine
import CoreLocation

struct GameChatView: View {
    let gameId: String
    let currentUser: User? // FirebaseAuth.User
    let currentPlayerTeam: Team
    
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @State private var messageText = ""
    
    @State private var locationSendError: String?
    
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
                // Location send button (seekers only)
                if currentPlayerTeam == .seekers {
                    Button(action: sendLocationMessage) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.red)
                            .clipShape(Circle())
                            .accessibilityLabel("Send Current Location")
                    }
                    .disabled(chatViewModel.isLoading)
                    .help("Send your current coordinates to chat")
                }
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.gray : Color.blue
                        )
                        .clipShape(Circle())
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatViewModel.isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))

            if let locationSendError = locationSendError {
                Text(locationSendError)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.bottom, 4)
            }
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
    
    private func sendLocationMessage() {
        guard currentPlayerTeam == .seekers else { return }
        guard let loc = LocationManager.shared.location else {
            locationSendError = "Location unavailable"
            return
        }
        let content = String(
            format: "Latitude: %.5f, Longitude: %.5f",
            loc.coordinate.latitude,
            loc.coordinate.longitude
        )
        Task {
            await chatViewModel.sendMessage(
                gameId: gameId,
                content: content,
                currentUser: currentUser,
                currentUserName: currentUserName,
                currentPlayerTeam: currentPlayerTeam
            )
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
