//
//  DevTool.swift
//  Bemo
//
//  Protocol defining the contract that all developer tools must follow
//

// WHAT: Protocol that all developer tools must implement. Similar to Game protocol but without child-focused features like CV processing and session tracking.
// ARCHITECTURE: Core protocol of the developer tool system. Enables modular dev tool addition without affecting game engine.
// USAGE: Implement this protocol for new dev tools. Must provide makeDevToolView(), and can specify parent auth requirements.

import SwiftUI

protocol DevTool {
    var id: String { get }
    var title: String { get }
    var description: String { get }
    var recommendedAge: ClosedRange<Int> { get }
    var thumbnailImageName: String { get }
    
    /// Whether this tool requires parent authentication to access
    var requiresParentAuth: Bool { get }
    
    /// UI configuration preferences for this dev tool
    var devToolUIConfig: DevToolUIConfig { get }
    
    /// Creates and returns the SwiftUI view for this dev tool
    /// - Parameter delegate: The delegate to communicate dev tool events back to the host
    /// - Returns: Type-erased SwiftUI view for the dev tool
    func makeDevToolView(delegate: DevToolDelegate) -> AnyView
    
    /// Called when the dev tool should reset to its initial state
    func reset()
    
    /// Returns the current dev tool state for persistence
    func saveState() -> Data?
    
    /// Restores the dev tool from a previously saved state
    func loadState(from data: Data)
}

// MARK: - Default Implementations
extension DevTool {
    /// Default UI configuration for dev tools (can be overridden)
    var devToolUIConfig: DevToolUIConfig {
        return .defaultDevToolConfig
    }
    
    /// Dev tools typically don't require parent auth by default
    var requiresParentAuth: Bool {
        return false
    }
}