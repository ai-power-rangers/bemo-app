//
//  GameLobbyViewModel.swift
//  Bemo
//
//  ViewModel for the game selection lobby
//

// WHAT: Manages game lobby state including available games, active profile, and navigation callbacks to games/parent dashboard.
// ARCHITECTURE: ViewModel in MVVM-S handling lobby logic. Depends on ProfileService for user data.
// USAGE: Created by AppCoordinator with navigation callbacks. Observe profile changes via callback, validate game access, handle selection.

import SwiftUI
import Combine
import Observation
import LocalAuthentication

@Observable
class GameLobbyViewModel {
    var availableGames: [GameItem] = []
    var activeProfile: Profile?
    var showProfileSelection = false
    var showProfileModal = false
    var showProfileDetails = false
    var showAuthenticationError = false
    
    // Returns active profile for display, or nil if no profiles exist
    var displayProfile: Profile? {
        if let activeProfile = activeProfile {
            return activeProfile
        } else if let currentUserProfile = profileService.currentProfile {
            return Profile(
                id: currentUserProfile.id,
                name: currentUserProfile.name,
                avatar: nil,  // TODO: Add avatar support
                level: calculateLevel(from: currentUserProfile.totalXP),
                xp: currentUserProfile.totalXP
            )
        } else {
            return nil
        }
    }
    
    private let profileService: ProfileService
    private let supabaseService: SupabaseService?
    private let puzzleManagementService: PuzzleManagementService?
    private let learningService: LearningService?
    private let developerService: DeveloperService
    
    private let onGameSelected: (Game) -> Void
    private let onDevToolSelected: (DevTool) -> Void
    private let onParentDashboardRequested: () -> Void
    private let onProfileSetupRequested: () -> Void
    
    // Display models
    struct Profile {
        let id: String
        let name: String
        let avatar: String?
        let level: Int
        let xp: Int
    }
    
    struct GameItem: Identifiable {
        let id = UUID()
        let game: Game?  // For regular games
        let devTool: DevTool?  // For developer tools
        let iconName: String
        let color: Color
        let badge: String?
        
        // Convenience properties
        var title: String {
            return game?.title ?? devTool?.title ?? "Unknown"
        }
        
        var description: String {
            return game?.description ?? devTool?.description ?? ""
        }
        
        var isDevTool: Bool {
            return devTool != nil
        }
        
        // Convenience initializers
        init(game: Game, iconName: String, color: Color, badge: String? = nil) {
            self.game = game
            self.devTool = nil
            self.iconName = iconName
            self.color = color
            self.badge = badge
        }
        
        init(devTool: DevTool, iconName: String, color: Color, badge: String? = nil) {
            self.game = nil
            self.devTool = devTool
            self.iconName = iconName
            self.color = color
            self.badge = badge
        }
    }
    
    init(
        profileService: ProfileService,
        supabaseService: SupabaseService? = nil,
        puzzleManagementService: PuzzleManagementService? = nil,
        learningService: LearningService? = nil,
        developerService: DeveloperService,
        onGameSelected: @escaping (Game) -> Void,
        onDevToolSelected: @escaping (DevTool) -> Void,
        onParentDashboardRequested: @escaping () -> Void,
        onProfileSetupRequested: @escaping () -> Void
    ) {
        self.profileService = profileService
        self.supabaseService = supabaseService
        self.puzzleManagementService = puzzleManagementService
        self.learningService = learningService
        self.developerService = developerService
        self.onGameSelected = onGameSelected
        self.onDevToolSelected = onDevToolSelected
        self.onParentDashboardRequested = onParentDashboardRequested
        self.onProfileSetupRequested = onProfileSetupRequested
        
        setupProfileObserver()
        loadGames()
        
        // Check if we need to show profile selection modal
        // This happens when user has profiles but none selected
        Task {
            // Small delay to ensure view is ready
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await MainActor.run {
                self.checkAndShowProfileModal()
            }
        }
    }
    
