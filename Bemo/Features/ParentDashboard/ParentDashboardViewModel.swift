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
    private let supabaseService: SupabaseService?
    private let onDismiss: () -> Void
    private let onAddChildRequested: () -> Void
    private var cancellables = Set<AnyCancellable>()
    
    // Display models
    struct ChildProfile: Identifiable {
        let id: String
        let name: String
        let avatarSymbol: String?
        let avatarColor: String?
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
        supabaseService: SupabaseService? = nil,
        onDismiss: @escaping () -> Void,
        onAddChildRequested: @escaping () -> Void
    ) {
        self.profileService = profileService
        self.apiService = apiService
        self.authenticationService = authenticationService
        self.supabaseService = supabaseService
        self.onDismiss = onDismiss
        self.onAddChildRequested = onAddChildRequested
        
        self.authenticatedUser = authenticationService.currentUser
        
        loadData()
        setupAuthenticationObserver()
    }

    // MARK: - Skills

    struct SkillStat: Identifiable {
        let id = UUID()
        let key: String
        let displayName: String
        let level: Int
        let xpTotal: Int
        let masteryState: String
    }

    var skills: [SkillStat] = []
    
    private func setupAuthenticationObserver() {
        // With @Observable, the authenticatedUser will automatically sync
        // when authenticationService.currentUser changes
        authenticatedUser = authenticationService.currentUser
    }
    
    private func loadData() {
        #if DEBUG
        print("🎯 [ParentDashboard] loadData() called")
        #endif
        
        // Load child profiles first (synchronously)
        loadChildProfiles()
        
        // Load insights
        generateInsights()

        // Load current skills for selected child after profiles are loaded
        Task { @MainActor [weak self] in
            // Small delay to ensure selectedChild is set
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await self?.loadSkills()
        }
    }

    private func loadSkills() async {
        #if DEBUG
        print("📊 [ParentDashboard] loadSkills() called")
        print("   - supabaseService: \(supabaseService != nil ? "✅ Available" : "❌ NIL")")
        print("   - selectedChild: \(selectedChild != nil ? "✅ \(selectedChild!.name)" : "❌ NIL")")
        #endif
        
        guard let supabase = supabaseService,
              let selected = selectedChild else {
            #if DEBUG
            print("📊 [ParentDashboard] loadSkills - Cannot proceed, missing dependencies")
            #endif
            skills = []
            return
        }
        
        #if DEBUG
        print("📊 [ParentDashboard] Loading skills for child: \(selected.name) (id: \(selected.id))")
        #endif
        
        // Fetch per-skill rows for Tangram (game_id = "tangram") via SupabaseService helper
        do {
            let response = try await supabase.listSkillProgressRows(childProfileId: selected.id, gameId: "tangram")
            
            #if DEBUG
            print("📊 [ParentDashboard] Fetched \(response.count) skill progress rows:")
            for row in response {
                print("   - \(row.skill_key): Level \(row.level), XP \(row.xp_total), Mastery: \(row.mastery_state)")
            }
            #endif
            
            let displayName: (String) -> String = { key in
                switch key {
                case "shape_matching": return "Shape Matching"
                case "mental_rotation": return "Mental Rotation"
                case "reflection": return "Reflection"
                case "decomposition": return "Decomposition"
                case "planning_sequencing": return "Planning & Sequencing"
                default: return key
                }
            }

            let mapped = response.map { r in
                SkillStat(
                    key: r.skill_key,
                    displayName: displayName(r.skill_key),
                    level: r.level,
                    xpTotal: r.xp_total,
                    masteryState: r.mastery_state
                )
            }
            
            #if DEBUG
            print("📊 [ParentDashboard] Mapped skills to display format:")
            for skill in mapped {
                print("   - \(skill.displayName) [\(skill.key)]: Level \(skill.level), \(skill.xpTotal) XP, \(skill.masteryState)")
            }
            #endif
            
            await MainActor.run { skills = mapped }
        } catch {
            #if DEBUG
            print("❌ [ParentDashboard] Failed to load skills: \(error)")
            #endif
            // Non-fatal
            await MainActor.run { skills = [] }
        }
    }
    
    private func loadChildProfiles() {
        // Load child profiles from ProfileService
        let userProfiles = profileService.childProfiles
        let activeProfileId = profileService.activeProfile?.id
        
        #if DEBUG
        print("👨‍👩‍👧‍👦 [ParentDashboard] Loading child profiles:")
        print("   - Total profiles: \(userProfiles.count)")
        print("   - Active profile ID: \(activeProfileId ?? "none")")
        #endif
        
        childProfiles = userProfiles.map { profile in
            let isSelected = profile.id == activeProfileId
            #if DEBUG
            print("   - \(profile.name) (id: \(profile.id)) - selected: \(isSelected)")
            #endif
            
            return ChildProfile(
                id: profile.id,
                name: profile.name,
                avatarSymbol: profile.avatarSymbol,
                avatarColor: profile.avatarColor,
                level: calculateLevel(from: profile.totalXP),
                totalXP: profile.totalXP,
                playTimeToday: generateMockPlayTime(), // Mock data for now
                recentAchievements: generateMockAchievements(), // Mock data for now
                isSelected: isSelected
            )
        }
        
        selectedChild = childProfiles.first { $0.isSelected } ?? childProfiles.first
        
        #if DEBUG
        if let selected = selectedChild {
            print("👶 [ParentDashboard] Initially selected child: \(selected.name) (id: \(selected.id))")
        } else {
            print("⚠️ [ParentDashboard] No child selected initially")
        }
        #endif
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
        #if DEBUG
        print("👶 [ParentDashboard] Child selected: \(profile.name) (id: \(profile.id))")
        #endif
        
        selectedChild = profile
        
        // Update selected status
        childProfiles = childProfiles.map { child in
            ChildProfile(
                id: child.id,
                name: child.name,
                avatarSymbol: child.avatarSymbol,
                avatarColor: child.avatarColor,
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
        
        // Reload skills for newly selected child
        Task { @MainActor [weak self] in
            #if DEBUG
            print("👶 [ParentDashboard] Reloading skills for newly selected child")
            #endif
            await self?.loadSkills()
        }
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
    
    // MARK: - Profile Management
    
    func getUserProfile(for childProfile: ChildProfile) -> UserProfile? {
        return profileService.childProfiles.first { $0.id == childProfile.id }
    }
    
    func updateChildProfile(_ profile: UserProfile) {
        profileService.updateChildProfile(profile)
        loadChildProfiles()
        generateInsights()
    }
    
    func deleteChildProfile(_ profileId: String) {
        profileService.deleteChildProfile(profileId)
        loadChildProfiles()
        generateInsights()
    }
    
    // Expose ProfileService for edit view
    var getProfileService: ProfileService {
        return profileService
    }
}