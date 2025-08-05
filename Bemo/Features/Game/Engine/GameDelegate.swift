//
//  GameDelegate.swift
//  Bemo
//
//  Protocol for games to communicate events back to the host


//This is the most abstract piece. It is a protocol, not a class or a view. Think of it as a contract or a set of rules.
// Its Job: To define a standardized, one-way communication channel from the isolated Game module back to the main app.

// What it Does:

// It defines a list of methods like gameDidCompleteLevel(xpAwarded: Int) and gameDidRequestQuit().

// It ensures that any game you create knows how to talk back to the host, but it doesn't know or care who the host is.



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
}