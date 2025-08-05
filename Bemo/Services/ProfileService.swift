//
//  ProfileService.swift
//  Bemo
//
//  Service for managing the active child's profile and session
//

// WHAT: Manages active child profile and session state. Single source of truth for current player. Persists to UserDefaults.
// ARCHITECTURE: Core service in MVVM-S. Publishes active profile changes. Used by all features needing user context.
// USAGE: Set/clear active profile for child switching. Subscribe to activeProfilePublisher. Updates propagate through app.

import Foundation
import Combine

class ProfileService {
    @Published private(set) var activeProfile: UserProfile?
    private let userDefaults = UserDefaults.standard
    private let activeProfileKey = "com.bemo.activeProfile"
    
    // Public publisher for active profile changes
    var activeProfilePublisher: AnyPublisher<UserProfile?, Never> {
        $activeProfile.eraseToAnyPublisher()
    }
    
    init() {
        loadActiveProfile()
        
        // For development: create a mock profile if none exists
        if activeProfile == nil {
            setActiveProfile(createMockProfile())
        }
    }
    
    // MARK: - Profile Management
    
    func setActiveProfile(_ profile: UserProfile) {
        activeProfile = profile
        saveActiveProfile()
        
        // Log session start
        print("Active profile set: \(profile.name)")
    }
    
    func clearActiveProfile() {
        activeProfile = nil
        userDefaults.removeObject(forKey: activeProfileKey)
        
        print("Active profile cleared")
    }
    
    // MARK: - Profile Updates
    
    func updateXP(_ xp: Int, for profileId: String) {
        guard activeProfile?.id == profileId else { return }
        
        activeProfile?.totalXP = xp
        saveActiveProfile()
    }
    
    func addAchievement(_ achievement: Achievement, for profileId: String) {
        guard activeProfile?.id == profileId else { return }
        
        activeProfile?.achievements.append(achievement)
        saveActiveProfile()
    }
    
    func updatePreferences(_ preferences: UserPreferences, for profileId: String) {
        guard activeProfile?.id == profileId else { return }
        
        activeProfile?.preferences = preferences
        saveActiveProfile()
    }
    
    // MARK: - Persistence
    
    private func saveActiveProfile() {
        guard let profile = activeProfile else { return }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(profile)
            userDefaults.set(data, forKey: activeProfileKey)
        } catch {
            print("Failed to save active profile: \(error)")
        }
    }
    
    private func loadActiveProfile() {
        guard let data = userDefaults.data(forKey: activeProfileKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            activeProfile = try decoder.decode(UserProfile.self, from: data)
        } catch {
            print("Failed to load active profile: \(error)")
        }
    }
    
    // MARK: - Mock Data (for testing)
    
    func createMockProfile() -> UserProfile {
        return UserProfile(
            id: UUID().uuidString,
            userId: "parent123",
            name: "Emma",
            age: 6,
            totalXP: 450,
            achievements: [
                Achievement(
                    id: "first_game",
                    name: "First Game",
                    description: "Completed your first game",
                    iconName: "gamecontroller.fill",
                    unlockedAt: Date()
                )
            ],
            preferences: UserPreferences()
        )
    }
}

// MARK: - Data Models

struct UserProfile: Codable {
    let id: String
    let userId: String // Parent's user ID
    var name: String
    var age: Int
    var totalXP: Int
    var achievements: [Achievement]
    var preferences: UserPreferences
}

struct UserPreferences: Codable {
    var soundEnabled: Bool = true
    var musicEnabled: Bool = true
    var difficultySetting: DifficultySetting = .normal
    var colorScheme: ColorScheme = .default
    
    enum DifficultySetting: String, Codable {
        case easy
        case normal
        case hard
    }
    
    enum ColorScheme: String, Codable {
        case `default`
        case highContrast
        case colorBlind
    }
}