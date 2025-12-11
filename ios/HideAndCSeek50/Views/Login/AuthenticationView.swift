//
//  AuthenticationView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices

struct AuthenticationView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var isShowingEmailSignIn = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // App Logo and Title
                    VStack(spacing: 8) {
                        Image("HideAndSeekIcon")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70, height: 70)
                            .foregroundColor(.white)
                            .shadow(radius: 10)
                            .padding(.bottom, 8)
                        
                        Text("Hide and CSeek50")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("An IRL + Digital Hide and Seek Adventure")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        
                        Text("By Noah Bruaner, Jack Ploof, and Ryan Eto")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    // Authentication Options
                    VStack(spacing: 16) {
                        
                        // Apple Sign In
                        SignInWithAppleButton(
                            onRequest: { request in
                                configureAppleSignInRequest(request)
                            },
                            onCompletion: { result in
                                handleAppleSignInResult(result)
                            }
                        )
                        .signInWithAppleButtonStyle(.whiteOutline)
                        .frame(height: 50)
                        
                        // Google Sign In
                        Button(action: handleGoogleSignIn) {
                            HStack {
                                Image(systemName: "globe")
                                    .font(.title2)
                                Text("Continue with Google")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                        }
                        .disabled(isLoading)
                        
                        // Email/Password Sign In
                        Button(action: { isShowingEmailSignIn = true }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .font(.title2)
                                Text("Continue with Email")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .disabled(isLoading)
                        
                        // Anonymous Sign In
                        Button(action: handleAnonymousSignIn) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.questionmark")
                                    .font(.title2)
                                Text("Continue as Guest")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.clear)
                            .foregroundColor(.white.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
                
                // Loading Overlay
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
        }
        .sheet(isPresented: $isShowingEmailSignIn) {
            EmailSignInView(
                isPresented: $isShowingEmailSignIn,
                onSignInComplete: handleEmailSignInComplete
            )
            .environmentObject(authManager)
        }
        .alert("Authentication Error", isPresented: $showingError) {
            Button("OK") {
                errorMessage = ""
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Authentication Methods
    
    private func configureAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        let rawNonce = authManager.generateNonce()
        request.nonce = authManager.sha256Hash(rawNonce)
    }
    
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            isLoading = true
            Task {
                do {
                    _ = try await authManager.signInWithApple(authorization)
                    await MainActor.run {
                        self.isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        self.handleAuthError(error)
                    }
                }
            }
        case .failure(let error):
            handleAuthError(error)
        }
    }
    
    private func handleGoogleSignIn() {
        isLoading = true
        Task {
            do {
                _ = try await authManager.signInWithGoogle()
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.handleAuthError(error)
                }
            }
        }
    }
    
    private func handleAnonymousSignIn() {
        isLoading = true
        Task {
            do {
                _ = try await authManager.signInAnonymously()
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.handleAuthError(error)
                }
            }
        }
    }
    
    private func handleEmailSignInComplete() {
        // The AuthenticationManager will automatically update the authentication state
        // No local state management needed
    }
    
    private func handleAuthError(_ error: Error) {
        isLoading = false
        errorMessage = error.localizedDescription
        showingError = true
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationManager())
}
