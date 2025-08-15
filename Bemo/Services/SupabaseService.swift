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

public struct ParentProfileData: Decodable {
    let apple_user_id: String
    let full_name: String?
    let email: String?
}

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
        } else {
            supabaseKey = config.supabaseAnonKey
        }
        
        print("[SupabaseService] Validating config - URL: '\(config.supabaseURL)', Key: '\(supabaseKey.isEmpty ? "EMPTY" : "SET (\(supabaseKey.count) chars)")'")
        
        guard let supabaseURL = URL(string: config.supabaseURL),
              !supabaseKey.isEmpty else {
            print("[SupabaseService] Validation failed - URL valid: \(URL(string: config.supabaseURL) != nil), Key not empty: \(!supabaseKey.isEmpty)")
            fatalError("Supabase configuration missing. Please configure SUPABASE_URL and SUPABASE_ANON_KEY in .xcconfig files")
        }
        
        print("[SupabaseService] Configuration validated successfully")
        
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
            // Check if Supabase has a stored session on init
            checkStoredSession()
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
    
    private func checkStoredSession() {
        // Check if Supabase has a stored session (it persists sessions locally)
        Task {
            do {
                // This will throw if no valid session/refresh token is found by the SDK.
                let session = try await client.auth.session
                print("Supabase: Found valid stored session.")
                await handleSupabaseAuthChange(event: .signedIn, session: session)
            } catch {
                // This is expected if the user is not logged in or token is expired.
                print("Supabase: No valid stored session found. \(error.localizedDescription)")
                await handleSupabaseAuthChange(event: .signedOut, session: nil)
            }
        }
    }
    
    private func processSignIn(session: Session) {
        Task {
            var parentProfile: ParentProfileData?
            do {
                let response: [ParentProfileData] = try await client
                    .from("parent_profiles")
                    .select("apple_user_id, full_name, email")
                    .eq("user_id", value: session.user.id)
                    .limit(1)
                    .execute()
                    .value
                parentProfile = response.first
            } catch {
                print("Supabase: Could not fetch parent profile for user \(session.user.id). This might be okay if it's the first sign-in. Error: \(error)")
                errorTracking?.trackError(error, context: ErrorContext(
                    feature: "Supabase",
                    action: "fetchParentProfileOnSignIn",
                    metadata: ["userId": session.user.id.uuidString]
                ))
            }
            
            let capturedProfile = parentProfile  // Capture the value before the concurrent code
            await MainActor.run {
                self.isConnected = true
                self.syncError = nil
                self.lastSyncDate = Date()
                print("Supabase Event: .signedIn or .tokenRefreshed. Notifying AuthenticationService.")
                self.authService?.updateUserAndConfirmAuth(session: session, parentProfile: capturedProfile)
            }
        }
    }
    
    @MainActor
    private func handleSupabaseAuthChange(event: AuthChangeEvent, session: Session?) {
        switch event {
        case .signedIn:
            guard let session = session else { return }
            processSignIn(session: session)
            
        case .signedOut:
            isConnected = false
            print("Supabase Event: .signedOut. Notifying AuthenticationService.")
            authService?.performLocalSignOut()
            
        case .tokenRefreshed:
            guard let session = session else { return }
            processSignIn(session: session)
            
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
        let _ = fullName?.givenName
        
        // First-time signup detected
        
        let profileData = ParentProfileInsert(
            user_id: supabaseUserID,
            apple_user_id: appleUserID,
            full_name: fullNameString,
            email: email
        )
        
        try await client
            .from("parent_profiles")
            .upsert(profileData, onConflict: "apple_user_id", returning: .minimal)
            .execute()
    }
    
    func syncChildProfile(_ profile: UserProfile) async throws {
        guard isConnected else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            let parentUserId = try await getCurrentUserID()
            
            let profileData = ChildProfileUpsert(
                id: profile.id,
                parent_user_id: parentUserId,
                name: profile.name,
                age: profile.age,
                gender: profile.gender,
                avatar_symbol: profile.avatarSymbol,
                avatar_color: profile.avatarColor,
                total_xp: profile.totalXP,
                preferences: try encodePreferences(profile.preferences)
            )
            
            try await client
                .from("child_profiles")
                .upsert(profileData, onConflict: "id", returning: .minimal)
                .execute()
            
            lastSyncDate = Date()
            
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
                .delete(returning: .minimal)
                .eq("id", value: profileId)
                .execute()
            
            lastSyncDate = Date()
            
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
            // Now using proper user authentication instead of service role
            // RLS policies will enforce that only the authenticated parent can track events for their children
            
            // Verify this is not a service role instance (learning events need proper user auth)
            guard !useServiceRole else {
                throw SupabaseError.notAuthenticated
            }
            
            let _ = try await client.auth.session
            // Tracking learning event
            
            // Insert learning event - RLS will ensure only authorized events are allowed
            let eventId = UUID()
            let encodedEventData = try encodeEventData(eventData)
            
            let eventRecord = LearningEventInsert(
                id: eventId,
                child_profile_id: childProfileId,
                event_type: eventType,
                game_id: gameId,
                xp_awarded: xpAwarded,
                event_data: encodedEventData,
                session_id: sessionId
            )
            
            try await client
                .from("learning_events")
                .insert(eventRecord, returning: .minimal)
                .execute()
            
            // Update XP if awarded - RLS will ensure only the parent can update their child's XP
            if xpAwarded > 0 {
                // First fetch current XP (RLS ensures we can only see our own child's data)
                let profile: ChildProfileXPResponse = try await client
                    .from("child_profiles")
                    .select("total_xp")
                    .eq("id", value: childProfileId)
                    .single()
                    .execute()
                    .value
                
                let newXP = profile.total_xp + xpAwarded
                try await client
                    .from("child_profiles")
                    .update(["total_xp": newXP], returning: .minimal)
                    .eq("id", value: childProfileId)
                    .execute()
            }
            
            lastSyncDate = Date()
            
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
            // Now using proper user authentication instead of service role
            // RLS policies will enforce that only the authenticated parent can create sessions for their children
            
            // Verify user is authenticated before proceeding
            guard !useServiceRole else {
                throw SupabaseError.notAuthenticated
            }
            
            let _ = try await client.auth.session
            // Starting game session
            
            // Insert into game_sessions table with RLS enforcement
            let sessionId = UUID().uuidString
            let encodedSessionData = try encodeEventData(sessionData)
            
            // Create a proper struct for insertion
            struct GameSessionInsert: Encodable {
                let id: String
                let child_profile_id: String
                let game_id: String
                let session_data: [String: Any]
                let started_at: String
                
                enum CodingKeys: String, CodingKey {
                    case id, child_profile_id, game_id, session_data, started_at
                }
                
                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode(id, forKey: .id)
                    try container.encode(child_profile_id, forKey: .child_profile_id)
                    try container.encode(game_id, forKey: .game_id)
                    try container.encode(AnyCodable(session_data), forKey: .session_data)
                    try container.encode(started_at, forKey: .started_at)
                }
            }
            
            let sessionRecord = GameSessionInsert(
                id: sessionId,
                child_profile_id: childProfileId,
                game_id: gameId,
                session_data: encodedSessionData,
                started_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await client
                .from("game_sessions")
                .insert(sessionRecord, returning: .minimal)
                .execute()
            
            // Also track the session start event
            try await trackLearningEvent(
                childProfileId: childProfileId,
                eventType: "game_started",
                gameId: gameId,
                xpAwarded: 0,
                eventData: ["session_started": true],
                sessionId: sessionId
            )
            
            lastSyncDate = Date()
            return sessionId
            
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
            // Now using proper user authentication instead of service role
            // RLS policies will enforce that only the authenticated parent can update their sessions
            
            // Verify user is authenticated before proceeding
            guard !useServiceRole else {
                throw SupabaseError.notAuthenticated
            }
            
            let _ = try await client.auth.session
            // Ending game session
            
            // First fetch the session to get child_profile_id and game_id
            struct GameSessionResponse: Decodable {
                let child_profile_id: String
                let game_id: String
            }
            
            let session: GameSessionResponse = try await client
                .from("game_sessions")
                .select("child_profile_id, game_id")
                .eq("id", value: sessionId)
                .single()
                .execute()
                .value
            
            // Update game_sessions table with RLS enforcement
            let encodedSessionData = try encodeEventData(finalSessionData)
            
            // Create a proper struct for update
            struct GameSessionUpdate: Encodable {
                let ended_at: String
                let total_xp_earned: Int
                let levels_completed: Int
                let session_data: [String: Any]
                
                enum CodingKeys: String, CodingKey {
                    case ended_at, total_xp_earned, levels_completed, session_data
                }
                
                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode(ended_at, forKey: .ended_at)
                    try container.encode(total_xp_earned, forKey: .total_xp_earned)
                    try container.encode(levels_completed, forKey: .levels_completed)
                    try container.encode(AnyCodable(session_data), forKey: .session_data)
                }
            }
            
            let updateData = GameSessionUpdate(
                ended_at: ISO8601DateFormatter().string(from: Date()),
                total_xp_earned: finalXPEarned,
                levels_completed: finalLevelsCompleted,
                session_data: encodedSessionData
            )
            
            try await client
                .from("game_sessions")
                .update(updateData, returning: .minimal)
                .eq("id", value: sessionId)
                .execute()
            
            // Track session end event with proper child profile ID
            try await trackLearningEvent(
                childProfileId: session.child_profile_id,
                eventType: "game_ended",
                gameId: session.game_id,
                xpAwarded: 0,
                eventData: [
                    "session_ended": true,
                    "total_xp_earned": finalXPEarned,
                    "levels_completed": finalLevelsCompleted
                ],
                sessionId: sessionId
            )
            
            lastSyncDate = Date()
            
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

    // MARK: - Skill Progress (CRUD)

    struct SkillProgressRow {
        let id: String
        let child_profile_id: String
        let game_id: String
        let skill_key: String
        let xp_total: Int
        let level: Int
        let sample_count: Int
        let success_rate_7d: Double
        let avg_time_ms_7d: Int?
        let avg_hints_7d: Double
        let completions_no_hint_7d: Int
        let mastery_state: String
        let mastery_score: Double
        let first_mastered_at: String?
        let last_mastery_event_at: String?
        let classifier_version: String?
        let mastery_threshold_version: String?
        let last_assessed_at: String?
        let metadata: [String: Any]
    }

    func fetchSkillProgress(childProfileId: String, gameId: String, skillKey: String) async throws -> SkillProgressRow? {
        guard isConnected else { throw SupabaseError.notAuthenticated }
        do {
            let response = try await client
                .from("skill_progress")
                .select()
                .eq("child_profile_id", value: childProfileId)
                .eq("game_id", value: gameId)
                .eq("skill_key", value: skillKey)
                .limit(1)
                .execute()

            // Custom decode for metadata JSONB
            struct RawRow: Decodable {
                let id: String
                let child_profile_id: String
                let game_id: String
                let skill_key: String
                let xp_total: Int
                let level: Int
                let sample_count: Int
                let success_rate_7d: Double
                let avg_time_ms_7d: Int?
                let avg_hints_7d: Double
                let completions_no_hint_7d: Int
                let mastery_state: String
                let mastery_score: Double
                let first_mastered_at: String?
                let last_mastery_event_at: String?
                let classifier_version: String?
                let mastery_threshold_version: String?
                let last_assessed_at: String?
                let metadata: AnyCodable  // Changed from String to AnyCodable for JSONB
            }

            let rawRows = try JSONDecoder().decode([RawRow].self, from: response.data)
            guard let r = rawRows.first else { return nil }
            let metaData = r.metadata.value as? [String: Any] ?? [:]  // Extract metadata from AnyCodable
            return SkillProgressRow(
                id: r.id,
                child_profile_id: r.child_profile_id,
                game_id: r.game_id,
                skill_key: r.skill_key,
                xp_total: r.xp_total,
                level: r.level,
                sample_count: r.sample_count,
                success_rate_7d: r.success_rate_7d,
                avg_time_ms_7d: r.avg_time_ms_7d,
                avg_hints_7d: r.avg_hints_7d,
                completions_no_hint_7d: r.completions_no_hint_7d,
                mastery_state: r.mastery_state,
                mastery_score: r.mastery_score,
                first_mastered_at: r.first_mastered_at,
                last_mastery_event_at: r.last_mastery_event_at,
                classifier_version: r.classifier_version,
                mastery_threshold_version: r.mastery_threshold_version,
                last_assessed_at: r.last_assessed_at,
                metadata: metaData
            )
        } catch {
            print("Supabase: Failed to fetch skill progress - \(error)")
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "fetchSkillProgress",
                metadata: ["child_profile_id": childProfileId, "game_id": gameId, "skill_key": skillKey]
            ))
            throw error
        }
    }

    struct SkillProgressListRow: Decodable {
        let skill_key: String
        let xp_total: Int
        let level: Int
        let mastery_state: String
    }

    func listSkillProgressRows(childProfileId: String, gameId: String) async throws -> [SkillProgressListRow] {
        guard isConnected else { throw SupabaseError.notAuthenticated }
        do {
            let rows: [SkillProgressListRow] = try await client
                .from("skill_progress")
                .select("skill_key,xp_total,level,mastery_state")
                .eq("child_profile_id", value: childProfileId)
                .eq("game_id", value: gameId)
                .order("skill_key")
                .execute()
                .value
            return rows
        } catch {
            print("Supabase: Failed to list skill progress rows - \(error)")
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "listSkillProgressRows",
                metadata: ["child_profile_id": childProfileId, "game_id": gameId]
            ))
            throw error
        }
    }

    func upsertSkillProgress(
        childProfileId: String,
        gameId: String,
        skillKey: String,
        xpTotal: Int,
        level: Int,
        sampleCount: Int,
        successRate7d: Double,
        avgTimeMs7d: Int?,
        avgHints7d: Double,
        completionsNoHint7d: Int,
        masteryState: String,
        masteryScore: Double,
        firstMasteredAt: String?,
        lastMasteryEventAt: String?,
        classifierVersion: String?,
        masteryThresholdVersion: String?,
        lastAssessedAt: String?,
        metadata: [String: Any]
    ) async throws {
        guard isConnected else { throw SupabaseError.notAuthenticated }
        do {
            struct UpsertRow: Encodable {
                let child_profile_id: String
                let game_id: String
                let skill_key: String
                let xp_total: Int
                let level: Int
                let sample_count: Int
                let success_rate_7d: Double
                let avg_time_ms_7d: Int?
                let avg_hints_7d: Double
                let completions_no_hint_7d: Int
                let mastery_state: String
                let mastery_score: Double
                let first_mastered_at: String?
                let last_mastery_event_at: String?
                let classifier_version: String?
                let mastery_threshold_version: String?
                let last_assessed_at: String?
                let metadata: [String: Any]

                enum CodingKeys: String, CodingKey {
                    case child_profile_id, game_id, skill_key, xp_total, level, sample_count, success_rate_7d, avg_time_ms_7d, avg_hints_7d, completions_no_hint_7d, mastery_state, mastery_score, first_mastered_at, last_mastery_event_at, classifier_version, mastery_threshold_version, last_assessed_at, metadata
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode(child_profile_id, forKey: .child_profile_id)
                    try container.encode(game_id, forKey: .game_id)
                    try container.encode(skill_key, forKey: .skill_key)
                    try container.encode(xp_total, forKey: .xp_total)
                    try container.encode(level, forKey: .level)
                    try container.encode(sample_count, forKey: .sample_count)
                    try container.encode(success_rate_7d, forKey: .success_rate_7d)
                    try container.encodeIfPresent(avg_time_ms_7d, forKey: .avg_time_ms_7d)
                    try container.encode(avg_hints_7d, forKey: .avg_hints_7d)
                    try container.encode(completions_no_hint_7d, forKey: .completions_no_hint_7d)
                    try container.encode(mastery_state, forKey: .mastery_state)
                    try container.encode(mastery_score, forKey: .mastery_score)
                    try container.encodeIfPresent(first_mastered_at, forKey: .first_mastered_at)
                    try container.encodeIfPresent(last_mastery_event_at, forKey: .last_mastery_event_at)
                    try container.encodeIfPresent(classifier_version, forKey: .classifier_version)
                    try container.encodeIfPresent(mastery_threshold_version, forKey: .mastery_threshold_version)
                    try container.encodeIfPresent(last_assessed_at, forKey: .last_assessed_at)
                    try container.encode(AnyCodable(metadata), forKey: .metadata)
                }
            }

            let row = UpsertRow(
                child_profile_id: childProfileId,
                game_id: gameId,
                skill_key: skillKey,
                xp_total: xpTotal,
                level: level,
                sample_count: sampleCount,
                success_rate_7d: successRate7d,
                avg_time_ms_7d: avgTimeMs7d,
                avg_hints_7d: avgHints7d,
                completions_no_hint_7d: completionsNoHint7d,
                mastery_state: masteryState,
                mastery_score: masteryScore,
                first_mastered_at: firstMasteredAt,
                last_mastery_event_at: lastMasteryEventAt,
                classifier_version: classifierVersion,
                mastery_threshold_version: masteryThresholdVersion,
                last_assessed_at: lastAssessedAt,
                metadata: metadata
            )

            try await client
                .from("skill_progress")
                .upsert(row, onConflict: "child_profile_id,game_id,skill_key", returning: .minimal)
                .execute()
        } catch {
            print("Supabase: Failed to upsert skill progress - \(error)")
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "upsertSkillProgress",
                metadata: ["child_profile_id": childProfileId, "game_id": gameId, "skill_key": skillKey]
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
    
    func getCurrentUserID() async throws -> String {
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
        
        // Extract avatar fields from response or use defaults
        let avatarSymbol = response.avatar_symbol ?? "star.fill"
        let avatarColor = response.avatar_color ?? "blue"
        
        return UserProfile(
            id: response.id,
            userId: response.parent_user_id,
            name: response.name,
            age: response.age,
            gender: response.gender,
            avatarSymbol: avatarSymbol,
            avatarColor: avatarColor,
            totalXP: response.total_xp,
            preferences: preferences
        )
    }
}

// MARK: - Data Models

private struct ChildProfileXPResponse: Decodable {
    let total_xp: Int
}

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
    let avatar_symbol: String?
    let avatar_color: String?
    let total_xp: Int
    let preferences: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case id, parent_user_id, name, age, gender, avatar_symbol, avatar_color, total_xp, preferences
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(parent_user_id, forKey: .parent_user_id)
        try container.encode(name, forKey: .name)
        try container.encode(age, forKey: .age)
        try container.encode(gender, forKey: .gender)
        try container.encodeIfPresent(avatar_symbol, forKey: .avatar_symbol)
        try container.encodeIfPresent(avatar_color, forKey: .avatar_color)
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
    let avatar_symbol: String?
    let avatar_color: String?
    let total_xp: Int
    let preferences: [String: Any]
    let created_at: String
    let updated_at: String
    
    enum CodingKeys: String, CodingKey {
        case id, parent_user_id, name, age, gender, avatar_symbol, avatar_color, total_xp, preferences, created_at, updated_at
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        parent_user_id = try container.decode(String.self, forKey: .parent_user_id)
        name = try container.decode(String.self, forKey: .name)
        age = try container.decode(Int.self, forKey: .age)
        gender = try container.decode(String.self, forKey: .gender)
        avatar_symbol = try? container.decode(String.self, forKey: .avatar_symbol)
        avatar_color = try? container.decode(String.self, forKey: .avatar_color)
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

// Struct for direct insert (bypassing RPC function)
struct LearningEventInsert: Encodable {
    let id: UUID
    let child_profile_id: String
    let event_type: String
    let game_id: String
    let xp_awarded: Int
    let event_data: [String: Any]
    let session_id: String?
    
    enum CodingKeys: String, CodingKey {
        case id, child_profile_id, event_type, game_id, xp_awarded, event_data, session_id
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(child_profile_id, forKey: .child_profile_id)
        try container.encode(event_type, forKey: .event_type)
        try container.encode(game_id, forKey: .game_id)
        try container.encode(xp_awarded, forKey: .xp_awarded)
        try container.encode(AnyCodable(event_data), forKey: .event_data)
        try container.encodeIfPresent(session_id, forKey: .session_id)
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
                .upsert(puzzle, onConflict: "puzzle_id", returning: .minimal)
                .execute()
            
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
                .delete(returning: .minimal)
                .eq("puzzle_id", value: puzzleId)
                .execute()
            
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

    /// Fetch a single tangram puzzle by its puzzle_id
    func fetchTangramPuzzleById(puzzleId: String) async throws -> TangramPuzzleDTO? {
        guard isConnected || useServiceRole else {
            throw SupabaseError.notAuthenticated
        }
        do {
            let response = try await client
                .from("tangram_puzzles")
                .select()
                .eq("puzzle_id", value: puzzleId)
                .limit(1)
                .execute()

            let results = try JSONDecoder().decode([TangramPuzzleDTO].self, from: response.data)
            return results.first
        } catch {
            print("Supabase: Failed to fetch tangram puzzle by id - \(error)")
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "Supabase",
                action: "fetchTangramPuzzleById",
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

// MARK: - SpellQuest Content Storage

struct SpellQuestAlbumDTO: Decodable {
    let id: String        // uuid
    let album_id: String  // slug
    let title: String
    let difficulty: Int   // 1 easy, 2 normal, 3 hard
    let order_index: Int?
    let published_at: String?
    let tags: [String]?
    let metadata: AnyCodable?
}

struct SpellQuestPuzzleDTO: Decodable {
    let id: String        // uuid
    let puzzle_id: String // slug
    let album_id: String  // album uuid (FK)
    let word: String
    let display_title: String?
    let image_path: String
    let difficulty: Int
    let order_index: Int?
    let published_at: String?
    let tags: [String]?
    let metadata: AnyCodable?
}

extension SupabaseService {
    func fetchSpellQuestAlbums() async throws -> [SpellQuestAlbumDTO] {
        guard isConnected || useServiceRole else { 
            print("[SupabaseService] Not connected and not using service role, cannot fetch SpellQuest albums")
            throw SupabaseError.notAuthenticated 
        }
        
        print("[SupabaseService] Fetching SpellQuest albums...")
        let response = try await client
            .from("spellquest_albums")
            .select()
            .eq("is_official", value: true)
            .not("published_at", operator: .is, value: "null")
            .order("order_index", ascending: true)
            .execute()
        
        let albums = try JSONDecoder().decode([SpellQuestAlbumDTO].self, from: response.data)
        print("[SupabaseService] Successfully decoded \(albums.count) SpellQuest albums")
        return albums
    }

    func fetchSpellQuestPuzzles(albumUUIDs: [String]) async throws -> [SpellQuestPuzzleDTO] {
        guard isConnected || useServiceRole else { throw SupabaseError.notAuthenticated }
        
        // If albumUUIDs is provided, fetch only those albums' puzzles
        // Otherwise fetch all published puzzles
        if !albumUUIDs.isEmpty {
            // Fetch puzzles for each album and combine results
            var allPuzzles: [SpellQuestPuzzleDTO] = []
            for albumId in albumUUIDs {
                let response = try await client
                    .from("spellquest_puzzles")
                    .select()
                    .eq("album_id", value: albumId)
                    .eq("is_official", value: true)
                    .not("published_at", operator: .is, value: "null")
                    .order("order_index", ascending: true)
                    .execute()
                
                let puzzles = try JSONDecoder().decode([SpellQuestPuzzleDTO].self, from: response.data)
                allPuzzles.append(contentsOf: puzzles)
            }
            
            // Sort combined results by order_index
            return allPuzzles.sorted { ($0.order_index ?? 0) < ($1.order_index ?? 0) }
        } else {
            // Fetch all published puzzles
            let response = try await client
                .from("spellquest_puzzles")
                .select()
                .eq("is_official", value: true)
                .not("published_at", operator: .is, value: "null")
                .order("order_index", ascending: true)
                .execute()
            
            return try JSONDecoder().decode([SpellQuestPuzzleDTO].self, from: response.data)
        }
    }

    func getSpellQuestImagePublicURL(path: String) throws -> String {
        try client.storage
            .from("spellquest-images")
            .getPublicURL(path: path)
            .absoluteString
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
        } else if let double = try? container.decode(Double.self) {  // Check Double BEFORE Bool
            self.value = double
        } else if let float = try? container.decode(Float.self) {    // Add Float support
            self.value = float
        } else if let int = try? container.decode(Int.self) {        // Check Int BEFORE Bool
            self.value = int
        } else if let bool = try? container.decode(Bool.self) {      // Bool check moved to LAST
            self.value = bool
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
        case let double as Double:  // Check Double BEFORE Bool
            try container.encode(double)
        case let float as Float:    // Add Float support BEFORE Bool
            try container.encode(float)
        case let int as Int:        // Check Int BEFORE Bool
            try container.encode(int)
        case let bool as Bool:      // Bool check moved to LAST numeric position
            try container.encode(bool)
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
    case customError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated with Supabase"
        case .encodingFailed:
            return "Failed to encode data for Supabase"
        case .configurationMissing:
            return "Supabase configuration missing"
        case .customError(let message):
            return message
        }
    }
}

// MARK: - Custom Supabase Logger (removed - not available in current SDK)
