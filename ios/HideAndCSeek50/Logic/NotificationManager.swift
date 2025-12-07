//
//  NotificationManager.swift
//  HideAndCSeek50
//
//  Created on 12/02/2025.
//

import Foundation
import UserNotifications
import FirebaseMessaging
import FirebaseAuth
internal import Combine
import UIKit
import FirebaseDatabaseInternal

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var fcmToken: String?
    @Published var isAuthorized = false
    
    private let databaseManager = DatabaseManager.shared
    
    override init() {
        super.init()
    }
    
    // MARK: - Permission Request
    
    /// Request notification permissions from the user
    func requestPermission() async throws {
        let center = UNUserNotificationCenter.current()

        // Request authorization
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])

        await MainActor.run {
            self.isAuthorized = granted
        }

        if granted {
            // Register for remote notifications on main thread
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    // MARK: - FCM Token Management
    
    /// Configure Firebase Messaging and set up delegate
    func configure() {
        Messaging.messaging().delegate = self
    }

    /// Refresh FCM token after APNS token is available
    /// This should be called after the APNS token is set to ensure proper registration
    func refreshFCMToken() async {
        // Delete the old instance ID to force a refresh
        do {
            try await Messaging.messaging().deleteToken()
        } catch {
            print("⚠️ Could not delete old FCM token: \(error.localizedDescription)")
        }

        // Get a fresh FCM token using async/await
        do {
            let token = try await Messaging.messaging().token()
            self.fcmToken = token

            // Save to database
            do {
                try await self.saveFCMTokenToUserProfile()
            } catch {
                print("❌ Failed to save FCM token: \(error.localizedDescription)")
            }
        } catch {
            print("❌ Error fetching FCM token: \(error.localizedDescription)")
        }
    }
    
    /// Subscribe to notifications for a specific game
    /// This subscribes the user to a game-specific topic so they receive notifications
    /// for new messages in that game
    func subscribeToGame(gameId: String) async throws {
        guard fcmToken != nil else {
            print("⚠️ Cannot subscribe to game - no FCM token available")
            return
        }

        let topic = "game_\(gameId)"
        try await Messaging.messaging().subscribe(toTopic: topic)
    }
    
    /// Unsubscribe from notifications for a specific game
    func unsubscribeFromGame(gameId: String) async throws {
        let topic = "game_\(gameId)"
        try await Messaging.messaging().unsubscribe(fromTopic: topic)
    }
    // MARK: - Token Storage
    
    /// Save FCM token to user's profile in Firebase
    /// This allows the backend to send targeted notifications
    func saveFCMTokenToUserProfile() async throws {
        guard let token = fcmToken,
              let currentUID = Auth.auth().currentUser?.uid else {
            return
        }
        
        let userRef = DatabaseReference.user(currentUID)
        try await userRef.child("fcmToken").setValue(token)
        try await userRef.child("fcmTokenUpdatedAt").setValue(Date().timeIntervalSince1970)
    }
}

// MARK: - MessagingDelegate

extension NotificationManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            self.fcmToken = fcmToken

            // Save token to user profile
            do {
                try await self.saveFCMTokenToUserProfile()
            } catch {
                print("❌ Failed to save FCM token: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo

        // Check if this is a chat message notification
        if userInfo["type"] as? String == "chat_message" {
            // Show banner and play sound even when app is in foreground
            return [.banner, .sound, .badge]
        }

        return [.banner, .sound]
    }
    
    // Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle notification tap - navigate to the game chat
        if let gameId = userInfo["gameId"] as? String {
            // Post notification to navigate to game
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .navigateToGame,
                    object: nil,
                    userInfo: ["gameId": gameId]
                )
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToGame = Notification.Name("navigateToGame")
}
