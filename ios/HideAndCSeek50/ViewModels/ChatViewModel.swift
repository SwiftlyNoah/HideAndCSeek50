//
//  ChatViewModel.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/28/25.
//

import SwiftUI
internal import Combine
import FirebaseAuth
import FirebaseStorage

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [GameMessage] = []
    @Published var hasUnreadMessages = false
    @Published var isLoading = false
    @Published var uploadProgress: Double = 0.0
    
    private let storage = Storage.storage()
    var lastReadMessageId: String?
    var isViewVisible = false
    
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
            eventType: nil
        )
        
        do {
            try await GameManager.sendMessage(gameId: gameId, message: message)
        } catch {
            // Handle error silently or show alert
        }
        
        isLoading = false
    }
    
    // MARK: - Photo Sending
    
    /// Uploads an image to Firebase Storage and sends it as a message
    func sendPhotoMessage(
        gameId: String,
        image: UIImage,
        currentUser: User?,
        currentUserName: String,
        currentPlayerTeam: Team
    ) async {
        guard let currentUID = currentUser?.uid else {
            return
        }
        
        isLoading = true
        uploadProgress = 0.0
        
        do {
            // Fix image orientation and compress to JPEG
            let orientationCorrectedImage = image.fixOrientation()
            
            // Use smart compression with max size of 5MB
            guard let imageData = orientationCorrectedImage.compressedJPEGData(maxSizeInMB: 5.0, compressionQuality: 0.7) else {
                print("Failed to convert image to data")
                isLoading = false
                return
            }
            
            // Create unique filename
            let messageId = UUID().uuidString
            let filename = "\(messageId).jpg"
            let storagePath = "games/\(gameId)/photos/\(filename)"
            
            // Upload to Firebase Storage
            let storageRef = storage.reference().child(storagePath)
            
            // Create metadata with uploadedBy
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            metadata.customMetadata = ["uploadedBy": currentUID]
            
            // Upload with progress tracking using async/await
            let downloadURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                let uploadTask = storageRef.putData(imageData, metadata: metadata)
                
                // Observe upload progress
                uploadTask.observe(.progress) { [weak self] snapshot in
                    guard let self = self,
                          let progress = snapshot.progress else { return }
                    Task { @MainActor in
                        self.uploadProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    }
                }
                
                // Observe completion
                uploadTask.observe(.success) { _ in
                    storageRef.downloadURL { url, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let url = url {
                            continuation.resume(returning: url)
                        } else {
                            continuation.resume(throwing: NSError(domain: "ChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"]))
                        }
                    }
                }
                
                // Observe failure
                uploadTask.observe(.failure) { snapshot in
                    if let error = snapshot.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: NSError(domain: "ChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Upload failed"]))
                    }
                }
            }
            
            // Create message with photo attachment
            let message = GameMessage(
                id: messageId,
                senderUID: currentUID,
                senderName: currentUserName,
                content: "📷 Photo",
                type: .photo,
                timestamp: Date(),
                attachments: MessageAttachments(
                    photoURL: downloadURL.absoluteString,
                    audioURL: nil,
                    duration: nil,
                    locationData: nil
                ),
                questionData: nil,
                team: currentPlayerTeam,
                eventType: nil
            )
            
            // Send message to database
            try await GameManager.sendMessage(gameId: gameId, message: message)
            
        } catch {
            print("Error sending photo message: \(error.localizedDescription)")
        }
        
        isLoading = false
        uploadProgress = 0.0
    }
    
    // MARK: - Location Sending
    
    /// Sends a location message with coordinates
    func sendLocationMessage(
        gameId: String,
        latitude: Double,
        longitude: Double,
        locationName: String?,
        currentUser: User?,
        currentUserName: String,
        currentPlayerTeam: Team
    ) async {
        guard let currentUID = currentUser?.uid else {
            return
        }
        
        isLoading = true
        
        let message = GameMessage(
            id: UUID().uuidString,
            senderUID: currentUID,
            senderName: currentUserName,
            content: "📍 Shared location\(locationName.map { ": \($0)" } ?? "")",
            type: .location,
            timestamp: Date(),
            attachments: MessageAttachments(
                photoURL: nil,
                audioURL: nil,
                duration: nil,
                locationData: LocationData(
                    latitude: latitude,
                    longitude: longitude,
                    locationName: locationName
                )
            ),
            questionData: nil,
            team: currentPlayerTeam,
            eventType: nil
        )
        
        do {
            try await GameManager.sendMessage(gameId: gameId, message: message)
        } catch {
            // Handle error silently or show alert
        }
        
        isLoading = false
    }
}
