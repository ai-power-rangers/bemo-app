//
//  GamificationService.swift
//  Bemo
//
//  Service for managing XP, achievements, and rewards
//

// WHAT: Manages gamification features including XP, levels, achievements, and streaks. Tracks and rewards player progress.
// ARCHITECTURE: Service layer in MVVM-S. Depends on ProfileService for active user. Publishes state changes via @Published.
// USAGE: Award XP/points through methods. Service auto-calculates levels, unlocks achievements. Subscribe to published properties.

import Foundation
import Combine

class GamificationService {
    @Published private(set) var currentXP: Int = 0
    @Published private(set) var currentLevel: Int = 1
    @Published private(set) var achievements: [Achievement] = []
    @Published private(set) var streakDays: Int = 0
    
    private let profileService: ProfileService
    private var cancellables = Set<AnyCancellable>()
    
    // XP thresholds for each level
    private let levelThresholds = [
        1: 0,
        2: 100,
        3: 250,
        4: 450,
        5: 700,
        6: 1000,
        7: 1400,
        8: 1850,
        9: 2350,
        10: 3000
    ]
    
    init(profileService: ProfileService) {
        self.profileService = profileService
        setupBindings()
    }
    
    private func setupBindings() {
        // Subscribe to profile changes
        profileService.activeProfilePublisher
            .compactMap { $0 }
            .sink { [weak self] profile in
                self?.loadGamificationData(for: profile)
            }
            .store(in: &cancellables)
    }
    
    private func loadGamificationData(for profile: UserProfile) {
        currentXP = profile.totalXP
        currentLevel = calculateLevel(from: profile.totalXP)
        achievements = profile.achievements
        // Calculate streak from profile data
        streakDays = calculateStreak(for: profile)
    }
    
    // MARK: - XP Management
    
    func awardXP(_ amount: Int, to profileId: String) {
        guard profileService.activeProfile?.id == profileId else { return }
        
        let previousLevel = currentLevel
        currentXP += amount
        currentLevel = calculateLevel(from: currentXP)
        
        // Check for level up
        if currentLevel > previousLevel {
            handleLevelUp(newLevel: currentLevel)
        }
        
        // Update profile
        profileService.updateXP(currentXP, for: profileId)
        
        // Check for XP-based achievements
        checkXPAchievements()
    }
    
    func awardPoints(_ points: Int, to profileId: String) {
        // Convert points to XP (could have different conversion rates)
        let xpAmount = points * 10
        awardXP(xpAmount, to: profileId)
    }
    
    // MARK: - Level Calculation
    
    private func calculateLevel(from xp: Int) -> Int {
        var level = 1
        for (lvl, threshold) in levelThresholds.sorted(by: { $0.key < $1.key }) {
            if xp >= threshold {
                level = lvl
            } else {
                break
            }
        }
        return level
    }
    
    func xpRequiredForNextLevel() -> Int {
        let nextLevel = currentLevel + 1
        guard let threshold = levelThresholds[nextLevel] else {
            return Int.max // Max level reached
        }
        return threshold - currentXP
    }
    
    func levelProgress() -> Float {
        let currentLevelThreshold = levelThresholds[currentLevel] ?? 0
        let nextLevelThreshold = levelThresholds[currentLevel + 1] ?? currentXP
        
        let progressInLevel = currentXP - currentLevelThreshold
        let totalRequiredForLevel = nextLevelThreshold - currentLevelThreshold
        
        return Float(progressInLevel) / Float(totalRequiredForLevel)
    }
    
    // MARK: - Achievements
    
    func unlockAchievement(_ achievementId: String) {
        guard !achievements.contains(where: { $0.id == achievementId }) else { return }
        
        if let achievement = getAchievementDefinition(id: achievementId) {
            achievements.append(achievement)
            profileService.addAchievement(achievement, for: profileService.activeProfile?.id ?? "")
            
            // Show achievement notification
            notifyAchievementUnlocked(achievement)
        }
    }
    
    private func checkXPAchievements() {
        // Check for XP milestones
        let xpMilestones = [
            ("first_100_xp", 100, "Century Club"),
            ("xp_500", 500, "XP Master"),
            ("xp_1000", 1000, "XP Legend")
        ]
        
        for (id, threshold, name) in xpMilestones {
            if currentXP >= threshold && !achievements.contains(where: { $0.id == id }) {
                let achievement = Achievement(
                    id: id,
                    name: name,
                    description: "Earned \(threshold) XP",
                    iconName: "star.fill",
                    unlockedAt: Date()
                )
                unlockAchievement(id)
            }
        }
    }
    
    // MARK: - Streaks
    
    func updateDailyStreak() {
        streakDays += 1
        
        // Check for streak achievements
        let streakMilestones = [
            ("streak_3", 3, "3 Day Streak"),
            ("streak_7", 7, "Week Warrior"),
            ("streak_30", 30, "Monthly Master")
        ]
        
        for (id, days, name) in streakMilestones {
            if streakDays >= days && !achievements.contains(where: { $0.id == id }) {
                let achievement = Achievement(
                    id: id,
                    name: name,
                    description: "Played \(days) days in a row",
                    iconName: "flame.fill",
                    unlockedAt: Date()
                )
                unlockAchievement(id)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateStreak(for profile: UserProfile) -> Int {
        // In a real app, this would check play history
        return 5 // Mock value
    }
    
    private func handleLevelUp(newLevel: Int) {
        print("Level up! Now level \(newLevel)")
        // Could trigger celebration animation, unlock new content, etc.
    }
    
    private func notifyAchievementUnlocked(_ achievement: Achievement) {
        print("Achievement unlocked: \(achievement.name)")
        // In a real app, this would show a notification/celebration
    }
    
    private func getAchievementDefinition(id: String) -> Achievement? {
        // In a real app, this would fetch from a configuration
        return Achievement(
            id: id,
            name: "Achievement",
            description: "You did something great!",
            iconName: "trophy.fill",
            unlockedAt: Date()
        )
    }
}

// MARK: - Achievement Model

struct Achievement: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let unlockedAt: Date
}