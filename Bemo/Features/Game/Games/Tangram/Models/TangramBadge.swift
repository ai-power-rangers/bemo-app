//
//  TangramBadge.swift
//  Bemo
//
//  Unified badge system for Tangram puzzles
//

// WHAT: Single source of truth for puzzle badge types and display properties
// ARCHITECTURE: Model in MVVM-S, shared across game and editor
// USAGE: Used by both GamePuzzleData and TangramPuzzle for consistent badge display

import SwiftUI

/// Unified badge type for all Tangram puzzles
enum TangramBadgeType: String, CaseIterable, Codable {
    case new = "New"
    case topPick = "Top Pick"
    case expert = "Expert"
    
    var color: Color {
        switch self {
        case .new: return .blue
        case .topPick: return .yellow
        case .expert: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .new: return "sparkle"
        case .topPick: return "star.fill"
        case .expert: return "graduationcap.fill"
        }
    }
    
    /// Priority for badge selection (higher number = higher priority)
    var priority: Int {
        switch self {
        case .new: return 3
        case .topPick: return 2
        case .expert: return 1
        }
    }
}

/// Badge calculation utilities
enum TangramBadgeCalculator {
    
    /// Returns the single highest priority badge based on puzzle properties
    /// Only one badge is shown per puzzle to keep UI clean
    static func calculateBadge(
        difficulty: Int,
        isNewest: Bool = false,
        isTopPick: Bool = false
    ) -> TangramBadgeType? {
        var possibleBadges: [TangramBadgeType] = []
        
        // Check if this is the newest puzzle
        if isNewest {
            possibleBadges.append(.new)
        }
        
        // Check if this is a top pick
        if isTopPick {
            possibleBadges.append(.topPick)
        }
        
        // Check if expert level (difficulty 4 or 5)
        if difficulty >= 4 {
            possibleBadges.append(.expert)
        }
        
        // Return the highest priority badge (only one)
        return possibleBadges.max(by: { $0.priority < $1.priority })
    }
}