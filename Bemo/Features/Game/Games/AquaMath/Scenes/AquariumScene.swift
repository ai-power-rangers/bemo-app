//
//  AquariumScene.swift
//  Bemo
//
//  SpriteKit scene for AquaMath aquarium (bubbles, water)
//

// WHAT: Renders bubbles and animated water. Not final; provides minimal API to integrate with ViewModel.
// ARCHITECTURE: Scene is a renderer; business logic remains in ViewModel/services.
// USAGE: Owned by AquaMathGameView; receives a weak reference to ViewModel for callbacks.

import SpriteKit
import UIKit

class AquariumScene: SKScene {
    private weak var viewModel: AquaMathGameViewModel?
    private var waterNode: SKShapeNode = SKShapeNode()
    private var backgroundNode: SKShapeNode = SKShapeNode()
    private var bubbleNodes: [SKSpriteNode: Int] = [:] // node -> value
    private var spawnTimer: TimeInterval = 0
    private var spawnInterval: TimeInterval = 1.5
    private var displayedWaterLevel: CGFloat = 0.0
    
    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        if backgroundNode.parent == nil {
            backgroundNode.fillColor = SKColor(cgColor: UIColor.systemTeal.withAlphaComponent(0.08).cgColor)
            backgroundNode.strokeColor = .clear
            addChild(backgroundNode)
        }
        if waterNode.parent == nil {
            waterNode.fillColor = SKColor(cgColor: UIColor.systemTeal.withAlphaComponent(0.25).cgColor)
            waterNode.strokeColor = .clear
            addChild(waterNode)
            layoutWater(level: 0.0)
        }
        physicsWorld.gravity = CGVector(dx: 0, dy: -0.3)
        // Ensure we start with at least one bubble quickly
        run(SKAction.sequence([SKAction.wait(forDuration: 0.2), SKAction.run { [weak self] in self?.spawnBubble() }]))
        layoutBackground()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutBackground()
        layoutWater(level: displayedWaterLevel)
    }
    
    func setViewModel(_ vm: AquaMathGameViewModel) {
        self.viewModel = vm
    }
    
    func highlightBubbles(matching value: Int?) {
        for (node, v) in bubbleNodes {
            node.removeAction(forKey: "pulse")
            if let value, v == value {
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.1, duration: 0.2),
                    SKAction.scale(to: 1.0, duration: 0.2)
                ])
                node.run(SKAction.repeatForever(pulse), withKey: "pulse")
            } else {
                node.run(SKAction.scale(to: 1.0, duration: 0.1))
            }
        }
    }
    
    func animateWater(to level: CGFloat) {
        let start = displayedWaterLevel
        let end = max(0, min(1, level))
        displayedWaterLevel = end
        let duration: CGFloat = 0.5
        let action = SKAction.customAction(withDuration: TimeInterval(duration)) { [weak self] node, elapsed in
            guard let self else { return }
            let t = max(0, min(1, CGFloat(elapsed) / duration))
            let v = start + (end - start) * t
            self.layoutWater(level: v)
        }
        waterNode.run(action)
    }
    
    func resetScene() {
        removeAllChildren()
        waterNode = SKShapeNode()
        addChild(waterNode)
        layoutWater(level: 0.0)
        bubbleNodes.removeAll()
        spawnTimer = 0
    }
    
    private func layoutWater(level: CGFloat) {
        let clamped = max(0, min(1, level))
        let height = size.height * clamped
        let rect = CGRect(x: 0, y: 0, width: size.width, height: height)
        waterNode.path = CGPath(rect: rect, transform: nil)
        waterNode.fillColor = SKColor(cgColor: UIColor.systemTeal.withAlphaComponent(0.25 + 0.15 * clamped).cgColor)
        waterNode.zPosition = -1
    }

    private func layoutBackground() {
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        backgroundNode.path = CGPath(rect: rect, transform: nil)
        backgroundNode.zPosition = -2
    }

    // MARK: - Bubble spawning and motion
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        guard size.width > 0, size.height > 0 else { return }
        if spawnTimer == 0 { spawnTimer = currentTime }
        if currentTime - spawnTimer > spawnInterval {
            spawnTimer = currentTime
            spawnBubble()
        }
        // Apply gentle horizontal sway
        for node in Array(bubbleNodes.keys) {
            let sway = sin((node.position.y + currentTime * 50) / 40) * 0.3
            node.position.x += sway
        }
        // Remove bubbles that went off bottom
        for node in Array(bubbleNodes.keys) {
            if node.position.y < -50 {
                node.removeFromParent()
                bubbleNodes.removeValue(forKey: node)
            }
        }
    }
    
    private func spawnBubble() {
        let value = Int.random(in: 2...12)
        let node = SKSpriteNode(texture: nil, color: .clear, size: CGSize(width: 56, height: 56))
        node.name = "bubble"
        let circle = SKShapeNode(circleOfRadius: 28)
        circle.fillColor = SKColor(cgColor: UIColor.white.withAlphaComponent(0.25).cgColor)
        circle.strokeColor = SKColor.white.withAlphaComponent(0.6)
        circle.lineWidth = 2
        circle.zPosition = 1
        node.addChild(circle)
        let label = SKLabelNode(text: "\(value)")
        label.fontName = "Helvetica-Bold"
        label.fontSize = 22
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.zPosition = 2
        node.addChild(label)
        let startX = CGFloat.random(in: 40...(size.width - 40))
        node.position = CGPoint(x: startX, y: size.height + 40)
        node.zPosition = 2
        addChild(node)
        bubbleNodes[node] = value
        // Motion: float downward with slight drift
        let duration = TimeInterval(CGFloat.random(in: 6...10))
        let move = SKAction.moveTo(y: -60, duration: duration)
        move.timingMode = .easeInEaseOut
        node.run(move)
        // Collision-lite: small jiggle when near others is omitted for now
        // Try pop if matches current target
        if let target = viewModel?.targetValue, target == value {
            popBubble(node, value: value)
        }
    }
    
    private func popBubble(_ node: SKSpriteNode, value: Int) {
        guard bubbleNodes[node] != nil else { return }
        bubbleNodes.removeValue(forKey: node)
        let pop = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.08),
            SKAction.fadeOut(withDuration: 0.12)
        ])
        node.run(pop) { [weak self] in
            node.removeFromParent()
            self?.viewModel?.aquariumDidPopBubbles(value: value, count: 1)
        }
    }
    
    // Public API to attempt popping matching bubbles when equation updates
    func tryPopMatchingBubbles(value: Int?) {
        guard let value else { return }
        let matches = bubbleNodes.filter { $0.value == value }.map { $0.key }
        for node in matches { popBubble(node, value: value) }
    }
}


