//
//  SpellQuestHintService.swift
//  Bemo
//
//  Provides hint functionality for SpellQuest
//

// WHAT: Manages hint logic and determines what hint to show next
// ARCHITECTURE: Service layer in MVVM-S
// USAGE: Called by ViewModels when hint is requested, always provides meaningful hint

import Foundation

class SpellQuestHintService {
    
    enum HintType {
        case highlightSlot(index: Int)
        case highlightLetter(character: Character)
        case revealLetter(index: Int, character: Character)
    }
    
    func getNextHint(for boardState: PlayerBoardState, mode: SpellQuestGameMode) -> HintType? {
        // Find the first empty slot that's not revealed
        guard let nextEmptySlot = boardState.slots.first(where: { !$0.isFilled && !$0.isRevealedByHint }) else {
            // All slots are either filled or revealed - no hint needed
            return nil
        }
        
        // For Zen Junior, more likely to reveal letters directly
        if mode == .zenJunior && boardState.hintsUsedThisPuzzle >= SpellQuestConstants.Gameplay.zenJuniorDirectRevealThreshold {
            return .revealLetter(index: nextEmptySlot.index, character: nextEmptySlot.expected)
        }
        
        // Standard hint progression
        if boardState.hintsUsedThisPuzzle % 2 == 0 {
            // Even hints: highlight the slot
            return .highlightSlot(index: nextEmptySlot.index)
        } else {
            // Odd hints: highlight the letter on the rack
            return .highlightLetter(character: nextEmptySlot.expected)
        }
    }
    
    func shouldAutoHint(for mode: SpellQuestGameMode, idleTime: TimeInterval) -> Bool {
        guard mode == .zenJunior else { return false }
        return idleTime >= SpellQuestConstants.Gameplay.zenJuniorAutoHintDelay
    }
}