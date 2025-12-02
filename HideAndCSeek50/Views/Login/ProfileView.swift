//
//  ProfileView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import SwiftUI
import FirebaseAuth
import PhotosUI

struct ProfileView: View {
    let user: User?
    let stats: UserStats?
    
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var databaseManager = DatabaseManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName = ""
    @State private var profileImage: Image?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isEditingName = false
    @State private var isLoading = false
    @State private var loadedStats: UserStats?
    @State private var errorMessage: String?
    @State private var showingSignOut = false
    @State private var showingLinkEmail = false
    @State private var showingLinkApple = false
    
    private var currentStats: UserStats? {
        loadedStats ?? stats
    }
    
    private var isGuest: Bool {
        user?.isAnonymous ?? false
    }
    
    private var currentDisplayName: String {
        if !displayName.isEmpty {
            return displayName
        } else if let userDisplayName = user?.displayName, !userDisplayName.isEmpty {
            return userDisplayName
        } else if let email = user?.email {
            return String(email.prefix(while: { $0 != "@" })).capitalized
        } else {
            return "Guest"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeaderSection
                    
                    // Stats Section
                    if let stats = currentStats {
                        statsSection(stats: stats)
                    }
                    
                    // Account Management Section
                    accountManagementSection
                    
                    // Guest Account Upgrade (if applicable)
                    if isGuest {
                        upgradeAccountSection
                    }
                    
                    // Settings Section
                    settingsSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await saveProfile() }
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                loadUserData()
                loadUserStats()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .confirmationDialog("Sign Out", isPresented: $showingSignOut, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    handleSignOut()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .sheet(isPresented: $showingLinkEmail) {
                LinkEmailView()
            }
            .sheet(isPresented: $showingLinkApple) {
                LinkAppleView()
            }
        }
    }
    
    // MARK: - Profile Header Section
    
