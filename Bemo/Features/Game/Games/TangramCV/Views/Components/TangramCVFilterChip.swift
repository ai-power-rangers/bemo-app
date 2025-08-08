//
//  TangramCVFilterChip.swift
//  Bemo
//
//  Filter chip component for TangramCV puzzle selection
//

// WHAT: Reusable filter chip UI component for categories and difficulty selection
// ARCHITECTURE: View component in MVVM-S pattern
// USAGE: Used in puzzle selection view for filtering puzzles by category/difficulty

import SwiftUI

struct TangramCVFilterChip: View {
    let title: String
    let isSelected: Bool
    var icon: String? = nil
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Text(icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(isSelected ? color.opacity(0.2) : Color(UIColor.tertiarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}