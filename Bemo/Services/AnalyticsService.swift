//
//  AnalyticsService.swift
//  Bemo
//
//  Service for tracking user analytics and game events using PostHog
//

// WHAT: Wrapper around PostHog SDK for tracking game events. Handles game clicks, session durations, and user behavior analytics.
// ARCHITECTURE: Service layer in MVVM-S. Simple method calls, no reactive bindings. Used directly by ViewModels when events occur.
// USAGE: Inject into ViewModels that need tracking. Call trackGameSelected() for clicks, startGameSession()/endGameSession() for duration.

import Foundation
import PostHog

class AnalyticsService {
    
    // Session tracking
    private var gameSessionStartTime: Date?
    private var currentGameId: String?
    private var isConfigured = false
    
    init() {
        setupPostHog()
    }
    
    private func setupPostHog() {
        let configuration = AppConfiguration.shared
        let apiKey = configuration.postHogAPIKey
        
        // Skip PostHog setup if API key is not configured
        guard !apiKey.isEmpty else {
            print("⚠️ PostHog API key not configured - analytics disabled")
            isConfigured = false
            return
        }
        
        var config = PostHogConfig(
            apiKey: apiKey,
            host: configuration.postHogHost
        )
        
        config.debug = configuration.isDebugBuild
        config.debug = configuration.isDebugBuild
        config.captureScreenViews = true  // Track screen navigation
        config.captureApplicationLifecycleEvents = true  // Track app lifecycle
        config.captureElementInteractions = false  // Disable to reduce noise in games
        config.flushAt = 10  // Batch events for efficiency

        PostHogSDK.shared.setup(config)
        isConfigured = true
    }
    
    
    func clearUser() {
        guard isConfigured else { return }
        PostHogSDK.shared.reset()
    }
    
    // MARK: - Game Events
    
    func trackGameSelected(gameId: String, gameTitle: String, userId: String) {
        guard isConfigured else { 
            print("📊 Analytics (disabled): Game selected - \(gameTitle)")
            return 
        }
        PostHogSDK.shared.capture(
            "game_selected",
            properties: [
                "game_id": gameId,
                "game_title": gameTitle,
                "user_id": userId,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
        
        print("📊 Analytics: Game selected - \(gameTitle)")
    }
    
    func startGameSession(gameId: String, gameTitle: String, userId: String) {
        gameSessionStartTime = Date()
        currentGameId = gameId
        
        guard isConfigured else { 
            print("📊 Analytics (disabled): Game session started - \(gameTitle)")
            return 
        }
        PostHogSDK.shared.capture(
            "game_session_started",
            properties: [
                "game_id": gameId,
                "game_title": gameTitle,
                "user_id": userId
            ]
        )
        
        print("📊 Analytics: Game session started - \(gameTitle)")
    }
    
    func endGameSession(userId: String, reason: GameSessionEndReason = .returnedToLobby) {
        guard let startTime = gameSessionStartTime,
              let gameId = currentGameId else {
            return
        }
        
        let sessionDuration = Date().timeIntervalSince(startTime)
        
        guard isConfigured else { 
            print("📊 Analytics (disabled): Game session ended - Duration: \(String(format: "%.1f", sessionDuration / 60)) minutes")
            gameSessionStartTime = nil
            currentGameId = nil
            return 
        }
        PostHogSDK.shared.capture(
            "game_session_ended",
            properties: [
                "game_id": gameId,
                "user_id": userId,
                "session_duration_seconds": sessionDuration,
                "session_duration_minutes": sessionDuration / 60,
                "session_end_reason": reason.rawValue
            ]
        )
        
        print("📊 Analytics: Game session ended - Duration: \(String(format: "%.1f", sessionDuration / 60)) minutes")
        
        // Reset session tracking
        gameSessionStartTime = nil
        currentGameId = nil
    }
}

enum GameSessionEndReason: String {
    case returnedToLobby = "returned_to_lobby"
    case quitGame = "quit_game"
    case levelCompleted = "level_completed"
}
