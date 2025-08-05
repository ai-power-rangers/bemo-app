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
    
    func apply(to transform: CGAffineTransform, parameter: Double) -> CGAffineTransform {
        switch type {
        case .rotation(let center, let range):
            let clampedAngle = max(range.lowerBound, min(range.upperBound, parameter))
            let rotation = CGAffineTransform(rotationAngle: CGFloat(clampedAngle))
            
            let toOrigin = CGAffineTransform(translationX: -center.x, y: -center.y)
            let fromOrigin = CGAffineTransform(translationX: center.x, y: center.y)
            
            return transform
                .concatenating(toOrigin)
                .concatenating(rotation)
                .concatenating(fromOrigin)
            
        case .translation(let vector, let range):
            let clampedT = max(range.lowerBound, min(range.upperBound, parameter))
            let translation = CGAffineTransform(
                translationX: vector.dx * CGFloat(clampedT),
                y: vector.dy * CGFloat(clampedT)
            )
            return transform.concatenating(translation)
            
        case .fixed:
            return transform
        }
    }
}