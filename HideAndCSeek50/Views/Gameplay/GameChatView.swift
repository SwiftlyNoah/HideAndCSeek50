//
//  GameChatView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/17/25.
//

import SwiftUI
import FirebaseAuth

struct GameChatView: View {
    let gameId: String
    let currentUser: User?
    let currentPlayerTeam: Team
    
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @State private var messageText = ""
    @State private var showingImagePicker = false
    @State private var showingImageSourceSelection = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedImage: UIImage?
    @State private var showingCameraPermissionAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatViewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                isCurrentUser: message.senderUID == currentUser?.uid
                            )
                        }
                    }
                    .padding()
                }
                .onChange(of: chatViewModel.messages.count) { _, _ in
                    if let lastMessage = chatViewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Upload progress indicator
            if chatViewModel.isLoading && chatViewModel.uploadProgress > 0 {
                VStack(spacing: 4) {
                    ProgressView(value: chatViewModel.uploadProgress)
                        .progressViewStyle(.linear)
                    Text("Uploading: \(Int(chatViewModel.uploadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            // Message input area
            HStack(spacing: 12) {
                // Photo button
                Button {
                    showingImageSourceSelection = true
                } label: {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 40, height: 40)
                }
                .disabled(chatViewModel.isLoading)
                
                // Text field
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .disabled(chatViewModel.isLoading)
                
                // Send button
                Button {
                    sendTextMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatViewModel.isLoading)
            }
            .padding()
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showingImageSourceSelection, titleVisibility: .visible) {
            Button("Camera") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    imageSourceType = .camera
                    showingImagePicker = true
                } else {
                    showingCameraPermissionAlert = true
                }
            }
            
            Button("Photo Library") {
                imageSourceType = .photoLibrary
                showingImagePicker = true
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: imageSourceType)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                sendPhotoMessage(image: image)
                selectedImage = nil
            }
        }
        .alert("Camera Not Available", isPresented: $showingCameraPermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Camera is not available on this device or permission has been denied.")
        }
    }
    
    private func sendTextMessage() {
        let text = messageText
        messageText = ""
        
        guard let displayName = currentUser?.displayName ?? currentUser?.email else {
            return
        }
        
        Task {
            await chatViewModel.sendMessage(
                gameId: gameId,
                content: text,
                currentUser: currentUser,
                currentUserName: displayName,
                currentPlayerTeam: currentPlayerTeam
            )
        }
    }
    
    private func sendPhotoMessage(image: UIImage) {
        guard let displayName = currentUser?.displayName ?? currentUser?.email else {
            return
        }
        
        Task {
            await chatViewModel.sendPhotoMessage(
                gameId: gameId,
                image: image,
                currentUser: currentUser,
                currentUserName: displayName,
                currentPlayerTeam: currentPlayerTeam
            )
        }
    }
}

struct MessageBubble: View {
    let message: GameMessage
    let isCurrentUser: Bool
    
    @State private var showFullImage = false
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender name
                if !isCurrentUser {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Message content
                if message.type == .photo,
                   let photoURL = message.attachments?.photoURL {
                    // Photo message
                    Button {
                        showFullImage = true
                    } label: {
                        AsyncImage(url: URL(string: photoURL)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 200, height: 200)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: 200, maxHeight: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            case .failure:
                                VStack {
                                    Image(systemName: "photo.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                    Text("Failed to load")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 200, height: 200)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    .sheet(isPresented: $showFullImage) {
                        FullScreenImageView(imageURL: photoURL)
                    }
                } else {
                    // Text message
                    Text(message.content)
                        .padding(10)
                        .background(isCurrentUser ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(isCurrentUser ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // Timestamp
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isCurrentUser {
                Spacer()
            }
        }
    }
}

struct FullScreenImageView: View {
    let imageURL: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                AsyncImage(url: URL(string: imageURL)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        VStack {
                            Image(systemName: "photo.fill")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("Failed to load image")
                                .foregroundColor(.gray)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        GameChatView(
            gameId: "preview-game",
            currentUser: nil,
            currentPlayerTeam: .hiders
        )
        .environmentObject(ChatViewModel())
    }
}
