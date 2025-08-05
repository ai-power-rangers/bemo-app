//
//  GameLobbyViewModel.swift
//  Bemo
//
//  ViewModel for the game selection lobby
//

// WHAT: Manages game lobby state including available games, active profile, and navigation callbacks to games/parent dashboard.
// ARCHITECTURE: ViewModel in MVVM-S handling lobby logic. Depends on ProfileService and GamificationService for user data.
// USAGE: Created by AppCoordinator with navigation callbacks. Subscribe to profile changes, validate game access, handle selection.

import SwiftUI
import Combine

class GameLobbyViewModel: ObservableObject {
    @Published var availableGames: [GameItem] = []
    @Published var activeProfile: Profile?
    @Published var showProfileSelection = false
    
    private let profileService: ProfileService
    private let gamificationService: GamificationService
    private let onGameSelected: (Game) -> Void
    private let onParentDashboardRequested: () -> Void
    private var cancellables = Set<AnyCancellable>()
    
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
        
        setupBindings()
        loadGames()
    }
    
    private func setupBindings() {
        // Subscribe to profile changes
        profileService.activeProfilePublisher
            .sink { [weak self] profile in
                self?.updateActiveProfile(profile)
            }
            .store(in: &cancellables)
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
        guard let profile = activeProfile else { return false }
        
        // For now, all games are unlocked
        // In a real app, this would check level requirements, completed prerequisites, etc.
        return true
    }
    
    func selectGame(_ game: Game) {
        guard activeProfile != nil else {
            showProfileSelection = true
            return
        }
        
        // Log game selection for analytics
        print("Game selected: \(game.title)")
        
        // Navigate to game
        onGameSelected(game)
    }
    
    func openParentDashboard() {
        print("Opening parent dashboard")
        onParentDashboardRequested()
    }
}