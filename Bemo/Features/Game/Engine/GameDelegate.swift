//
//  GameDelegate.swift
//  Bemo
//
//  Protocol for games to communicate events back to the host
//

// WHAT: Protocol defining callbacks for game events (level completion, quit, errors). Enables games to communicate with the host.
// ARCHITECTURE: Communication bridge from isolated games to GameHostViewModel. Implements inversion of control for game modularity.
// USAGE: GameHostViewModel implements this. Games receive delegate in makeGameView() and call methods to report events.

import Foundation

protocol GameDelegate: AnyObject {
    /// Called when a level is completed
    /// - Parameter xpAwarded: The amount of experience points to award
    func gameDidCompleteLevel(xpAwarded: Int)
    
    /// Called when the user requests to quit the game
    func gameDidRequestQuit()
    
    /// Called when the user requests a hint
    func gameDidRequestHint()
    
    /// Called when the game encounters an error
    /// - Parameter error: The error that occurred
    func gameDidEncounterError(_ error: Error)
    
    /// Called when the game wants to update its progress
    /// - Parameter progress: Progress value between 0.0 and 1.0
    func gameDidUpdateProgress(_ progress: Float)
    
    /// Called when the game detects frustration (via CV or game logic)
    /// - Parameter level: The frustration level (0.0 to 1.0)
    func gameDidDetectFrustration(level: Float)

    /// Provides the active child's default gameplay difficulty as set by the parent
    /// Games can use this as a baseline and optionally allow in-game overrides
    func getChildDifficultySetting() -> UserPreferences.DifficultySetting
    
    /// Shows a celebration character animation
    /// - Parameter position: Position on screen for the animation
    func showCelebrationAnimation(at position: CharacterAnimationService.AnimationPosition)
    
    /// Shows a custom character animation
    /// - Parameters:
    ///   - character: The character type to show
    ///   - position: Position on screen
    ///   - duration: How long to show the animation
    func showCharacterAnimation(
        _ character: CharacterAnimationService.CharacterType,
        at position: CharacterAnimationService.AnimationPosition,
        duration: TimeInterval
    )
}

// Default implementations for optional behaviors
extension GameDelegate {
    func getChildDifficultySetting() -> UserPreferences.DifficultySetting { .normal }
    func showCelebrationAnimation(at position: CharacterAnimationService.AnimationPosition) { }
    func showCharacterAnimation(
        _ character: CharacterAnimationService.CharacterType,
        at position: CharacterAnimationService.AnimationPosition,
        duration: TimeInterval
    ) { }
}