//
//  TgramViewerViewModel.swift
//  Bemo
//
//  ViewModel for the TgramViewer game
//

// WHAT: Manages front-facing camera and ARKit face tracking for frustration detection
// ARCHITECTURE: ViewModel in MVVM-S pattern, uses @Observable for state management
// USAGE: Created by TgramViewerGame with GameDelegate, detects user frustration via facial expressions

import SwiftUI
import Observation
import Combine
import UIKit
import AVFoundation
import ARKit
import RealityKit

@Observable
class TgramViewerViewModel: NSObject {
    
    // MARK: - Frustration Detection State
    
    var isFrustrated = false
    var frustrationScore: Float = 0.0
    var isSessionActive = false
    var errorMessage: String?
    var debugInfo: String = ""
    
    // MARK: - AR View
    var arView: ARView?
    
    // MARK: - Blend Shape Values (for debugging)
    var browDownLeft: Float = 0.0
    var browDownRight: Float = 0.0
    var mouthFrownLeft: Float = 0.0
    var mouthFrownRight: Float = 0.0
    var jawClench: Float = 0.0
    var eyeSquintLeft: Float = 0.0
    var eyeSquintRight: Float = 0.0
    
    // MARK: - Dependencies
    
    private weak var delegate: GameDelegate?
    private var arSession: ARSession?
    
    // MARK: - Initialization
    
    init(delegate: GameDelegate) {
        self.delegate = delegate
        super.init()
        setupARSession()
    }
    
    deinit {
        // Ensure sessions are stopped when view model is deallocated
        if isSessionActive {
            stopSession()
        }
    }
    
    private func setupARSession() {
        // Check if ARKit face tracking is supported
        guard ARFaceTrackingConfiguration.isSupported else {
            errorMessage = "Face tracking is not supported on this device"
            return
        }
        
        // Create AR View
        arView = ARView(frame: .zero)
        arView?.automaticallyConfigureSession = false
        
        arSession = ARSession()
        arSession?.delegate = self
        
        // Assign session to ARView
        arView?.session = arSession!
    }
    
    // MARK: - Session Management
    
    func startSession() {
        guard !isSessionActive else { return }
        
        // Check if face tracking is supported
        guard ARFaceTrackingConfiguration.isSupported else {
            errorMessage = "Face tracking requires a device with TrueDepth camera"
            return
        }
        
        isSessionActive = true
        errorMessage = nil
        
        // Configure and run AR session
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false
        arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        print("🎭 Face tracking session started")
    }
    
    func stopSession() {
        guard isSessionActive else { return }
        
        isSessionActive = false
        arSession?.pause()
        
        print("🛑 Face tracking session stopped")
    }
    
    // MARK: - Frustration Detection
    
    private func calculateFrustrationScore(from blendShapes: [ARFaceAnchor.BlendShapeLocation: NSNumber]) -> Float {
        // Extract blend shape values
        browDownLeft = blendShapes[.browDownLeft]?.floatValue ?? 0.0
        browDownRight = blendShapes[.browDownRight]?.floatValue ?? 0.0
        mouthFrownLeft = blendShapes[.mouthFrownLeft]?.floatValue ?? 0.0
        mouthFrownRight = blendShapes[.mouthFrownRight]?.floatValue ?? 0.0
        eyeSquintLeft = blendShapes[.eyeSquintLeft]?.floatValue ?? 0.0
        eyeSquintRight = blendShapes[.eyeSquintRight]?.floatValue ?? 0.0
        
        // Calculate weighted frustration score
        let score = 0.4 * (browDownLeft + browDownRight) +
                   0.4 * (mouthFrownLeft + mouthFrownRight) +
                   0.2 * (eyeSquintLeft + eyeSquintRight)
        
        // Update debug info
        debugInfo = String(format: "Brow: %.2f, Frown: %.2f, Jaw: %.2f, Squint: %.2f",
                          (browDownLeft + browDownRight) / 2,
                          (mouthFrownLeft + mouthFrownRight) / 2,
                          (eyeSquintLeft + eyeSquintRight) / 2)
        
        return score
    }
    

    
    // MARK: - Actions
    
    func reset() {
        isFrustrated = false
        frustrationScore = 0.0
        errorMessage = nil
        debugInfo = ""
        
        // Reset blend shape values
        browDownLeft = 0.0
        browDownRight = 0.0
        mouthFrownLeft = 0.0
        mouthFrownRight = 0.0
        jawClench = 0.0
        eyeSquintLeft = 0.0
        eyeSquintRight = 0.0
        
        // Stop session if active
        if isSessionActive {
            stopSession()
        }
    }
    
    func quit() {
        // Clean up any active sessions
        if isSessionActive {
            stopSession()
        }
        
        delegate?.gameDidRequestQuit()
    }
}

// MARK: - ARSessionDelegate

extension TgramViewerViewModel: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Process face anchors
        for anchor in anchors {
            guard let faceAnchor = anchor as? ARFaceAnchor else { continue }
            
            // Get blend shapes
            let blendShapes = faceAnchor.blendShapes
            
            // Calculate frustration score
            frustrationScore = calculateFrustrationScore(from: blendShapes)
            
            // Determine if frustrated (using threshold)
            isFrustrated = frustrationScore > 0.6
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        errorMessage = "AR Session failed: \(error.localizedDescription)"
        isSessionActive = false
    }
}

// MARK: - ARView UIViewRepresentable

struct ARViewContainer: UIViewRepresentable {
    let arView: ARView
    
    func makeUIView(context: Context) -> ARView {
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // No update needed
    }
}
