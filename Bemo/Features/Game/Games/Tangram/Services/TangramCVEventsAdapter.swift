//
//  TangramCVEventsAdapter.swift
//  Bemo
//
//  Game-specific adapter that converts CVService detections into CVEventBus frames
//

// WHAT: Subscribes to CVService detection results and emits CVFrameEvent via CVEventBus.
// ARCHITECTURE: Game-scoped service (MVVM-S) – keeps CVService generic for reuse across games.
// USAGE: Start when Tangram game starts, stop when it ends.

import Foundation
import Combine
import CoreGraphics

final class TangramCVEventsAdapter {
    private let cvService: CVService
    private var cancellables = Set<AnyCancellable>()

    // Must match the viewSize used by CVService pipeline for consistent coordinates
    private let referenceViewSize = CGSize(width: 1080, height: 1920)

    init(cvService: CVService) {
        self.cvService = cvService
    }

    func start() {
        // Bridge detection results → CVEventBus frames
        cvService.detectionResultsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                guard let self else { return }
                let frame = self.buildFrame(from: result)
                CVEventBus.shared.emitFrame(frame)
            }
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
    }

    // MARK: - Mapping

    private func buildFrame(from result: CVService.CVDetectionResult) -> CVFrameEvent {
        // Prefer the integrated tangram result if available to get real rotation/vertices
        if let trAny: AnyObject = result.tangramResult {
            if let frame = buildFrameFromTangramResult(trAny) {
                return frame
            }
        }

        // Fallback to bounding-box based approximation
        var objects: [CVPieceEvent] = []
        for det in result.detections {
            let classId = Int(det.classId)
            let name = cvName(for: classId)
            let centerX = (det.bbox.origin.x + det.bbox.width / 2) * referenceViewSize.width
            let centerY = (det.bbox.origin.y + det.bbox.height / 2) * referenceViewSize.height
            let pose = CVPieceEvent.Pose(rotationDegrees: 0, translation: [Double(centerX), Double(centerY)])
            let x0 = det.bbox.origin.x * referenceViewSize.width
            let y0 = det.bbox.origin.y * referenceViewSize.height
            let x1 = (det.bbox.origin.x + det.bbox.width) * referenceViewSize.width
            let y1 = (det.bbox.origin.y + det.bbox.height) * referenceViewSize.height
            let vertices: [[Double]] = [[Double(x0), Double(y0)], [Double(x1), Double(y0)], [Double(x1), Double(y1)], [Double(x0), Double(y1)]]
            objects.append(CVPieceEvent(name: name, classId: classId, pose: pose, vertices: vertices))
        }
        return CVFrameEvent(objects: objects)
    }

    // MARK: - KVC bridge for TPTangramResult → CVFrameEvent
    private func buildFrameFromTangramResult(_ tr: AnyObject) -> CVFrameEvent? {
        // TPTangramResult API: H_3x3 (homography), scale, poses (classId->TPPose {theta,tx,ty}), refinedPolygons (classId->flat array)
        guard let hom = tr.value(forKey: "H_3x3") as? [NSNumber], hom.count == 9 else { return nil }
        let scale: Double = (tr.value(forKey: "scale") as? NSNumber)?.doubleValue ?? 0
        let poses = tr.value(forKey: "poses") as? [NSNumber: AnyObject] ?? [:]
        let polys = tr.value(forKey: "refinedPolygons") as? [NSNumber: [NSNumber]] ?? [:]

        // Build objects per present classId
        var objects: [CVPieceEvent] = []
        let classIds = Set(poses.keys.map { $0.intValue } + polys.keys.map { $0.intValue })
        for cid in classIds {
            let classId = cid
            let name = cvName(for: classId)

            // Pose
            var rotationDeg = 0.0
            var translation: [Double] = [0, 0]
            if let p = poses[NSNumber(value: classId)] {
                let theta = (p.value(forKey: "theta") as? NSNumber)?.doubleValue ?? 0
                let tx = (p.value(forKey: "tx") as? NSNumber)?.doubleValue ?? 0
                let ty = (p.value(forKey: "ty") as? NSNumber)?.doubleValue ?? 0
                rotationDeg = theta * 180.0 / .pi
                translation = [tx, ty]
            }

            // Vertices: refinedPolygons are normalized [x1,y1,x2,y2,...] in model space; scale to referenceViewSize
            var vertices: [[Double]] = []
            if let arr = polys[NSNumber(value: classId)] {
                var tmp: [[Double]] = []
                var i = 0
                while i + 1 < arr.count {
                    let x = arr[i].doubleValue * referenceViewSize.width
                    let y = arr[i+1].doubleValue * referenceViewSize.height
                    tmp.append([x, y])
                    i += 2
                }
                vertices = tmp
            }

            let pose = CVPieceEvent.Pose(rotationDegrees: rotationDeg, translation: translation)
            objects.append(CVPieceEvent(name: name, classId: classId, pose: pose, vertices: vertices))
        }

        // Homography 3x3 into 2D array
        let H = [
            [hom[0].doubleValue, hom[1].doubleValue, hom[2].doubleValue],
            [hom[3].doubleValue, hom[4].doubleValue, hom[5].doubleValue],
            [hom[6].doubleValue, hom[7].doubleValue, hom[8].doubleValue]
        ]

        var frame = CVFrameEvent(objects: objects)
        // Note: CVFrameEvent currently fixes homography/scale in its init; we’d extend it if needed.
        // For now we just return objects; homography usage will be integrated in rendering strategy.
        _ = H
        _ = scale
        return frame
    }

    private func cvName(for classId: Int) -> String {
        switch classId {
        case 0: return "tangram_parallelogram"
        case 1: return "tangram_square"
        case 2: return "tangram_triangle_lrg"
        case 3: return "tangram_triangle_lrg2"
        case 4: return "tangram_triangle_med"
        case 5: return "tangram_triangle_sml"
        case 6: return "tangram_triangle_sml2"
        default: return "tangram_unknown"
        }
    }
}


