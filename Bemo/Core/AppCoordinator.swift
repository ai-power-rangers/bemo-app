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
            // Access the properties we want to observe
            _ = authService.isAuthenticated
            _ = authService.currentUser
        } onChange: { [weak self] in
            // This will be called when isAuthenticated or currentUser changes
            Task { @MainActor in
                await self?.handleAuthenticationChange(isAuthenticated: authService.isAuthenticated)
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
            // Observe hasProfiles, activeProfile, and sync status changes
            _ = profileService.hasProfiles
            _ = profileService.activeProfile
            _ = profileService.hasSyncedAtLeastOnce
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
        
        print("AppCoordinator: handleProfileServiceChange called - hasProfiles: \(profileService.hasProfiles), hasSyncedAtLeastOnce: \(profileService.hasSyncedAtLeastOnce)")
        
        // Only handle profile changes if user is authenticated
        guard authService.isAuthenticated else { return }
        
        if profileService.hasProfiles {
            // When profiles become available while in setup or loading flows, move to lobby
            switch currentState {
            case .loading, .profileSetup, .addChildProfile:
                currentState = .lobby
                // Auto-select the profile if it's the only one
                if profileService.childProfiles.count == 1 && profileService.activeProfile == nil {
                    profileService.setActiveProfile(profileService.childProfiles[0])
                }
            default:
                break
            }
        } else if profileService.hasSyncedAtLeastOnce {
            // Sync completed but no profiles exist - navigate to profile setup
            switch currentState {
            case .loading:
                if let user = authService.currentUser {
                    print("AppCoordinator: Navigating from loading to profileSetup after sync completed with no profiles")
                    currentState = .profileSetup(user)
                } else {
                    currentState = .onboarding
                }
            case .onboarding, .profileSetup, .addChildProfile:
                // Already in the correct flow
                print("AppCoordinator: Already in correct flow, not changing state")
                break
            default:
                if let user = authService.currentUser {
                    print("AppCoordinator: Navigating to profileSetup from \(currentState)")
                    currentState = .profileSetup(user)
                } else {
                    currentState = .onboarding
                }
            }
        }
        // If not synced yet, stay in current state (e.g., loading)
    }
    
    private func checkAuthenticationAndNavigate() {
        let authService = dependencyContainer.authenticationService
        
        if authService.isAuthenticated {
            // If we are authenticated but don't have the user object yet,
            // it means we are waiting for Supabase to confirm the session.
            // Show a loading view to prevent flashing irrelevant screens.
            guard let user = authService.currentUser else {
                currentState = .loading
                return
            }

            let profileService = dependencyContainer.profileService
            
            // Sync is triggered from handleAuthenticationChange, so we just check state here.
            
            // First check if we have profiles at all
            if profileService.childProfiles.isEmpty {
                // No profiles exist
                if profileService.hasSyncedAtLeastOnce {
                    // Sync completed but no profiles - user needs to create their first profile
                    print("AppCoordinator: Sync complete with no profiles - navigating to profile setup")
                    currentState = .profileSetup(user)
                } else {
                    // Still waiting for sync to complete
                    print("AppCoordinator: No profiles yet, waiting for sync to complete")
                    currentState = .loading
                }
            } else if profileService.profilesBelong(to: user.id) {
                // We have profiles and they belong to the current user
                currentState = .lobby
                // If there's an active profile saved, it will be used.
                // If not, and there's only one profile, set it as active.
                if profileService.activeProfile == nil && profileService.childProfiles.count == 1 {
                    profileService.setActiveProfile(profileService.childProfiles[0])
                }
            } else {
                // Profiles exist but belong to a different user
                // Wait for sync to fetch correct profiles or confirm no profiles exist
                if profileService.hasSyncedAtLeastOnce {
                    // Sync completed, and we still have wrong user's profiles
                    // This means current user has no profiles
                    currentState = .profileSetup(user)
                } else {
                    currentState = .loading
                }
            }
        } else {
            // Not authenticated, show onboarding
            currentState = .onboarding
        }
    }
    
    private func handleAuthenticationChange(isAuthenticated: Bool) async {
        if !isAuthenticated {
            // User signed out, only clear active profile selection (not all profiles)
            dependencyContainer.profileService.clearActiveProfile()
            currentState = .onboarding
        } else {
            // User signed in, filter profiles for current user and sync
            await dependencyContainer.profileService.filterProfilesForCurrentUser()
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
                learningService: self.dependencyContainer.learningService,
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
                    learningService: self.dependencyContainer.learningService,
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
                supabaseService: self.dependencyContainer.supabaseService,
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
