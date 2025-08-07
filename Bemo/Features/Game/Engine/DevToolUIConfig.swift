//
//  DevToolUIConfig.swift
//  Bemo
//
//  Configuration for customizing developer tool UI presentation
//

// WHAT: Configuration struct for dev tools to customize their container UI. Controls safe areas, overlays, and custom UI elements.
// ARCHITECTURE: Part of the DevTool protocol system. Allows dev tools to customize their container UI without modifying DevToolHostView.
// USAGE: Each DevTool implementation provides a devToolUIConfig property. DevToolHostView reads this to conditionally show/hide UI elements.

import SwiftUI

struct DevToolUIConfig {
    /// Whether the dev tool respects safe areas or uses full screen
    let respectsSafeAreas: Bool
    
    /// Whether to show a quit button in the top-left corner
    let showQuitButton: Bool
    
    /// Whether to show a progress bar
    let showProgressBar: Bool
    
    /// Whether to show a save button in the top-right corner
    let showSaveButton: Bool
    
    /// Custom top bar view (replaces default top bar if provided)
    let customTopBar: AnyView?
    
    /// Custom bottom bar view (displayed at bottom if provided)
    let customBottomBar: AnyView?
    
    /// Background color for the dev tool container
    let backgroundColor: Color?
    
    init(
        respectsSafeAreas: Bool = true,
        showQuitButton: Bool = true,
        showProgressBar: Bool = false,
        showSaveButton: Bool = false,
        customTopBar: AnyView? = nil,
        customBottomBar: AnyView? = nil,
        backgroundColor: Color? = nil
    ) {
        self.respectsSafeAreas = respectsSafeAreas
        self.showQuitButton = showQuitButton
        self.showProgressBar = showProgressBar
        self.showSaveButton = showSaveButton
        self.customTopBar = customTopBar
        self.customBottomBar = customBottomBar
        self.backgroundColor = backgroundColor
    }
}

// MARK: - Default Configurations
extension DevToolUIConfig {
    /// Default configuration for most dev tools
    static var defaultDevToolConfig: DevToolUIConfig {
        return DevToolUIConfig(
            respectsSafeAreas: true,
            showQuitButton: true,
            showProgressBar: false,
            showSaveButton: true
        )
    }
    
    /// Configuration for full-screen dev tools
    static var fullScreenDevToolConfig: DevToolUIConfig {
        return DevToolUIConfig(
            respectsSafeAreas: false,
            showQuitButton: true,
            showProgressBar: false,
            showSaveButton: true
        )
    }
    
    /// Configuration for dev tools with custom UI (no default overlays)
    static var customUIDevToolConfig: DevToolUIConfig {
        return DevToolUIConfig(
            respectsSafeAreas: true,
            showQuitButton: false,
            showProgressBar: false,
            showSaveButton: false
        )
    }
}