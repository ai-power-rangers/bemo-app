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
        return "https://us.i.posthog.com"
    }
    
    // MARK: - Supabase Configuration
    
    var supabaseURL: String {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              !url.isEmpty,
              url != "YOUR_SUPABASE_PROJECT_URL" else {
            print("[AppConfiguration] SupabaseURL value from Info.plist: \(Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") ?? "nil")")
            assertionFailure("SupabaseURL not found or not configured in Info.plist")
            return ""
        }

        // Add this line to remove the escape characters
        let cleanedURL = url.replacingOccurrences(of: "\\", with: "")

        print("[AppConfiguration] SupabaseURL loaded: \(cleanedURL)")
        return cleanedURL // Return the cleaned URL
    }    
    var supabaseAnonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
              !key.isEmpty,
              key != "YOUR_SUPABASE_ANON_KEY" else {
            assertionFailure("SupabaseAnonKey not found or not configured in Info.plist")
            return ""
        }
        return key
    }
    
    // MARK: - Sentry Configuration
    
    var sentryDSN: String {
        guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String,
              !dsn.isEmpty,
              dsn != "YOUR_SENTRY_DSN" else {
            print("[AppConfiguration] SentryDSN value from Info.plist: \(Bundle.main.object(forInfoDictionaryKey: "SentryDSN") ?? "nil")")
            print("[AppConfiguration] Sentry DSN not configured - error tracking disabled")
            return ""
        }
        
        // Remove any escape characters
        let cleanedDSN = dsn.replacingOccurrences(of: "\\", with: "")
        
        print("[AppConfiguration] SentryDSN loaded: \(cleanedDSN)")
        return cleanedDSN
    }
    
    var sentryEnvironment: String {
        if isDebugBuild {
            return "debug"
        } else {
            return Bundle.main.object(forInfoDictionaryKey: "SentryEnvironment") as? String ?? "production"
        }
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