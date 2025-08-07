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
    private let authService: AuthenticationService?
    private let errorTracking: ErrorTrackingService?
    private let useServiceRole: Bool
    
    // Observable state
    private(set) var isConnected = false
    private(set) var syncError: Error?
    private(set) var lastSyncDate: Date?
    
    // Connection state
    private(set) var authStateChangeTask: Task<Void, Never>?
    
    init(authService: AuthenticationService? = nil, errorTracking: ErrorTrackingService? = nil, useServiceRole: Bool = false) {
        self.authService = authService
        self.errorTracking = errorTracking
        self.useServiceRole = useServiceRole
        
        // Initialize Supabase client with configuration from AppConfiguration
        let config = AppConfiguration.shared
        
        // Use service role key if requested and available (for editor/developer tools)
        let supabaseKey: String
        if useServiceRole, let serviceKey = config.supabaseServiceRoleKey {
            supabaseKey = serviceKey
            print("[SupabaseService] Using service role key for authentication (bypasses RLS)")
        } else {
            supabaseKey = config.supabaseAnonKey
            print("[SupabaseService] Using anonymous key for authentication")
        }
        
        print("[SupabaseService] Initializing with URL: '\(config.supabaseURL)'")
        
        guard let supabaseURL = URL(string: config.supabaseURL),
              !supabaseKey.isEmpty else {
            print("[SupabaseService] Failed to create URL from: '\(config.supabaseURL)'")
            fatalError("Supabase configuration missing. Please configure SUPABASE_URL and SUPABASE_ANON_KEY in .xcconfig files")
        }
        
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: .init(
                    flowType: .pkce,
                    autoRefreshToken: !useServiceRole  // Don't auto-refresh for service role
                )
            )
        )
        
        // Service role doesn't need auth sync
        if useServiceRole {
            isConnected = true  // Service role is always "connected"
        } else if authService != nil {
            setupAuthenticationSync()
        }
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
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "signInWithApple",
                metadata: ["hasEmail": email != nil]
            ))
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
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "signOut"
            ))
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
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "syncChildProfile",
                metadata: ["profileId": profile.id]
            ))
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
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "fetchChildProfiles"
            ))
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
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "deleteChildProfile",
                metadata: ["profileId": profileId]
            ))
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
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "trackLearningEvent",
                metadata: [
                    "eventType": eventType,
                    "gameId": gameId,
                    "childProfileId": childProfileId
                ]
            ))
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
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "startGameSession",
                metadata: [
                    "gameId": gameId,
                    "childProfileId": childProfileId
                ]
            ))
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
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "endGameSession",
                metadata: [
                    "sessionId": sessionId,
                    "finalXPEarned": finalXPEarned
                ]
            ))
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
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "getLearningStats",
                metadata: ["childProfileId": childProfileId]
            ))
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
                errorTracking?.trackError(error, context: ErrorContext(
                    feature: "Supabase",
                    action: "subscribeToRealtime"
                ))
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

// MARK: - Tangram Puzzle Storage

extension SupabaseService {
    
