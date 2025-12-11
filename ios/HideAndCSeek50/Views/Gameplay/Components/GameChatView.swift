//
//  GameChatView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/17/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseStorage
internal import _LocationEssentials

struct GameChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var gameManager: GameManager

    @ObservedObject var chatViewModel: ChatViewModel
    @ObservedObject var mapToolsViewModel: MapToolsViewModel
    @ObservedObject var locationManager: LocationManager
    
    let gameId: String
    let currentUser: User?
    let currentPlayerTeam: Team
    
    @State private var messageText = ""
    @State private var showingImagePicker = false
    @State private var showingImageSourceSelection = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedImage: UIImage?
    @State private var showingCameraPermissionAlert = false
    
    @Binding var pendingDrawAction: DrawAction?
    
    var body: some View {
        NavigationStack {
            content
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
                .navigationTitle("Game Chat")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
    
    private var content: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatViewModel.messages) { message in
                            // Render events differently
                            if message.type == .event {
                                EventMessageView(message: message)
                                    .padding(.horizontal)
                            }
                            // Show answer UI for unanswered questions if user is a hider
                            else if message.type == .question,
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
                            }
                            else {
                                MessageBubble(
                                    message: message,
                                    isCurrentUser: message.senderUID == currentUser?.uid,
                                    mapToolsViewModel: mapToolsViewModel,
                                    onClaimReward: handleClaimReward(_:)
                                )
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: chatViewModel.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onAppear {
                    // Scroll to bottom when view first appears
                    scrollToBottom(proxy: proxy, animated: false)
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
                
                // Location button (only for seekers)
                if currentPlayerTeam == .seekers {
                    Button {
                        sendLocationMessage()
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 40, height: 40)
                    }
                    .disabled(chatViewModel.isLoading)
                }
                
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
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastMessage = chatViewModel.messages.last else { return }
        
        if animated {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
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
    
    private func sendLocationMessage() {
        guard let displayName = currentUser?.displayName ?? currentUser?.email,
              let location = locationManager.location else {
            return
        }
        
        Task {
            await chatViewModel.sendLocationMessage(
                gameId: gameId,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                locationName: nil,
                currentUser: currentUser,
                currentUserName: displayName,
                currentPlayerTeam: currentPlayerTeam
            )
        }
    }
    
    private func handleClaimReward(_ questionData: QuestionData) {
        // Create draw action for selection
        let action = QuestionData.parseDrawAction(from: questionData.reward)
        pendingDrawAction = action
        
        dismiss()
    }
}

struct MessageBubble: View {
    let message: GameMessage
    let isCurrentUser: Bool
    var mapToolsViewModel: MapToolsViewModel? = nil
    var onClaimReward: ((QuestionData) -> Void)? = nil
    
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
                    
                case .location:
                    locationMessageView
                    
                default:
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
    
    private var locationMessageView: some View {
        Button {
            if let locationData = message.attachments?.locationData,
               let mapToolsVM = mapToolsViewModel {
                mapToolsVM.setPendingChatLocation(
                    latitude: locationData.latitude,
                    longitude: locationData.longitude,
                    senderName: message.senderName,
                    messageId: message.id
                )
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .foregroundColor(isCurrentUser ? .white : .blue)
                    Text(message.content)
                        .fontWeight(.medium)
                }
                
                if let locationData = message.attachments?.locationData {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lat: \(locationData.latitude, specifier: "%.5f")")
                            .font(.caption)
                        Text("Lon: \(locationData.longitude, specifier: "%.5f")")
                            .font(.caption)
                    }
                    .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .secondary)
                }
                
                if mapToolsViewModel != nil && !isCurrentUser {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap.fill")
                            .font(.caption2)
                        Text("Tap to add to map")
                            .font(.caption2)
                    }
                    .foregroundColor(isCurrentUser ? .white.opacity(0.7) : .blue.opacity(0.7))
                    .padding(.top, 4)
                }
            }
            .padding(10)
            .background(isCurrentUser ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(isCurrentUser ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(mapToolsViewModel == nil)
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
                
                // Show timer for unanswered questions
                if let questionData = message.questionData, !questionData.isAnswered {
                    QuestionTimerView(
                        questionTimestamp: message.timestamp,
                        questionCategory: questionData.questionCategory
                    )
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
                    
                    // Show reward button for hiders (who can answer)
                    // Button only shows after question is answered
                    if !isCurrentUser, let onClaim = onClaimReward {
                        Button(action: {
                            onClaim(questionData)
                        }) {
                            HStack {
                                Image(systemName: "gift.fill")
                                Text(questionData.reward)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .foregroundColor(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.top, 4)
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

// MARK: - Event Message View
struct EventMessageView: View {
    let message: GameMessage
    
    var body: some View {
        VStack(spacing: 4) {
            Text(message.content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}


struct FullScreenImageView: View {
    let imageURL: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
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
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale = min(max(scale * delta, 1.0), 5.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        if scale < 1.0 {
                                            withAnimation {
                                                scale = 1.0
                                                offset = .zero
                                            }
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1.0 {
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.3)) {
                                    if scale > 1.0 {
                                        // Reset zoom
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        // Zoom to 2x
                                        scale = 2.0
                                    }
                                }
                            }
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
    @EnvironmentObject private var gameManager: GameManager
    
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
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question text (red background)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.white)
                    Text(message.content)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                // Timer display
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                    Text(timeRemainingText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
                .foregroundColor(timeRemaining < 60 ? .yellow : .white.opacity(0.9))
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
                    switch questionData.questionCategory {
                    case .matching, .radar:
                        yesNoButtons
                        
                    case .measuring:
                        closerFurtherButtons
                        
                    case .thermometer:
                        hotterColderButtons
                        
                    case .tentacles:
                        textAnswerField
                        
                    case .photos:
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
                if questionData.questionCategory == .tentacles {
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
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Timer Methods
    
    private func startTimer() {
        // Calculate initial time remaining
        updateTimeRemaining()
        
        // Start updating every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTimeRemaining()
        }
    }
    
    private func updateTimeRemaining() {
        let elapsed = Date().timeIntervalSince(message.timestamp)
        let timeLimit = questionTimeLimit
        timeRemaining = max(0, timeLimit - elapsed)
    }
    
    private var questionTimeLimit: TimeInterval {
        // Photo questions: 10 minutes, all others: 5 minutes
        return questionData.questionCategory == .photos ? 600 : 300
    }
    
    private var timeRemainingText: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        
        if timeRemaining <= 0 {
            return "Time's up!"
        } else if minutes > 0 {
            return String(format: "%d:%02d remaining", minutes, seconds)
        } else {
            return String(format: "%d seconds remaining", seconds)
        }
    }
    
    // MARK: - Answer Type Views
    
    private var yesNoButtons: some View {
        HStack(spacing: 12) {
            // Yes = green, No = red for stronger contrast on white
            answerButton(
                title: "Yes",
                icon: "checkmark.circle.fill",
            )
            answerButton(
                title: "No",
                icon: "xmark.circle.fill",
            )
        }
    }
    
    private var closerFurtherButtons: some View {
        HStack(spacing: 12) {
            answerButton(title: "Hotter", icon: "arrow.down.circle.fill")
            answerButton(title: "Colder", icon: "arrow.up.circle.fill")
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
    
    private func answerButton(
        title: String,
        icon: String,
        background: Color = .white,
        foreground: Color = .blue
    ) -> some View {
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
            .foregroundColor(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        // Avoid default control tint briefly flashing system blue
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }
    
    // MARK: - Helper Properties
    
    private var canSubmit: Bool {
        switch questionData.questionCategory {
        case .tentacles:
            return !textAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .photos:
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
        switch questionData.questionCategory {
        case .tentacles:
            answer = textAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        case .photos:
            answer = "Photo submitted"
        default:
            answer = selectedAnswer ?? ""
        }
        
        Task {
            do {
                try await gameManager.answerQuestion(
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
                try await gameManager.answerQuestionWithPhoto(
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

// MARK: - Question Timer View
struct QuestionTimerView: View {
    let questionTimestamp: Date
    let questionCategory: QuestionCategory
    
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.caption)
            Text(timeRemainingText)
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .foregroundColor(timeRemaining < 60 ? .yellow : .white.opacity(0.9))
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startTimer() {
        updateTimeRemaining()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTimeRemaining()
        }
    }
    
    private func updateTimeRemaining() {
        let elapsed = Date().timeIntervalSince(questionTimestamp)
        let timeLimit = questionCategory == .photos ? 600.0 : 300.0 // 10 min for photo, 5 min for others
        timeRemaining = max(0, timeLimit - elapsed)
    }
    
    private var timeRemainingText: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        
        if timeRemaining <= 0 {
            return "Time's up!"
        } else if minutes > 0 {
            return String(format: "%d:%02d remaining", minutes, seconds)
        } else {
            return String(format: "%d seconds remaining", seconds)
        }
    }
}
