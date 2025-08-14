//
//  LearningService.swift
//  Bemo
//
//  WHAT: Centralized learning telemetry, skill aggregation, and mastery observation
//  ARCHITECTURE: Service in MVVM-S (@Observable), wraps Supabase learning_events and updates skill_progress
//  USAGE: Inject via DependencyContainer. Games call record* methods; service scopes writes to active child.
//

import Foundation
import Observation

@Observable
class LearningService {
    // MARK: - Nested Types

    enum SkillKey: String, CaseIterable {
        case shapeMatching = "shape_matching"
        case mentalRotation = "mental_rotation"
        case reflection = "reflection"
        case decomposition = "decomposition"
        case planningSequencing = "planning_sequencing"
    }

    struct SkillProfileWeights {
        var weights: [SkillKey: Double]

        init(weights: [SkillKey: Double]) {
            self.weights = weights
        }

        static var baseline: SkillProfileWeights {
            return SkillProfileWeights(weights: [
                .shapeMatching: 0.1,
                .mentalRotation: 0.0,
                .reflection: 0.0,
                .decomposition: 0.0,
                .planningSequencing: 0.0
            ])
        }
    }

    // MARK: - Dependencies

    private let supabaseService: SupabaseService
    private let profileService: ProfileService
    private let errorTrackingService: ErrorTrackingService?

    // MARK: - State

    private var currentSessionIdByGame: [String: String] = [:]

    // MARK: - Init

    init(supabaseService: SupabaseService, profileService: ProfileService, errorTrackingService: ErrorTrackingService? = nil) {
        self.supabaseService = supabaseService
        self.profileService = profileService
        self.errorTrackingService = errorTrackingService
        #if DEBUG
        print("[LearningService] Initialized")
        #endif
    }

    // MARK: - Session Lifecycle

    func startSession(gameId: String, context: [String: Any] = [:]) {
        guard let childId = profileService.activeProfile?.id else {
            #if DEBUG
            print("[LearningService] startSession aborted: no active child profile")
            #endif
            return
        }
        #if DEBUG
        print("[LearningService] startSession gameId=\(gameId) childId=\(childId) context=\(context)")
        #endif
        Task {
            do {
                let sessionId = try await supabaseService.startGameSession(
                    childProfileId: childId,
                    gameId: gameId,
                    sessionData: context
                )
                self.currentSessionIdByGame[gameId] = sessionId
                #if DEBUG
                print("[LearningService] startSession success sessionId=\(sessionId)")
                #endif
            } catch {
                self.errorTrackingService?.trackError(error, context: ErrorContext(
                    feature: "LearningService",
                    action: "startSession",
                    metadata: ["gameId": gameId]
                ))
                #if DEBUG
                print("[LearningService] startSession error=\(error)")
                #endif
            }
        }
    }

    func endSession(gameId: String, finalXP: Int = 0, levelsCompleted: Int = 0, context: [String: Any] = [:]) {
        guard let sessionId = currentSessionIdByGame[gameId] else {
            #if DEBUG
            print("[LearningService] endSession skipped: no session for gameId=\(gameId)")
            #endif
            return
        }
        #if DEBUG
        print("[LearningService] endSession gameId=\(gameId) sessionId=\(sessionId) finalXP=\(finalXP) levels=\(levelsCompleted) context=\(context)")
        #endif
        Task {
            do {
                try await supabaseService.endGameSession(
                    sessionId: sessionId,
                    finalXPEarned: finalXP,
                    finalLevelsCompleted: levelsCompleted,
                    finalSessionData: context
                )
                #if DEBUG
                print("[LearningService] endSession success")
                #endif
            } catch {
                self.errorTrackingService?.trackError(error, context: ErrorContext(
                    feature: "LearningService",
                    action: "endSession",
                    metadata: ["gameId": gameId, "sessionId": sessionId]
                ))
                #if DEBUG
                print("[LearningService] endSession error=\(error)")
                #endif
            }
            self.currentSessionIdByGame.removeValue(forKey: gameId)
        }
    }

    // MARK: - Event Recording (wrapped learning_events)
    
