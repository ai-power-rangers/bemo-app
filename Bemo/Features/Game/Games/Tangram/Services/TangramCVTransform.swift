//
//  TangramCVTransform.swift
//  Bemo
//
//  Centralized transform utilities for mapping CV outputs → SpriteKit target space
//

// WHAT: Single source of truth for CV → SK mapping, angle adjustments, and smoothing
// ARCHITECTURE: Game service (MVVM-S) used by scene rendering and validation
// USAGE: Call helpers to map normalized/pixel CV coordinates and rotations into SK space

import CoreGraphics
import Foundation

final class TangramCVTransform {
    struct SmoothedPose { var pos: CGPoint; var rot: CGFloat }
    private var smoothedById: [String: SmoothedPose] = [:]

    // MARK: - Mapping
    func mapToTarget(nx: CGFloat, ny: CGFloat, frame: CVFrameEvent, targetSize: CGSize) -> CGPoint {
        // Normalized (0..1) to centered target coords with Y inversion or homography path for pixels
        if TangramCVTuning.shared.useHomography {
            let px = nx * 1080.0
            let py = ny * 1920.0
            return mapCVToTarget(cvX: px, cvY: py, frame: frame, targetSize: targetSize)
        } else {
            var x = (nx - 0.5) * targetSize.width
            var y = (0.5 - ny) * targetSize.height
            if TangramCVTuning.shared.rotate180 { x = -x; y = -y }
            if TangramCVTuning.shared.mirrorX { x = -x }
            return CGPoint(x: x, y: y)
        }
    }

    func adjustedRotationRadians(fromDegrees deg: Double) -> CGFloat {
        var rot = CGFloat(deg) * .pi / 180
        if TangramCVTuning.shared.mirrorX { rot = -rot }
        if TangramCVTuning.shared.rotate180 { rot += .pi }
        return normalizeAngle(rot)
    }

    // MARK: - Smoothing
    func smoothPose(for id: String, targetPos: CGPoint, targetRot: CGFloat, alpha: CGFloat) -> (CGPoint, CGFloat) {
        let last = smoothedById[id]?.pos ?? targetPos
        let lastRot = smoothedById[id]?.rot ?? targetRot
        let blendedPos = CGPoint(x: last.x * (1 - alpha) + targetPos.x * alpha,
                                 y: last.y * (1 - alpha) + targetPos.y * alpha)
        let rotDelta = shortestAngleDelta(from: lastRot, to: targetRot)
        let blendedRot = normalizeAngle(lastRot + alpha * rotDelta)
        smoothedById[id] = SmoothedPose(pos: blendedPos, rot: blendedRot)
        return (blendedPos, blendedRot)
    }

    // MARK: - Homography Mapping (pixels → target SK coords)
    private func mapCVToTarget(cvX: CGFloat, cvY: CGFloat, frame: CVFrameEvent, targetSize: CGSize) -> CGPoint {
        let H = frame.homography
        guard H.count == 3, H[0].count == 3 else {
            let ref = CGSize(width: 1080, height: 1920)
            var tx = (cvX / ref.width - 0.5) * targetSize.width
            var ty = (0.5 - cvY / ref.height) * targetSize.height
            if TangramCVTuning.shared.rotate180 { tx = -tx; ty = -ty }
            if TangramCVTuning.shared.mirrorX { tx = -tx }
            return CGPoint(x: tx, y: ty)
        }
        let h00 = H[0][0], h01 = H[0][1], h02 = H[0][2]
        let h10 = H[1][0], h11 = H[1][1], h12 = H[1][2]
        let h20 = H[2][0], h21 = H[2][1], h22 = H[2][2]
        let det = h00*(h11*h22 - h12*h21) - h01*(h10*h22 - h12*h20) + h02*(h10*h21 - h11*h20)
        if abs(det) < 1e-9 {
            let ref = CGSize(width: 1080, height: 1920)
            var tx = (cvX / ref.width - 0.5) * targetSize.width
            var ty = (0.5 - cvY / ref.height) * targetSize.height
            if TangramCVTuning.shared.rotate180 { tx = -tx; ty = -ty }
            if TangramCVTuning.shared.mirrorX { tx = -tx }
            return CGPoint(x: tx, y: ty)
        }
        let inv00 =  (h11*h22 - h12*h21) / det
        let inv01 = -(h01*h22 - h02*h21) / det
        let inv02 =  (h01*h12 - h02*h11) / det
        let inv10 = -(h10*h22 - h12*h20) / det
        let inv11 =  (h00*h22 - h02*h20) / det
        let inv12 = -(h00*h12 - h02*h10) / det
        let inv20 =  (h10*h21 - h11*h20) / det
        let inv21 = -(h00*h21 - h01*h20) / det
        let inv22 =  (h00*h11 - h01*h10) / det

        let x = Double(cvX), y = Double(cvY)
        let X = inv00*x + inv01*y + inv02*1.0
        let Y = inv10*x + inv11*y + inv12*1.0
        let W = inv20*x + inv21*y + inv22*1.0
        let nx = CGFloat(X / W)
        let ny = CGFloat(Y / W)

        let ref = CGSize(width: 1080, height: 1920)
        var tx = (nx / ref.width - 0.5) * targetSize.width
        var ty = (0.5 - ny / ref.height) * targetSize.height
        if TangramCVTuning.shared.rotate180 { tx = -tx; ty = -ty }
        if TangramCVTuning.shared.mirrorX { tx = -tx }
        return CGPoint(x: tx, y: ty)
    }

    // MARK: - Angle helpers
    private func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        var a = angle
        while a > .pi { a -= 2 * .pi }
        while a < -.pi { a += 2 * .pi }
        return a
    }

    private func shortestAngleDelta(from: CGFloat, to: CGFloat) -> CGFloat {
        var d = to - from
        while d > .pi { d -= 2 * .pi }
        while d < -.pi { d += 2 * .pi }
        return d
    }
}


