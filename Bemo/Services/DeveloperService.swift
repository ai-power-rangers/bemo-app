//
//  DeveloperService.swift
//  Bemo
//
//  Service for detecting if the current user is a developer
//

// WHAT: Determines if the authenticated user is a developer based on their Apple Sign-In email address.
// ARCHITECTURE: Simple service in MVVM-S providing developer detection capability.
// USAGE: Inject into ViewModels to conditionally show developer features like editor tools.

import Foundation
import Observation

@Observable
class DeveloperService {
    
    // MARK: - Developer Configuration
    
    /// Known developer email domains and specific addresses
    private static let developerEmails: Set<String> = [
        "roosh.Bemo",           // Roosh's developer Apple ID
        "com.roosh.Bemo",
        "com.mitchellwhite.Bemo", // Mitchell's developer Apple ID  
        "com.bemo.services",     // Bemo services account (unclear but included)
        "000767.d1fc3d632c26450c9435e21be79649d3.0250", // Mitchell's actual Apple ID from database
        "001294.16f395dadbdc471fb1bd3df6126e1437.2034"  // Another developer Apple ID from database
    ]
    
    /// Additional email domains that should have developer access
    private static let developerDomains: Set<String> = [
        // Add any company email domains here if needed
        // "bemo.com",
        // "yourdomain.com"
    ]
    
    // MARK: - Authentication Integration
    
    private weak var authenticationService: AuthenticationService?
    
    init(authenticationService: AuthenticationService? = nil) {
        self.authenticationService = authenticationService
    }
    
    func setAuthenticationService(_ authenticationService: AuthenticationService) {
        self.authenticationService = authenticationService
    }
    
    // MARK: - Developer Detection
    
    /// Returns true if the current authenticated user is a developer
    var isDeveloper: Bool {
        guard let authService = authenticationService,
              let currentUser = authService.currentUser else {
            return false
        }
        
        return isDeveloper(user: currentUser)
    }
    
    /// Returns true if the specified user is a developer
    /// - Parameter user: The authenticated user to check
    /// - Returns: true if the user is a developer
    func isDeveloper(user: AuthenticatedUser) -> Bool {
        // TEMPORARY OVERRIDE FOR TESTING - REMOVE IN PRODUCTION
        #if DEBUG
        print("🛠️ DEBUG MODE: Developer access granted for testing (user: \(user.appleUserIdentifier))")
        return true
        #else
        
        // Check by email address first
        if let email = user.email {
            // Check exact email matches
            if Self.developerEmails.contains(email) {
                return true
            }
            
            // Check domain matches
            let emailComponents = email.split(separator: "@")
            if emailComponents.count == 2 {
                let domain = String(emailComponents[1])
                if Self.developerDomains.contains(domain) {
                    return true
                }
            }
        }
        
        // Check by Apple user identifier as fallback (Apple Sign-In sometimes uses identifiers)
        if Self.developerEmails.contains(user.appleUserIdentifier) {
            return true
        }
        
        return false
        #endif
    }
    
    /// Returns the developer role/type for the current user
    var developerRole: DeveloperRole? {
        guard isDeveloper else { return nil }
        
        guard let currentUser = authenticationService?.currentUser else {
            return nil
        }
        
        // Determine role based on email/identifier
        if let email = currentUser.email {
            switch email {
            case "roosh.Bemo":
                return .founder
            case "com.mitchellwhite.Bemo":
                return .founder
            case "com.bemo.services":
                return .service
            default:
                return .developer
            }
        }
        
        return .developer
    }
    
    /// Available developer tools for the current user
    var availableDevTools: [DevToolType] {
        guard isDeveloper else { return [] }
        
        // For now, all developers get access to all tools
        // In the future, you could restrict tools based on role
        return [.tangramEditor, .animationLab, .tangramProgress]
    }
}

// MARK: - Supporting Types

enum DeveloperRole {
    case founder        // Core founders (roosh, mitchell)
    case developer      // Other developers
    case service        // Service accounts
    
    var displayName: String {
        switch self {
        case .founder:
            return "Founder"
        case .developer:
            return "Developer"
        case .service:
            return "Service"
        }
    }
}

enum DevToolType {
    case tangramEditor
    case animationLab
    case tangramProgress
    // Add future dev tools here:
    // case levelEditor
    // case analyticsConsole
    // case debugPanel
    
    var displayName: String {
        switch self {
        case .tangramEditor:
            return "Tangram Editor"
        case .animationLab:
            return "Animation Lab"
        case .tangramProgress:
            return "Progress Test"
        }
    }
    
    var description: String {
        switch self {
        case .tangramEditor:
            return "Create and edit tangram puzzles"
        case .animationLab:
            return "Test and debug animations"
        case .tangramProgress:
            return "Test difficulty selection and progress tracking"
        }
    }
}