    func recordEvent(gameId: String, eventType: String, xpAwarded: Int = 0, eventData: [String: Any] = [:]) {
        guard let childId = profileService.activeProfile?.id else {
            #if DEBUG
            print("[LearningService] recordEvent aborted: no active child")
            #endif
            return
        }
        #if DEBUG
        print("[LearningService] recordEvent type=\(eventType) gameId=\(gameId) xp=\(xpAwarded) data=\(eventData)")
        #endif
        Task {
            try? await supabaseService.trackLearningEvent(
                childProfileId: childId,
                eventType: eventType,
                gameId: gameId,
                xpAwarded: xpAwarded,
                eventData: eventData,
                sessionId: currentSessionIdByGame[gameId]
            )
        }
    }

    func recordPuzzleStarted(gameId: String, puzzleId: String, difficulty: Int, context: [String: Any] = [:]) {
        guard let childId = profileService.activeProfile?.id else { return }
        let payload: [String: Any] = [
            "puzzle_id": puzzleId,
            "difficulty": difficulty
        ].merging(context) { $1 }
        #if DEBUG
        print("[LearningService] recordPuzzleStarted puzzleId=\(puzzleId) difficulty=\(difficulty) context=\(context)")
        #endif

        Task {
            try? await supabaseService.trackLearningEvent(
                childProfileId: childId,
                eventType: "puzzle_started",
                gameId: gameId,
                xpAwarded: 0,
                eventData: payload,
                sessionId: currentSessionIdByGame[gameId]
            )
        }
    }

    func recordHintRequested(gameId: String, puzzleId: String, hintType: String, reason: String, context: [String: Any] = [:]) {
        guard let childId = profileService.activeProfile?.id else { return }
        let payload: [String: Any] = [
            "puzzle_id": puzzleId,
            "hint_type": hintType,
            "hint_reason": reason
        ].merging(context) { $1 }
        #if DEBUG
        print("[LearningService] recordHintRequested puzzleId=\(puzzleId) hintType=\(hintType) reason=\(reason)")
        #endif

        Task {
            try? await supabaseService.trackLearningEvent(
                childProfileId: childId,
                eventType: "hint_used",
                gameId: gameId,
                xpAwarded: 0,
                eventData: payload,
                sessionId: currentSessionIdByGame[gameId]
            )
        }
    }

    // MARK: - Completion recording with skill_progress updates

    func recordPuzzleCompleted(
        gameId: String,
        puzzleId: String,
        difficulty: Int,
        completionTimeSeconds: Double,
        hintsUsed: Int,
        xpAwarded: Int,
        context: [String: Any] = [:]
    ) {
        #if DEBUG
        print("🎮 [LearningService] recordPuzzleCompleted called")
        print("   - activeProfile: \(profileService.activeProfile?.name ?? "NIL")")
        print("   - activeProfileId: \(profileService.activeProfile?.id ?? "NIL")")
        #endif
        
        guard let childId = profileService.activeProfile?.id else { 
            #if DEBUG
            print("❌ [LearningService] No active profile - aborting skill progress update")
            #endif
            return 
        }

        // 1) Log learning_event
        var eventPayload: [String: Any] = [
            "puzzle_id": puzzleId,
            "difficulty": difficulty,
            "completion_time_seconds": completionTimeSeconds,
            "hints_used": hintsUsed,
            "xp_awarded": xpAwarded
        ]
        eventPayload.merge(context) { $1 }
        #if DEBUG
        print("📝 [LearningService] recordPuzzleCompleted puzzleId=\(puzzleId) time=\(completionTimeSeconds)s hints=\(hintsUsed) xp=\(xpAwarded)")
        #endif

        Task { [weak self] in
            guard let self else { 
                #if DEBUG
                print("❌ [LearningService] self is nil in Task - aborting")
                #endif
                return 
            }
            
            // Record event (fire and forget)
            do {
                try await self.supabaseService.trackLearningEvent(
                    childProfileId: childId,
                    eventType: "puzzle_completed",
                    gameId: gameId,
                    xpAwarded: xpAwarded,
                    eventData: eventPayload,
                    sessionId: self.currentSessionIdByGame[gameId]
                )
                #if DEBUG
                print("✅ [LearningService] Learning event tracked successfully")
                #endif
            } catch {
                #if DEBUG
                print("❌ [LearningService] Failed to track learning event: \(error)")
                #endif
            }

            // 2) Fetch or derive skill profile for this puzzle
            #if DEBUG
            print("🔄 [LearningService] Fetching skill profile...")
            #endif
            let profile = await self.fetchSkillProfile(for: puzzleId)
            #if DEBUG
            print("📊 [LearningService] skill profile fetched for puzzleId=\(puzzleId): \(profile.weights)")
            #endif

            // 3) Update per-skill aggregates and basic mastery observation
            #if DEBUG
            print("🔄 [LearningService] Updating skill progress...")
            #endif
            await self.updateSkillProgress(
                childProfileId: childId,
                gameId: gameId,
                puzzleId: puzzleId,
                completionTimeSeconds: completionTimeSeconds,
                hintsUsed: hintsUsed,
                xpAwarded: xpAwarded,
                skillProfile: profile
            )
            #if DEBUG
            print("✅ [LearningService] Skill progress update complete")
            #endif
        }
    }

