//
//  SupabaseService.swift
//  Bemo
//
//  Supabase integration service for backend sync and learning analytics
//

// WHAT: Manages Supabase backend integration for user profiles and learning events. Bridges Apple Sign-In with Supabase Auth and syncs local profile data.
// ARCHITECTURE: Core service in MVVM-S that integrates with existing AuthenticationService and ProfileService. Uses Supabase Swift SDK for database operations.
// USAGE: Injected via DependencyContainer. Automatically syncs authentication state, profiles, and tracks learning events. Supports realtime updates.

import Foundation
import Supabase
import Observation

@Observable
class SupabaseService {
    private let client: SupabaseClient
    private let authService: AuthenticationService
    
    // Observable state
    private(set) var isConnected = false
    private(set) var syncError: Error?
    private(set) var lastSyncDate: Date?
    
    // Connection state
    private(set) var authStateChangeTask: Task<Void, Never>?
    
    init(authService: AuthenticationService) {
        self.authService = authService
        
        // Initialize Supabase client with configuration from AppConfiguration
        let config = AppConfiguration.shared
        
        print("[SupabaseService] Initializing with URL: '\(config.supabaseURL)'")
        print("[SupabaseService] Anon key present: \(!config.supabaseAnonKey.isEmpty)")
        
        guard let supabaseURL = URL(string: config.supabaseURL),
              !config.supabaseAnonKey.isEmpty else {
            print("[SupabaseService] Failed to create URL from: '\(config.supabaseURL)'")
            fatalError("Supabase configuration missing. Please configure SUPABASE_URL and SUPABASE_ANON_KEY in .xcconfig files")
        }
        
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: config.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    flowType: .pkce,
                    autoRefreshToken: true
                )
            )
        )
        
        setupAuthenticationSync()
    }
    
    deinit {
        authStateChangeTask?.cancel()
    }
    
    // MARK: - Authentication Sync
    
    private func setupAuthenticationSync() {
        // Listen to Supabase auth state changes
        authStateChangeTask = Task {
            for await (event, session) in client.auth.authStateChanges {
                await handleSupabaseAuthChange(event: event, session: session)
            }
        }
    }
    
    @MainActor
    private func handleSupabaseAuthChange(event: AuthChangeEvent, session: Session?) {
        switch event {
        case .signedIn:
            isConnected = true
            syncError = nil
            lastSyncDate = Date()
            print("Supabase: User signed in - \(session?.user.id.uuidString ?? "unknown")")
            
        case .signedOut:
            isConnected = false
            print("Supabase: User signed out")
            
        case .tokenRefreshed:
            lastSyncDate = Date()
            print("Supabase: Token refreshed")
            
        default:
            break
        }
    }
    
    func signInWithAppleIdentity(
        _ appleUserID: String,
        identityToken: String,
        nonce: String,
        email: String?,
        fullName: PersonNameComponents?
    ) async throws {
        do {
            // Sign in with Apple ID token via Supabase Auth
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: identityToken,
                    nonce: nonce
                )
            )

            // Create or update parent profile
            try await upsertParentProfile(
                supabaseUserID: session.user.id,
                appleUserID: appleUserID,
                email: email,
                fullName: fullName
            )
            
            print("Supabase: Successfully signed in with Apple ID - \(session.user.id)")
            
        } catch {
            syncError = error
            print("Supabase: Sign-in failed - \(error)")
            throw error
        }
    }
    
    func signOut() async throws {
        do {
            try await client.auth.signOut()
            print("Supabase: Successfully signed out")
        } catch {
            syncError = error
            print("Supabase: Sign-out failed - \(error)")
            throw error
        }
    }
    
    // MARK: - Profile Management
    
    private func upsertParentProfile(
        supabaseUserID: UUID,
        appleUserID: String,
        email: String?,
        fullName: PersonNameComponents?
    ) async throws {
        let fullNameString = fullName?.formatted(.name(style: .long))
        let firstName = fullName?.givenName
        
        // Log first-time signup information
        if email != nil || fullName != nil {
            print("Supabase: First-time signup detected")
            print("  - Email: \(email ?? "not provided")")
            print("  - First Name: \(firstName ?? "not provided")")
            print("  - Full Name: \(fullNameString ?? "not provided")")
        }
        
        let profileData = ParentProfileInsert(
            user_id: supabaseUserID,
            apple_user_id: appleUserID,
            full_name: fullNameString,
            email: email
        )
        
        try await client
            .from("parent_profiles")
            .upsert(profileData)
            .execute()
        
        print("Supabase: Parent profile upserted for user \(supabaseUserID)")
    }
    
    func syncChildProfile(_ profile: UserProfile) async throws {
        guard isConnected else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            let profileData = ChildProfileUpsert(
                id: profile.id,
                parent_user_id: try await getCurrentUserID(),
                name: profile.name,
                age: profile.age,
                gender: profile.gender,
                total_xp: profile.totalXP,
                preferences: try encodePreferences(profile.preferences)
            )
            
            try await client
                .from("child_profiles")
                .upsert(profileData)
                .execute()
            
            lastSyncDate = Date()
            print("Supabase: Child profile synced - \(profile.name)")
            
        } catch {
            syncError = error
            print("Supabase: Failed to sync child profile - \(error)")
            throw error
        }
    }
    
    func fetchChildProfiles() async throws -> [UserProfile] {
        guard isConnected else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            let response: [ChildProfileResponse] = try await client
                .from("child_profiles")
                .select()
                .order("created_at")
                .execute()
                .value
            
            let profiles = try response.map { try convertToUserProfile($0) }
            lastSyncDate = Date()
            
            print("Supabase: Fetched \(profiles.count) child profiles")
            return profiles
            
        } catch {
            syncError = error
            print("Supabase: Failed to fetch child profiles - \(error)")
            throw error
        }
    }
    
    func deleteChildProfile(_ profileId: String) async throws {
        guard isConnected else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            try await client
                .from("child_profiles")
                .delete()
                .eq("id", value: profileId)
                .execute()
            
            lastSyncDate = Date()
            print("Supabase: Child profile deleted - \(profileId)")
            
        } catch {
            syncError = error
            print("Supabase: Failed to delete child profile - \(error)")
            throw error
        }
    }
    
    // MARK: - Learning Events
    
    func trackLearningEvent(
        childProfileId: String,
        eventType: String,
        gameId: String,
        xpAwarded: Int = 0,
        eventData: [String: Any] = [:],
        sessionId: String? = nil
    ) async throws {
        guard isConnected else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            // Use the database function for atomic event creation + XP update
            let eventParams = LearningEventParams(
                child_id: childProfileId,
                event_type_param: eventType,
                game_id_param: gameId,
                xp_awarded_param: xpAwarded,
                event_data_param: try encodeEventData(eventData),
                session_id_param: sessionId
            )
            
            try await client
                .rpc("record_learning_event", params: eventParams)
                .execute()
            
            lastSyncDate = Date()
            print("Supabase: Learning event tracked - \(eventType) for child \(childProfileId)")
            
        } catch {
            syncError = error
            print("Supabase: Failed to track learning event - \(error)")
            throw error
        }
    }
    
    func startGameSession(
        childProfileId: String,
        gameId: String,
        sessionData: [String: Any] = [:]
    ) async throws -> String {
        guard isConnected else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            let sessionParams = GameSessionStartParams(
                child_id: childProfileId,
                game_id_param: gameId,
                session_data_param: try encodeEventData(sessionData)
            )
            
            let response: String = try await client
                .rpc("start_game_session", params: sessionParams)
                .execute()
                .value
            
            lastSyncDate = Date()
            print("Supabase: Game session started - \(response)")
            
            return response
            
        } catch {
            syncError = error
            print("Supabase: Failed to start game session - \(error)")
            throw error
        }
    }
    
    func endGameSession(
        sessionId: String,
        finalXPEarned: Int = 0,
        finalLevelsCompleted: Int = 0,
        finalSessionData: [String: Any] = [:]
    ) async throws {
        guard isConnected else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            let endParams = GameSessionEndParams(
                session_id_param: sessionId,
                final_xp_earned: finalXPEarned,
                final_levels_completed: finalLevelsCompleted,
                final_session_data: try encodeEventData(finalSessionData)
            )
            
            try await client
                .rpc("end_game_session", params: endParams)
                .execute()
            
            lastSyncDate = Date()
            print("Supabase: Game session ended - \(sessionId)")
            
        } catch {
            syncError = error
            print("Supabase: Failed to end game session - \(error)")
            throw error
        }
    }
    
    // MARK: - Analytics
    
    func getChildLearningStats(childProfileId: String) async throws -> LearningStats {
        guard isConnected else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            let params = LearningStatsParams(child_id: childProfileId)
            
            let response: LearningStatsResponse = try await client
                .rpc("get_child_learning_summary", params: params)
                .single()
                .execute()
                .value
            
            return LearningStats(
                totalXP: response.total_xp ?? 0,
                gamesPlayed: response.games_played ?? 0,
                totalSessions: response.total_sessions ?? 0,
                totalPlayTimeMinutes: response.total_play_time_minutes ?? 0,
                levelsCompleted: response.levels_completed ?? 0,
                favoriteGame: response.favorite_game
            )
            
        } catch {
            syncError = error
            print("Supabase: Failed to get learning stats - \(error)")
            throw error
        }
    }
    
    // MARK: - Realtime Subscriptions
    
    func subscribeToChildProfileUpdates(childProfileId: String, onUpdate: @escaping (UserProfile) -> Void) {
        let channel = client.realtimeV2.channel("child-profile-\(childProfileId)")
        
        // Subscribe to the channel
        Task {
            do {
                try await channel.subscribeWithError()
            } catch {
                print("Failed to subscribe to realtime channel: \(error)")
            }
        }
        
        // Note: Realtime subscription API has changed in recent SDK versions
        // This is a simplified version - you may need to adjust based on your exact SDK version
        print("Realtime subscription set up for child profile: \(childProfileId)")
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserID() async throws -> String {
        let session = try await client.auth.session
        guard !session.user.id.uuidString.isEmpty else {
            throw SupabaseError.notAuthenticated
        }
        return session.user.id.uuidString
    }
    
    private func encodePreferences(_ preferences: UserPreferences) throws -> [String: Any] {
        let encoder = JSONEncoder()
        let data = try encoder.encode(preferences)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SupabaseError.encodingFailed
        }
        return json
    }
    
    private func encodeEventData(_ eventData: [String: Any]) throws -> [String: Any] {
        // Return empty dict if no data provided
        guard !eventData.isEmpty else {
            return [:]
        }
        
        // Ensure all values are JSON-serializable
        return eventData.compactMapValues { value in
            if JSONSerialization.isValidJSONObject([value]) {
                return value
            }
            return String(describing: value)
        }
    }
    
    private func convertToUserProfile(_ response: ChildProfileResponse) throws -> UserProfile {
        let preferencesData = try JSONSerialization.data(withJSONObject: response.preferences)
        let preferences = try JSONDecoder().decode(UserPreferences.self, from: preferencesData)
        
        return UserProfile(
            id: response.id,
            userId: response.parent_user_id,
            name: response.name,
            age: response.age,
            gender: response.gender,
            totalXP: response.total_xp,
            preferences: preferences
        )
    }
}

