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
    let supabaseService: SupabaseService?
    
    init(supabaseService: SupabaseService? = nil) {
        self.supabaseService = supabaseService
        self.contentService = SpellQuestContentService(supabaseService: supabaseService)
        self.hintService = SpellQuestHintService()
        self.scoringService = SpellQuestScoringService()
        self.audioHapticsService = SpellQuestAudioHapticsService()
    }
}