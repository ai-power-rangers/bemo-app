//
//  TangramCVPuzzleThumbnail.swift
//  Bemo
//
//  Wrapper for shared puzzle thumbnail service
//

// WHAT: Wrapper view that uses the shared PuzzleThumbnailService
// ARCHITECTURE: SwiftUI View that delegates to shared service
// USAGE: Used in puzzle selection cards to show completed puzzle state

import SwiftUI

struct TangramCVPuzzleThumbnail: View {
    let puzzle: GamePuzzleData
    private let thumbnailService = PuzzleThumbnailService.shared
    
    var body: some View {
        // Use the shared service for consistent thumbnails across all games
        thumbnailService.tangramThumbnailView(for: puzzle, colorful: true)
    }
}