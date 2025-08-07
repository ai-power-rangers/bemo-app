//
//  GamePuzzleData+Badge.swift
//  Bemo
//
//  Badge system for puzzle thumbnails
//

import SwiftUI

extension GamePuzzleData {
    enum BadgeType: String {
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
        
        // Priority for badge selection (higher number = higher priority)
        var priority: Int {
            switch self {
            case .new: return 3
            case .topPick: return 2
            case .expert: return 1
            }
        }
    }
    
    /// Returns the single highest priority badge for this puzzle
    /// Only one badge is shown per puzzle to keep UI clean
    func getBadge(isNewest: Bool = false, isTopPick: Bool = false) -> BadgeType? {
        var possibleBadges: [BadgeType] = []
        
        // Check if this is the newest puzzle (would be determined by caller)
        if isNewest {
            possibleBadges.append(.new)
        }
        
        // Check if this is a top pick (would be determined by caller)
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

// Extension for TangramPuzzle (Editor model)
extension TangramPuzzle {
    enum BadgeType: String {
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
        
        // Priority for badge selection
        var priority: Int {
            switch self {
            case .new: return 3
            case .topPick: return 2
            case .expert: return 1
            }
        }
    }
    
    /// Returns the single highest priority badge for this puzzle
    func getBadge(allPuzzles: [TangramPuzzle]) -> BadgeType? {
        var possibleBadges: [BadgeType] = []
        
        // Find newest puzzle (most recent modifiedDate)
        let newestPuzzle = allPuzzles.max(by: { $0.modifiedDate < $1.modifiedDate })
        if let newest = newestPuzzle, newest.id == self.id {
            possibleBadges.append(.new)
        }
        
        // For demo: mark first puzzle as top pick
        // In production, this would use play count data
        if let firstPuzzle = allPuzzles.first, firstPuzzle.id == self.id {
            possibleBadges.append(.topPick)
        }
        
        // Check if expert level
        if difficulty.rawValue >= 4 {
            possibleBadges.append(.expert)
        }
        
        // Return the highest priority badge (only one)
        return possibleBadges.max(by: { $0.priority < $1.priority })
    }
}