//
//  MapNodeState.swift
//  Bemo
//
//  State enum for map puzzle nodes
//

// WHAT: Represents the visual state of a puzzle node on the map
// ARCHITECTURE: Model in MVVM-S pattern, shared between ViewModels and Views
// USAGE: Used by TangramMapViewModel and MapNodeView to determine node appearance and interactions

import Foundation

/// Represents the visual state of a puzzle node on the map
enum MapNodeState {
    case locked      // Cannot be played yet
    case unlocked    // Available to play
    case current     // The next puzzle in progression (highlighted)
    case completed   // Already finished
    
    var isInteractive: Bool {
        switch self {
        case .locked: return false
        case .unlocked, .current, .completed: return true
        }
    }
}
