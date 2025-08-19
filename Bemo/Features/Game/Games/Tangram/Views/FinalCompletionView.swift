//
//  FinalCompletionView.swift
//  Bemo
//
//  Final completion celebration view when all difficulties are completed
//

// WHAT: Displays final completion celebration screen with master achievement and replay options
// ARCHITECTURE: View in MVVM-S pattern, observes FinalCompletionViewModel
// USAGE: Shown when user completes all Hard puzzles, provides navigation to lobby or replay

import SwiftUI

struct FinalCompletionView: View {
    private let viewModel: FinalCompletionViewModel
    
    // State for triggering animations when view appears
    @State private var isAnimating = false
    
    init(viewModel: FinalCompletionViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            // Epic background with animated gradient
            RadialGradient(
                colors: [
                    .purple.opacity(0.4),
                    .blue.opacity(0.3),
                    .indigo.opacity(0.4),
                    .black.opacity(0.1)
                ],
                center: .center,
                startRadius: 100,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 40) {
                    // Master Achievement Section
                    VStack(spacing: 20) {
                        // Animated Crown Icon
                        Image(systemName: "crown.fill")
                            .font(.system(size: 120))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .orange.opacity(0.5), radius: 20)
                            .scaleEffect(isAnimating ? 1.2 : 1.0)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6).repeatCount(2, autoreverses: true), value: isAnimating)
                        
                        // Title
                        Text(viewModel.masterTitle)
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.1), radius: 2)
                        
                        // Completion Message
                        VStack(spacing: 8) {
                            Text(viewModel.completionMessage)
                                .font(.title2.weight(.semibold))
                                .foregroundColor(.primary.opacity(0.9))
                                .multilineTextAlignment(.center)
                            
                            Text(viewModel.congratulationsMessage)
                                .font(.body)
                                .foregroundColor(.primary.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 15)
                    )
                    .padding(.horizontal)
                    
                    // Final Statistics
                    VStack(spacing: 16) {
                        Text("🎯 Final Statistics")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            StatisticRow(
                                icon: "puzzle.piece.fill",
                                title: "Total Puzzles Completed",
                                value: "\(viewModel.totalPuzzlesCompleted)",
                                color: .green
                            )
                            
                            if let timeText = viewModel.formattedTotalTime {
                                StatisticRow(
                                    icon: "clock.fill",
                                    title: "Total Play Time",
                                    value: timeText,
                                    color: .blue
                                )
                            }
                            
                            StatisticRow(
                                icon: "crown.fill",
                                title: "Master Achievement",
                                value: viewModel.achievementUnlocked,
                                color: .purple
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
                    
                    // Achievements Section
                    VStack(spacing: 16) {
                        Text("🏅 Achievements Unlocked")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            ForEach(Array(viewModel.achievements.enumerated()), id: \.offset) { index, achievement in
                                AchievementBadge(achievement: achievement)
                                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                                    .opacity(isAnimating ? 1.0 : 0.0)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.2), value: isAnimating)
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 10)
                    )
                    .padding(.horizontal)
                    
                    // Action Options
                    VStack(spacing: 20) {
                        Text("🎮 What's Next?")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 16) {
                            // Primary action - Return to lobby
                            Button(action: {
                                viewModel.returnToGameLobby()
                            }) {
                                Label("🏠 Return to Game Lobby", systemImage: "house.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.purple)
                            
                            // Replay options
                            Text("Or replay any difficulty:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                Button("🟢 Easy") {
                                    viewModel.replayDifficulty(.easy)
                                }
                                .buttonStyle(.bordered)
                                .tint(.green)
                                
                                Button("🔵 Medium") {
                                    viewModel.replayDifficulty(.normal)
                                }
                                .buttonStyle(.bordered)
                                .tint(.blue)
                                
                                Button("🟣 Hard") {
                                    viewModel.replayDifficulty(.hard)
                                }
                                .buttonStyle(.bordered)
                                .tint(.purple)
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.thinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 10)
                    )
                    .padding(.horizontal)
                    
                    // Bottom padding for scroll
                    Spacer(minLength: 20)
                }
                .padding(.top, 20)
            }
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
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.8))
                
                Spacer()
                
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
            }
        }
    }
    
    private struct AchievementBadge: View {
        let achievement: FinalCompletionViewModel.Achievement
        
        var body: some View {
            HStack(spacing: 16) {
                // Achievement Icon
                Image(systemName: achievement.icon)
                    .font(.title2)
                    .foregroundColor(achievement.color)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(achievement.color.opacity(0.1))
                    )
                
                // Achievement Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(achievement.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(achievement.description)
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.6))
                }
                
                Spacer()
                
                // Checkmark
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(achievement.color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}
