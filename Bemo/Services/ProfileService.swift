//
//  ProfileService.swift
//  Bemo
//
//  Service for managing the active child's profile and session
//

// WHAT: Manages active child profile and session state. Single source of truth for current player. Persists to UserDefaults.
// ARCHITECTURE: Core ObservableObject service in MVVM-S. 
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
    
    // Track whether we've completed at least one sync from Supabase
    private(set) var hasSyncedAtLeastOnce = false
    
    // Optional Supabase integration - will be injected after initialization
    private weak var supabaseService: SupabaseService?
    
    // Optional authentication service - will be injected after initialization
    private weak var authenticationService: AuthenticationService?
    
    // Optional error tracking - will be injected after initialization
    private weak var errorTrackingService: ErrorTrackingService?
    
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
        
        // Don't auto-set profile on init - wait for proper authentication
        // Profile will be set after sync or user selection
    }
    
    // MARK: - Supabase Integration
    
    func setSupabaseService(_ supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }
    
    func setAuthenticationService(_ authenticationService: AuthenticationService) {
        self.authenticationService = authenticationService
    }
    
    func setErrorTrackingService(_ errorTrackingService: ErrorTrackingService) {
        self.errorTrackingService = errorTrackingService
    }
    
    func syncWithSupabase() {
        guard let supabaseService = supabaseService else {
            print("Supabase service not available - skipping profile sync")
            return
        }
        // Avoid noisy errors during cold start when Supabase has no stored session yet
        guard supabaseService.isConnected else {
            print("Profile sync from Supabase skipped: not connected")
            return
        }
        
        // Background sync from Supabase to local storage
        Task {
            do {
                let remoteProfiles = try await supabaseService.fetchChildProfiles()
                
                await MainActor.run {
                    // All fetched profiles belong to the current authenticated user
                    // (Supabase RLS policies ensure we only get our own profiles)
                    
                    // Merge remote profiles with local profiles
                    for remoteProfile in remoteProfiles {
                        if !childProfiles.contains(where: { $0.id == remoteProfile.id }) {
                            childProfiles.append(remoteProfile)
                        } else {
                            // Update existing profile with remote data
                            if let index = childProfiles.firstIndex(where: { $0.id == remoteProfile.id }) {
                                childProfiles[index] = remoteProfile
                            }
                        }
                    }
                    saveChildProfiles()
                    self.hasSyncedAtLeastOnce = true
                    print("Profile sync from Supabase completed - synced \(remoteProfiles.count) profiles")
                    
                    // Don't auto-select profile here - let the coordinator handle it
                    // This ensures proper UI flow
                }
            } catch {
                await MainActor.run {
                    self.hasSyncedAtLeastOnce = true
                }
                print("Profile sync from Supabase failed (non-critical): \(error)")
                errorTrackingService?.trackError(error, context: ErrorContext(
                    feature: "ProfileService",
                    action: "syncFromSupabase"
                ))
            }
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
    
    func clearAllLocalProfiles() {
        // Clear all local profile data - useful for logout or data corruption recovery
        activeProfile = nil
        childProfiles.removeAll()
        userDefaults.removeObject(forKey: activeProfileKey)
        userDefaults.removeObject(forKey: childProfilesKey)
        
        // Reset sync flag when clearing all profiles
        hasSyncedAtLeastOnce = false
        
        print("All local profile data cleared")
    }
    
    func profilesBelong(to userId: String) -> Bool {
        // If there are no profiles, they don't belong to anyone.
        if childProfiles.isEmpty { return false }
        
        // This is an optimistic check. If we have any profile for the user,
        // we can assume we're good to go to the lobby. `filterProfilesForCurrentUser`
        // will clean up any stale profiles from other users.
        return childProfiles.contains { $0.userId == userId }
    }
    
    func filterProfilesForCurrentUser() async {
        // Filter local profiles to only keep those belonging to the current authenticated user
        // This is called after authentication to ensure we only show the right profiles
        if let supabaseService = supabaseService {
            do {
                let currentUserId = try await supabaseService.getCurrentUserID()
                await MainActor.run {
                    // Filter profiles to only those belonging to current user
                    let filteredProfiles = childProfiles.filter { $0.userId == currentUserId }
                    if filteredProfiles.count != childProfiles.count {
                        print("Filtered profiles: keeping \(filteredProfiles.count) of \(childProfiles.count) profiles for user \(currentUserId)")
                        childProfiles = filteredProfiles
                        saveChildProfiles()
                        
                        // Clear active profile if it doesn't belong to current user
                        if let active = activeProfile,
                           !filteredProfiles.contains(where: { $0.id == active.id }) {
                            clearActiveProfile()
                        }
                    }
                }
            } catch {
                print("Failed to filter profiles for current user: \(error)")
            }
        }
    }
    
    func addChildProfile(_ profile: UserProfile) {
        childProfiles.append(profile)
        saveChildProfiles()
        print("Child profile added: \(profile.name)")
        
        // Sync to Supabase if available (non-blocking)
        syncProfileToSupabase(profile)
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
        
        // Sync deletion to Supabase if available (non-blocking)
        syncProfileDeletionToSupabase(profileId)
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
            
            // Sync to Supabase if available (non-blocking)
            syncProfileToSupabase(profile)
        }
    }
    
    // MARK: - Profile Updates
    
    func updateXP(_ xp: Int, for profileId: String) {
        guard activeProfile?.id == profileId else { return }
        
        let oldXP = activeProfile?.totalXP ?? 0
        activeProfile?.totalXP = xp
        saveActiveProfile()
        
        // Update in childProfiles array as well
        if let index = childProfiles.firstIndex(where: { $0.id == profileId }) {
            childProfiles[index].totalXP = xp
            saveChildProfiles()
            
            // Sync to Supabase if available (non-blocking)
            syncProfileToSupabase(childProfiles[index])
            
            // Track XP change as a learning event
            if xp > oldXP {
                trackXPGainEvent(profileId: profileId, xpGained: xp - oldXP)
            }
        }
    }
    
    private func trackXPGainEvent(profileId: String, xpGained: Int) {
        guard let supabaseService = supabaseService else { return }
        
        Task {
            do {
                try await supabaseService.trackLearningEvent(
                    childProfileId: profileId,
                    eventType: "xp_gained",
                    gameId: "system",
                    xpAwarded: xpGained,
                    eventData: ["source": "manual_update"]
                )
                            } catch {
                    print("Failed to track XP gain event (non-critical): \(error)")
                    errorTrackingService?.trackError(error, context: ErrorContext(
                        feature: "ProfileService",
                        action: "trackXPGain",
                        metadata: [
                            "profileId": profileId
                        ]
                    ))
                }
        }
    }
    
    
    func updatePreferences(_ preferences: UserPreferences, for profileId: String) {
        // Update in activeProfile if it's the current one
        if activeProfile?.id == profileId {
            activeProfile?.preferences = preferences
            saveActiveProfile()
        }
        
        // Update in childProfiles array
        if let index = childProfiles.firstIndex(where: { $0.id == profileId }) {
            childProfiles[index].preferences = preferences
            saveChildProfiles()
            
            // Sync to Supabase if available (non-blocking)
            syncProfileToSupabase(childProfiles[index])
        }
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
            errorTrackingService?.trackError(error, context: ErrorContext(
                feature: "ProfileService",
                action: "saveActiveProfile",
                metadata: ["profileId": profile.id]
            ))
        }
    }
    
    private func loadActiveProfile() {
        guard let data = userDefaults.data(forKey: activeProfileKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            activeProfile = try decoder.decode(UserProfile.self, from: data)
        } catch {
            print("Failed to load active profile: \(error)")
            errorTrackingService?.trackError(error, context: ErrorContext(
                feature: "ProfileService",
                action: "loadActiveProfile"
            ))
        }
    }
    
    private func saveChildProfiles() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(childProfiles)
            userDefaults.set(data, forKey: childProfilesKey)
        } catch {
            print("Failed to save child profiles: \(error)")
            errorTrackingService?.trackError(error, context: ErrorContext(
                feature: "ProfileService",
                action: "saveChildProfiles",
                metadata: ["profileCount": childProfiles.count]
            ))
        }
    }
    
    private func loadChildProfiles() {
        guard let data = userDefaults.data(forKey: childProfilesKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            childProfiles = try decoder.decode([UserProfile].self, from: data)
        } catch {
            print("Failed to load child profiles: \(error)")
            errorTrackingService?.trackError(error, context: ErrorContext(
                feature: "ProfileService",
                action: "loadChildProfiles"
            ))
        }
    }
    
    // MARK: - Profile Creation
    
    func createProfile(name: String, age: Int, gender: String, userId: String, avatarSymbol: String? = nil, avatarColor: String? = nil) -> UserProfile {
        // Use provided avatar or generate random one
        let defaultAvatar = Avatar.random()
        
        return UserProfile(
            id: UUID().uuidString,
            userId: userId,
            name: name,
            age: age,
            gender: gender,
            avatarSymbol: avatarSymbol ?? defaultAvatar.symbol,
            avatarColor: avatarColor ?? defaultAvatar.colorName,
            totalXP: 0,
            preferences: UserPreferences()
        )
    }
    
    // MARK: - Authentication Helper
    
    private func getCurrentAuthenticatedUserId() -> String? {
        // Get the current Supabase user ID (not Apple user ID) from the Supabase session
        // This is critical because child profiles use parent_user_id = Supabase UUID
        // For now, return Apple user ID but we need to fix the sync to be async
        return authenticationService?.currentUser?.id
    }
    
    private func getCurrentSupabaseUserId() async -> String? {
        // Get the current Supabase user ID asynchronously
        guard let supabaseService = supabaseService else { return nil }
        
        do {
            return try await supabaseService.getCurrentUserID()
        } catch {
            print("Failed to get current Supabase user ID: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Supabase Sync Methods
    
    private func syncProfileToSupabase(_ profile: UserProfile) {
        guard let supabaseService = supabaseService else {
            print("Supabase service not available - skipping profile sync")
            return
        }
        
        // Background sync - don't block existing functionality
        Task {
            do {
                try await supabaseService.syncChildProfile(profile)
                print("Profile synced to Supabase: \(profile.name)")
            } catch {
                print("Profile sync to Supabase failed (non-critical): \(error)")
                errorTrackingService?.trackError(error, context: ErrorContext(
                    feature: "ProfileService",
                    action: "syncProfileToSupabase",
                    metadata: ["profileId": profile.id]
                ))
                // Don't affect main profile functionality
            }
        }
    }
    
    private func syncProfileDeletionToSupabase(_ profileId: String) {
        guard let supabaseService = supabaseService else {
            print("Supabase service not available - skipping profile deletion sync")
            return
        }
        
        // Background sync - don't block existing functionality  
        Task {
            do {
                try await supabaseService.deleteChildProfile(profileId)
                print("Profile deletion synced to Supabase: \(profileId)")
            } catch {
                print("Profile deletion sync to Supabase failed (non-critical): \(error)")
                errorTrackingService?.trackError(error, context: ErrorContext(
                    feature: "ProfileService",
                    action: "syncProfileDeletionToSupabase",
                    metadata: ["profileId": profileId]
                ))
                // Don't affect main profile functionality
            }
        }
    }
}

// MARK: - Data Models

struct UserProfile: Codable, Identifiable {
    let id: String
    let userId: String // Parent's authenticated user ID
    var name: String
    var age: Int
    var gender: String
    var avatarSymbol: String
    var avatarColor: String
    var totalXP: Int
    var preferences: UserPreferences

    // Maintain backward compatibility with older saved profiles that didn't include avatar fields
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case name
        case age
        case gender
        case avatarSymbol
        case avatarColor
        case totalXP
        case preferences
    }

    init(
        id: String,
        userId: String,
        name: String,
        age: Int,
        gender: String,
        avatarSymbol: String,
        avatarColor: String,
        totalXP: Int,
        preferences: UserPreferences
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.age = age
        self.gender = gender
        self.avatarSymbol = avatarSymbol
        self.avatarColor = avatarColor
        self.totalXP = totalXP
        self.preferences = preferences
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.name = try container.decode(String.self, forKey: .name)
        self.age = try container.decode(Int.self, forKey: .age)
        self.gender = try container.decode(String.self, forKey: .gender)

        // Provide safe defaults if avatar fields were missing in previously saved data
        let defaultAvatar = Avatar.random()
        self.avatarSymbol = try container.decodeIfPresent(String.self, forKey: .avatarSymbol) ?? defaultAvatar.symbol
        self.avatarColor = try container.decodeIfPresent(String.self, forKey: .avatarColor) ?? defaultAvatar.colorName

        self.totalXP = (try? container.decode(Int.self, forKey: .totalXP)) ?? 0

        // Preferences were introduced later; default if missing
        self.preferences = (try? container.decode(UserPreferences.self, forKey: .preferences)) ?? UserPreferences()
    }

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