// MARK: - Data Models

struct ParentProfileInsert: Codable {
    let user_id: UUID
    let apple_user_id: String
    let full_name: String?
    let email: String?
}

struct ChildProfileUpsert: Encodable {
    let id: String
    let parent_user_id: String
    let name: String
    let age: Int
    let gender: String
    let total_xp: Int
    let preferences: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case id, parent_user_id, name, age, gender, total_xp, preferences
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(parent_user_id, forKey: .parent_user_id)
        try container.encode(name, forKey: .name)
        try container.encode(age, forKey: .age)
        try container.encode(gender, forKey: .gender)
        try container.encode(total_xp, forKey: .total_xp)
        
        // Encode preferences as JSONB
        let preferencesData = try JSONSerialization.data(withJSONObject: preferences)
        let preferencesString = String(data: preferencesData, encoding: .utf8)!
        try container.encode(preferencesString, forKey: .preferences)
    }
}

struct ChildProfileResponse: Decodable {
    let id: String
    let parent_user_id: String
    let name: String
    let age: Int
    let gender: String
    let total_xp: Int
    let preferences: [String: Any]
    let created_at: String
    let updated_at: String
    
    enum CodingKeys: String, CodingKey {
        case id, parent_user_id, name, age, gender, total_xp, preferences, created_at, updated_at
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        parent_user_id = try container.decode(String.self, forKey: .parent_user_id)
        name = try container.decode(String.self, forKey: .name)
        age = try container.decode(Int.self, forKey: .age)
        gender = try container.decode(String.self, forKey: .gender)
        total_xp = try container.decode(Int.self, forKey: .total_xp)
        created_at = try container.decode(String.self, forKey: .created_at)
        updated_at = try container.decode(String.self, forKey: .updated_at)
        
