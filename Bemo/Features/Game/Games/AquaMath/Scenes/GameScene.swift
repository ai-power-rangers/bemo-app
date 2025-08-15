//
//  GameScene.swift
//  Bemo
//
//  Main SpriteKit scene for AquaMath rendering
//

// WHAT: Unified SpriteKit scene managing both aquarium and workspace visualization
// ARCHITECTURE: Rendering layer in MVVM-S, receives commands from ViewModel
// USAGE: Created by AquaMathGameView, renders all game visuals

import SpriteKit
import SwiftUI

class GameScene: SKScene {
    
    // MARK: - Properties
    
    private weak var viewModel: AquaMathGameViewModel?
    
    // Container nodes
    private let aquariumNode = SKNode()
    private let workspaceNode = SKNode()
    
    // Aquarium elements
    private var waterNode = SKShapeNode()
    private var backgroundNode = SKShapeNode()
    private var bubbleNodes: [UUID: SKSpriteNode] = [:]
    
    // Workspace elements
    private var tileNodes: [UUID: SKSpriteNode] = [:]
    private var workspaceBackground = SKShapeNode()
    
    // UI overlays
    private var comboLabel: SKLabelNode?
    private var levelCompleteNode: SKNode?
    
    // Water animation
    private var displayedWaterLevel: CGFloat = 0.0
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        setupScene()
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutScene()
    }
    
    // MARK: - Setup
    
    private func setupScene() {
        // Light blue background for entire scene
        backgroundColor = SKColor(cgColor: UIColor(red: 0.85, green: 0.92, blue: 0.98, alpha: 1.0).cgColor)
        scaleMode = .resizeFill
        
        // Setup container nodes
        addChild(aquariumNode)
        addChild(workspaceNode)
        
        // Setup aquarium
        setupAquarium()
        
        // Setup workspace
        setupWorkspace()
        
        // Setup physics
        physicsWorld.gravity = CGVector(dx: 0, dy: -0.5)
        
        layoutScene()
    }
    
    private func setupAquarium() {
        // Background
        backgroundNode.fillColor = SKColor(cgColor: UIColor.systemTeal.withAlphaComponent(0.08).cgColor)
        backgroundNode.strokeColor = .clear
        backgroundNode.zPosition = -10
        aquariumNode.addChild(backgroundNode)
        
        // Water
        waterNode.fillColor = SKColor(cgColor: UIColor.systemTeal.withAlphaComponent(0.25).cgColor)
        waterNode.strokeColor = .clear
        waterNode.zPosition = -5
        aquariumNode.addChild(waterNode)
    }
    
    private func setupWorkspace() {
        // Workspace background - light blue
        let lightBlue = UIColor(red: 0.85, green: 0.92, blue: 0.98, alpha: 1.0)
        workspaceBackground.fillColor = SKColor(cgColor: lightBlue.cgColor)
        workspaceBackground.strokeColor = SKColor(cgColor: lightBlue.withAlphaComponent(0.8).cgColor)
        workspaceBackground.lineWidth = 2
        workspaceBackground.zPosition = -1
        workspaceNode.addChild(workspaceBackground)
    }
    
    private func layoutScene() {
        guard size.width > 0, size.height > 0 else { return }
        
        // Position container nodes
        let workspaceHeight = size.height * 0.3
        let aquariumHeight = size.height * 0.7
        
        aquariumNode.position = CGPoint(x: 0, y: workspaceHeight)
        workspaceNode.position = CGPoint(x: 0, y: 0)
        
        // Layout aquarium
        let aquariumRect = CGRect(x: 0, y: 0, width: size.width, height: aquariumHeight)
        backgroundNode.path = CGPath(rect: aquariumRect, transform: nil)
        layoutWater(level: displayedWaterLevel)
        
        // Layout workspace
        let workspaceRect = CGRect(x: 20, y: 20, width: size.width - 40, height: workspaceHeight - 120)
        workspaceBackground.path = CGPath(rect: workspaceRect, transform: nil)
    }
    
    // MARK: - ViewModel Connection
    
    func setViewModel(_ vm: AquaMathGameViewModel) {
        self.viewModel = vm
    }
    
    // MARK: - Scene Reset
    
    func resetScene() {
        // Remove all dynamic nodes
        bubbleNodes.values.forEach { $0.removeFromParent() }
        bubbleNodes.removeAll()
        
        tileNodes.values.forEach { $0.removeFromParent() }
        tileNodes.removeAll()
        
        displayedWaterLevel = 0.0
        layoutWater(level: 0.0)
    }
    
    // MARK: - Aquarium: Water
    
    private func layoutWater(level: CGFloat) {
        let aquariumHeight = size.height * 0.7
        let waterHeight = aquariumHeight * level
        let waterRect = CGRect(x: 0, y: 0, width: size.width, height: waterHeight)
        
        // Create wave effect at top
        let path = UIBezierPath(rect: waterRect)
        if level > 0 {
            // Add wave curve at top
            let wavePath = UIBezierPath()
            wavePath.move(to: CGPoint(x: 0, y: waterHeight))
            
            let waveCount = 3
            let waveWidth = size.width / CGFloat(waveCount)
            let waveHeight: CGFloat = 10
            
            for i in 0...waveCount {
                let x = CGFloat(i) * waveWidth
                let cp1 = CGPoint(x: x - waveWidth/2, y: waterHeight + waveHeight)
                let cp2 = CGPoint(x: x - waveWidth/2, y: waterHeight - waveHeight)
                let end = CGPoint(x: x, y: waterHeight)
                
                if i > 0 {
                    wavePath.addCurve(to: end, controlPoint1: cp1, controlPoint2: cp2)
                }
            }
            
            wavePath.addLine(to: CGPoint(x: size.width, y: 0))
            wavePath.addLine(to: CGPoint(x: 0, y: 0))
            wavePath.close()
            
            waterNode.path = wavePath.cgPath
        } else {
            waterNode.path = path.cgPath
        }
        
        // Update color opacity based on depth
        let opacity = 0.25 + 0.15 * level
        waterNode.fillColor = SKColor(cgColor: UIColor.systemTeal.withAlphaComponent(opacity).cgColor)
    }
    
    func animateWater(to level: CGFloat) {
        let start = displayedWaterLevel
        let end = max(0, min(1, level))
        displayedWaterLevel = end
        
        let duration: CGFloat = 0.5
        let action = SKAction.customAction(withDuration: TimeInterval(duration)) { [weak self] _, elapsed in
            guard let self else { return }
            let t = max(0, min(1, CGFloat(elapsed) / duration))
            let currentLevel = start + (end - start) * t
            self.layoutWater(level: currentLevel)
        }
        
        waterNode.run(action)
    }
    
    // MARK: - Aquarium: Bubbles
    
    func spawnBubble(_ bubble: BubbleModel) {
        let node = createBubbleNode(for: bubble)
        
        // Position at top of aquarium
        let aquariumHeight = size.height * 0.7
        let startX = bubble.position.x * size.width  // Position is normalized 0-1
        node.position = CGPoint(x: startX, y: aquariumHeight + 40)
        
        aquariumNode.addChild(node)
        bubbleNodes[bubble.id] = node
        
        // Animate floating down
        let duration = TimeInterval(CGFloat.random(in: 6...10))
        let moveAction = SKAction.moveTo(y: -60, duration: duration)
        moveAction.timingMode = .easeInEaseOut
        
        // Add gentle sway
        let swayAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.moveBy(x: 20, y: 0, duration: 2),
                SKAction.moveBy(x: -40, y: 0, duration: 4),
                SKAction.moveBy(x: 20, y: 0, duration: 2)
            ])
        )
        
        node.run(SKAction.group([moveAction, swayAction]))
    }
    
    private func createBubbleNode(for bubble: BubbleModel) -> SKSpriteNode {
        // Load the single bubble image
        let bubbleTexture = SKTexture(imageNamed: "bubble_1")
        
        let node = SKSpriteNode(texture: bubbleTexture)
        node.size = CGSize(width: 80, height: 80)
        node.name = "bubble_\(bubble.id)"
        
        switch bubble.type {
        case .normal:
            // Add number label with better visibility
            let label = SKLabelNode(text: "\(bubble.value)")
            label.fontName = "Helvetica-Bold"
            label.fontSize = 28
            label.fontColor = .white  // White text on bubble
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.zPosition = 10  // Higher z-position to ensure it's on top
            
            // Add shadow for better readability
            let shadowLabel = SKLabelNode(text: "\(bubble.value)")
            shadowLabel.fontName = "Helvetica-Bold"
            shadowLabel.fontSize = 28
            shadowLabel.fontColor = .black.withAlphaComponent(0.3)
            shadowLabel.verticalAlignmentMode = .center
            shadowLabel.horizontalAlignmentMode = .center
            shadowLabel.position = CGPoint(x: 1, y: -1)
            shadowLabel.zPosition = 9
            
            node.addChild(shadowLabel)
            node.addChild(label)
            
        case .lightning:
            // Tint yellow for lightning
            node.colorBlendFactor = 0.3
            node.color = .yellow
            addLightningIcon(to: node)
            
        case .bomb:
            // Tint red for bomb
            node.colorBlendFactor = 0.3
            node.color = .red
            addBombIcon(to: node)
            
        case .sponge:
            // Tint orange for sponge
            node.colorBlendFactor = 0.3
            node.color = .orange
            addSpongeIcon(to: node)
            
        case .crate:
            // Replace with crate shape
            node.texture = nil
            let crate = SKSpriteNode(color: .brown, size: CGSize(width: 60, height: 60))
            crate.zPosition = 1
            node.addChild(crate)
        }
        
        // Add physics body for collisions
        node.physicsBody = SKPhysicsBody(circleOfRadius: 35)
        node.physicsBody?.isDynamic = true
        node.physicsBody?.affectedByGravity = false
        node.physicsBody?.collisionBitMask = 0x1
        node.physicsBody?.categoryBitMask = 0x1
        
        return node
    }
    
    private func addLightningIcon(to node: SKSpriteNode) {
        let label = SKLabelNode(text: "⚡")
        label.fontSize = 30
        label.verticalAlignmentMode = .center
        label.zPosition = 2
        node.addChild(label)
    }
    
    private func addBombIcon(to node: SKSpriteNode) {
        let label = SKLabelNode(text: "💣")
        label.fontSize = 30
        label.verticalAlignmentMode = .center
        label.zPosition = 2
        node.addChild(label)
    }
    
    private func addSpongeIcon(to node: SKSpriteNode) {
        let label = SKLabelNode(text: "🧽")
        label.fontSize = 30
        label.verticalAlignmentMode = .center
        label.zPosition = 2
        node.addChild(label)
    }
    
    func highlightBubbles(matching value: Int?) {
        for (id, node) in bubbleNodes {
            node.removeAction(forKey: "pulse")
            
            // Check if this bubble matches the value
            let shouldHighlight = value != nil && viewModel?.gameState.activeBubbles.first(where: { $0.id == id })?.value == value
            
            if shouldHighlight {
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.15, duration: 0.3),
                    SKAction.scale(to: 1.0, duration: 0.3)
                ])
                node.run(SKAction.repeatForever(pulse), withKey: "pulse")
            } else {
                node.run(SKAction.scale(to: 1.0, duration: 0.1))
            }
        }
    }
    
    func popBubbles(_ bubbles: [BubbleModel]) {
        for bubble in bubbles {
            guard let node = bubbleNodes[bubble.id] else { continue }
            
            bubbleNodes.removeValue(forKey: bubble.id)
            
            // Remove any child labels before animation
            node.children.forEach { $0.removeFromParent() }
            
            // Create a smooth pop animation without sprite frames
            let popSequence = SKAction.sequence([
                // Expand and wobble
                SKAction.group([
                    SKAction.sequence([
                        SKAction.scale(to: 1.2, duration: 0.1),
                        SKAction.scale(to: 1.4, duration: 0.1),
                        SKAction.scale(to: 1.6, duration: 0.1)
                    ]),
                    SKAction.sequence([
                        SKAction.rotate(byAngle: 0.1, duration: 0.05),
                        SKAction.rotate(byAngle: -0.2, duration: 0.05),
                        SKAction.rotate(byAngle: 0.2, duration: 0.05),
                        SKAction.rotate(byAngle: -0.1, duration: 0.05)
                    ]),
                    SKAction.fadeAlpha(to: 0.7, duration: 0.2)
                ]),
                // Final pop
                SKAction.group([
                    SKAction.scale(to: 0.1, duration: 0.2),
                    SKAction.fadeOut(withDuration: 0.2)
                ]),
                SKAction.removeFromParent()
            ])
            
            // Create bubble particle burst effect
            for i in 0..<12 {
                let particle = SKShapeNode(circleOfRadius: 4)
                particle.fillColor = .white.withAlphaComponent(0.8)
                particle.strokeColor = .cyan.withAlphaComponent(0.5)
                particle.lineWidth = 1
                particle.position = node.position
                particle.zPosition = node.zPosition + 1
                aquariumNode.addChild(particle)
                
                let angle = (CGFloat(i) / 12.0) * 2.0 * .pi
                let distance = CGFloat.random(in: 40...80)
                let moveX = cos(angle) * distance
                let moveY = sin(angle) * distance
                
                let particleAction = SKAction.sequence([
                    SKAction.group([
                        SKAction.moveBy(x: moveX, y: moveY, duration: 0.6),
                        SKAction.sequence([
                            SKAction.scale(to: 1.5, duration: 0.2),
                            SKAction.scale(to: 0.1, duration: 0.4)
                        ]),
                        SKAction.fadeOut(withDuration: 0.6)
                    ]),
                    SKAction.removeFromParent()
                ])
                particle.run(particleAction)
            }
            
            // Add a pop sound effect if audio service is available
            if let vm = viewModel {
                //vm.audioService.playSound("pop")
            }
            
            node.run(popSequence)
        }
    }
    
    // MARK: - Workspace: Tiles
    
    func addTileToWorkspace(_ tile: Tile) {
        let node = createTileNode(for: tile)
        
        // Position tiles in a row, centered in workspace
        let tileCount = tileNodes.count
        let spacing: CGFloat = 70
        let totalWidth = CGFloat(tileCount) * spacing
        let startX = (size.width - totalWidth) / 2 + spacing / 2
        
        // Center vertically in the workspace area (which is 30% of screen height)
        let workspaceHeight = size.height * 0.3
        let yPosition: CGFloat = workspaceHeight / 2 - 50  // Center in workspace, accounting for tile tray
        
        node.position = CGPoint(x: startX + CGFloat(tileCount) * spacing, y: yPosition)
        node.setScale(0.1)
        node.alpha = 0
        
        workspaceNode.addChild(node)
        tileNodes[tile.id] = node
        
        // Animate appearance
        let appear = SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.2),
            SKAction.fadeIn(withDuration: 0.2)
        ])
        appear.timingMode = .easeOut
        node.run(appear)
    }
    
    private func createTileNode(for tile: Tile) -> SKSpriteNode {
        let node = SKSpriteNode(color: .clear, size: CGSize(width: 60, height: 60))
        node.name = "tile_\(tile.id)"
        
        // White background with subtle border
        let bg = SKShapeNode(rect: CGRect(x: -30, y: -30, width: 60, height: 60), cornerRadius: 8)
        bg.fillColor = .white
        bg.strokeColor = SKColor(cgColor: UIColor.systemGray5.cgColor)
        bg.lineWidth = 1
        node.addChild(bg)
        
        // Add shadow effect
        let shadow = SKShapeNode(rect: CGRect(x: -28, y: -32, width: 60, height: 60), cornerRadius: 8)
        shadow.fillColor = SKColor.black.withAlphaComponent(0.1)
        shadow.strokeColor = .clear
        shadow.zPosition = -1
        node.addChild(shadow)
        
        // Colored label
        let label = SKLabelNode(text: tile.kind.displayValue)
        label.fontName = "Helvetica-Bold"
        label.fontSize = tile.kind.displayValue.count > 2 ? 16 : 28
        label.fontColor = SKColor(cgColor: tile.kind.numberUIColor.cgColor)
        label.verticalAlignmentMode = .center
        label.zPosition = 1
        node.addChild(label)
        
        return node
    }
    
    func clearWorkspace() {
        // Animate tiles disappearing
        for node in tileNodes.values {
            let disappear = SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 0.1, duration: 0.2),
                    SKAction.fadeOut(withDuration: 0.2)
                ]),
                SKAction.removeFromParent()
            ])
            node.run(disappear)
        }
        tileNodes.removeAll()
    }
    
    private func convertPointToWorkspace(_ point: CGPoint) -> CGPoint {
        // Convert from view coordinates to workspace node coordinates
        return CGPoint(x: point.x, y: point.y - workspaceNode.position.y)
    }
    
    // MARK: - Effects
    
    func showComboText(_ text: String) {
        // Remove existing combo label
        comboLabel?.removeFromParent()
        
        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica-Bold"
        label.fontSize = 48
        label.fontColor = SKColor.yellow
        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
        label.zPosition = 100
        
        addChild(label)
        comboLabel = label
        
        // Animate
        let animation = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.5, duration: 0.3),
                SKAction.fadeAlpha(to: 0.8, duration: 0.3)
            ]),
            SKAction.wait(forDuration: 0.5),
            SKAction.group([
                SKAction.scale(to: 0.1, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3)
            ]),
            SKAction.removeFromParent()
        ])
        
        label.run(animation) { [weak self] in
            self?.comboLabel = nil
        }
    }
    
    func showLevelComplete() {
        let container = SKNode()
        container.position = CGPoint(x: size.width / 2, y: size.height / 2)
        container.zPosition = 200
        
        // Background overlay
        let overlay = SKShapeNode(rect: CGRect(x: -size.width/2, y: -size.height/2, width: size.width, height: size.height))
        overlay.fillColor = SKColor.black.withAlphaComponent(0.5)
        container.addChild(overlay)
        
        // Text
        let label = SKLabelNode(text: "Level Complete!")
        label.fontName = "Helvetica-Bold"
        label.fontSize = 56
        label.fontColor = SKColor.white
        container.addChild(label)
        
        addChild(container)
        levelCompleteNode = container
        
        // Animate
        container.setScale(0.1)
        container.alpha = 0
        
        let appear = SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.5),
            SKAction.fadeIn(withDuration: 0.5)
        ])
        appear.timingMode = .easeOut
        
        container.run(appear)
    }
    
    func showFishUnlocked(_ fish: Fish) {
        // Show fish swimming into tank
        let fishNode = SKSpriteNode(color: .orange, size: CGSize(width: 40, height: 20))
        fishNode.position = CGPoint(x: -50, y: size.height * 0.5)
        fishNode.zPosition = 50
        
        aquariumNode.addChild(fishNode)
        
        // Swim across screen
        let swim = SKAction.sequence([
            SKAction.moveTo(x: size.width + 50, duration: 3.0),
            SKAction.removeFromParent()
        ])
        
        fishNode.run(swim)
    }
    
    func showBonusPoints(_ points: Int) {
        let label = SKLabelNode(text: "+\(points)")
        label.fontName = "Helvetica-Bold"
        label.fontSize = 36
        label.fontColor = SKColor.green
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.7)
        label.zPosition = 100
        
        addChild(label)
        
        // Float up and fade
        let animation = SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 50, duration: 1.0),
                SKAction.fadeOut(withDuration: 1.0)
            ]),
            SKAction.removeFromParent()
        ])
        
        label.run(animation)
    }
    
    func showHint(for value: Int?) {
        guard let value = value else { return }
        
        let hint = SKLabelNode(text: "Try making \(value)!")
        hint.fontName = "Helvetica"
        hint.fontSize = 24
        hint.fontColor = SKColor.white
        hint.position = CGPoint(x: size.width / 2, y: size.height * 0.3)
        hint.zPosition = 90
        
        addChild(hint)
        
        hint.run(SKAction.sequence([
            SKAction.wait(forDuration: 3.0),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }
    
    // MARK: - Power-up Effects
    
    func triggerLightningEffect(on bubbles: [BubbleModel]) {
        // Create lightning bolts to each bubble
        for bubble in bubbles {
            guard let node = bubbleNodes[bubble.id] else { continue }
            
            let lightning = SKShapeNode()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: size.width / 2, y: size.height))
            path.addLine(to: node.position)
            lightning.path = path.cgPath
            lightning.strokeColor = SKColor.yellow
            lightning.lineWidth = 3
            lightning.zPosition = 60
            
            aquariumNode.addChild(lightning)
            
            // Flash and remove
            lightning.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.1),
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ]))
        }
    }
    
    func triggerExplosion(at position: CGPoint, affecting bubbles: [BubbleModel]) {
        // Explosion circle
        let explosion = SKShapeNode(circleOfRadius: 150)
        explosion.fillColor = SKColor.orange.withAlphaComponent(0.3)
        explosion.strokeColor = SKColor.red
        explosion.lineWidth = 3
        explosion.position = position
        explosion.zPosition = 60
        explosion.setScale(0.1)
        
        aquariumNode.addChild(explosion)
        
        // Expand and fade
        let explode = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.0, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3)
            ]),
            SKAction.removeFromParent()
        ])
        
        explosion.run(explode)
    }
    
    // MARK: - Update Loop
    
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        
        // Check if we should spawn bubbles
        if let vm = viewModel,
           vm.isGameActive,
           vm.bubbleManager.shouldSpawnBubble(currentTime: currentTime) {
            vm.spawnBubble()
        }
        
        // Remove off-screen bubbles
        for (id, node) in bubbleNodes {
            if node.position.y < -100 {
                node.removeFromParent()
                bubbleNodes.removeValue(forKey: id)
            }
        }
    }
}
