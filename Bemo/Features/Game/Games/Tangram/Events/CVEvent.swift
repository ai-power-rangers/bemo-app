//
//  CVEvent.swift
//  Bemo
//
//  CV event types for piece manipulation
//

// WHAT: Defines CV events emitted by physical world and consumed by digital displays
// ARCHITECTURE: Event-driven system bridging physical and digital worlds
// USAGE: Emitted when pieces are manipulated in bottom section, consumed by top sections

import Foundation
import CoreGraphics

/// CV-format event matching the output from real CV hardware
struct CVPieceEvent: Codable {
    let name: String
    let classId: Int
    let pose: Pose
    let vertices: [[Double]]
    
    struct Pose: Codable {
        let rotationDegrees: Double
        let translation: [Double]
        
        enum CodingKeys: String, CodingKey {
            case rotationDegrees = "rotation_degrees"
            case translation
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case classId = "class_id"
        case pose
        case vertices
    }
}

/// Full CV frame event with all pieces
struct CVFrameEvent: Codable {
    let homography: [[Double]]
    let scale: Double
    let objects: [CVPieceEvent]
    // Optional: canonical model plane polygons and colors (for debug/QA overlays)
    // Keyed by class id; each value is a flat [x0,y0,x1,y1,...] in plane coordinates
    let planeModelPolygons: [Int: [Double]]?
    // Optional RGB colors 0..255 per class id
    let modelColorsRGB: [Int: [Double]]?
    // Optional: pipeline-composited overlay image (PNG data) for debug/QA
    let overlayPNGData: Data?
    
    init() {
        // Default homography matrix (identity-ish for our simulation)
        self.homography = [
            [0.915, 0.406, 35.684],
            [-0.017, -0.485, 77.180],
            [-0.0000185, 0.000657, 1.0]
        ]
        self.scale = 2.609
        self.objects = []
        self.planeModelPolygons = nil
        self.modelColorsRGB = nil
        self.overlayPNGData = nil
    }
    
    init(objects: [CVPieceEvent]) {
        // Default homography matrix (identity-ish for our simulation)
        self.homography = [
            [0.915, 0.406, 35.684],
            [-0.017, -0.485, 77.180],
            [-0.0000185, 0.000657, 1.0]
        ]
        self.scale = 2.609
        self.objects = objects
        self.planeModelPolygons = nil
        self.modelColorsRGB = nil
        self.overlayPNGData = nil
    }

    init(homography: [[Double]], scale: Double, objects: [CVPieceEvent], planeModelPolygons: [Int: [Double]]? = nil, modelColorsRGB: [Int: [Double]]? = nil, overlayPNGData: Data? = nil) {
        self.homography = homography
        self.scale = scale
        self.objects = objects
        self.planeModelPolygons = planeModelPolygons
        self.modelColorsRGB = modelColorsRGB
        self.overlayPNGData = overlayPNGData
    }
}

/// Simplified event for internal use
enum TangramCVEvent {
    case pieceMoved(id: String, position: CGPoint, rotation: CGFloat)
    case pieceFlipped(id: String, isFlipped: Bool)
    case pieceLifted(id: String)
    case piecePlaced(id: String)
    case frameUpdate(CVFrameEvent)
    case validationChanged(pieceId: String, isValid: Bool)
    
    var pieceId: String? {
        switch self {
        case .pieceMoved(let id, _, _),
             .pieceFlipped(let id, _),
             .pieceLifted(let id),
             .piecePlaced(let id),
             .validationChanged(let id, _):
            return id
        case .frameUpdate:
            return nil
        }
    }
}