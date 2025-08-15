//
//  PlayerBoardViewModel.swift
//  Bemo
//
//  ViewModel for individual player board in SpellQuest
//

// WHAT: Manages state and logic for a single player's puzzle board
// ARCHITECTURE: ViewModel in MVVM-S, uses @Observable for SwiftUI binding
// USAGE: Created by SpellQuestGameViewModel for each player/AI board

import Foundation
import SwiftUI
import Observation

@Observable
class PlayerBoardViewModel {
    // MARK: - Observable State
    private(set) var boardState: PlayerBoardState
    private(set) var isShaking: Bool = false
    private(set) var highlightedSlotIndex: Int? = nil
    private(set) var highlightedLetter: Character? = nil
    
    // MARK: - Dependencies
    private let audioHapticsService: SpellQuestAudioHapticsService
    private let onLetterPlaced: (Int) -> Void
    private let onWordCompleted: (PlayerBoardState) -> Void
    
    // MARK: - Initialization
    init(
        audioHapticsService: SpellQuestAudioHapticsService,
        onLetterPlaced: @escaping (Int) -> Void,
        onWordCompleted: @escaping (PlayerBoardState) -> Void
    ) {
        self.audioHapticsService = audioHapticsService
        self.onLetterPlaced = onLetterPlaced
        self.onWordCompleted = onWordCompleted
        self.boardState = PlayerBoardState(puzzle: SpellQuestPuzzle(
            id: "empty",
            imageName: "",
            word: "",
            displayTitle: nil
        ))
    }
    
    // MARK: - Public Methods
    func beginRound(puzzle: SpellQuestPuzzle) {
        boardState = PlayerBoardState(puzzle: puzzle)
        clearHighlights()
    }
    
    func resetBoard() {
        let currentPuzzle = boardState.currentPuzzle
        boardState = PlayerBoardState(puzzle: currentPuzzle)
        clearHighlights()
    }
    
    
    enum PlacementResult {
        case correctPlacement(points: Int)
        case incorrectPlacement
        case alreadyFilled
    }
    
    func attemptPlace(letter: Character, atSlotIndex index: Int) -> PlacementResult {
        guard index >= 0 && index < boardState.slots.count else {
            return .incorrectPlacement
        }
        
        var slot = boardState.slots[index]
        
        // Check if slot is already filled
        if slot.isFilled && !slot.isRevealedByHint {
            return .alreadyFilled
        }
        
        // Check if letter matches expected
        if letter == slot.expected {
            // Correct placement
            slot.currentLetter = letter
            slot.isFilled = true
            slot.isRevealedByHint = false
            boardState.slots[index] = slot
            
            audioHapticsService.playCorrect()
            onLetterPlaced(SpellQuestConstants.Scoring.xpPerCorrectLetter)
            
            // Check for word completion
            if boardState.isComplete {
                boardState.status = .completed
                audioHapticsService.playComplete()
                onWordCompleted(boardState)
            }
            
            return .correctPlacement(points: SpellQuestConstants.Scoring.xpPerCorrectLetter)
        } else {
            // Incorrect placement
            boardState.errorsThisPuzzle += 1
            triggerShake()
            audioHapticsService.playIncorrect()
            return .incorrectPlacement
        }
    }
    
    func revealHint(_ hintType: SpellQuestHintService.HintType) {
        clearHighlights()
        boardState.hintsUsedThisPuzzle += 1
        
        switch hintType {
        case .highlightSlot(let index):
            highlightedSlotIndex = index
            audioHapticsService.playHintTick()
            
        case .highlightLetter(let character):
            highlightedLetter = character
            audioHapticsService.playHintTick()
            
        case .revealLetter(let index, let character):
            if index < boardState.slots.count {
                boardState.slots[index].currentLetter = character
                boardState.slots[index].isFilled = true
                boardState.slots[index].isRevealedByHint = true
                audioHapticsService.playCorrect()
                
                // Check for completion
                if boardState.isComplete {
                    boardState.status = .completed
                    audioHapticsService.playComplete()
                    onWordCompleted(boardState)
                }
            }
        }
    }
    
    func removeLetter(at index: Int) {
        guard index >= 0 && index < boardState.slots.count else { return }
        
        // Don't allow removing hint-revealed letters
        guard !boardState.slots[index].isRevealedByHint else { return }
        
        // Clear the slot
        boardState.slots[index].currentLetter = nil
        boardState.slots[index].isFilled = false
        
        // Play feedback
        audioHapticsService.playHintTick()
    }
    
    func clearHighlights() {
        highlightedSlotIndex = nil
        highlightedLetter = nil
    }
    
    // MARK: - Private Methods
    private func triggerShake() {
        isShaking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + SpellQuestConstants.UI.shakeAnimationDuration) { [weak self] in
            self?.isShaking = false
        }
    }
}