    private func setupProfileObserver() {
        // Set initial profile from service
        updateActiveProfile(profileService.activeProfile)
        
        // With @Observable ProfileService, we need to manually observe changes
        // since we're transforming the data to our display model
        withObservationTracking {
            _ = profileService.activeProfile
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateActiveProfile(self?.profileService.activeProfile)
                // Re-establish observation
                self?.setupProfileObserver()
            }
        }
    }
    
    private func loadGames() {
        // Load available games
        let tangramGame = TangramGame(
            supabaseService: supabaseService,
            puzzleManagementService: puzzleManagementService,
            learningService: learningService
        )
        
        let aquaMathGame = AquaMathGame()
        
        // Start with regular games (Tangram is now CV-ready)
        availableGames = [
            GameItem(
                game: tangramGame,
                iconName: "square.on.square",
                color: .blue,
                badge: nil
            ),
            GameItem(
                game: aquaMathGame,
                iconName: "drop.circle.fill",
                color: .cyan,
                badge: "New"
            )
        ]
        
        // Add developer tools only if user is a developer
        if developerService.isDeveloper {
            let tangramEditorTool = TangramEditorTool(puzzleManagementService: puzzleManagementService)
            
            availableGames.append(
                GameItem(
                    devTool: tangramEditorTool,
                    iconName: "pencil.and.ruler.fill",
                    color: .orange,
                    badge: "Dev Tool"
                )
            )
            
            // Add Animation Lab
            let animationLabTool = AnimationLabTool()
            availableGames.append(
                GameItem(
                    devTool: animationLabTool,
                    iconName: "wand.and.stars",
                    color: .indigo,
                    badge: "Dev Tool"
                )
            )
            
            // Add Tangram Progress Test Tool
            let tangramProgressTool = TangramProgressTool()
            availableGames.append(
                GameItem(
                    devTool: tangramProgressTool,
                    iconName: "chart.line.uptrend.xyaxis",
                    color: .green,
                    badge: "Dev Tool"
                )
            )
            
            // Add TgramViewer as a developer tool
            let tgramViewerGame = TgramViewerGame()
            availableGames.append(
                GameItem(
                    game: tgramViewerGame,
                    iconName: "eye.circle.fill",
                    color: .purple,
                    badge: "CV Viewer"
                )
            )
            
            print("🛠️ Developer tools loaded for developer user")
        } else {
            print("👤 Regular user - dev tools hidden")
        }
    }
    
    private func updateActiveProfile(_ profile: UserProfile?) {
        if let profile = profile {
            activeProfile = Profile(
                id: profile.id,
                name: profile.name,
                avatar: nil,  // TODO: Add avatar support
                level: calculateLevel(from: profile.totalXP),
                xp: profile.totalXP
            )
        } else {
            activeProfile = nil
        }
        checkAndShowProfileModal()
    }
    
    private func calculateLevel(from xp: Int) -> Int {
        // Simple level calculation
        return (xp / 100) + 1
    }
    
    func isGameUnlocked(_ game: Game) -> Bool {
        // Check if the player meets the requirements for this game
        guard let _ = profileService.currentProfile else {
            return false // No profiles exist, no games unlocked
        }
        
        // For now, all games are unlocked if a profile exists
        // In a real app, this would check level requirements, completed prerequisites, etc.
        return true
    }
    
    func selectGameItem(_ gameItem: GameItem) {
        if gameItem.isDevTool {
            // Handle dev tool selection
            guard let devTool = gameItem.devTool else {
                print("Error: GameItem marked as dev tool but devTool is nil")
                return
            }
            
            // Dev tools don't require a child profile
            print("🛠️ Developer tool selected: \(devTool.title)")
            
            // Navigate to dev tool
            onDevToolSelected(devTool)
        } else {
            // Handle regular game selection
            guard let game = gameItem.game else {
                print("Error: GameItem marked as game but game is nil")
                return
            }
            
            // Ensure we have a profile before selecting a game
            guard let currentUserProfile = profileService.currentProfile else {
                print("Cannot select game: No active profile")
                return
            }
            
            let profile = Profile(
                id: currentUserProfile.id,
                name: currentUserProfile.name,
                avatar: nil,  // TODO: Add avatar support
                level: calculateLevel(from: currentUserProfile.totalXP),
                xp: currentUserProfile.totalXP
            )
            
            // Track analytics for regular games
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
    }
    
    func openParentDashboard() {
        print("Opening parent dashboard")
        onParentDashboardRequested()
    }
    
    // MARK: - Parent Gate with LocalAuthentication
    
    func requestParentalAccess() {
        let context = LAContext()
        var error: NSError?
        
        // Check if device can perform local authentication
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Please authenticate to access the Parent Dashboard."
            
            // Request authentication
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, authenticationError in
                Task { @MainActor in
                    if success {
                        // Authentication successful, navigate to parent dashboard
                        self?.onParentDashboardRequested()
                    } else {
                        // Authentication failed or was cancelled
                        print("Authentication failed or was cancelled: \(authenticationError?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
        } else {
            // No authentication method available on device
            // Show alert to inform user they need to set up a passcode/Face ID
            showAuthenticationError = true
        }
    }
    
    func showProfileSelectionModal() {
        showProfileModal = true
    }
    
    func hideProfileSelectionModal() {
        showProfileModal = false
    }
    
    func showProfileDetailsView() {
        // Only show details if we have an active profile
        if profileService.activeProfile != nil {
            showProfileDetails = true
        } else if profileService.hasProfiles {
            // If we have profiles but none selected, show selection modal
            showProfileModal = true
        }
    }
    
    func hideProfileDetailsView() {
        showProfileDetails = false
    }
    
    func selectProfile(_ profile: UserProfile) {
        profileService.setActiveProfile(profile)
        hideProfileSelectionModal()
    }
    
    func addNewProfile() {
        hideProfileSelectionModal()
        onProfileSetupRequested()
    }
    
    func switchProfileFromDetails() {
        showProfileDetails = false
        showProfileModal = true
    }
    
    // Get the current active profile data
    var currentUserProfile: UserProfile? {
        return profileService.activeProfile
    }
    
    private func checkAndShowProfileModal() {
        // Show modal if user has profiles but none are selected
        if profileService.hasProfiles && profileService.activeProfile == nil {
            // Delay slightly to ensure view is ready
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await MainActor.run {
                    self.showProfileModal = true
                }
            }
        }
    }
    
    var availableProfiles: [UserProfile] {
        return profileService.childProfiles
    }

    // You can inject analytics service directly, or access it through a simple method
    private func getAnalyticsService() -> AnalyticsService? {
        // Could be injected via init, or accessed through app coordinator
        return nil // Implement based on your preference
    }
}
