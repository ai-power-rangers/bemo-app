//
//  GamePuzzleData+CVBadge.swift
//  Bemo
//
//  Badge extensions for TangramCV puzzle types
//

// WHAT: Extensions to add badge calculation to GamePuzzleData for CV version
// ARCHITECTURE: Model extension in MVVM-S pattern
// USAGE: Call getBadge() on any puzzle to get its display badge

import SwiftUI

// MARK: - GamePuzzleData Extension

extension GamePuzzleData {
    /// Returns the single highest priority badge for this puzzle
    /// Only one badge is shown per puzzle to keep UI clean
    func getCVBadge(isNewest: Bool = false, isTopPick: Bool = false) -> TangramCVBadgeType? {
        return TangramCVBadgeCalculator.calculateBadge(
            difficulty: difficulty,
            isNewest: isNewest,
            isTopPick: isTopPick
        )
    }
    
    /// Alternative method that determines newest and top pick from puzzle array
    func getCVBadge(allPuzzles: [GamePuzzleData]) -> TangramCVBadgeType? {
        // Find newest puzzle (for demo, using name sorting as proxy for date)
        // In production, this would use actual timestamps
        let isNewest = allPuzzles.last?.id == self.id
        
        // For demo: mark first puzzle as top pick
        // In production, this would use play count data
        let isTopPick = allPuzzles.first?.id == self.id
        
        return TangramCVBadgeCalculator.calculateBadge(
            difficulty: difficulty,
            isNewest: isNewest,
            isTopPick: isTopPick
        )
    }
}