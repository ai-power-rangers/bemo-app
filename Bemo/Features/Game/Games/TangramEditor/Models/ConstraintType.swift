//
//  ConstraintType.swift
//  Bemo
//
//  Pure data model for constraint types
//

import Foundation
import CoreGraphics

enum ConstraintType: Codable {
    case rotation(around: CGPoint, range: ClosedRange<Double>)
    case translation(along: CGVector, range: ClosedRange<Double>)
    case fixed
}

struct Constraint: Codable {
    let type: ConstraintType
    let affectedPieceId: String
}