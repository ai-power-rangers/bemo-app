//
//  GamePuzzleData+Badge.swift
//  Bemo
//
//  Badge extensions for puzzle types
//

import SwiftUI

// MARK: - GamePuzzleData Extension

extension GamePuzzleData {
    /// Returns the single highest priority badge for this puzzle
    /// Only one badge is shown per puzzle to keep UI clean
    func getBadge(isNewest: Bool = false, isTopPick: Bool = false) -> TangramBadgeType? {
        return TangramBadgeCalculator.calculateBadge(
            difficulty: difficulty,
            isNewest: isNewest,
            isTopPick: isTopPick
        )
    }
}

// MARK: - TangramPuzzle Extension

extension TangramPuzzle {
    /// Returns the single highest priority badge for this puzzle
    func getBadge(allPuzzles: [TangramPuzzle]) -> TangramBadgeType? {
        // Find newest puzzle (most recent modifiedDate)
        let newestPuzzle = allPuzzles.max(by: { $0.modifiedDate < $1.modifiedDate })
        let isNewest = newestPuzzle?.id == self.id
        
        // For demo: mark first puzzle as top pick
        // In production, this would use play count data
        let isTopPick = allPuzzles.first?.id == self.id
        
        return TangramBadgeCalculator.calculateBadge(
            difficulty: difficulty.rawValue,
            isNewest: isNewest,
            isTopPick: isTopPick
        )
    }
    
    /// Alternative method matching GamePuzzleData's signature
    func getBadge(isNewest: Bool = false, isTopPick: Bool = false) -> TangramBadgeType? {
        return TangramBadgeCalculator.calculateBadge(
            difficulty: difficulty.rawValue,
            isNewest: isNewest,
            isTopPick: isTopPick
        )
    }
}