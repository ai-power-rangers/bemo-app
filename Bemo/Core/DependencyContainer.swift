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
    let authenticationService: AuthenticationService
    let apiService: APIService
    let cvService: CVService
    let profileService: ProfileService
    let analyticsService: AnalyticsService
    
    init() {
        self.authenticationService = AuthenticationService()
        self.apiService = APIService(authenticationService: authenticationService)
        self.profileService = ProfileService()
        self.cvService = CVService()
        self.analyticsService = AnalyticsService()
        
        // Initialize services that need setup
        setupServices()
    }
    
    private func setupServices() {
        // Perform any necessary service initialization
        cvService.initialize()
        
        // Analytics will observe profile changes via @Published properties
        // when needed in the future
    }
}
