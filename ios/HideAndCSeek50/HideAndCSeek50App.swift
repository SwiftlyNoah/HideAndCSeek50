//
//  HideAndCSeek50App.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import SwiftUI
import Firebase
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()

        // Set up notification center delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared

        // Configure Firebase Messaging
        Task { @MainActor in
            NotificationManager.shared.configure()
        }
        
        return true
    }
    
    // Called when APNs successfully registers the device
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("✅ APNs Device Token received: \(token)")

        // Set the APNS token with the correct type for Firebase Messaging
        #if DEBUG
        Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
        print("✅ APNs token passed to Firebase Messaging (sandbox/development)")
        #else
        Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
        print("✅ APNs token passed to Firebase Messaging (production)")
        #endif

        // Now that APNS token is set, refresh the FCM token
        Task { @MainActor in
            await NotificationManager.shared.refreshFCMToken()
        }
    }
    
    // Called when APNs fails to register the device
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // Handle remote notification in background
    nonisolated func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any]
    ) async -> UIBackgroundFetchResult {
        // Handle the notification
        print("🔔 Received remote notification in background:")
        print("   UserInfo: \(userInfo)")

        // Return appropriate fetch result
        return .newData
    }
}

@main
struct HideAndCSeek50App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    MainView(user: authManager.currentUser)
                } else {
                    AuthenticationView()
                }
            }
            .environmentObject(authManager)
        }
    }
}
