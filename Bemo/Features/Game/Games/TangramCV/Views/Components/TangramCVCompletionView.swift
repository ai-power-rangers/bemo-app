//
//  TangramCVCompletionView.swift
//  Bemo
//
//  Puzzle completion celebration view for TangramCV
//

// WHAT: Completion view matching TangramGame's celebration UI with animations
// ARCHITECTURE: View component in MVVM-S pattern
// USAGE: Displayed when puzzle is completed, offers navigation options

import SwiftUI

struct TangramCVCompletionView: View {
    let puzzle: GamePuzzleData?
    let timeElapsed: String
    let onNextPuzzle: () -> Void
    let onBackToLobby: () -> Void
    
    @State private var showAnimation = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Celebration emoji and title
            Text("🎉")
                .font(.system(size: 80))
                .rotationEffect(.degrees(showAnimation ? -15 : 0))
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.6)
                    .repeatCount(3, autoreverses: true),
                    value: showAnimation
                )
                .onAppear {
                    showAnimation = true
                }
            
            Text("Puzzle Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.green)
            
            Text("Amazing work! You solved \"\(puzzle?.name ?? "the puzzle")\"!")
                .font(.title2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Time display
            if !timeElapsed.isEmpty {
                HStack {
                    Image(systemName: "timer")
                        .font(.title3)
                        .foregroundColor(.orange)
                    Text("Time: \(timeElapsed)")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.1))
                )
            }
            
            // Star rating display
            HStack(spacing: 10) {
                ForEach(0..<3) { index in
                    Image(systemName: "star.fill")
                        .font(.title)
                        .foregroundColor(.yellow)
                        .scaleEffect(showAnimation ? 1.2 : 0.8)
                        .animation(
                            .spring(response: 0.3, dampingFraction: 0.6)
                            .delay(Double(index) * 0.1),
                            value: showAnimation
                        )
                }
            }
            .padding()
            
            // Stats if available
            if let puzzle = puzzle {
                HStack(spacing: 30) {
                    VStack {
                        Text("Difficulty")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 2) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < puzzle.difficulty ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundColor(index < puzzle.difficulty ? difficultyColor(puzzle.difficulty) : .gray.opacity(0.3))
                            }
                        }
                    }
                    
                    VStack {
                        Text("Category")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(puzzle.category)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
            
            // Navigation buttons
            HStack(spacing: 20) {
                Button(action: onBackToLobby) {
                    Label("Back to Lobby", systemImage: "house.fill")
                        .frame(minWidth: 150)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: onNextPuzzle) {
                    Label("Next Puzzle", systemImage: "arrow.right.circle.fill")
                        .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.top)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 10)
        )
        .padding()
    }
    
    private func difficultyColor(_ difficulty: Int) -> Color {
        switch difficulty {
        case 1: return .green
        case 2: return .blue
        case 3: return .orange
        case 4: return .red
        case 5: return .purple
        default: return .gray
        }
    }
}