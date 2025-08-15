//
//  SpellQuestDependencyContainer.swift
//  Bemo
//
//  Dependency injection container for SpellQuest services
//

// WHAT: Wires up all SpellQuest-specific services for dependency injection
// ARCHITECTURE: Service layer in MVVM-S, provides dependencies to ViewModels
// USAGE: Created when SpellQuestGame instantiates the game view

import Foundation

class SpellQuestDependencyContainer {
    let contentService: SpellQuestContentService
    let hintService: SpellQuestHintService
    let scoringService: SpellQuestScoringService
    let audioHapticsService: SpellQuestAudioHapticsService
    
    init() {
        self.contentService = SpellQuestContentService()
        self.hintService = SpellQuestHintService()
        self.scoringService = SpellQuestScoringService()
        self.audioHapticsService = SpellQuestAudioHapticsService()
    }
}