//
//  DevToolDelegate.swift
//  Bemo
//
//  Protocol for developer tools to communicate events back to the host
//

// WHAT: Protocol defining callbacks for dev tool events (save, quit, errors). Enables dev tools to communicate with the host.
// ARCHITECTURE: Communication bridge from isolated dev tools to DevToolHostViewModel. Implements inversion of control for dev tool modularity.
// USAGE: DevToolHostViewModel implements this. Dev tools receive delegate in makeDevToolView() and call methods to report events.

import Foundation

protocol DevToolDelegate: AnyObject {
    /// Called when the user requests to quit the dev tool
    func devToolDidRequestQuit()
    
    /// Called when the dev tool encounters an error
    /// - Parameter error: The error that occurred
    func devToolDidEncounterError(_ error: Error)
    
    /// Called when the dev tool wants to update its progress
    /// - Parameter progress: Progress value between 0.0 and 1.0
    func devToolDidUpdateProgress(_ progress: Float)
    
    /// Called when the dev tool successfully saves data
    /// - Parameter message: Optional success message to display
    func devToolDidSaveSuccessfully(message: String?)
    
    /// Called when the dev tool wants to show a toast/notification
    /// - Parameters:
    ///   - message: The message to display
    ///   - type: The type of notification (success, warning, error)
    func devToolDidShowNotification(message: String, type: NotificationType)
}

enum NotificationType {
    case success
    case warning
    case error
    case info
}