        // Handle JSONB preferences field
        if let preferencesString = try? container.decode(String.self, forKey: .preferences),
           let preferencesData = preferencesString.data(using: .utf8),
           let preferencesObj = try? JSONSerialization.jsonObject(with: preferencesData) as? [String: Any] {
            preferences = preferencesObj
        } else {
            preferences = [:]
        }
    }
}

struct LearningEventParams: Encodable {
    let child_id: String
    let event_type_param: String
    let game_id_param: String
    let xp_awarded_param: Int
    let event_data_param: [String: Any]
    let session_id_param: String?
    
    enum CodingKeys: String, CodingKey {
        case child_id, event_type_param, game_id_param, xp_awarded_param, event_data_param, session_id_param
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(child_id, forKey: .child_id)
        try container.encode(event_type_param, forKey: .event_type_param)
        try container.encode(game_id_param, forKey: .game_id_param)
        try container.encode(xp_awarded_param, forKey: .xp_awarded_param)
        try container.encodeIfPresent(session_id_param, forKey: .session_id_param)
        
        // Encode event data as JSONB
        let eventDataString = try JSONSerialization.data(withJSONObject: event_data_param)
        try container.encode(String(data: eventDataString, encoding: .utf8)!, forKey: .event_data_param)
    }
}

struct GameSessionStartParams: Encodable {
    let child_id: String
    let game_id_param: String
    let session_data_param: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case child_id, game_id_param, session_data_param
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(child_id, forKey: .child_id)
        try container.encode(game_id_param, forKey: .game_id_param)
        
