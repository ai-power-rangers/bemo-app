//
//  TangramCVTuningService.swift
//  Bemo
//
//  Runtime-tunable parameters for Tangram CV rendering and identity tracking
//

// WHAT: Centralized tuning knobs for smoothing/thresholds/linger and identity assignment radius
// ARCHITECTURE: Game-scoped service (MVVM-S). Read by scene and adapter.
// USAGE: Adjust values at runtime (e.g., via a debug menu) to tune stability without code changes.

import Foundation
import Observation

@Observable
final class TangramCVTuning {
    static let shared = TangramCVTuning()
    private init() {}

    // Scene rendering
    var smoothingAlpha: Double = 0.30
    var positionThresholdPx: Double = 4.0
    var rotationThresholdDeg: Double = 4.0
    var lingerSeconds: Double = 0.8

    // Identity tracker (adapter)
    var assignmentThresholdPx: Double = 40.0

    // Mapping controls
    var useHomography: Bool = false
    var mirrorX: Bool = false
    var rotate180: Bool = true
}


