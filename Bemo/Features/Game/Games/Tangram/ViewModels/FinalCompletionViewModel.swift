//
//  FinalCompletionViewModel.swift
//  Bemo
//
//  ViewModel for the final completion celebration when all difficulties are completed
//

// WHAT: Manages state for final completion celebration screen shown after completing all difficulties
// ARCHITECTURE: ViewModel in MVVM-S pattern, uses @Observable for state management  
// USAGE: Created when user completes all Hard puzzles, handles navigation to lobby or replay options

import SwiftUI
import Observation

@Observable
class FinalCompletionViewModel {
    
    // MARK: - Properties
    
    let totalPuzzlesCompleted: Int
    let totalTimeSpent: TimeInterval?
    let achievementUnlocked: String = "Tangram Master"
    
    private let onReturnToLobby: () -> Void
    private let onReplayDifficulty: (UserPreferences.DifficultySetting) -> Void
    
    // MARK: - Initialization
    
    init(
        totalPuzzlesCompleted: Int,
        totalTimeSpent: TimeInterval?,
        onReturnToLobby: @escaping () -> Void,
        onReplayDifficulty: @escaping (UserPreferences.DifficultySetting) -> Void
    ) {
        self.totalPuzzlesCompleted = totalPuzzlesCompleted
        self.totalTimeSpent = totalTimeSpent
        self.onReturnToLobby = onReturnToLobby
        self.onReplayDifficulty = onReplayDifficulty
    }
    
    // MARK: - User Actions
    
    func returnToGameLobby() {
        onReturnToLobby()
    }
    
    func replayDifficulty(_ difficulty: UserPreferences.DifficultySetting) {
        onReplayDifficulty(difficulty)
    }
    
    // MARK: - Computed Properties
    
    var masterTitle: String {
        return "🏆 TANGRAM MASTER! 🏆"
    }
    
    var completionMessage: String {
        return "You've completed ALL difficulty levels!"
    }
    
    var congratulationsMessage: String {
        return "Incredible work! You've mastered every Tangram challenge."
    }
    
    var formattedTotalTime: String? {
        guard let timeSpent = totalTimeSpent else { return nil }
        
        let hours = Int(timeSpent) / 3600
        let minutes = Int(timeSpent) % 3600 / 60
        let seconds = Int(timeSpent) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    var achievements: [Achievement] {
        return [
            Achievement(
                icon: "star.fill",
                title: "Easy Master",
                description: "Completed all Easy puzzles",
                color: .green
            ),
            Achievement(
                icon: "star.leadinghalf.filled", 
                title: "Medium Master",
                description: "Completed all Medium puzzles",
                color: .blue
            ),
            Achievement(
                icon: "crown.fill",
                title: "Tangram Master",
                description: "Completed all difficulty levels",
                color: .purple
            )
        ]
    }
    
    // MARK: - Achievement Model
    
    struct Achievement {
        let icon: String
        let title: String
        let description: String
        let color: Color
    }
}