    // MARK: - Private helpers

    private func fetchSkillProfile(for puzzleId: String) async -> SkillProfileWeights {
        #if DEBUG
        print("🔍 [LearningService] fetchSkillProfile for puzzleId: \(puzzleId)")
        #endif
        
        do {
            if let dto = try await supabaseService.fetchTangramPuzzleById(puzzleId: puzzleId) {
                #if DEBUG
                print("✅ [LearningService] Fetched puzzle DTO successfully")
                print("   - metadata exists: \(dto.metadata != nil)")
                if let meta = dto.metadata?.value {
                    print("   - metadata type: \(type(of: meta))")
                    if let metaDict = meta as? [String: Any] {
                        print("   - metadata keys: \(metaDict.keys.sorted())")
                        print("   - has skill_profile: \(metaDict["skill_profile"] != nil)")
                    }
                }
                #endif
                
                if let meta = dto.metadata?.value as? [String: Any],
                   let sp = meta["skill_profile"] as? [String: Any] {
                    var weights: [SkillKey: Double] = [:]
                    
                    #if DEBUG
                    print("📊 [LearningService] Found skill_profile: \(sp)")
                    #endif
                    
                    for (k, v) in sp {
                        guard let val = v as? Double else { 
                            #if DEBUG
                            print("⚠️ [LearningService] Skipping non-double value for key \(k): \(v)")
                            #endif
                            continue 
                        }
                        if let key = SkillKey(rawValue: k) {
                            weights[key] = val
                            #if DEBUG
                            print("   - Added skill: \(k) = \(val)")
                            #endif
                        } else {
                            #if DEBUG
                            print("⚠️ [LearningService] Unknown skill key: \(k)")
                            #endif
                        }
                    }
                    if !weights.isEmpty { 
                        #if DEBUG
                        print("✅ [LearningService] Returning skill weights: \(weights)")
                        #endif
                        return SkillProfileWeights(weights: weights) 
                    }
                } else {
                    #if DEBUG
                    print("❌ [LearningService] No skill_profile found in metadata")
                    #endif
                }
            } else {
                #if DEBUG
                print("❌ [LearningService] Failed to fetch puzzle DTO")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ [LearningService] fetchSkillProfile error=\(error)")
            #endif
            // ignore and fall back
        }
        
        #if DEBUG
        print("⚠️ [LearningService] Returning baseline skill profile")
        #endif
        return .baseline
    }

    @MainActor
    private func updateSkillProgress(
        childProfileId: String,
        gameId: String,
        puzzleId: String,
        completionTimeSeconds: Double,
        hintsUsed: Int,
        xpAwarded: Int,
        skillProfile: SkillProfileWeights
    ) async {
        do {
            for (skill, weight) in skillProfile.weights where weight > 0 {
                // Compute simple deltas
                let deltaXP = Int(Double(xpAwarded) * weight)
                let noHint = hintsUsed == 0
                #if DEBUG
                print("🎯 [LearningService] updateSkillProgress skill=\(skill.rawValue) weight=\(weight) deltaXP=\(deltaXP) noHint=\(noHint)")
                #endif

                // Read existing row (if any)
                #if DEBUG
                print("   - Fetching existing skill progress for \(skill.rawValue)...")
                #endif
                let existing = try await supabaseService.fetchSkillProgress(
                    childProfileId: childProfileId,
                    gameId: gameId,
                    skillKey: skill.rawValue
                )
                #if DEBUG
                print("   - Existing progress: \(existing != nil ? "Found (xp=\(existing!.xp_total), samples=\(existing!.sample_count))" : "Not found")")
                #endif

                // Aggregate client-side
                let newXp = (existing?.xp_total ?? 0) + deltaXP
                let newSamples = (existing?.sample_count ?? 0) + 1
                let prevNoHint7d = existing?.completions_no_hint_7d ?? 0
                let newNoHint7d = prevNoHint7d + (noHint ? 1 : 0)

                // Basic mastery heuristic v1
                var newState = existing?.mastery_state ?? "none"
                var firstMasteredAt = existing?.first_mastered_at
                var lastMasteryEventAt = existing?.last_mastery_event_at
                var masteryScore = existing?.mastery_score ?? 0.0

                if newNoHint7d >= 3 && (existing?.mastery_state ?? "none") == "none" {
                    newState = "candidate"
                    masteryScore = max(masteryScore, 0.6)
                    lastMasteryEventAt = ISO8601DateFormatter().string(from: Date())
                    #if DEBUG
                    print("[LearningService] mastery_observation skill=\(skill.rawValue) state=candidate noHint7d=\(newNoHint7d)")
                    #endif
                }

                // Persist upsert
                #if DEBUG
                print("   - Upserting skill progress: xp=\(newXp), samples=\(newSamples), noHint7d=\(newNoHint7d)")
                #endif
                
                try await supabaseService.upsertSkillProgress(
                    childProfileId: childProfileId,
                    gameId: gameId,
                    skillKey: skill.rawValue,
                    xpTotal: newXp,
                    level: existing?.level ?? 0,
                    sampleCount: newSamples,
                    successRate7d: existing?.success_rate_7d ?? 0.0, // placeholder
                    avgTimeMs7d: existing?.avg_time_ms_7d,
                    avgHints7d: existing?.avg_hints_7d ?? 0.0, // placeholder
                    completionsNoHint7d: newNoHint7d,
                    masteryState: newState,
                    masteryScore: masteryScore,
                    firstMasteredAt: firstMasteredAt,
                    lastMasteryEventAt: lastMasteryEventAt,
                    classifierVersion: existing?.classifier_version,
                    masteryThresholdVersion: existing?.mastery_threshold_version,
                    lastAssessedAt: ISO8601DateFormatter().string(from: Date()),
                    metadata: [
                        "puzzle_id": puzzleId,
                        "last_completion_time_s": completionTimeSeconds,
                        "last_hints_used": hintsUsed
                    ]
                )
                
                #if DEBUG
                print("   ✅ Skill progress upserted successfully for \(skill.rawValue)")
                #endif

                // Emit mastery_observation event when state changed to candidate
                if existing?.mastery_state != newState && newState == "candidate" {
                    try? await supabaseService.trackLearningEvent(
                        childProfileId: childProfileId,
                        eventType: "mastery_observation",
                        gameId: gameId,
                        xpAwarded: 0,
                        eventData: [
                            "skill_key": skill.rawValue,
                            "state": newState,
                            "no_hint_7d": newNoHint7d
                        ],
                        sessionId: currentSessionIdByGame[gameId]
                    )
                }
            }
        } catch {
            errorTrackingService?.trackError(error, context: ErrorContext(
                feature: "LearningService",
                action: "updateSkillProgress",
                metadata: ["gameId": gameId, "puzzleId": puzzleId]
            ))
            #if DEBUG
            print("❌ [LearningService] updateSkillProgress error=\(error)")
            print("   - childProfileId: \(childProfileId)")
            print("   - gameId: \(gameId)")
            print("   - puzzleId: \(puzzleId)")
            print("   - skillProfile: \(skillProfile.weights)")
            #endif
        }
    }
}



