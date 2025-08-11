//
//  TangramCVSceneDelegate.swift
//  Bemo
//
//  Delegate protocol for TangramThreeZoneScene communication
//

// WHAT: Defines the contract for Scene to communicate state changes
// ARCHITECTURE: Delegate pattern for loose coupling between Scene and ViewModel
// USAGE: ViewModel implements this to respond to Scene events

import Foundation

protocol TangramCVSceneDelegate: AnyObject {
    
    // MARK: - Piece Movement Events
    
    /// Called when a piece is selected for dragging
    func sceneDidSelectPiece(_ piece: CVPuzzlePieceNode)
    
    /// Called when a piece is moved between zones
    func sceneDidMovePiece(_ piece: CVPuzzlePieceNode, from: Zone, to: Zone)
    
    /// Called when a piece is released
    func sceneDidReleasePiece(_ piece: CVPuzzlePieceNode, in zone: Zone)
    
    // MARK: - Assembly Events
    
    /// Called when a piece enters the assembly zone
    func sceneDidAddPieceToAssembly(_ piece: CVPuzzlePieceNode)
    
    /// Called when a piece leaves the assembly zone
    func sceneDidRemovePieceFromAssembly(_ piece: CVPuzzlePieceNode)
    
    // MARK: - Anchor Events
    
    /// Called when anchor needs to be updated
    func sceneRequestsAnchorUpdate(currentAnchor: CVPuzzlePieceNode?, assembledPieces: [CVPuzzlePieceNode])
    
    // MARK: - CV Generation
    
    /// Called when CV output should be generated
    func sceneRequestsCVGeneration(state: TangramCVPuzzleState)
    
    /// Called when scene updates from CV detection data
    func sceneDidUpdateFromCV(state: TangramCVPuzzleState)
    
    // MARK: - Validation
    
    /// Called when a piece position should be validated
    func sceneRequestsValidation(for piece: CVPuzzlePieceNode, at position: CGPoint) -> Bool
    
    /// Called when the puzzle completion should be checked
    func sceneRequestsCompletionCheck(state: TangramCVPuzzleState) -> Bool
}