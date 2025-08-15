//
//  PlayerBoardState.swift
//  Bemo
//
//  Tracks the state of a player's puzzle board
//

// WHAT: Complete state representation for a player's current puzzle
// ARCHITECTURE: Model in MVVM-S
// USAGE: Maintained by PlayerBoardViewModel to track gameplay state

import Foundation

struct PlayerBoardState: Equatable {
    var currentPuzzle: SpellQuestPuzzle
    var slots: [LetterSlot]
    var errorsThisPuzzle: Int = 0
    var hintsUsedThisPuzzle: Int = 0
    var status: BoardStatus = .inProgress
    
    enum BoardStatus {
        case inProgress
        case completed
    }
    
    var solvedLetters: Int {
        slots.filter { $0.isFilled && $0.isCorrect }.count
    }
    
    var progress: Float {
        guard !slots.isEmpty else { return 0 }
        return Float(solvedLetters) / Float(slots.count)
    }
    
    var isComplete: Bool {
        solvedLetters == slots.count
    }
    
    init(puzzle: SpellQuestPuzzle) {
        self.currentPuzzle = puzzle
        self.slots = puzzle.word.enumerated().map { index, char in
            LetterSlot(index: index, expected: char)
        }
    }
}