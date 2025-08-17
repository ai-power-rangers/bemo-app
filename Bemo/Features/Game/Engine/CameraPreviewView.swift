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


