//
//  SpellQuestGameMode.swift
//  Bemo
//
//  Game mode enumeration for SpellQuest
//

// WHAT: Defines the four game modes available in SpellQuest
// ARCHITECTURE: Model in MVVM-S
// USAGE: Used by ViewModels to determine game flow and UI behavior

import Foundation

enum SpellQuestGameMode: String, CaseIterable {
    case zen = "Zen"
    case zenJunior = "Zen Junior"
    
    var description: String {
        switch self {
        case .zen:
            return "Relax and solve at your own pace"
        case .zenJunior:
            return "Perfect for younger players with helpful hints"
        }
    }
    
    var systemImage: String {
        switch self {
        case .zen:
            return "leaf.fill"
        case .zenJunior:
            return "star.fill"
        }
    }
}