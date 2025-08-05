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

class ParentDashboardViewModel: ObservableObject {
    @Published var childProfiles: [ChildProfile] = []
    @Published var selectedChild: ChildProfile?
    @Published var insights: [Insight] = []
    @Published var showAddChildSheet = false
    
    private let profileService: ProfileService
    private let apiService: APIService
    private let onDismiss: () -> Void
    private var cancellables = Set<AnyCancellable>()
    
    // Display models
    struct ChildProfile: Identifiable {
        let id: String
        let name: String
        let level: Int
        let totalXP: Int
        let playTimeToday: TimeInterval
        let recentAchievements: [Achievement]
        let isSelected: Bool
    }
    
    struct Achievement: Identifiable {
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
        onDismiss: @escaping () -> Void
    ) {
        self.profileService = profileService
        self.apiService = apiService
        self.onDismiss = onDismiss
        
        loadData()
    }
    
    private func loadData() {
        // Load child profiles
        loadChildProfiles()
        
        // Load insights
        generateInsights()
    }
    
    private func loadChildProfiles() {
        // In a real app, this would fetch from the profile service
        // For now, create mock data
        let mockProfiles = [
            ChildProfile(
                id: "1",
                name: "Emma",
                level: 5,
                totalXP: 450,
                playTimeToday: 1800, // 30 minutes
                recentAchievements: [
                    Achievement(name: "Shape Master", iconName: "star.fill", date: Date()),
                    Achievement(name: "5 Day Streak", iconName: "flame.fill", date: Date().addingTimeInterval(-86400))
                ],
                isSelected: true
            ),
            ChildProfile(
                id: "2",
                name: "Liam",
                level: 3,
                totalXP: 280,
                playTimeToday: 1200, // 20 minutes
                recentAchievements: [
                    Achievement(name: "First Victory", iconName: "trophy.fill", date: Date().addingTimeInterval(-172800))
                ],
                isSelected: false
            )
        ]
        
        childProfiles = mockProfiles
        selectedChild = mockProfiles.first
    }
    
    private func generateInsights() {
        insights = [
            Insight(
                title: "Strong Spatial Skills",
                description: "Emma excels at shape recognition tasks",
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
    
    func dismiss() {
        onDismiss()
    }
}