    /// Fetch all tangram puzzles from Supabase (all are official)
    func fetchOfficialTangramPuzzles() async throws -> [TangramPuzzleDTO] {
        guard isConnected || useServiceRole else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            let response = try await client
                .from("tangram_puzzles")
                .select()
                .eq("is_official", value: true)
                .not("published_at", operator: .is, value: "null")
                .order("category", ascending: true)
                .order("order_index", ascending: true)
                .order("difficulty", ascending: true)
                .execute()
            
            let puzzles = try JSONDecoder().decode([TangramPuzzleDTO].self, from: response.data)
            print("Supabase: Fetched \(puzzles.count) official tangram puzzles")
            return puzzles
            
        } catch {
            print("Supabase: Failed to fetch tangram puzzles - \(error)")
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "fetchOfficialTangramPuzzles"
            ))
            throw error
        }
    }
    
    /// Save a tangram puzzle to Supabase (developer use only)
    func saveTangramPuzzle(_ puzzle: TangramPuzzleDTO) async throws {
        guard isConnected || useServiceRole else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            // Upsert puzzle (insert or update based on puzzle_id)
            try await client
                .from("tangram_puzzles")
                .upsert(puzzle)
                .execute()
            
            print("Supabase: Saved tangram puzzle - \(puzzle.puzzle_id)")
            
        } catch {
            print("Supabase: Failed to save tangram puzzle - \(error)")
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "saveTangramPuzzle",
                metadata: ["puzzle_id": puzzle.puzzle_id]
            ))
            throw error
        }
    }
    
    /// Upload thumbnail for a tangram puzzle
    func uploadTangramThumbnail(puzzleId: String, thumbnailData: Data) async throws -> String {
        guard isConnected || useServiceRole else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            let path = "\(puzzleId).png"
            
            // Upload to storage bucket (updated API)
            _ = try await client.storage
                .from("tangram-thumbnails")
                .upload(
                    path,
                    data: thumbnailData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/png",
                        upsert: true
                    )
                )
            
            // Get public URL
            let publicURL = try client.storage
                .from("tangram-thumbnails")
                .getPublicURL(path: path)
            
            print("Supabase: Uploaded thumbnail for puzzle \(puzzleId)")
            return publicURL.absoluteString
            
        } catch {
            print("Supabase: Failed to upload thumbnail - \(error)")
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "uploadTangramThumbnail",
                metadata: ["puzzle_id": puzzleId]
            ))
            throw error
        }
    }
    
    /// Download thumbnail for a tangram puzzle
    func downloadTangramThumbnail(puzzleId: String) async throws -> Data {
        do {
            let path = "\(puzzleId).png"
            let data = try await client.storage
                .from("tangram-thumbnails")
                .download(path: path)
            
            return data
            
        } catch {
            print("Supabase: Failed to download thumbnail - \(error)")
            // Don't track as error - thumbnails might not exist for all puzzles
            throw error
        }
    }
    
    /// Get tangram puzzles by category
    func fetchTangramPuzzlesByCategory(_ category: String) async throws -> [TangramPuzzleDTO] {
        guard isConnected || useServiceRole else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            let response = try await client
                .from("tangram_puzzles")
                .select()
                .eq("is_official", value: true)
                .eq("category", value: category)
                .not("published_at", operator: .is, value: "null")
                .order("order_index", ascending: true)
                .order("difficulty", ascending: true)
                .execute()
            
            return try JSONDecoder().decode([TangramPuzzleDTO].self, from: response.data)
            
        } catch {
            print("Supabase: Failed to fetch puzzles for category \(category) - \(error)")
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "fetchTangramPuzzlesByCategory",
                metadata: ["category": category]
            ))
            throw error
        }
    }
    
    /// Delete a tangram puzzle from Supabase
    func deleteTangramPuzzle(puzzleId: String) async throws {
        guard isConnected || useServiceRole else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            try await client
                .from("tangram_puzzles")
                .delete()
                .eq("puzzle_id", value: puzzleId)
                .execute()
            
            print("Supabase: Deleted tangram puzzle - \(puzzleId)")
            
        } catch {
            print("Supabase: Failed to delete tangram puzzle - \(error)")
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "deleteTangramPuzzle",
                metadata: ["puzzle_id": puzzleId]
            ))
            throw error
        }
    }
}

// MARK: - Tangram Puzzle DTO

struct TangramPuzzleDTO: Codable {
    let id: UUID?
    let puzzle_id: String
    let name: String
    let category: String
    let difficulty: Int
    let puzzle_data: AnyCodable  // Entire TangramPuzzle stored as JSONB (must be AnyCodable for JSONB)
    let solution_checksum: String?
    let is_official: Bool
    let tags: [String]?
    let order_index: Int?
    let thumbnail_path: String?
    let published_at: String?
    let metadata: AnyCodable?  // JSONB metadata
    
    // Convert to TangramPuzzle model
    func toTangramPuzzle() throws -> TangramPuzzle {
        // First convert AnyCodable back to Data, then decode
        let jsonData = try JSONSerialization.data(withJSONObject: puzzle_data.value, options: [])
        let puzzle = try JSONDecoder().decode(TangramPuzzle.self, from: jsonData)
        return puzzle
    }
    
    // Create DTO from TangramPuzzle
    init(from puzzle: TangramPuzzle) throws {
        self.id = nil  // Let database generate
        self.puzzle_id = puzzle.id
        self.name = puzzle.name
        self.category = puzzle.category.rawValue
        self.difficulty = puzzle.difficulty.rawValue
        
        // Encode the puzzle to JSON data first, then convert to dictionary for JSONB storage
        let jsonData = try JSONEncoder().encode(puzzle)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
        self.puzzle_data = AnyCodable(jsonObject)
        
        self.solution_checksum = puzzle.solutionChecksum
        // All puzzles created in the editor are official puzzles
        self.is_official = true
        self.tags = puzzle.tags
        self.order_index = 0  // Default order
        self.thumbnail_path = nil  // Set after upload
        // Publish immediately - all editor puzzles are official
        self.published_at = ISO8601DateFormatter().string(from: Date())
        self.metadata = AnyCodable([:] as [String: String])  // Empty metadata as AnyCodable
    }
}

// Helper to encode/decode Any types for JSONB
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if container.decodeNil() {
            self.value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
        }
    }
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
