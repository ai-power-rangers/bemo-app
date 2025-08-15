//
//  LetterSlot.swift
//  Bemo
//
//  Represents a single letter position in the word puzzle
//

// WHAT: Model for individual letter slots in the word-spelling interface
// ARCHITECTURE: Model in MVVM-S
// USAGE: Tracks state of each letter position (filled, revealed, etc.)

import Foundation

struct LetterSlot: Identifiable, Equatable {
    let id = UUID()
    let index: Int
    let expected: Character
    var isFilled: Bool = false
    var isRevealedByHint: Bool = false
    var currentLetter: Character? = nil
    
    var isCorrect: Bool {
        guard let current = currentLetter else { return false }
        return current == expected
    }
}