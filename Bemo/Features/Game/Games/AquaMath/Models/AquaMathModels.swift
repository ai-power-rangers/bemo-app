//
//  AquaMathModels.swift
//  Bemo
//
//  Data models for AquaMath game
//

// WHAT: Core data models for AquaMath including tiles, bubbles, game modes and state
// ARCHITECTURE: Simple Swift structs following MVVM-S pattern
// USAGE: Used throughout AquaMath components for state management and data flow

import Foundation
import CoreGraphics

// MARK: - Game Mode

enum GameMode: String, Codable, CaseIterable {
    case count      // Count dots
    case add        // Add numerals
    case connect    // Connect for multi-digit numbers
    case multiply   // Multiply adjacent tiles
    
    var displayName: String {
        switch self {
        case .count: return "Count"
        case .add: return "Add"
        case .connect: return "Connect"
        case .multiply: return "Multiply"
        }
    }
    
    var modeMultiplier: Double {
        switch self {
        case .count: return 1.0
        case .add: return 1.5
        case .connect: return 2.0
        case .multiply: return 2.5
        }
    }
}

// MARK: - Tile Types

enum TileKind: Hashable, Codable {
    case dot(Int)      // Dot pattern (1-6)
    case numeral(Int)  // Number (0-9)
    
    var displayValue: String {
        switch self {
        case .dot(let count):
            return String(repeating: "•", count: count)
        case .numeral(let value):
            return "\(value)"
        }
    }
    
    var numericValue: Int {
        switch self {
        case .dot(let count):
            return count
        case .numeral(let value):
            return value
        }
    }
}

// MARK: - Tile Model

struct Tile: Identifiable, Codable {
    let id: UUID
    let kind: TileKind
    var position: CGPoint
    
    init(kind: TileKind, position: CGPoint = .zero) {
        self.id = UUID()
        self.kind = kind
        self.position = position
    }
}

// MARK: - Tile Group (for connected tiles)

struct TileGroup: Identifiable, Codable {
    let id: UUID
    var tiles: [Tile]
    var frame: CGRect
    
    init(tiles: [Tile] = [], frame: CGRect = .zero) {
        self.id = UUID()
        self.tiles = tiles
        self.frame = frame
    }
    
    // Calculate numeric value based on game mode
    func value(for mode: GameMode) -> Int {
        switch mode {
        case .count, .add:
            return tiles.reduce(0) { $0 + $1.kind.numericValue }
        case .connect:
            // Tiles form a multi-digit number
            let digits = tiles.map { $0.kind.numericValue }
            return digits.reduce(0) { $0 * 10 + $1 }
        case .multiply:
            return tiles.reduce(1) { $0 * $1.kind.numericValue }
        }
    }
}

// MARK: - Bubble Types

enum BubbleType: String, Codable {
    case normal
    case lightning  // Pops nearby bubbles
    case bomb       // Explodes in radius
    case sponge     // Absorbs water
    case crate      // Mystery reward
}

// MARK: - Bubble Model

struct BubbleModel: Identifiable, Codable {
    let id: UUID
    let value: Int
    let type: BubbleType
    var position: CGPoint
    
    init(value: Int, type: BubbleType = .normal, position: CGPoint = .zero) {
        self.id = UUID()
        self.value = value
        self.type = type
        self.position = position
    }
}

// MARK: - Fish Model

struct Fish: Identifiable, Codable {
    let id: UUID
    let name: String
    let imageName: String
    let requiredScore: Int
    
    init(name: String, imageName: String, requiredScore: Int) {
        self.id = UUID()
        self.name = name
        self.imageName = imageName
        self.requiredScore = requiredScore
    }
}

// MARK: - Game State

struct AquaMathGameState: Codable {
    var mode: GameMode
    var score: Int
    var waterLevel: Double  // 0.0 to 1.0
    var tileGroups: [TileGroup]
    var activeBubbles: [BubbleModel]
    var collectedFish: [Fish]
    var currentLevel: Int
    var comboCount: Int
    var lastEquationResult: Int?
    
    init() {
        self.mode = .add
        self.score = 0
        self.waterLevel = 0.0
        self.tileGroups = []
        self.activeBubbles = []
        self.collectedFish = []
        self.currentLevel = 1
        self.comboCount = 0
        self.lastEquationResult = nil
    }
}

// MARK: - Equation Display

struct Equation {
    let expression: String
    let result: Int?
    
