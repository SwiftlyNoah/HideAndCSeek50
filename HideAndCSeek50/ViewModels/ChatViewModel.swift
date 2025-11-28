//
//  ChatViewModel.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/28/25.
//

import SwiftUI
internal import Combine
import FirebaseAuth

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
