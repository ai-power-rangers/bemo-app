//
//  AppCoordinator.swift
//  Bemo
//
//  Central navigation coordinator that manages app flow with authentication
//

// WHAT: Manages app navigation and view transitions. Holds DependencyContainer and exposes the current root view based on app state including authentication.
// ARCHITECTURE: Central coordinator in MVVM-S. Creates ViewModels with injected dependencies and manages navigation flow between features with auth state.
// USAGE: Create as Observable instance in BemoApp. Access rootView property for display. Call start() to begin app flow with authentication check.

import SwiftUI
import Observation

@Observable
class AppCoordinator {
    private let dependencyContainer: DependencyContainer
    
    enum AppState {
        case loading
        case onboarding
        case profileSetup(AuthenticatedUser)
        case addChildProfile(AuthenticatedUser)
        case lobby
        case game(Game)
        case parentDashboard
    }
    
    private var currentState: AppState = .loading
    
    init() {
        self.dependencyContainer = DependencyContainer()
        setupAuthenticationObserver()
    }
    
    func start() {
        checkAuthenticationAndNavigate()
    }
    
    private func setupAuthenticationObserver() {
        // With @Observable, we can use withObservationTracking for precise observation
        let authService = dependencyContainer.authenticationService
        
        withObservationTracking {
            // Access the property we want to observe
            _ = authService.isAuthenticated
        } onChange: { [weak self] in
            // This will be called when isAuthenticated changes
            Task { @MainActor in
                self?.handleAuthenticationChange(isAuthenticated: authService.isAuthenticated)
            }
            // Re-establish observation
            self?.setupAuthenticationObserver()
        }
        
        // Also observe ProfileService changes
        setupProfileServiceObserver()
    }
    
    private func setupProfileServiceObserver() {
        let profileService = dependencyContainer.profileService
        
        withObservationTracking {
            // Observe both hasProfiles and activeProfile changes
            _ = profileService.hasProfiles
            _ = profileService.activeProfile
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.handleProfileServiceChange()
            }
            // Re-establish observation
            self?.setupProfileServiceObserver()
        }
    }
    
    private func handleProfileServiceChange() {
        let authService = dependencyContainer.authenticationService
        let profileService = dependencyContainer.profileService
        
        // Only handle profile changes if user is authenticated
        guard authService.isAuthenticated else { return }
        
        // If no profiles exist, navigate to profile setup
        if !profileService.hasProfiles {
            if let currentUser = authService.currentUser {
                currentState = .profileSetup(currentUser)
            }
        } else {
            // If profiles exist and we're in profile setup/add child, navigate to lobby
            switch currentState {
            case .profileSetup, .addChildProfile:
                currentState = .lobby
            default:
                break
            }
        }
    }
    
    private func checkAuthenticationAndNavigate() {
        let authService = dependencyContainer.authenticationService
        
        if authService.isAuthenticated {
            // Check if user has child profiles
            if dependencyContainer.profileService.hasProfiles {
                currentState = .lobby
            } else {
                // Authenticated but no profiles exist
                if let currentUser = authService.currentUser {
                    currentState = .profileSetup(currentUser)
                } else {
                    currentState = .onboarding
                }
            }
        } else {
            currentState = .onboarding
        }
    }
    
    private func handleAuthenticationChange(isAuthenticated: Bool) {
        if !isAuthenticated {
            // User signed out, clear profile and go to onboarding
            dependencyContainer.profileService.clearActiveProfile()
            currentState = .onboarding
        } else {
            // User signed in, check for profile setup
            checkAuthenticationAndNavigate()
        }
    }
    
    @ViewBuilder
    var rootView: some View {
        switch currentState {
        case .loading:
            LoadingView()
            
        case .onboarding:
            OnboardingView(viewModel: OnboardingViewModel(
                authenticationService: self.dependencyContainer.authenticationService,
                onAuthenticationComplete: { [weak self] user in
                    // Navigate to profile setup or lobby based on existing profiles
                    self?.checkAuthenticationAndNavigate()
                }
            ))
            
        case .profileSetup(let user):
            ProfileSetupView(viewModel: ProfileSetupViewModel(
                authenticatedUser: user,
                profileService: self.dependencyContainer.profileService,
                apiService: self.dependencyContainer.apiService,
                onProfileSetupComplete: { [weak self] in
                    self?.currentState = .lobby
                }
            ))
            
        case .addChildProfile(let user):
            ProfileSetupView(viewModel: ProfileSetupViewModel(
                authenticatedUser: user,
                profileService: self.dependencyContainer.profileService,
                apiService: self.dependencyContainer.apiService,
                onProfileSetupComplete: { [weak self] in
                    self?.currentState = .lobby
                }
            ))
            
        case .lobby:
            GameLobbyView(viewModel: GameLobbyViewModel(
                profileService: self.dependencyContainer.profileService,
                onGameSelected: { [weak self] selectedGame in
                    self?.currentState = .game(selectedGame)
                },
                onParentDashboardRequested: { [weak self] in
                    self?.currentState = .parentDashboard
                },
                onProfileSetupRequested: { [weak self] in
                    if let currentUser = self?.dependencyContainer.authenticationService.currentUser {
                        self?.currentState = .addChildProfile(currentUser)
                    }
                }
            ))
            
        case .game(let game):
            GameHostView(viewModel: GameHostViewModel(
                game: game,
                cvService: self.dependencyContainer.cvService,
                profileService: self.dependencyContainer.profileService,
                supabaseService: self.dependencyContainer.supabaseService,
                currentChildProfileId: activeProfile.id,
                onQuit: { [weak self] in
                    self?.currentState = .lobby
                }
            ))
            
        case .parentDashboard:
            ParentDashboardView(viewModel: ParentDashboardViewModel(
                profileService: self.dependencyContainer.profileService,
                apiService: self.dependencyContainer.apiService,
                authenticationService: self.dependencyContainer.authenticationService,
                onDismiss: { [weak self] in
                    self?.currentState = .lobby
                },
                onAddChildRequested: { [weak self] in
                    if let currentUser = self?.dependencyContainer.authenticationService.currentUser {
                        self?.currentState = .addChildProfile(currentUser)
                    }
                }
            ))
        }
    }
}
