//
//  OnboardingViewModel.swift
//  Bemo
//
//  ViewModel for onboarding flow and Apple Sign-In
//

// WHAT: Manages onboarding state and Apple Sign-In authentication. Handles authentication flow and user feedback.
// ARCHITECTURE: ViewModel in MVVM-S. Uses AuthenticationService for authentication logic. Publishes state for UI updates.
// USAGE: Created by AppCoordinator with AuthenticationService dependency. Handles Apple Sign-In requests and results.

import Foundation
import AuthenticationServices
import Combine
import Observation

@Observable
class OnboardingViewModel {
    var authenticationError: AuthenticationService.AuthenticationError?
    var isLoading = false
    
    private let authenticationService: AuthenticationService
    private let onAuthenticationComplete: (AuthenticatedUser) -> Void
    private var cancellables = Set<AnyCancellable>()
    
    init(authenticationService: AuthenticationService, onAuthenticationComplete: @escaping (AuthenticatedUser) -> Void) {
        self.authenticationService = authenticationService
        self.onAuthenticationComplete = onAuthenticationComplete
        setupAuthenticationObserver()
    }
    
    private func setupAuthenticationObserver() {
        // With @Observable, we can use withObservationTracking for more granular observation
        // For now, we'll check authentication state changes in the UI
        // The @Observable pattern will automatically update views when properties change
        
        // Set initial state
        if authenticationService.isAuthenticated, let user = authenticationService.currentUser {
            onAuthenticationComplete(user)
        }
        
        // Monitor authentication changes
        Task { @MainActor in
            withObservationTracking {
                _ = authenticationService.isAuthenticated
            } onChange: {
                Task { @MainActor in
                    self.checkAuthenticationStatus()
                    self.setupAuthenticationObserver() // Re-register for future changes
                }
            }
        }
    }
    
    private func checkAuthenticationStatus() {
        if authenticationService.isAuthenticated,
           let user = authenticationService.currentUser {
            isLoading = false
            authenticationError = authenticationService.authenticationError
            onAuthenticationComplete(user)
        }
    }
    
    func configureAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }
    
    func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        isLoading = true
        
        switch result {
        case .success(let authorization):
            // Forward the authorization to AuthenticationService
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                handleAppleIDCredential(appleIDCredential)
            } else {
                authenticationError = .invalidCredential
                isLoading = false
            }
            
        case .failure(let error):
            // Convert the error to our authentication error type
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    authenticationError = .cancelled
                case .failed:
                    authenticationError = .failed
                case .invalidResponse:
                    authenticationError = .invalidCredential
                case .notHandled:
                    authenticationError = .notHandled
                case .unknown:
                    authenticationError = .unknown
                case .notInteractive:
                    authenticationError = .unknown
                default:
                    authenticationError = .unknown
                }
            } else {
                authenticationError = .unknown
            }
            isLoading = false
        }
    }
    
    private func handleAppleIDCredential(_ credential: ASAuthorizationAppleIDCredential) {
        // This should not be called anymore - the AuthenticationService
        // handles the credential directly via its delegate methods
        isLoading = false
    }
    
    func signInWithApple() {
        isLoading = true
        authenticationService.signInWithApple()
    }
    
    func clearError() {
        authenticationError = nil
    }
}

