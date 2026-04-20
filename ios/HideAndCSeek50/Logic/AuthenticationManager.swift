//
//  AuthenticationManager.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import Foundation
import Firebase
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit
internal import Combine

@MainActor
class AuthenticationManager: ObservableObject {    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private var currentNonce: String?
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
        // Listen for authentication state changes
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
        }
    }
    
    deinit {
        if let authStateListener = authStateListener {
            Auth.auth().removeStateDidChangeListener(authStateListener)
        }
    }
    
    // MARK: - Apple Sign In
    
    func generateNonce() -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = 32
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        currentNonce = result
        return result
    }
    
    func sha256Hash(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    @MainActor
    func signInWithApple(_ authorization: ASAuthorization) async throws -> User {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthenticationError.invalidCredential
        }
        
        let credential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idTokenString,
            rawNonce: nonce
        )
        
        let result = try await Auth.auth().signIn(with: credential)
        
        // Create user profile in database
        await createUserProfileIfNeeded(user: result.user, fullName: appleIDCredential.fullName)
        
        return result.user
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() async throws -> User {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthenticationError.missingClientID
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            throw AuthenticationError.noRootViewController
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthenticationError.invalidCredential
        }
        
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        
        let authResult = try await Auth.auth().signIn(with: credential)
        
        // Create user profile in database
        await createUserProfileIfNeeded(user: authResult.user)
        
        return authResult.user
    }
    
    // MARK: - Email/Password Authentication
    
    func signInWithEmail(email: String, password: String) async throws -> User {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            
            // Create user profile in database if needed
            await createUserProfileIfNeeded(user: result.user)
            
            return result.user
        } catch let error as NSError {
            // Convert Firebase Auth errors to our custom errors
            if let authErrorCode = AuthErrorCode(rawValue: error.code) {
                switch authErrorCode {
                case .wrongPassword:
                    throw AuthenticationError.incorrectPassword
                case .userNotFound:
                    throw AuthenticationError.accountDoesNotExist
                case .invalidEmail:
                    throw AuthenticationError.invalidEmail
                case .userDisabled:
                    throw AuthenticationError.accountDisabled
                case .tooManyRequests:
                    throw AuthenticationError.tooManyAttempts
                default:
                    throw AuthenticationError.signInFailed(error.localizedDescription)
                }
            } else {
                throw AuthenticationError.signInFailed(error.localizedDescription)
            }
        }
    }
    
    func createAccount(email: String, password: String) async throws -> User {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Create user profile in database for new account
            await createUserProfileIfNeeded(user: result.user)
            
            return result.user
        } catch let error as NSError {
            // Convert Firebase Auth errors to our custom errors
            if let authErrorCode = AuthErrorCode(rawValue: error.code) {
                switch authErrorCode {
                case .emailAlreadyInUse:
                    throw AuthenticationError.emailAlreadyInUse
                case .weakPassword:
                    throw AuthenticationError.weakPassword
                case .invalidEmail:
                    throw AuthenticationError.invalidEmail
                default:
                    throw AuthenticationError.accountCreationFailed(error.localizedDescription)
                }
            } else {
                throw AuthenticationError.accountCreationFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Anonymous Authentication
    
    func signInAnonymously() async throws -> User {
        let result = try await Auth.auth().signInAnonymously()
        
        // Create user profile in database for anonymous user
        await createUserProfileIfNeeded(user: result.user)
        
        return result.user
    }
    
    // MARK: - Sign Out
    
    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }
    
    // MARK: - Account Linking
    
    func linkAnonymousAccountWithEmail(email: String, password: String) async throws -> User {
        guard let currentUser = Auth.auth().currentUser, currentUser.isAnonymous else {
            throw AuthenticationError.notAnonymous
        }
        
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        let result = try await currentUser.link(with: credential)
        return result.user
    }
    
    func linkAnonymousAccountWithApple(_ authorization: ASAuthorization) async throws -> User {
        guard let currentUser = Auth.auth().currentUser, currentUser.isAnonymous else {
            throw AuthenticationError.notAnonymous
        }
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthenticationError.invalidCredential
        }
        
        let credential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idTokenString,
            rawNonce: nonce
        )
        
        let result = try await currentUser.link(with: credential)
        return result.user
    }
    
    func linkAnonymousAccountWithGoogle() async throws -> User {
        guard let currentUser = Auth.auth().currentUser, currentUser.isAnonymous else {
            throw AuthenticationError.notAnonymous
        }
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthenticationError.missingClientID
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            throw AuthenticationError.noRootViewController
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthenticationError.invalidCredential
        }
        
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        
        let authResult = try await currentUser.link(with: credential)
        return authResult.user
    }
    
    // MARK: - User Profile Management
    
    func updateDisplayName(_ displayName: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthenticationError.noCurrentUser
        }
        
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()
    }
    
    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthenticationError.noCurrentUser
        }
        
        try await user.sendEmailVerification()
    }
    
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthenticationError.noCurrentUser
        }
        
        try await user.delete()
    }
    
    // MARK: - Database Integration
    
    private func createUserProfileIfNeeded(user: User, fullName: PersonNameComponents? = nil) async {
        do {
            // Check if user profile already exists
            let _ = try await UserManager.shared.getUserProfile(uid: user.uid)
        } catch DatabaseError.userNotFound {
            // Create new user profile
            let displayName = generateDisplayName(user: user, fullName: fullName)
            let profile = UserProfile(
                uid: user.uid,
                displayName: displayName,
                email: user.email,
                isAnonymous: user.isAnonymous,
                createdAt: Date(),
                lastActive: Date(),
                avatarURL: user.photoURL?.absoluteString
            )

            try? await UserManager.shared.createUser(profile: profile)
        } catch {
            // Handle other errors silently for now
            print("Error checking user profile: \(error)")
        }

        // Idempotent — backfills existing accounts that pre-date the question-sets feature.
        try? await UserManager.shared.seedDefaultQuestionSetIfNeeded(uid: user.uid)
        try? await UserManager.shared.seedDefaultCardDeckIfNeeded(uid: user.uid)
    }
    
    private func generateDisplayName(user: User, fullName: PersonNameComponents? = nil) -> String {
        // Try to get name from Apple Sign In
        if let fullName = fullName {
            let firstName = fullName.givenName ?? ""
            let lastName = fullName.familyName ?? ""
            let combinedName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
            if !combinedName.isEmpty {
                return combinedName
            }
        }
        
        // Try to get name from user profile
        if let displayName = user.displayName, !displayName.isEmpty {
            return displayName
        }
        
        // Generate from email
        if let email = user.email {
            let username = String(email.prefix(while: { $0 != "@" }))
            return username.capitalized
        }
        
        // Anonymous user
        if user.isAnonymous {
            return "Guest Player"
        }
        
        // Fallback
        return "Player"
    }
}

