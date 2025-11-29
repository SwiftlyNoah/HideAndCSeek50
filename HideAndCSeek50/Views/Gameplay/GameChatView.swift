//
//  GameChatView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/17/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseStorage

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
                            // Show answer UI for unanswered questions if user is a hider
                            if message.type == .question,
                               let questionData = message.questionData,
                               !questionData.isAnswered,
                               currentPlayerTeam == .hiders {
                                QuestionAnswerView(
                                    gameId: gameId,
                                    message: message,
                                    questionData: questionData,
                                    currentUser: currentUser
                                )
                                .padding(.horizontal)
                            } else {
                                MessageBubble(
                                    message: message,
                                    isCurrentUser: message.senderUID == currentUser?.uid
                                )
                            }
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
                
                // Message content based on type
                switch message.type {
                case .photo:
                    if let photoURL = message.attachments?.photoURL {
                        photoMessageView(photoURL: photoURL)
                    }
                    
                case .question:
                    questionMessageView
                    
                case .answer:
                    answerMessageView
                    
                case .text:
                    textMessageView
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
    
    // MARK: - Message Type Views
    
    private var textMessageView: some View {
        Text(message.content)
            .padding(10)
            .background(isCurrentUser ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(isCurrentUser ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var questionMessageView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Question part (red background)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.white)
                    Text(message.content)
                        .fontWeight(.medium)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red)
            
            // Answer part (blue background) - only show if answered
            if let questionData = message.questionData, questionData.isAnswered,
               let answer = questionData.playerAnswer {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text("Answer: \(answer)")
                            .font(.subheadline)
                    }
                    
                    // Show photo if attached
                    if let photoURL = message.attachments?.photoURL {
                        AsyncImage(url: URL(string: photoURL)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(height: 150)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            case .failure:
                                Text("Failed to load photo")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue)
            }
        }
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var answerMessageView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                Text(message.content)
                    .fontWeight(.medium)
            }
        }
        .padding(12)
        .background(Color.blue)
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func photoMessageView(photoURL: String) -> some View {
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

struct QuestionAnswerView: View {
    let gameId: String
    let message: GameMessage
    let questionData: QuestionData
    let currentUser: User?
    
    @State private var selectedAnswer: String?
    @State private var textAnswer = ""
    @State private var isSubmitting = false
    @State private var showImagePicker = false
    @State private var showImageSourceSelection = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedImage: UIImage?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var uploadProgress: Double = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question text (red background)
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.white)
                Text(message.content)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red)
            .clipShape(
                .rect(
                    topLeadingRadius: 16,
                    topTrailingRadius: 16
                )
            )
            
            // Answer section (blue background)
            VStack(alignment: .leading, spacing: 12) {
                Text("Tap to answer:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                
                // Answer options based on question type
                Group {
                    switch questionData.questionType {
                    case .yesNo:
                        yesNoButtons
                        
                    case .closerFurther:
                        closerFurtherButtons
                        
                    case .hotterColder:
                        hotterColderButtons
                        
                    case .text:
                        textAnswerField
                        
                    case .photo:
                        photoAnswerButton
                    }
                }
                
                // Upload progress for photos
                if isSubmitting && uploadProgress > 0 {
                    VStack(spacing: 4) {
                        ProgressView(value: uploadProgress)
                            .progressViewStyle(.linear)
                            .tint(.white)
                        Text("Uploading: \(Int(uploadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                // Submit button (for text answers)
                if questionData.questionType == .text {
                    Button(action: submitAnswer) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        } else {
                            Text("Submit Answer")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 10)
                    .background(canSubmit ? Color.white : Color.white.opacity(0.5))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue)
            .clipShape(
                .rect(
                    bottomLeadingRadius: 16,
                    bottomTrailingRadius: 16
                )
            )
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showImageSourceSelection, titleVisibility: .visible) {
            Button("Camera") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    imageSourceType = .camera
                    showImagePicker = true
                } else {
                    errorMessage = "Camera not available on this device"
                    showError = true
                }
            }
            
            Button("Photo Library") {
                imageSourceType = .photoLibrary
                showImagePicker = true
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: imageSourceType)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                // Upload photo and submit answer
                submitPhotoAnswer(image: image)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Answer Type Views
    
    private var yesNoButtons: some View {
        HStack(spacing: 12) {
            answerButton(title: "Yes", icon: "checkmark.circle.fill")
            answerButton(title: "No", icon: "xmark.circle.fill")
        }
    }
    
    private var closerFurtherButtons: some View {
        HStack(spacing: 12) {
            answerButton(title: "Closer", icon: "arrow.down.circle.fill")
            answerButton(title: "Further", icon: "arrow.up.circle.fill")
        }
    }
    
    private var hotterColderButtons: some View {
        HStack(spacing: 12) {
            answerButton(title: "Hotter", icon: "flame.fill")
            answerButton(title: "Colder", icon: "snowflake")
        }
    }
    
    private var textAnswerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Type your answer...", text: $textAnswer, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .disabled(isSubmitting)
        }
    }
    
    private var photoAnswerButton: some View {
        Button {
            showImageSourceSelection = true
        } label: {
            HStack {
                Image(systemName: "camera.fill")
                Text(selectedImage == nil ? "Take/Select Photo" : "Photo Selected")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white)
            .foregroundColor(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isSubmitting)
    }
    
    private func answerButton(title: String, icon: String) -> some View {
        Button {
            selectedAnswer = title
            submitAnswer()
        } label: {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white)
            .foregroundColor(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isSubmitting)
    }
    
    // MARK: - Helper Properties
    
    private var canSubmit: Bool {
        switch questionData.questionType {
        case .text:
            return !textAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .photo:
            return selectedImage != nil
        default:
            return true
        }
    }
    
    // MARK: - Actions
    
    private func submitAnswer() {
        guard let currentUID = currentUser?.uid else {
            errorMessage = "Unable to submit answer"
            showError = true
            return
        }
        
        isSubmitting = true
        
        let answer: String
        switch questionData.questionType {
        case .yesNo, .closerFurther, .hotterColder:
            answer = selectedAnswer ?? ""
        case .text:
            answer = textAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        case .photo:
            answer = "Photo submitted"
        }
        
        Task {
            do {
                try await DatabaseManager.shared.answerQuestion(
                    gameId: gameId,
                    questionMessageId: message.id,
                    answer: answer,
                    answeredBy: currentUID
                )
                
                await MainActor.run {
                    isSubmitting = false
                    selectedAnswer = nil
                    textAnswer = ""
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isSubmitting = false
                }
            }
        }
    }
    
    private func submitPhotoAnswer(image: UIImage) {
        guard let currentUID = currentUser?.uid else {
            errorMessage = "Unable to submit answer"
            showError = true
            return
        }
        
        isSubmitting = true
        
        Task {
            do {
                // Fix image orientation and compress
                let orientationCorrectedImage = image.fixOrientation()
                guard let imageData = orientationCorrectedImage.compressedJPEGData(maxSizeInMB: 5.0, compressionQuality: 0.7) else {
                    throw NSError(domain: "QuestionAnswerView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])
                }
                
                // Upload to Firebase Storage
                let filename = "\(message.id)_answer.jpg"
                let storagePath = "games/\(gameId)/questions/\(filename)"
                let storageRef = Storage.storage().reference().child(storagePath)
                
                // Create metadata
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                metadata.customMetadata = ["uploadedBy": currentUID]
                
                // Upload with progress tracking
                let downloadURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                    let uploadTask = storageRef.putData(imageData, metadata: metadata)
                    
                    uploadTask.observe(.progress) { snapshot in
                        guard let progress = snapshot.progress else { return }
                        Task { @MainActor in
                            self.uploadProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                        }
                    }
                    
                    uploadTask.observe(.success) { _ in
                        storageRef.downloadURL { url, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else if let url = url {
                                continuation.resume(returning: url)
                            } else {
                                continuation.resume(throwing: NSError(domain: "QuestionAnswerView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"]))
                            }
                        }
                    }
                    
                    uploadTask.observe(.failure) { snapshot in
                        if let error = snapshot.error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(throwing: NSError(domain: "QuestionAnswerView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Upload failed"]))
                        }
                    }
                }
                
                // Update question with photo URL
                try await DatabaseManager.shared.answerQuestionWithPhoto(
                    gameId: gameId,
                    questionMessageId: message.id,
                    photoURL: downloadURL.absoluteString,
                    answeredBy: currentUID
                )
                
                await MainActor.run {
                    isSubmitting = false
                    selectedImage = nil
                    uploadProgress = 0.0
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isSubmitting = false
                    uploadProgress = 0.0
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
