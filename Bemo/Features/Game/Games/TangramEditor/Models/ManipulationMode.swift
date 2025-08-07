//
//  ManipulationMode.swift
//  Bemo
//
//  Defines how a tangram piece can be manipulated based on its connections
//

// WHAT: Enum defining the possible manipulation modes for tangram pieces
// ARCHITECTURE: Model in MVVM-S pattern, used by services and ViewModels
// USAGE: Calculated by PieceManipulationService based on piece connections

import Foundation
import CoreGraphics

enum ManipulationMode: Equatable {
    case locked                                             // 2+ connections - no movement allowed
    case rotatable(pivot: CGPoint, snapAngles: [Double])   // 1 vertex connection - can rotate
    case slidable(edge: Edge, range: ClosedRange<Double>, snapPositions: [Double])  // 1 edge connection - can slide
    
    struct Edge: Equatable {
        let start: CGPoint
        let end: CGPoint
        let vector: CGVector  // Normalized direction vector
    }
    
    var canManipulate: Bool {
        switch self {
        case .locked:
            return false
        case .rotatable, .slidable:
            return true
        }
    }
    
    var description: String {
        switch self {
        case .locked:
            return "Locked (2+ connections)"
        case .rotatable:
            return "Rotatable around vertex"
        case .slidable:
            return "Slidable along edge"
        }
    }
}