// MARK: - Authentication Errors

enum AuthenticationError: LocalizedError {
    case invalidCredential
    case missingClientID
    case noRootViewController
    case notAnonymous
    case noCurrentUser
    case incorrectPassword
    case accountDoesNotExist
    case invalidEmail
    case accountDisabled
    case tooManyAttempts
    case signInFailed(String)
    case emailAlreadyInUse
    case weakPassword
    case accountCreationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid authentication credential"
        case .missingClientID:
            return "Missing Google client ID"
        case .noRootViewController:
            return "No root view controller found"
        case .notAnonymous:
            return "Current user is not anonymous"
        case .noCurrentUser:
            return "No current user found"
        case .incorrectPassword:
            return "Incorrect password. Please try again."
        case .accountDoesNotExist:
            return "No account found with this email address."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .accountDisabled:
            return "This account has been disabled. Please contact support."
        case .tooManyAttempts:
            return "Too many failed sign-in attempts. Please try again later."
        case .signInFailed(let message):
            return "Sign-in failed: \(message)"
        case .emailAlreadyInUse:
            return "An account with this email address already exists."
        case .weakPassword:
            return "Password is too weak. Please choose a stronger password."
        case .accountCreationFailed(let message):
            return "Account creation failed: \(message)"
        }
    }
}
