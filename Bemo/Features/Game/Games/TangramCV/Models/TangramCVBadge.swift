//
//  TangramCVBadge.swift
//  Bemo
//
//  Badge system for TangramCV puzzles
//

// WHAT: Badge types and display properties for CV version of Tangram
// ARCHITECTURE: Model in MVVM-S, used for puzzle selection UI
// USAGE: Applied to puzzles to highlight special properties (new, top pick, expert)

import SwiftUI

/// Badge type for TangramCV puzzles
enum TangramCVBadgeType: String, CaseIterable, Codable {
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

/// Badge calculation utilities for TangramCV
enum TangramCVBadgeCalculator {
    
    /// Returns the single highest priority badge based on puzzle properties
    /// Only one badge is shown per puzzle to keep UI clean
    static func calculateBadge(
        difficulty: Int,
        isNewest: Bool = false,
        isTopPick: Bool = false
    ) -> TangramCVBadgeType? {
        var possibleBadges: [TangramCVBadgeType] = []
        
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