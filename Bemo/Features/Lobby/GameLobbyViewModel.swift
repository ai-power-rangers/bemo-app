//
//  GameLobbyViewModel.swift
//  Bemo
//
//  ViewModel for the game selection lobby
//

// WHAT: Manages game lobby state including available games, active profile, and navigation callbacks to games/parent dashboard.
// ARCHITECTURE: ViewModel in MVVM-S handling lobby logic. Depends on ProfileService and GamificationService for user data.
// USAGE: Created by AppCoordinator with navigation callbacks. Observe profile changes via callback, validate game access, handle selection.

import SwiftUI

class GameLobbyViewModel: ObservableObject {
    @Published var availableGames: [GameItem] = []
    @Published var activeProfile: Profile?
    @Published var showProfileSelection = false
    
    // Always returns a profile for display (either active or default)
    var displayProfile: Profile {
        if let activeProfile = activeProfile {
            return activeProfile
        } else {
            let currentUserProfile = profileService.currentProfile
            return Profile(
                id: currentUserProfile.id,
                name: currentUserProfile.name,
                level: calculateLevel(from: currentUserProfile.totalXP),
                xp: currentUserProfile.totalXP
            )
        }
    }
    
    private let profileService: ProfileService
    private let gamificationService: GamificationService
    private let onGameSelected: (Game) -> Void
    private let onParentDashboardRequested: () -> Void
    
    // Display models
    struct Profile {
        let id: String
        let name: String
        let level: Int
        let xp: Int
    }
    
    struct GameItem: Identifiable {
        let id = UUID()
        let game: Game
        let iconName: String
        let color: Color
    }
    
    init(
        profileService: ProfileService,
        gamificationService: GamificationService,
        onGameSelected: @escaping (Game) -> Void,
        onParentDashboardRequested: @escaping () -> Void
    ) {
        self.profileService = profileService
        self.gamificationService = gamificationService
        self.onGameSelected = onGameSelected
        self.onParentDashboardRequested = onParentDashboardRequested
        
        setupProfileObserver()
        loadGames()
    }
    
    private func setupProfileObserver() {
        // Set initial profile from service
        updateActiveProfile(profileService.activeProfile)
        
        // Use callback to observe profile changes
        profileService.onProfileChanged = { [weak self] profile in
            self?.updateActiveProfile(profile)
        }
    }
    
    private func loadGames() {
        // Load available games
        // In a real app, this would come from a configuration or backend
        let tangramGame = TangramGame()
        
        availableGames = [
            GameItem(
                game: tangramGame,
                iconName: "square.on.square",
                color: .blue
            )
            // Add more games here as they're implemented
        ]
    }
    
    private func updateActiveProfile(_ profile: UserProfile?) {
        if let profile = profile {
            activeProfile = Profile(
                id: profile.id,
                name: profile.name,
                level: calculateLevel(from: profile.totalXP),
                xp: profile.totalXP
            )
        } else {
            activeProfile = nil
        }
    }
    
    private func calculateLevel(from xp: Int) -> Int {
        // Simple level calculation
        return (xp / 100) + 1
    }
    
    func isGameUnlocked(_ game: Game) -> Bool {
        // Check if the player meets the requirements for this game
        // Always has a profile (active or default) via currentProfile
        let currentUserProfile = profileService.currentProfile
        
        // For now, all games are unlocked
        // In a real app, this would check level requirements, completed prerequisites, etc.
        return true
    }
    
    func selectGame(_ game: Game) {
        // Use currentProfile which always returns a profile (active or default)
        let currentUserProfile = profileService.currentProfile
        let profile = Profile(
            id: currentUserProfile.id,
            name: currentUserProfile.name,
            level: calculateLevel(from: currentUserProfile.totalXP),
            xp: currentUserProfile.totalXP
        )
        
        // Simple direct call to analytics
        if let analyticsService = getAnalyticsService() {
            analyticsService.trackGameSelected(
                gameId: game.id,
                gameTitle: game.title,
                userId: profile.id
            )
        }
        
        // Navigate to game
        onGameSelected(game)
    }
    
    func openParentDashboard() {
        print("Opening parent dashboard")
        onParentDashboardRequested()
    }

    // You can inject analytics service directly, or access it through a simple method
    private func getAnalyticsService() -> AnalyticsService? {
        // Could be injected via init, or accessed through app coordinator
        return nil // Implement based on your preference
    }
}