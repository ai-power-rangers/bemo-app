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
    let puzzleManagementService: PuzzleManagementService
    
    init() {
        // Initialize error tracking first so it's available for other services
        self.errorTrackingService = ErrorTrackingService()
        
        self.authenticationService = AuthenticationService()
        self.apiService = APIService(authenticationService: authenticationService)
        self.profileService = ProfileService()
        self.cvService = CVService()
        self.analyticsService = AnalyticsService()
        // Use service role for Supabase to ensure puzzle loading always works
        self.supabaseService = SupabaseService(errorTracking: errorTrackingService, useServiceRole: true)
        self.puzzleManagementService = PuzzleManagementService(supabaseService: supabaseService, errorTracking: errorTrackingService)
        
        // Initialize services that need setup
        setupServices()
    }
    
    private func setupServices() {
        // Perform any necessary service initialization
        cvService.initialize()
        
        // Setup Supabase integration with existing services
        authenticationService.setSupabaseService(supabaseService)
        profileService.setSupabaseService(supabaseService)
        
        // Setup error tracking integration
        authenticationService.setErrorTrackingService(errorTrackingService)
        profileService.setErrorTrackingService(errorTrackingService)
        
        // Trigger initial profile sync from Supabase if user is already authenticated
        if authenticationService.isAuthenticated {
            profileService.syncWithSupabase()
        }
    }
}
