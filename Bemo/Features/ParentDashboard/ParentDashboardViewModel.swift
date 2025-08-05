//
//  ParentDashboardViewModel.swift
//  Bemo
//
//  ViewModel for the parent dashboard
//

// WHAT: Manages parent dashboard state including child profiles, analytics, insights, and settings. Handles profile switching.
// ARCHITECTURE: ViewModel in MVVM-S for parent features. Uses ProfileService and APIService for data management.
// USAGE: Created by AppCoordinator with dismiss callback. Load child data, generate insights, handle profile selection.

import SwiftUI
import Combine
import Observation

@Observable
class ParentDashboardViewModel {
    var childProfiles: [ChildProfile] = []
    var selectedChild: ChildProfile?
    var insights: [Insight] = []

    var authenticatedUser: AuthenticatedUser?
    
    private let profileService: ProfileService
    private let apiService: APIService
    private let authenticationService: AuthenticationService
    private let onDismiss: () -> Void
    private let onAddChildRequested: () -> Void
    private var cancellables = Set<AnyCancellable>()
    
    // Display models
    struct ChildProfile: Identifiable {
        let id: String
        let name: String
        let level: Int
        let totalXP: Int
        let playTimeToday: TimeInterval
        let recentAchievements: [RecentAchievement]
        let isSelected: Bool
    }
    
    struct RecentAchievement: Identifiable {
        let id = UUID()
        let name: String
        let iconName: String
        let date: Date
    }
    
    struct Insight: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let iconName: String
        let color: Color
    }
    
    init(
        profileService: ProfileService,
        apiService: APIService,
        authenticationService: AuthenticationService,
        onDismiss: @escaping () -> Void,
        onAddChildRequested: @escaping () -> Void
    ) {
        self.profileService = profileService
        self.apiService = apiService
        self.authenticationService = authenticationService
        self.onDismiss = onDismiss
        self.onAddChildRequested = onAddChildRequested
        
        self.authenticatedUser = authenticationService.currentUser
        
        loadData()
        setupAuthenticationObserver()
    }
    
    private func setupAuthenticationObserver() {
        // With @Observable, the authenticatedUser will automatically sync
        // when authenticationService.currentUser changes
        authenticatedUser = authenticationService.currentUser
    }
    
    private func loadData() {
        // Load child profiles
        loadChildProfiles()
        
        // Load insights
        generateInsights()
    }
    
    private func loadChildProfiles() {
        // Load child profiles from ProfileService
        let userProfiles = profileService.childProfiles
        let activeProfileId = profileService.activeProfile?.id
        
        childProfiles = userProfiles.map { profile in
            ChildProfile(
                id: profile.id,
                name: profile.name,
                level: calculateLevel(from: profile.totalXP),
                totalXP: profile.totalXP,
                playTimeToday: generateMockPlayTime(), // Mock data for now
                recentAchievements: generateMockAchievements(), // Mock data for now
                isSelected: profile.id == activeProfileId
            )
        }
        
        selectedChild = childProfiles.first { $0.isSelected } ?? childProfiles.first
    }
    
    private func generateInsights() {
        guard let child = selectedChild else {
            insights = []
            return
        }
        
        insights = [
            Insight(
                title: "Strong Spatial Skills",
                description: "\(child.name) excels at shape recognition tasks",
                iconName: "cube.fill",
                color: .green
            ),
            Insight(
                title: "Consistent Practice",
                description: "Playing daily for the past week",
                iconName: "calendar.badge.plus",
                color: .blue
            ),
            Insight(
                title: "Try New Challenges",
                description: "Ready for more advanced puzzles",
                iconName: "arrow.up.circle.fill",
                color: .orange
            )
        ]
    }
    
    private func calculateLevel(from xp: Int) -> Int {
        return (xp / 100) + 1
    }
    
    private func generateMockPlayTime() -> TimeInterval {
        return Double.random(in: 600...3600) // 10 minutes to 1 hour
    }
    
    private func generateMockAchievements() -> [RecentAchievement] {
        let allAchievements = [
            RecentAchievement(name: "Shape Master", iconName: "star.fill", date: Date()),
            RecentAchievement(name: "5 Day Streak", iconName: "flame.fill", date: Date().addingTimeInterval(-86400)),
            RecentAchievement(name: "First Victory", iconName: "trophy.fill", date: Date().addingTimeInterval(-172800)),
            RecentAchievement(name: "Speed Runner", iconName: "bolt.fill", date: Date().addingTimeInterval(-259200))
        ]
        
        return Array(allAchievements.prefix(Int.random(in: 1...3)))
    }
    
    func selectChild(_ profile: ChildProfile) {
        selectedChild = profile
        
        // Update selected status
        childProfiles = childProfiles.map { child in
            ChildProfile(
                id: child.id,
                name: child.name,
                level: child.level,
                totalXP: child.totalXP,
                playTimeToday: child.playTimeToday,
                recentAchievements: child.recentAchievements,
                isSelected: child.id == profile.id
            )
        }
        
        // Update the active profile in ProfileService
        if let userProfile = profileService.childProfiles.first(where: { $0.id == profile.id }) {
            profileService.setActiveProfile(userProfile)
        }
        
        // Update insights for selected child
        generateInsights()
    }
    
    func formattedPlayTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    func signOut() {
        authenticationService.signOut()
        // Navigation will be handled by AppCoordinator's authentication observer
    }
    
    func deleteChild(_ profile: ChildProfile) {
        // Call API to delete profile
        apiService.deleteChildProfile(profileId: profile.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        print("Failed to delete profile: \(error)")
                        // Handle error - could show alert to user
                    }
                },
                receiveValue: { [weak self] _ in
                    // Remove from ProfileService
                    self?.profileService.deleteChildProfile(profile.id)
                    
                    // Reload profiles
                    self?.loadChildProfiles()
                    self?.generateInsights()
                }
            )
            .store(in: &cancellables)
    }
    
    func addChild() {
        onAddChildRequested()
    }
    
    func dismiss() {
        onDismiss()
    }
}