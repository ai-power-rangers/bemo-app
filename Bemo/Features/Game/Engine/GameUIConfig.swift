//
//  GameUIConfig.swift
//  Bemo
//
//  Configuration for game-specific UI preferences
//

// WHAT: Configuration struct that games use to declare their UI preferences (safe areas, hints, progress bar, etc.)
// ARCHITECTURE: Part of the Game protocol system. Allows games to customize their container UI without modifying GameHostView.
// USAGE: Each Game implementation provides a gameUIConfig property. GameHostView reads this to conditionally show/hide UI elements.

import SwiftUI

struct GameUIConfig {
    /// Whether the game content should respect safe areas (true for tools/editors, false for immersive games)
    let respectsSafeAreas: Bool
    
    /// Whether to show the hint button in the game UI
    let showHintButton: Bool
    
    /// Whether to show the progress bar at the top
    let showProgressBar: Bool
    
    /// Whether to show the quit/close button (recommended to always be true)
    let showQuitButton: Bool
    
    /// Optional custom overlay views
    let customTopBar: AnyView?
    let customBottomBar: AnyView?
    
    /// Default initializer with sensible game defaults
    init(
        respectsSafeAreas: Bool = false,  // Games typically want full screen
        showHintButton: Bool = true,       // Most games have hints
        showProgressBar: Bool = true,      // Most games track progress
        showQuitButton: Bool = true,       // Always allow quitting
        customTopBar: AnyView? = nil,
        customBottomBar: AnyView? = nil
    ) {
        self.respectsSafeAreas = respectsSafeAreas
        self.showHintButton = showHintButton
        self.showProgressBar = showProgressBar
        self.showQuitButton = showQuitButton
        self.customTopBar = customTopBar
        self.customBottomBar = customBottomBar
    }
    
    /// Convenience initializer for editor/tool configurations
    static var editorConfig: GameUIConfig {
        GameUIConfig(
            respectsSafeAreas: true,
            showHintButton: false,
            showProgressBar: false,
            showQuitButton: true
        )
    }
    
    /// Default game configuration
    static var defaultGameConfig: GameUIConfig {
        GameUIConfig()
    }
}