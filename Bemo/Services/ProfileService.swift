//
//  ProfileService.swift
//  Bemo
//
//  Service for managing the active child's profile and session
//

// WHAT: Manages active child profile and session state. Single source of truth for current player. Persists to UserDefaults.
// ARCHITECTURE: Core ObservableObject service in MVVM-S. Publishes profile changes via @Published properties. Used by all features needing user context.
// USAGE: Set/clear active profile for child switching. Observe $activeProfile for profile changes throughout the app.

import Foundation
import Observation

@Observable
class ProfileService {
    private(set) var activeProfile: UserProfile?
    private(set) var childProfiles: [UserProfile] = []
    private let userDefaults = UserDefaults.standard
    private let activeProfileKey = "com.bemo.activeProfile"
    private let childProfilesKey = "com.bemo.childProfiles"
    
    // Returns active profile or nil if no profiles exist
    var currentProfile: UserProfile? {
        return activeProfile
    }
    
    // Check if any profiles exist
    var hasProfiles: Bool {
        return !childProfiles.isEmpty
    }
    
    init() {
        loadActiveProfile()
        loadChildProfiles()
        
        // Set first profile as active if no active profile but profiles exist
        if activeProfile == nil && !childProfiles.isEmpty {
            setActiveProfile(childProfiles.first!)
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
    
    func addChildProfile(_ profile: UserProfile) {
        childProfiles.append(profile)
        saveChildProfiles()
        print("Child profile added: \(profile.name)")
    }
    
    func deleteChildProfile(_ profileId: String) {
        childProfiles.removeAll { $0.id == profileId }
        saveChildProfiles()
        
        // If the deleted profile was active, switch to another profile or clear
        if activeProfile?.id == profileId {
            if let firstProfile = childProfiles.first {
                setActiveProfile(firstProfile)
            } else {
                clearActiveProfile()
            }
        }
        
        print("Child profile deleted: \(profileId)")
    }
    
    func updateChildProfile(_ profile: UserProfile) {
        if let index = childProfiles.firstIndex(where: { $0.id == profile.id }) {
            childProfiles[index] = profile
            saveChildProfiles()
            
            // Update active profile if it's the same one
            if activeProfile?.id == profile.id {
                activeProfile = profile
                saveActiveProfile()
            }
        }
    }
    
    // MARK: - Profile Updates
    
    func updateXP(_ xp: Int, for profileId: String) {
        guard activeProfile?.id == profileId else { return }
        
        activeProfile?.totalXP = xp
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
    
    private func saveChildProfiles() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(childProfiles)
            userDefaults.set(data, forKey: childProfilesKey)
        } catch {
            print("Failed to save child profiles: \(error)")
        }
    }
    
    private func loadChildProfiles() {
        guard let data = userDefaults.data(forKey: childProfilesKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            childProfiles = try decoder.decode([UserProfile].self, from: data)
        } catch {
            print("Failed to load child profiles: \(error)")
        }
    }
    
    // MARK: - Profile Creation
    
    func createProfile(name: String, age: Int, gender: String, userId: String) -> UserProfile {
        return UserProfile(
            id: UUID().uuidString,
            userId: userId,
            name: name,
            age: age,
            gender: gender,
            totalXP: 0,
            preferences: UserPreferences()
        )
    }
}

// MARK: - Data Models

struct UserProfile: Codable {
    let id: String
    let userId: String // Parent's authenticated user ID
    var name: String
    var age: Int
    var gender: String
    var totalXP: Int
    var preferences: UserPreferences
    
    // Helper to check if profile belongs to authenticated user
    func belongsTo(authenticatedUserId: String) -> Bool {
        return userId == authenticatedUserId
    }
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