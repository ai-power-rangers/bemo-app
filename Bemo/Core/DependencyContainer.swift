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
    let apiService: APIService
    let cvService: CVService
    let gamificationService: GamificationService
    let profileService: ProfileService
    
    init() {
        self.apiService = APIService()
        self.profileService = ProfileService()
        self.cvService = CVService()
        self.gamificationService = GamificationService(profileService: profileService)
        
        // Initialize services that need setup
        setupServices()
    }
    
    private func setupServices() {
        // Perform any necessary service initialization
        cvService.initialize()
    }
}