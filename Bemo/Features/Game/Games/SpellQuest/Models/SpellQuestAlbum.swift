//
//  SpellQuestAlbum.swift
//  Bemo
//
//  Album model containing puzzles for SpellQuest
//

// WHAT: Represents a collection of related puzzles (words and images)
// ARCHITECTURE: Model in MVVM-S
// USAGE: Used by ContentService to organize and serve puzzles

import Foundation

struct SpellQuestAlbum: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let puzzles: [SpellQuestPuzzle]
    let isInstalled: Bool
    let difficulty: DifficultyLevel
    
    enum DifficultyLevel: String, Codable {
        case easy, normal, hard
    }
}