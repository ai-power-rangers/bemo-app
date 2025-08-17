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

@MainActor
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
        var objects: [CVPieceEvent] = []

        for det in result.detections {
            let classId = Int(det.classId)
            let name = cvName(for: classId)

            // Convert normalized bbox center → reference pixel coordinates
            let centerX = (det.bbox.origin.x + det.bbox.width / 2) * referenceViewSize.width
            let centerY = (det.bbox.origin.y + det.bbox.height / 2) * referenceViewSize.height

            let pose = CVPieceEvent.Pose(
                rotationDegrees: 0, // rotation to be provided when available from tangram pose
                translation: [Double(centerX), Double(centerY)]
            )

            // Approximate vertices from bbox
            let x0 = det.bbox.origin.x * referenceViewSize.width
            let y0 = det.bbox.origin.y * referenceViewSize.height
            let x1 = (det.bbox.origin.x + det.bbox.width) * referenceViewSize.width
            let y1 = (det.bbox.origin.y + det.bbox.height) * referenceViewSize.height
            let vertices: [[Double]] = [
                [Double(x0), Double(y0)],
                [Double(x1), Double(y0)],
                [Double(x1), Double(y1)],
                [Double(x0), Double(y1)]
            ]

            let obj = CVPieceEvent(name: name, classId: classId, pose: pose, vertices: vertices)
            objects.append(obj)
        }

        return CVFrameEvent(objects: objects)
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


