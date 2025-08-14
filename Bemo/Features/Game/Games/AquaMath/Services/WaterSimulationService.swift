//
//  WaterSimulationService.swift
//  Bemo
//
//  Manages water level calculations and physics
//

// WHAT: Service calculating water level changes based on game events
// ARCHITECTURE: Service in MVVM-S pattern
// USAGE: Used by AquaMathGameViewModel to determine water level progression

import Foundation

class WaterSimulationService {
    
    // MARK: - Constants
    
    private let baseWaterPerBubble: Double = 0.05  // 5% per bubble
    private let comboWaterReduction: Double = 0.02  // Combos evaporate 2% water
    private let spongeReduction: Double = 0.15      // Sponge removes 15% water
    
    // MARK: - Water Calculations
    
    func calculateWaterIncrease(bubblesPopped: Int, withCombo: Bool) -> Double {
        var waterIncrease = Double(bubblesPopped) * baseWaterPerBubble
        
        // Combos cause slight evaporation (extends play time)
        if withCombo {
            waterIncrease -= comboWaterReduction
        }
        
        return max(0, waterIncrease)
    }
    
    func spongeWaterReduction() -> Double {
        return spongeReduction
    }
    
    func calculateWaterForPowerUp(_ type: BubbleType) -> Double {
        switch type {
        case .normal:
            return baseWaterPerBubble
        case .lightning:
            return baseWaterPerBubble * 3  // Lightning adds more water
        case .bomb:
            return baseWaterPerBubble * 2
        case .sponge:
            return -spongeReduction  // Negative for removal
        case .crate:
            return 0  // Crates don't affect water
        }
    }
    
    // MARK: - Level Requirements
    
    func waterRequiredForLevel(_ level: Int) -> Double {
        // Always 100% to complete level
        return 1.0
    }
    
    func estimatedBubblesForCompletion(currentWater: Double) -> Int {
        let remaining = 1.0 - currentWater
        return Int(ceil(remaining / baseWaterPerBubble))
    }
}