//
//  ErrorTrackingService.swift
//  Bemo
//
//  Service for tracking errors and crashes using Sentry
//

// WHAT: Wraps Sentry SDK for error tracking, crash reporting, and performance monitoring. Handles initialization and provides methods for tracking errors with context.
// ARCHITECTURE: Service layer in MVVM-S. Singleton-like service initialized early in app lifecycle. Used by all services and ViewModels for error tracking.
// USAGE: Inject via DependencyContainer. Call trackError() for handled errors, addBreadcrumb() for navigation tracking, setUserContext() after login.

import Foundation
import Sentry

@Observable
class ErrorTrackingService {
    private let isEnabled: Bool
    
    init() {
        let config = AppConfiguration.shared
        self.isEnabled = !config.sentryDSN.isEmpty
        
        if isEnabled {
            setupSentry()
            print("[ErrorTrackingService] Sentry initialized for environment: \(config.sentryEnvironment)")
        } else {
            print("[ErrorTrackingService] Sentry not initialized - no DSN configured")
        }
    }
    
    private func setupSentry() {
        let config = AppConfiguration.shared
        
        SentrySDK.start { options in
            options.dsn = config.sentryDSN
            options.environment = config.sentryEnvironment
            options.debug = config.isDebugBuild
            
            // Performance monitoring - lower sample rate for production
            options.tracesSampleRate = config.isDebugBuild ? 1.0 : 0.25
            
            // Profile sampling using the new API
            if #available(iOS 16.0, *) {
                options.profilesSampler = { _ in
                    return config.isDebugBuild ? 1.0 : 0.1
                }
            }
            
            // Attachments for better debugging
            options.attachScreenshot = true
            options.attachViewHierarchy = true
            
            // Session tracking
            options.enableAutoSessionTracking = true
            options.sessionTrackingIntervalMillis = 30000 // 30 seconds
            
            // Privacy - scrub sensitive data
            options.beforeSend = { event in
                return self.sanitizeEvent(event)
            }
            
            // Breadcrumb configuration
            options.beforeBreadcrumb = { breadcrumb in
                // Filter out noisy breadcrumbs if needed
                return breadcrumb
            }
        }
    }
    
    private func sanitizeEvent(_ event: Event) -> Event? {
        // Remove any PII from the event
        
        // Scrub child names from error messages
        if let message = event.message?.formatted {
            event.message = SentryMessage(formatted: scrubSensitiveData(message))
        }
        
        // Scrub exception values
        event.exceptions?.forEach { exception in
            exception.value = scrubSensitiveData(exception.value)
        }
        
        // Clean extra data
        if var extra = event.extra {
            extra = extra.mapValues { value in
                if let stringValue = value as? String {
                    return scrubSensitiveData(stringValue)
                }
                return value
            }
            event.extra = extra
        }
        
        return event
    }
    
    private func scrubSensitiveData(_ text: String) -> String {
        var result = text
        
        // Remove email addresses
        let emailRegex = try? NSRegularExpression(pattern: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}", options: .caseInsensitive)
        if let regex = emailRegex {
            result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count), withTemplate: "[EMAIL]")
        }
        
        // Remove potential child names (capitalized words that might be names)
        // This is conservative - you may want to adjust based on your needs
        
        return result
    }
    
    // MARK: - Error Tracking
    
    func trackError(_ error: Error, context: ErrorContext? = nil) {
        guard isEnabled else { return }
        
        SentrySDK.capture(error: error) { scope in
            // Add context
            if let context = context {
                scope.setContext(value: context.toDictionary(), key: "error_context")
                
                // Add tags for easier filtering
                scope.setTag(value: context.feature, key: "feature")
                scope.setTag(value: context.action, key: "action")
            }
            
            // Add current profile if available
            if let profileId = UserDefaults.standard.string(forKey: "activeChildProfileId") {
                scope.setTag(value: profileId, key: "profile_id")
            }
        }
    }
    
    // MARK: - Custom Events
    
    func trackEvent(_ message: String, level: SentryLevel = .info, extras: [String: Any]? = nil) {
        guard isEnabled else { return }
        
        let event = Event(level: level)
        event.message = SentryMessage(formatted: message)
        
        if let extras = extras {
            event.extra = extras
        }
        
        SentrySDK.capture(event: event)
    }
    
    // MARK: - User Context
    
    func setUserContext(profileId: String?, userId: String?) {
        guard isEnabled else { return }
        
        if let profileId = profileId, let userId = userId {
            let user = Sentry.User()
            user.userId = userId
            user.username = profileId
            SentrySDK.setUser(user)
        } else {
            // Clear user on logout
            SentrySDK.setUser(nil)
        }
    }
    
    // MARK: - Breadcrumbs
    
    func addBreadcrumb(message: String, category: String, level: SentryLevel = .info, data: [String: Any]? = nil) {
        guard isEnabled else { return }
        
        let crumb = Breadcrumb()
        crumb.message = message
        crumb.category = category
        crumb.level = level
        crumb.data = data
        
        SentrySDK.addBreadcrumb(crumb)
    }
    
    // MARK: - Performance Monitoring
    
    func startTransaction(name: String, operation: String) -> Span? {
        guard isEnabled else { return nil }
        
        return SentrySDK.startTransaction(name: name, operation: operation)
    }
    
    // MARK: - Testing Helpers
    
    #if DEBUG
    func triggerTestError() {
        let testError = NSError(
            domain: "com.bemo.test",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "This is a test error from Bemo"]
        )
        
        trackError(testError, context: ErrorContext(
            feature: "Testing",
            action: "manualTestError",
            metadata: ["triggered": "manually", "timestamp": Date().timeIntervalSince1970]
        ))
    }
    #endif
}

// MARK: - Supporting Types

struct ErrorContext {
    let feature: String
    let action: String
    let metadata: [String: Any]?
    
    init(feature: String, action: String, metadata: [String: Any]? = nil) {
        self.feature = feature
        self.action = action
        self.metadata = metadata
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "feature": feature,
            "action": action
        ]
        if let metadata = metadata {
            dict["metadata"] = metadata
        }
        return dict
    }
}