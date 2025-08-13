//
//  CharacterAnimations.swift
//  Bemo
//
//  Reusable character-style animations for any SKNode container
//

// WHAT: Provides breathing, pulse, wobble, happy jump, and shimmer
// ARCHITECTURE: Pure SKAction builders and shaderless effects; no game coupling
// USAGE: Run returned actions on any assembled tangram container node

import SpriteKit
import UIKit

enum CharacterAnimations {
    static func breathing(amplitude: CGFloat = 0.04, period: TimeInterval = 2.0) -> SKAction {
        let up = SKAction.scale(to: 1.0 + amplitude, duration: period/2)
        up.timingMode = .easeInEaseOut
        let down = SKAction.scale(to: 1.0, duration: period/2)
        down.timingMode = .easeInEaseOut
        return SKAction.sequence([up, down])
    }

    static func pulse(strength: CGFloat = 0.08, duration: TimeInterval = 0.6, count: Int = 1) -> SKAction {
        let up = SKAction.scale(to: 1.0 + strength, duration: duration/2)
        let down = SKAction.scale(to: 1.0, duration: duration/2)
        return SKAction.repeat(SKAction.sequence([up, down]), count: count)
    }

    static func wobble(angle: CGFloat = .pi/32, period: TimeInterval = 0.8) -> SKAction {
        let left = SKAction.rotate(toAngle: -angle, duration: period/2, shortestUnitArc: true)
        left.timingMode = .easeInEaseOut
        let right = SKAction.rotate(toAngle: angle, duration: period/2, shortestUnitArc: true)
        right.timingMode = .easeInEaseOut
        return SKAction.sequence([left, right])
    }

    static func happyJump(height: CGFloat = 24, duration: TimeInterval = 0.5, squash: CGFloat = 0.12) -> SKAction {
        let up = SKAction.moveBy(x: 0, y: height, duration: duration * 0.4)
        up.timingMode = .easeOut
        let down = SKAction.moveBy(x: 0, y: -height, duration: duration * 0.4)
        down.timingMode = .easeIn
        let squashOn = SKAction.group([
            SKAction.scaleX(to: 1.0 + squash, duration: duration * 0.1),
            SKAction.scaleY(to: 1.0 - squash, duration: duration * 0.1)
        ])
        let squashOff = SKAction.group([
            SKAction.scaleX(to: 1.0, duration: duration * 0.1),
            SKAction.scaleY(to: 1.0, duration: duration * 0.1)
        ])
        return SKAction.sequence([squashOn, up, down, squashOff])
    }

    // Shimmer: transient brighten + optional sparkle sweep
    static func applyShimmer(to node: SKNode?) {
        guard let node else { return }
        removeShimmer(from: node)
        // brighten fills briefly for each SKShapeNode child
        let brighten = SKAction.customAction(withDuration: 0.6) { target, t in
            if let shape = target as? SKShapeNode {
                let base = shape.fillColor
                let k: CGFloat = 0.35
                let new = UIColor(
                    red: min(1, base.rgba.r + k),
                    green: min(1, base.rgba.g + k),
                    blue: min(1, base.rgba.b + k),
                    alpha: base.rgba.a
                )
                shape.fillColor = new
            }
        }
        let restore = SKAction.run {
            node.enumerateChildNodes(withName: "//*") { n, _ in
                if let shape = n as? SKShapeNode, let color = shape.userData?["baseFill"] as? UIColor {
                    shape.fillColor = color
                }
            }
        }
        // store base colors once
        node.enumerateChildNodes(withName: "//*") { n, _ in
            if let shape = n as? SKShapeNode {
                if shape.userData == nil { shape.userData = [:] }
                shape.userData?["baseFill"] = shape.fillColor
                shape.run(SKAction.sequence([brighten, restore]), withKey: "shimmer_once")
            }
        }
        // loop with delay
        let loop = SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: 1.2),
            SKAction.run { [weak node] in
                node?.enumerateChildNodes(withName: "//*") { n, _ in
                    if let shape = n as? SKShapeNode {
                        shape.removeAction(forKey: "shimmer_once")
                        shape.run(SKAction.sequence([brighten, restore]), withKey: "shimmer_once")
                    }
                }
            }
        ]))
        node.run(loop, withKey: "shimmer_loop")
    }

    static func removeShimmer(from node: SKNode?) {
        guard let node else { return }
        node.removeAction(forKey: "shimmer_loop")
        node.enumerateChildNodes(withName: "//*") { n, _ in
            n.removeAction(forKey: "shimmer_once")
            if let shape = n as? SKShapeNode, let color = shape.userData?["baseFill"] as? UIColor {
                shape.fillColor = color
            }
        }
    }
}

private extension UIColor {
    var rgba: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
}


