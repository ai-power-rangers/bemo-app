//
//  TangramPuzzleCard.swift
//  Bemo
//
//  Puzzle card component matching Editor UI exactly
//

// WHAT: Simplified puzzle card showing thumbnail, badge, name, stars, category
// ARCHITECTURE: View component in MVVM-S pattern
// USAGE: Used in puzzle selection grid for consistent UI across all Tangram modes

import SwiftUI

struct TangramPuzzleCard: View {
    let puzzle: GamePuzzleData
    let allPuzzles: [GamePuzzleData]
    let action: () -> Void
    
    @State private var isPressed = false
    
    // Calculate badge for this puzzle
    private func getBadge() -> TangramBadgeType? {
        // Find newest puzzle (would be based on created_at in production)
        // For now, use last puzzle in list as "newest"
        let isNewest = allPuzzles.last?.id == puzzle.id
        
        // Mark first puzzle as "Top Pick" for demo
        // In production, this would use play count from analytics
        let isTopPick = allPuzzles.first?.id == puzzle.id
        
        return puzzle.getBadge(isNewest: isNewest, isTopPick: isTopPick)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail - maintain square frame
            ZStack {
                // Background for consistent card size
                Rectangle()
                    .fill(Color(.systemGray6))
                    .aspectRatio(1, contentMode: .fit)
                
                // Render puzzle using shared service
                PuzzleThumbnailService.shared.tangramThumbnailView(for: puzzle, colorful: true)
                    .padding(8)
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .overlay(
                // Dynamic badge based on puzzle properties - top left corner
                Group {
                    if let badge = getBadge() {
                        VStack {
                            HStack {
                                Label(badge.rawValue, systemImage: badge.icon)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(badge.color)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                                    .padding(8)
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }
            )
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(puzzle.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    // Category badge
                    Text(puzzle.category)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    // Difficulty stars
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= puzzle.difficulty ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {
            action()
        }
        ._onButtonGesture { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        } perform: {
            action()
        }
    }
}