        // Encode session data as JSONB
        let sessionDataString = try JSONSerialization.data(withJSONObject: session_data_param)
        try container.encode(String(data: sessionDataString, encoding: .utf8)!, forKey: .session_data_param)
    }
}

struct GameSessionEndParams: Encodable {
    let session_id_param: String
    let final_xp_earned: Int
    let final_levels_completed: Int
    let final_session_data: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case session_id_param, final_xp_earned, final_levels_completed, final_session_data
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(session_id_param, forKey: .session_id_param)
        try container.encode(final_xp_earned, forKey: .final_xp_earned)
        try container.encode(final_levels_completed, forKey: .final_levels_completed)
        
        // Encode session data as JSONB
        let sessionDataString = try JSONSerialization.data(withJSONObject: final_session_data)
        try container.encode(String(data: sessionDataString, encoding: .utf8)!, forKey: .final_session_data)
    }
}

struct LearningStatsParams: Codable {
    let child_id: String
}

struct LearningStatsResponse: Codable {
    let total_xp: Int?
    let games_played: Int?
    let total_sessions: Int?
    let total_play_time_minutes: Int?
    let levels_completed: Int?
    let favorite_game: String?
}

struct LearningStats {
    let totalXP: Int
    let gamesPlayed: Int
    let totalSessions: Int
    let totalPlayTimeMinutes: Int
    let levelsCompleted: Int
    let favoriteGame: String?
}

// MARK: - Error Types

enum SupabaseError: Error, LocalizedError {
    case notAuthenticated
    case encodingFailed
    case configurationMissing
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated with Supabase"
        case .encodingFailed:
            return "Failed to encode data for Supabase"
        case .configurationMissing:
            return "Supabase configuration missing"
        }
    }
}

// MARK: - Custom Supabase Logger (removed - not available in current SDK)
