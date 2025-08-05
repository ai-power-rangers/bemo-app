//
//  AppConfiguration.swift
//  Bemo
//
//  Centralized configuration management for the app
//

// WHAT: Provides type-safe access to configuration values from Info.plist that are populated from .xcconfig files
// ARCHITECTURE: Shared utility in MVVM-S. Used by Services to get environment-specific configuration
// USAGE: AppConfiguration.shared.postHogAPIKey to access values. Handles missing keys gracefully with fallbacks.

import Foundation

class AppConfiguration {
    static let shared = AppConfiguration()
    
    private init() {}
    
    // MARK: - PostHog Configuration
    
    var postHogAPIKey: String {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "PostHogAPIKey") as? String,
              !apiKey.isEmpty else {
            assertionFailure("PostHogAPIKey not found in Info.plist")
            return ""
        }
        return apiKey
    }
    
    var postHogHost: String {
        guard let host = Bundle.main.object(forInfoDictionaryKey: "PostHogHost") as? String,
              !host.isEmpty else {
            assertionFailure("PostHogHost not found in Info.plist")
            return "https://us.i.posthog.com"
        }
        return host
    }
    
    // MARK: - Debug Helpers
    
    var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}