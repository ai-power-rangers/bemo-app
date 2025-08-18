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
    case locked      // Cannot be played yet - future puzzles
    case current     // The next puzzle in progression (highlighted)
    case completed   // Already finished - available for replay
    
    var isInteractive: Bool {
        switch self {
        case .locked: return false
        case .current, .completed: return true
        }
    }
}
