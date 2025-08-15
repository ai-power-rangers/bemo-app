//
//  BubbleManager.swift
//  Bemo
//
//  Manages bubble spawning logic and distribution
//

// WHAT: Service managing bubble spawn cadence, value distribution, and power-up probability
// ARCHITECTURE: Service in MVVM-S pattern
// USAGE: Used by AquaMathGameViewModel to generate bubbles based on level configuration

import Foundation
import CoreGraphics

class BubbleManager {
    
    // MARK: - Properties
    
    private var levelConfig: LevelConfig
    private var lastSpawnTime: TimeInterval = 0
    private var bubbleHistory: [Int] = []  // Track recent values for variety
    
    // MARK: - Initialization
    
    init(levelConfig: LevelConfig) {
        self.levelConfig = levelConfig
    }
    
    // MARK: - Configuration
    
    func updateConfig(_ config: LevelConfig) {
        self.levelConfig = config
        bubbleHistory.removeAll()
    }
    
    // MARK: - Bubble Spawning
    
    func shouldSpawnBubble(currentTime: TimeInterval) -> Bool {
        if lastSpawnTime == 0 {
            lastSpawnTime = currentTime
            return true
        }
        
        if currentTime - lastSpawnTime >= levelConfig.bubbleSpawnInterval {
            lastSpawnTime = currentTime
            return true
        }
        
        return false
    }
    
    func spawnBubble() -> BubbleModel {
        let type = selectBubbleType()
        let value = selectBubbleValue(for: type)
        let position = randomSpawnPosition()
        
        // Track history for variety
        if type == .normal {
            bubbleHistory.append(value)
            if bubbleHistory.count > 5 {
                bubbleHistory.removeFirst()
            }
        }
        
        return BubbleModel(value: value, type: type, position: position)
    }
    
    // MARK: - Type Selection
    
    private func selectBubbleType() -> BubbleType {
        let random = Double.random(in: 0...1)
        
        if random < levelConfig.powerUpProbability {
            // Select a random power-up type
            let powerUps: [BubbleType] = [.lightning, .bomb, .sponge, .crate]
            return powerUps.randomElement()!
        }
        
        return .normal
    }
    
    // MARK: - Value Selection
    
    private func selectBubbleValue(for type: BubbleType) -> Int {
        switch type {
        case .normal:
            return selectNormalValue()
        case .lightning, .bomb, .sponge, .crate:
            // Power-ups don't have numeric values
            return 0
        }
    }
    
    private func selectNormalValue() -> Int {
        // Generate value within range
        var value = Int.random(in: levelConfig.valueRange)
        
        // Avoid too many repeats
        var attempts = 0
        while bubbleHistory.filter({ $0 == value }).count >= 2 && attempts < 10 {
            value = Int.random(in: levelConfig.valueRange)
            attempts += 1
        }
        
        // Occasionally spawn easier values (small numbers)
        if Double.random(in: 0...1) < 0.2 {
            value = min(value, Int.random(in: 2...5))
        }
        
        return value
    }
    
    // MARK: - Position
    
    private func randomSpawnPosition() -> CGPoint {
        // This will be adjusted based on actual screen dimensions
        // For now, return a position that will be transformed by the scene
        let xRange: ClosedRange<CGFloat> = 0.1...0.9  // Percentage of screen width
        let x = CGFloat.random(in: xRange)
        return CGPoint(x: x, y: 1.0)  // Top of screen
    }
    
    // MARK: - Difficulty Scaling
    
    func adjustDifficulty(basedOn score: Int) {
        // Dynamic difficulty adjustment
        // Could make spawn rate faster or value range wider based on performance
    }
}