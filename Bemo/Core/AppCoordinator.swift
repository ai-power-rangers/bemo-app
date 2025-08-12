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
        case devTool(DevTool)
        case parentDashboard
    }
    
    private var currentState: AppState = .loading
    
    init() {
        self.dependencyContainer = DependencyContainer()
        setupAuthenticationObserver()
    }
    
    func start() {
        // Preload puzzles in background for fast access
        Task {
            await dependencyContainer.puzzleManagementService.preloadAllPuzzles()
        }
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
        
        // Observe Supabase connection state
        setupSupabaseObserver()
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
    
    private func setupSupabaseObserver() {
        let supabaseService = dependencyContainer.supabaseService
        
        withObservationTracking {
            // Observe Supabase connection state
            _ = supabaseService.isConnected
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.handleSupabaseConnectionChange()
            }
            // Re-establish observation
            self?.setupSupabaseObserver()
        }
    }
    
    private func handleProfileServiceChange() {
        let authService = dependencyContainer.authenticationService
        let profileService = dependencyContainer.profileService
        
        // Only handle profile changes if user is authenticated
        guard authService.isAuthenticated else { return }
        
        if profileService.hasProfiles {
            // When profiles become available while in setup flows, move to lobby
            switch currentState {
            case .profileSetup, .addChildProfile:
                currentState = .lobby
                // Auto-select the profile if it's the only one
                if profileService.childProfiles.count == 1 && profileService.activeProfile == nil {
                    profileService.setActiveProfile(profileService.childProfiles[0])
                }
            default:
                break
            }
        } else {
            // No profiles exist. Ensure we cannot remain in main app surfaces.
            switch currentState {
            case .onboarding, .profileSetup, .addChildProfile:
                // Already in the correct flow
                break
            default:
                if let user = authService.currentUser {
                    currentState = .profileSetup(user)
                } else {
                    currentState = .onboarding
                }
            }
        }
    }
    
    private func checkAuthenticationAndNavigate() {
        let authService = dependencyContainer.authenticationService
        
        if authService.isAuthenticated {
            let profileService = dependencyContainer.profileService
            
            // Check if we have local profiles first
            // This handles the case where Supabase might not be authenticated yet
            if !profileService.childProfiles.isEmpty {
                // Have local profiles - go to lobby immediately
                currentState = .lobby
                
                // Auto-select if only one profile
                if profileService.childProfiles.count == 1 && profileService.activeProfile == nil {
                    profileService.setActiveProfile(profileService.childProfiles[0])
                }
                
                // Try to sync from Supabase in background (will work if Supabase session exists)
                profileService.syncWithSupabase()
            } else {
                // No local profiles - try to sync from Supabase
                profileService.syncWithSupabase()
                
                // Give sync a moment to complete, then check for profiles
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second for sync
                    
                    await MainActor.run {
                        // After sync attempt, check if any profiles exist
                        if profileService.childProfiles.isEmpty {
                            // No profiles exist at all - go to profile setup
                            if let currentUser = authService.currentUser {
                                self.currentState = .profileSetup(currentUser)
                            }
                        } else {
                            // Profiles were synced - go to lobby
                            self.currentState = .lobby
                            
                            // Auto-select if only one profile
                            if profileService.childProfiles.count == 1 && profileService.activeProfile == nil {
                                profileService.setActiveProfile(profileService.childProfiles[0])
                            }
                        }
                    }
                }
            }
        } else {
            // Not authenticated, show onboarding
            currentState = .onboarding
        }
    }
    
    private func handleAuthenticationChange(isAuthenticated: Bool) {
        if !isAuthenticated {
            // User signed out, only clear active profile selection (not all profiles)
            dependencyContainer.profileService.clearActiveProfile()
            currentState = .onboarding
        } else {
            // User signed in, filter profiles for current user and sync
            dependencyContainer.profileService.filterProfilesForCurrentUser()
            dependencyContainer.profileService.syncWithSupabase()
            checkAuthenticationAndNavigate()
        }
    }
    
    private func handleSupabaseConnectionChange() {
        // When Supabase connection state changes, we may need to update navigation
        let isConnected = dependencyContainer.supabaseService.isConnected
        
        if isConnected {
            print("Supabase connected - checking authentication state")
            // If we were waiting for Supabase to connect, check navigation again
            if dependencyContainer.authenticationService.isAuthenticated {
                checkAuthenticationAndNavigate()
            }
        } else {
            print("Supabase disconnected")
            // If we lose Supabase connection while in profile setup, we should handle it
            switch currentState {
            case .profileSetup, .addChildProfile:
                // Can't create profiles without Supabase - redirect to onboarding
                print("Lost Supabase connection during profile setup - redirecting to onboarding")
                currentState = .onboarding
            default:
                // Other states can continue offline
                break
            }
        }
    }
    
    /// Check if user is fully authenticated (both Apple Sign In and Supabase)
    private func isFullyAuthenticated() -> Bool {
        return dependencyContainer.authenticationService.isAuthenticated &&
               dependencyContainer.supabaseService.isConnected
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
                authenticationService: self.dependencyContainer.authenticationService,
                onProfileSetupComplete: { [weak self] in
                    self?.currentState = .lobby
                },
                onBackRequested: { [weak self] in
                    self?.currentState = .onboarding
                }
            ))
            
        case .addChildProfile(let user):
            // Verify user is fully authenticated (Apple + Supabase) before showing profile setup
            if isFullyAuthenticated() {
                ProfileSetupView(viewModel: ProfileSetupViewModel(
                    authenticatedUser: user,
                    profileService: self.dependencyContainer.profileService,
                    apiService: self.dependencyContainer.apiService,
                    authenticationService: self.dependencyContainer.authenticationService,
                    onProfileSetupComplete: { [weak self] in
                        self?.currentState = .lobby
                    },
                    onBackRequested: { [weak self] in
                        self?.currentState = .lobby
                    }
                ))
            } else {
                // User is not fully authenticated, redirect to onboarding
                OnboardingView(viewModel: OnboardingViewModel(
                    authenticationService: self.dependencyContainer.authenticationService,
                    onAuthenticationComplete: { [weak self] user in
                        self?.checkAuthenticationAndNavigate()
                    }
                ))
            }
            
        case .lobby:
            GameLobbyView(viewModel: GameLobbyViewModel(
                profileService: self.dependencyContainer.profileService,
                supabaseService: self.dependencyContainer.supabaseService,
                puzzleManagementService: self.dependencyContainer.puzzleManagementService,
                developerService: self.dependencyContainer.developerService,
                onGameSelected: { [weak self] selectedGame in
                    self?.currentState = .game(selectedGame)
                },
                onDevToolSelected: { [weak self] selectedDevTool in
                    self?.currentState = .devTool(selectedDevTool)
                },
                onParentDashboardRequested: { [weak self] in
                    self?.currentState = .parentDashboard
                },
                onProfileSetupRequested: { [weak self] in
                    guard let self = self else { return }
                    
                    // Check full authentication status
                    if let currentUser = self.dependencyContainer.authenticationService.currentUser,
                       self.isFullyAuthenticated() {
                        self.currentState = .addChildProfile(currentUser)
                    } else {
                        // Not fully authenticated - redirect to onboarding
                        print("Profile setup requested but user not fully authenticated")
                        self.currentState = .onboarding
                    }
                }
            ))
            
        case .game(let game):
            GameHostView(viewModel: {
                // Configure TangramGame with child profile ID before creating view model
                if let tangramGame = game as? TangramGame,
                   let childProfileId = self.dependencyContainer.profileService.activeProfile?.id {
                    tangramGame.setChildProfileId(childProfileId)
                }
                
                return GameHostViewModel(
                    game: game,
                    cvService: self.dependencyContainer.cvService,
                    profileService: self.dependencyContainer.profileService,
                    supabaseService: self.dependencyContainer.supabaseService,
                    errorTrackingService: self.dependencyContainer.errorTrackingService,
                    currentChildProfileId: self.dependencyContainer.profileService.activeProfile!.id,
                    onQuit: { [weak self] in
                        self?.currentState = .lobby
                    }
                )
            }())
            
        case .devTool(let devTool):
            DevToolHostView(viewModel: {
                return DevToolHostViewModel(
                    devTool: devTool,
                    supabaseService: self.dependencyContainer.puzzleSupabaseService, // Use service role version
                    errorTrackingService: self.dependencyContainer.errorTrackingService,
                    onQuit: { [weak self] in
                        self?.currentState = .lobby
                    }
                )
            }())
            
        case .parentDashboard:
            ParentDashboardView(viewModel: ParentDashboardViewModel(
                profileService: self.dependencyContainer.profileService,
                apiService: self.dependencyContainer.apiService,
                authenticationService: self.dependencyContainer.authenticationService,
                onDismiss: { [weak self] in
                    guard let self else { return }
                    let profileService = self.dependencyContainer.profileService
                    let authService = self.dependencyContainer.authenticationService
                    if profileService.hasProfiles {
                        self.currentState = .lobby
                    } else if let user = authService.currentUser {
                        // No profiles remain: take user to initial profile setup flow
                        self.currentState = .profileSetup(user)
                    } else {
                        // Not authenticated anymore
                        self.currentState = .onboarding
                    }
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