    private var profileHeaderSection: some View {
        VStack(spacing: 20) {
            // Profile Photo
            VStack(spacing: 12) {
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    ZStack {
                        if let profileImage = profileImage {
                            profileImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Text(String(currentDisplayName.prefix(1)))
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        
                        // Camera overlay
                        Circle()
                            .fill(.black.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            )
                            .opacity(selectedPhoto != nil ? 0 : 1)
                    }
                }
                .onChange(of: selectedPhoto) { _, newValue in
                    loadSelectedPhoto(newValue)
                }
                
                Text("Tap to change photo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Display Name
            VStack(spacing: 8) {
                if isEditingName {
                    TextField("Display Name", text: $displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            isEditingName = false
                        }
                } else {
                    Text(currentDisplayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .onTapGesture {
                            isEditingName = true
                            displayName = currentDisplayName
                        }
                }
                
                if !isEditingName {
                    Text("Tap to edit name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Account Type Badge
            HStack(spacing: 8) {
                if isGuest {
                    Label("Guest Account", systemImage: "person.crop.circle.badge.questionmark")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.tint(.orange.opacity(0.2)), in: .capsule)
                } else {
                    Label("Account Linked", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.tint(.green.opacity(0.2)), in: .capsule)
                }
                
                if let email = user?.email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Stats Section
    
    private func statsSection(stats: UserStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Game Statistics")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Overall Stats
            HStack(spacing: 16) {
                statCard(
                    title: "Games Played",
                    value: "\(stats.totalGamesPlayed)",
                    icon: "gamecontroller.fill",
                    color: .pink
                )
                
                statCard(
                    title: "As Hider",
                    value: "\(stats.hiderStats.gamesPlayed)",
                    icon: "eye.slash.fill",
                    color: .blue
                )
                
                statCard(
                    title: "As Seeker",
                    value: "\(stats.seekerStats.gamesPlayed)",
                    icon: "eye.fill",
                    color: .red
                )
            }
            
            // Hider Stats
            if stats.hiderStats.gamesPlayed > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "eye.slash.fill")
                            .foregroundColor(.blue)
                        Text("Hider Stats")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Divider()
                    
                    detailStatRow(
                        label: "Best Hiding Time",
                        value: formatTime(stats.hiderStats.bestHidingTime),
                        icon: "trophy.fill",
                        color: .yellow
                    )
                    
                    detailStatRow(
                        label: "Average Hiding Time",
                        value: formatTime(stats.hiderStats.averageHidingTime),
                        icon: "clock.fill",
                        color: .blue
                    )
                }
                .padding(12)
                .background(.blue.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Seeker Stats
            if stats.seekerStats.gamesPlayed > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "eye.fill")
                            .foregroundColor(.red)
                        Text("Seeker Stats")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Divider()
                    
                    detailStatRow(
                        label: "Best Find Time",
                        value: formatTime(stats.seekerStats.bestFindTime),
                        icon: "trophy.fill",
                        color: .yellow
                    )
                    
                    detailStatRow(
                        label: "Average Find Time",
                        value: formatTime(stats.seekerStats.averageFindTime),
                        icon: "clock.fill",
                        color: .red
                    )
                }
                .padding(12)
                .background(.red.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Achievements
            if hasAnyAchievement(stats.achievements) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "rosette")
                            .foregroundColor(.yellow)
                        Text("Achievements")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Divider()
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                        if stats.achievements.quickSeeker {
                            achievementBadge(
                                title: "Quick Seeker",
                                icon: "bolt.fill",
                                color: .orange
                            )
                        }
                        
                        if stats.achievements.masterHider {
                            achievementBadge(
                                title: "Master Hider",
                                icon: "star.fill",
                                color: .purple
                            )
                        }
                        
                        if stats.achievements.teamPlayer {
                            achievementBadge(
                                title: "Team Player",
                                icon: "person.3.fill",
                                color: .blue
                            )
                        }
                        
                        if stats.achievements.veteran {
                            achievementBadge(
                                title: "Veteran",
                                icon: "medal.fill",
                                color: .yellow
                            )
                        }
                    }
                }
                .padding(12)
                .background(.yellow.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(20)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .glassEffect(.regular.tint(color.opacity(0.1)), in: .rect(cornerRadius: 12))
    }
    
    private func detailStatRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
    
    private func achievementBadge(title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.2))
        .cornerRadius(8)
    }
    
    private func hasAnyAchievement(_ achievements: Achievements) -> Bool {
        achievements.quickSeeker || achievements.masterHider || 
        achievements.teamPlayer || achievements.veteran
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        if timeInterval == 0 {
            return "N/A"
        }
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    // MARK: - Account Management Section
    
    private var accountManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                accountRow(
                    title: "Email",
                    value: user?.email ?? "Not linked",
                    icon: "envelope.fill"
                )
                
                accountRow(
                    title: "User ID",
                    value: user?.uid.prefix(8).description ?? "Unknown",
                    icon: "person.badge.key.fill"
                )
                
                accountRow(
                    title: "Account Created",
                    value: formatDate(user?.metadata.creationDate),
                    icon: "calendar.circle.fill"
                )
            }
        }
        .padding(20)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func accountRow(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Upgrade Account Section
    
    private var upgradeAccountSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Save Your Progress")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Link your account to save stats and never lose your progress")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    showingLinkEmail = true
                }) {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("Link with Email")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)
                
                Button(action: {
                    showingLinkApple = true
                }) {
                    HStack {
                        Image(systemName: "applelogo")
                        Text("Link with Apple ID")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.black)
            }
        }
        .padding(20)
        .glassEffect(.regular.tint(.yellow.opacity(0.1)), in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.yellow.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                settingsRow(
                    title: "Notifications",
                    icon: "bell.fill",
                    action: {
                        // Handle notifications
                    }
                )
                
                settingsRow(
                    title: "Privacy",
                    icon: "lock.fill",
                    action: {
                        // Handle privacy
                    }
                )
                
                settingsRow(
                    title: "Help & Support",
                    icon: "questionmark.circle.fill",
                    action: {
                        // Handle help
                    }
                )
                
                Divider()
                
                Button(action: {
                    showingSignOut = true
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                        Text("Sign Out")
                            .foregroundColor(.red)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func settingsRow(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func loadUserData() {
        if let userDisplayName = user?.displayName, !userDisplayName.isEmpty {
            displayName = userDisplayName
        } else if let email = user?.email {
            displayName = String(email.prefix(while: { $0 != "@" })).capitalized
        }
    }
    
    private func loadUserStats() {
        guard let user = user, stats == nil else { return }
        
        Task {
            do {
                let userStats = try await databaseManager.getUserStats(uid: user.uid)
                await MainActor.run {
                    self.loadedStats = userStats
                }
            } catch {
                await MainActor.run {
                    self.loadedStats = UserStats() // Default stats if loading fails
                }
            }
        }
    }
    
    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        Task {
            guard let item = item,
                  let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                return
            }
            
            await MainActor.run {
                profileImage = Image(uiImage: uiImage)
            }
        }
    }
    
    private func saveProfile() async {
        guard let user = user else { return }
        
        isLoading = true
        
        do {
            // Update display name if changed
            if !displayName.isEmpty && displayName != user.displayName {
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
                
                // Update in database
                let profile = UserProfile(
                    uid: user.uid,
                    displayName: displayName,
                    email: user.email,
                    isAnonymous: user.isAnonymous,
                    createdAt: user.metadata.creationDate ?? Date(),
                    lastActive: Date(),
                    avatarURL: nil // TODO: Upload image if selected
                )
                
                try await databaseManager.updateUserProfile(profile)
            }
            
            await MainActor.run {
                isLoading = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save profile: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func handleSignOut() {
        do {
            try authManager.signOut()
            dismiss()
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Link Email View

struct LinkEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Link Email Account") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                }
                
                Section {
                    Button("Link Account") {
                        Task { await linkEmail() }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                } footer: {
                    Text("This will link your current progress to an email account.")
                }
            }
            .navigationTitle("Link Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private func linkEmail() async {
        isLoading = true
        
        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await Auth.auth().currentUser?.link(with: credential)
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Link Apple View

struct LinkAppleView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "applelogo")
                    .font(.system(size: 60))
                    .foregroundColor(.primary)
                
                Text("Link with Apple ID")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Sign in with Apple to link your account and save your progress securely.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Continue with Apple") {
                    // TODO: Implement Sign in with Apple linking
                }
                .buttonStyle(.glassProminent)
                .tint(.black)
                
                Spacer()
            }
            .padding(30)
            .navigationTitle("Link Apple ID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView(user: nil, stats: UserStats())
}
