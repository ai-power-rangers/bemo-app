//
//  ZenView.swift
//  Bemo
//
//  Zen mode view for relaxed single-player gameplay
//

// WHAT: Single-player relaxed mode without timers or competition
// ARCHITECTURE: View layer in MVVM-S
// USAGE: Displayed when Zen mode is selected

import SwiftUI

struct ZenView: View {
    let viewModel: SpellQuestGameViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZenHeaderView(viewModel: viewModel)
            
            // Board - takes up remaining space
            if let playerVM = viewModel.playerViewModel {
                BoardView(viewModel: playerVM, isZenJunior: false)
                    .frame(maxHeight: .infinity)
            }
            
            // Next button (shown after completion)
            if viewModel.playerViewModel?.boardState.isComplete == true {
                Button(action: {
                    viewModel.advanceToNextPuzzle()
                }) {
                    HStack {
                        Text("Next Puzzle")
                            .font(.headline)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        Capsule()
                            .fill(Color.green)
                    )
                }
                .padding(.vertical, 20)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay(alignment: .center) {
            if viewModel.showingCelebration {
                ConfettiOverlay()
            }
        }
    }
}

private struct ZenHeaderView: View {
    let viewModel: SpellQuestGameViewModel
    
    var body: some View {
        HStack {
            // Back button
            Button(action: {
                viewModel.onQuitRequested()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Exit")
                }
                .font(.body)
                .foregroundColor(Color("AppPrimaryTextColor"))
            }
            
            Spacer()
            
            // Puzzle info
            VStack {
                if let currentPuzzle = viewModel.currentPuzzles[safe: viewModel.currentPuzzleIndex] {
                    Text("Zen Mode")
                        .font(.headline)
                        .foregroundColor(Color("AppPrimaryTextColor"))
                    
                    if let title = currentPuzzle.displayTitle {
                        Text(title)
                            .font(.caption)
                            .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            Color.white
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                .ignoresSafeArea(edges: .top)
        )
    }
}

// Safe array subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}