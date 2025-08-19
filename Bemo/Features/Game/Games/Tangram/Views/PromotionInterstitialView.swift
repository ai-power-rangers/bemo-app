//
//  PromotionInterstitialView.swift
//  Bemo
//
//  Celebration view shown when user is promoted to a new difficulty level
//

// WHAT: Displays promotion celebration screen with auto-advance and manual controls
// ARCHITECTURE: View in MVVM-S pattern, observes PromotionInterstitialViewModel
// USAGE: Shown when difficulty promotion is triggered, allows continue or skip to map

import SwiftUI

struct PromotionInterstitialView: View {
    private let viewModel: PromotionInterstitialViewModel
    
    // State for triggering animations when view appears
    @State private var isAnimating = false
    
    init(viewModel: PromotionInterstitialViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            // Background with celebration gradient
            LinearGradient(
                colors: [
                    viewModel.promotionColor.opacity(0.3), 
                    viewModel.promotionColor.opacity(0.1),
                    Color.white.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Celebration Icon with Animation
                Image(systemName: viewModel.promotionIcon)
                    .font(.system(size: 100))
                    .foregroundColor(viewModel.promotionColor)
                    .shadow(color: viewModel.promotionColor.opacity(0.3), radius: 20)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).repeatCount(3, autoreverses: true), value: isAnimating)
                
                // Congratulations Message
                VStack(spacing: 16) {
                    Text(viewModel.promotionTitle)
                        .font(.largeTitle.bold())
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(viewModel.completionMessage)
                        .font(.title2)
                        .foregroundColor(.primary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Statistics Card
                VStack(spacing: 12) {
                    Text("📊 Achievement Stats")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        StatisticRow(
                            icon: "puzzle.piece.fill",
                            title: "Puzzles Completed",
                            value: "\(viewModel.completedPuzzleCount)",
                            color: .green
                        )
                        
                        if let timeSpent = viewModel.totalTimeSpent {
                            StatisticRow(
                                icon: "clock.fill",
                                title: "Total Time",
                                value: formatTime(timeSpent),
                                color: .blue
                            )
                        }
                        
                        StatisticRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Difficulty Level", 
                            value: viewModel.fromDifficulty.displayName,
                            color: getDifficultyColor(viewModel.fromDifficulty)
                        )
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 10)
                )
                .padding(.horizontal)
                
                // Next Difficulty Preview
                VStack(spacing: 12) {
                    Text("🚀 Next Challenge")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.toDifficulty.icon)
                            .font(.title)
                            .foregroundColor(viewModel.promotionColor)
                        
                        Text(viewModel.nextDifficultyMessage)
                            .font(.title2.bold())
                            .foregroundColor(viewModel.promotionColor)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.promotionColor.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(viewModel.promotionColor.opacity(0.3), lineWidth: 2)
                        )
                )
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        Button(action: {
                            viewModel.skipToMap()
                        }) {
                            Label("Back to Map", systemImage: "map.fill")
                                .frame(minWidth: 120)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        
                        Button(action: {
                            viewModel.continueToNextDifficulty()
                        }) {
                            Label("Continue", systemImage: "arrow.right.circle.fill")
                                .frame(minWidth: 120)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(viewModel.promotionColor)
                    }
                    
                    // Auto-advance indicator
                    if viewModel.isAutoAdvancing && viewModel.remainingAutoAdvanceTime > 0 {
                        Text(viewModel.autoAdvanceMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .animation(.easeInOut(duration: 0.1), value: viewModel.remainingAutoAdvanceTime)
                    }
                }
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 20)
        }
        .onAppear {
            // Trigger animations when the view appears
            withAnimation(.easeInOut(duration: 0.3)) {
                isAnimating = true
            }
        }
    }
    
    // MARK: - Helper Components
    
    private struct StatisticRow: View {
        let icon: String
        let title: String
        let value: String
        let color: Color
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.7))
                
                Spacer()
                
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func getDifficultyColor(_ difficulty: UserPreferences.DifficultySetting) -> Color {
        switch difficulty {
        case .easy:
            return .green
        case .normal:
            return .blue
        case .hard:
            return .red
        }
    }
}
