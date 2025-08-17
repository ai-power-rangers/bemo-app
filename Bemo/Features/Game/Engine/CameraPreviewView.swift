//
//  CameraPreviewView.swift
//  Bemo
//
//  Minimal live camera preview overlay for debugging CV
//

// WHAT: SwiftUI view that shows a live camera preview using AVCaptureVideoPreviewLayer.
// ARCHITECTURE: View layer utility. Reads from the shared CVService's capture session.
// USAGE: Overlay in GameHostView for Tangram to aid debugging.

import SwiftUI
import AVFoundation

struct CameraPreviewView: View {
    let cvService: CVService

    var body: some View {
        CameraPreviewRepresentable(captureSessionProvider: { cvService.getCaptureSessionForPreview() })
            .background(Color.black.opacity(0.8))
    }
}

private struct CameraPreviewRepresentable: UIViewRepresentable {
    let captureSessionProvider: () -> AVCaptureSession?

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = captureSessionProvider()
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

// MARK: - HUD Wrapper

struct CameraPreviewWithHUD: View {
    let cvService: CVService
    @State private var detectionCount: Int = 0
    @State private var codes: [String] = []

    private func code(for classId: Int, index: Int) -> String {
        switch classId {
        case 0: return "P"
        case 1: return "SQ"
        case 2: return "LT1"
        case 3: return "LT2"
        case 4: return "MT"
        case 5: return "ST1"
        case 6: return "ST2"
        default: return "?"
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            CameraPreviewView(cvService: cvService)
            VStack(alignment: .leading, spacing: 4) {
                Text("Detections: \(detectionCount)")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4)
                if !codes.isEmpty {
                    Text(codes.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                }
            }
            .padding(6)
        }
        .onReceive(cvService.detectionResultsPublisher) { result in
            detectionCount = result.detections.count
            // Deterministic ordering by class and x
            let sorted = result.detections.sorted { l, r in
                if l.classId == r.classId { return l.bbox.origin.x < r.bbox.origin.x }
                return l.classId < r.classId
            }
            var idxByClass: [Int: Int] = [:]
            codes = sorted.map { det in
                let idx = idxByClass[det.classId].map { $0 + 1 } ?? 1
                idxByClass[det.classId] = idx
                return code(for: Int(det.classId), index: idx)
            }
        }
    }
}