    init(groups: [TileGroup], mode: GameMode) {
        if groups.isEmpty {
            self.expression = ""
            self.result = nil
            return
        }
        
        switch mode {
        case .count:
            let total = groups.reduce(0) { $0 + $1.value(for: mode) }
            self.expression = ""  // No expression needed for count mode
            self.result = total
            
        case .add:
            let values = groups.map { $0.value(for: mode) }
            if values.count == 1 {
                self.expression = ""  // Single number, no operator needed
            } else {
                self.expression = values.map { "\($0)" }.joined(separator: " + ")
            }
            self.result = values.reduce(0, +)
            
        case .connect:
            let values = groups.map { $0.value(for: mode) }
            if values.count == 1 {
                self.expression = ""
            } else {
                self.expression = values.map { "\($0)" }.joined(separator: " + ")
            }
            self.result = values.reduce(0, +)
            
        case .multiply:
            let values = groups.map { $0.value(for: mode) }
            if values.count == 1 {
                self.expression = ""
            } else {
                self.expression = values.map { "\($0)" }.joined(separator: " × ")
            }
            self.result = values.reduce(1, *)
        }
    }
}

// MARK: - Level Configuration

struct LevelConfig {
    let levelNumber: Int
    let bubbleSpawnInterval: TimeInterval
    let valueRange: ClosedRange<Int>
    let powerUpProbability: Double
    let fishThresholds: [Int]  // Score thresholds for fish rewards
    
    static func config(for level: Int) -> LevelConfig {
        // Difficulty progression
        let baseInterval = 2.0 - (Double(level - 1) * 0.1)
        let spawnInterval = max(0.8, baseInterval)
        
        let maxValue = min(20, 8 + (level * 2))
        let valueRange = 2...maxValue
        
        let powerUpChance = min(0.3, 0.05 + (Double(level) * 0.02))
        
        let baseThreshold = 100 * level
        let thresholds = [
            baseThreshold,
            baseThreshold * 2,
            baseThreshold * 3
        ]
        
        return LevelConfig(
            levelNumber: level,
            bubbleSpawnInterval: spawnInterval,
            valueRange: valueRange,
            powerUpProbability: powerUpChance,
            fishThresholds: thresholds
        )
    }
}

// MARK: - Number Color Mapping

import SwiftUI

extension TileKind {
    var numberColor: Color {
        switch self {
        case .numeral(let value), .dot(let value):
            switch value {
            case 1: return Color(red: 0.85, green: 0.35, blue: 0.45) // Pink/Red
            case 2: return Color(red: 0.45, green: 0.35, blue: 0.70) // Purple
            case 3: return Color(red: 0.30, green: 0.65, blue: 0.35) // Green
            case 4: return Color(red: 0.25, green: 0.60, blue: 0.65) // Teal
            case 5: return Color(red: 0.35, green: 0.50, blue: 0.75) // Blue
            case 6: return Color(red: 0.55, green: 0.55, blue: 0.55) // Gray
            case 7: return Color(red: 0.35, green: 0.45, blue: 0.70) // Dark Blue
            case 8: return Color(red: 0.95, green: 0.55, blue: 0.25) // Orange
            case 9: return Color(red: 0.85, green: 0.35, blue: 0.30) // Red
            case 0: return Color(red: 0.50, green: 0.50, blue: 0.50) // Medium Gray
            default: return Color.black
            }
        }
    }
    
    var numberUIColor: UIColor {
        switch self {
        case .numeral(let value), .dot(let value):
            switch value {
            case 1: return UIColor(red: 0.85, green: 0.35, blue: 0.45, alpha: 1.0) // Pink/Red
            case 2: return UIColor(red: 0.45, green: 0.35, blue: 0.70, alpha: 1.0) // Purple
            case 3: return UIColor(red: 0.30, green: 0.65, blue: 0.35, alpha: 1.0) // Green
            case 4: return UIColor(red: 0.25, green: 0.60, blue: 0.65, alpha: 1.0) // Teal
            case 5: return UIColor(red: 0.35, green: 0.50, blue: 0.75, alpha: 1.0) // Blue
            case 6: return UIColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.0) // Gray
            case 7: return UIColor(red: 0.35, green: 0.45, blue: 0.70, alpha: 1.0) // Dark Blue
            case 8: return UIColor(red: 0.95, green: 0.55, blue: 0.25, alpha: 1.0) // Orange
            case 9: return UIColor(red: 0.85, green: 0.35, blue: 0.30, alpha: 1.0) // Red
            case 0: return UIColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 1.0) // Medium Gray
            default: return UIColor.black
            }
        }
    }
}