//
//  DependencyContainer.swift
//  Bemo
//
//  Central container for creating and holding all service dependencies
//

// WHAT: Service locator that creates and holds all app services (API, CV, Profile, Gamification). Ensures single instances.
// ARCHITECTURE: Dependency injection container in MVVM-S. Created by AppCoordinator and provides services to all ViewModels.
// USAGE: Access via AppCoordinator. Services are created on init. Add new services as properties and initialize in init().

import Foundation

class DependencyContainer {
    let errorTrackingService: ErrorTrackingService
    let authenticationService: AuthenticationService
    let apiService: APIService
    let cvService: CVService
    let profileService: ProfileService
    let analyticsService: AnalyticsService
    let supabaseService: SupabaseService
    let puzzleSupabaseService: SupabaseService  // Service role version for dev tools
    let puzzleManagementService: PuzzleManagementService
    let developerService: DeveloperService
    let learningService: LearningService
    
    init() {
        // Initialize error tracking first so it's available for other services
        self.errorTrackingService = ErrorTrackingService()
        
        self.authenticationService = AuthenticationService()
        self.apiService = APIService(authenticationService: authenticationService)
        self.profileService = ProfileService()
        self.cvService = CVService()
        self.analyticsService = AnalyticsService()
        // Use regular authentication for user data - this ensures proper RLS enforcement
        self.supabaseService = SupabaseService(authService: authenticationService, errorTracking: errorTrackingService, useServiceRole: false)
        
        // Create a separate service role Supabase instance for puzzle management and dev tools
        // This allows operations to work without user authentication constraints
        self.puzzleSupabaseService = SupabaseService(errorTracking: errorTrackingService, useServiceRole: true)
        self.puzzleManagementService = PuzzleManagementService(supabaseService: puzzleSupabaseService, errorTracking: errorTrackingService)
        
        // Initialize developer service for determining dev tool access
        self.developerService = DeveloperService(authenticationService: authenticationService)
        self.learningService = LearningService(
            supabaseService: supabaseService,
            profileService: profileService,
            errorTrackingService: errorTrackingService
        )
        
        // Initialize services that need setup
        setupServices()
    }
    
    private func setupServices() {
        // Perform any necessary service initialization
        cvService.initialize()
        
        // Setup Supabase integration with existing services
        authenticationService.setSupabaseService(supabaseService)
        profileService.setSupabaseService(supabaseService)
        apiService.setSupabaseService(supabaseService)
        
        // Setup cross-service dependencies
        profileService.setAuthenticationService(authenticationService)
        authenticationService.setProfileService(profileService)
        
        // Setup error tracking integration
        authenticationService.setErrorTrackingService(errorTrackingService)
        profileService.setErrorTrackingService(errorTrackingService)
    }
}
