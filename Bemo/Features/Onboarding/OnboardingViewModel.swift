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
    private let characterAnimationService: CharacterAnimationService?
    private let onAuthenticationComplete: (AuthenticatedUser) -> Void
    private var cancellables = Set<AnyCancellable>()
    
    init(authenticationService: AuthenticationService, characterAnimationService: CharacterAnimationService? = nil, onAuthenticationComplete: @escaping (AuthenticatedUser) -> Void) {
        self.authenticationService = authenticationService
        self.characterAnimationService = characterAnimationService
        self.onAuthenticationComplete = onAuthenticationComplete
        setupAuthenticationObserver()
        
        // Show waving character on onboarding start
        showWelcomeAnimation()
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
        // Clear the looping animation when user starts sign in
        characterAnimationService?.clearAllAnimations()
        authenticationService.signInWithApple()
    }
    
    func showSignInCharacter() {
        // Show a cheerful waving character on the sign-in screen that loops indefinitely
        print("CharacterAnimationService: Showing sign-in character with loop=true")
        characterAnimationService?.showCharacter(
            .waving,
            at: .topCenter,
            size: CGSize(width: 150, height: 150),
            duration: 3.0,
            interactive: true,
            onTap: { [weak self] in
                // Wave again when tapped with a fun bounce effect
                print("CharacterAnimationService: Character tapped, showing bounce effect")
                self?.characterAnimationService?.showCharacter(
                    .waving,
                    at: .topCenter,
                    size: CGSize(width: 170, height: 170),
                    duration: 2.5,
                    scale: 1.2,
                    rotation: -10,
                    loop: true  // Keep looping on tap as well
                )
            },
            loop: true  // Loop the animation indefinitely
        )
    }
    
    func clearError() {
        authenticationError = nil
    }
    
    // MARK: - Character Animations
    
    private func showWelcomeAnimation() {
        // Show waving character with a slight delay for better visual effect
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
            await MainActor.run {
                characterAnimationService?.showWelcome(at: .bottomRight)
            }
        }
    }
    
    func showCharacterForStep(_ step: Int) {
        // Show character at different positions for different onboarding steps
        let positions: [CharacterAnimationService.AnimationPosition] = [
            .bottomRight,  // Step 0: Tangram Adventures
            .topLeft,      // Step 1: Real Objects
            .bottomLeft,   // Step 2: Progress Tracking
            .topRight      // Step 3: Parent Dashboard
        ]
        
        if step < positions.count {
            characterAnimationService?.showCharacter(
                .waving,
                at: positions[step],
                size: CGSize(width: 120, height: 120),
                duration: 2.5,
                interactive: true,
                onTap: { [weak self] in
                    // Make the character wave again when tapped
                    self?.characterAnimationService?.showCharacter(
                        .waving,
                        at: positions[step],
                        size: CGSize(width: 140, height: 140), // Slightly bigger
                        duration: 2.0,
                        scale: 1.1
                    )
                }
            )
        }
    }
}

