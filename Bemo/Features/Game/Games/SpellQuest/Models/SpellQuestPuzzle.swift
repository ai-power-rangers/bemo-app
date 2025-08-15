//
//  SpellQuestPuzzle.swift
//  Bemo
//
//  Individual puzzle model for SpellQuest
//

// WHAT: Represents a single word-image puzzle
// ARCHITECTURE: Model in MVVM-S
// USAGE: Core data structure for gameplay, contains word and image reference

import Foundation

struct SpellQuestPuzzle: Identifiable, Equatable {
    let id: String
    let imageName: String
    let word: String // Stored uppercase internally
    let displayTitle: String?
    
    var letterCount: Int { word.count }
    
    init(id: String, imageName: String, word: String, displayTitle: String? = nil) {
        self.id = id
        self.imageName = imageName
        self.word = word.uppercased()
        self.displayTitle = displayTitle
    }
}