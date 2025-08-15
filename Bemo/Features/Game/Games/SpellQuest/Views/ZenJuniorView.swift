//
//  ZenJuniorView.swift
//  Bemo
//
//  Zen Junior mode for younger players with larger UI and auto-hints
//

// WHAT: Child-friendly mode with larger controls and automatic hints
// ARCHITECTURE: View layer in MVVM-S
// USAGE: Displayed when Zen Junior mode is selected

import SwiftUI

struct ZenJuniorView: View {
    let viewModel: SpellQuestGameViewModel
    
    var body: some View {
        VStack {
            // Header (simplified for young players)
            ZenJuniorHeaderView(viewModel: viewModel)
            
            Spacer()
            
            // Board with larger elements
            if let playerVM = viewModel.playerViewModel {
                BoardView(viewModel: playerVM, isZenJunior: true)
            }
            
            Spacer()
            
            // Big friendly next button
            if viewModel.playerViewModel?.boardState.isComplete == true {
                Button(action: {
                    viewModel.advanceToNextPuzzle()
                }) {
                    HStack(spacing: 15) {
                        Image(systemName: "star.fill")
                            .font(.largeTitle)
                        Text("Next")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.largeTitle)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple, Color.pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .scaleEffect(1.2)
                }
                .padding()
                .transition(.scale.combined(with: .opacity))
            }
            
            // Encouraging message
            if let boardState = viewModel.playerViewModel?.boardState,
               boardState.solvedLetters > 0 && !boardState.isComplete {
                Text("Great job! Keep going! 🌟")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .padding()
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.1), Color.pink.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .overlay(alignment: .center) {
            if viewModel.showingCelebration {
                KidFriendlyCelebration()
            }
        }
    }
}

private struct ZenJuniorHeaderView: View {
    let viewModel: SpellQuestGameViewModel
    
    var body: some View {
        HStack {
            // Parent exit button (smaller, less prominent)
            Button(action: {
                viewModel.onQuitRequested()
            }) {
                Image(systemName: "house.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            .padding()
            
            Spacer()
            
            // Fun title with animation
            VStack {
                Text("Spell It!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                
                // Progress stars
                if let boardState = viewModel.playerViewModel?.boardState {
                    HStack(spacing: 8) {
                        ForEach(0..<boardState.slots.count, id: \.self) { index in
                            Image(systemName: index < boardState.solvedLetters ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundColor(.yellow)
                                .scaleEffect(index == boardState.solvedLetters - 1 ? 1.3 : 1.0)
                                .animation(.spring(response: 0.3), value: boardState.solvedLetters)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Big hint button with animation
            Button(action: {
                viewModel.onHintRequested()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "lightbulb.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .scaleEffect(1.0)
            .animation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true),
                value: viewModel.playerViewModel?.boardState.hintsUsedThisPuzzle
            )
        }
        .background(
            Color.white
                .opacity(0.95)
                .ignoresSafeArea(edges: .top)
        )
    }
}

private struct KidFriendlyCelebration: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Colorful background
            Color.clear
                .overlay(
                    ForEach(0..<20, id: \.self) { index in
                        StarParticle(delay: Double(index) * 0.1)
                    }
                )
            
            // Success message
            VStack(spacing: 20) {
                Text("Amazing!")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                
                HStack(spacing: 10) {
                    ForEach(["🌟", "🎉", "🏆", "🎊", "✨"], id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 50))
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    }
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.pink, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).repeatCount(3, autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

private struct StarParticle: View {
    let delay: Double
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 1
    
    var body: some View {
        Image(systemName: "star.fill")
            .font(.title)
            .foregroundColor([Color.yellow, Color.orange, Color.pink, Color.purple].randomElement()!)
            .offset(offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 2).delay(delay)) {
                    offset = CGSize(
                        width: Double.random(in: -200...200),
                        height: Double.random(in: -300...(-100))
                    )
                    opacity = 0
                }
            }
    }
}