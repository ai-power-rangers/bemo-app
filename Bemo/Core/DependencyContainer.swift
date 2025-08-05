//
//  DependencyContainer.swift
//  Bemo
//
//  Central container for creating and holding all service dependencies
//

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