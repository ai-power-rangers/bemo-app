//
//  CVService.swift
//  Bemo
//
//  Computer Vision service wrapper for TPIntegratedPipeline
//

// WHAT: Computer vision service that processes camera frames to recognize game pieces. Publishes RecognizedPiece array via Combine.
// ARCHITECTURE: Core service in MVVM-S. Wraps CV SDK, publishes recognition events. Central to game input processing.
// USAGE: Start/stop sessions for games. Subscribe to recognizedPiecesPublisher for real-time piece detection. Handle calibration.

import Foundation
import Combine
import CoreImage
import Vision
import AVFoundation
import UIKit

// Wrapper to avoid issues with @Observable macro and C++ types
private class PipelineWrapper {
    var pipeline: TPIntegratedPipeline?
}

@Observable
class CVService: NSObject {
    // MARK: - Published Properties
    private let recognizedPiecesSubject = PassthroughSubject<[RecognizedPiece], Never>()
    private let detectionResultsSubject = PassthroughSubject<CVDetectionResult, Never>()
    private var isSessionActive = false
    
    // MARK: - CV Pipeline
    private let pipelineWrapper = PipelineWrapper()
    
    // MARK: - Camera Properties
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let videoQueue = DispatchQueue(label: "com.bemo.cvservice.video", qos: .userInteractive)
    
    // MARK: - State
    private var cancellables = Set<AnyCancellable>()
    private var lastProcessingTime: TimeInterval = 0
    
    // Public publishers
    var recognizedPiecesPublisher: AnyPublisher<[RecognizedPiece], Never> {
        recognizedPiecesSubject.eraseToAnyPublisher()
    }
    
    var detectionResultsPublisher: AnyPublisher<CVDetectionResult, Never> {
        detectionResultsSubject.eraseToAnyPublisher()
    }
    
    enum CVError: Error {
        case sessionNotActive
        case processingError
        case calibrationRequired
        case cameraError(String)
        case pipelineInitializationError(String)
    }
    
    struct CVDetectionResult {
        let detections: [TPDetection]
        let tangramResult: TPTangramResult?
        let overlayImage: UIImage?
        let processingTimeMs: Double
        let fps: Double
    }
    
    override init() {
        super.init()
        setupPipeline()
    }
    
    private func setupPipeline() {
        // Path to tangram shapes configuration
        guard let modelPath = Bundle.main.path(forResource: "tangram_shapes_2d", ofType: "json") else {
            print("❌ CVService: Model file not found")
            return
        }
        
        // Path to YOLO model
        guard let yoloPath = Bundle.main.path(forResource: "best_aug16_realSynth", ofType: "mlmodelc") ?? 
                             Bundle.main.path(forResource: "best_aug16_realSynth", ofType: "mlpackage") else {
            print("❌ CVService: YOLO model not found")
            return
        }
        
        // Initialize the integrated pipeline
        do {
            pipelineWrapper.pipeline = try TPIntegratedPipeline(
                modelPath: yoloPath,
                tangramModelsJSON: modelPath,
                assetsDir: nil
            )
            print("✅ CVService: Pipeline initialized successfully")
        } catch {
            print("❌ CVService: Failed to initialize pipeline: \(error.localizedDescription)")
        }
    }
    
    func initialize() {
        // Perform any necessary initialization
        print("CVService initialized")
    }

    // MARK: - Debug Preview Accessor
    /// Returns the active AVCaptureSession for preview purposes (read-only)
    /// Intended for debug overlays. Do not hold a strong reference.
    func getCaptureSessionForPreview() -> AVCaptureSession? {
        return captureSession
    }
    
    // MARK: - Session Management
    
    func startSession() {
        guard !isSessionActive else { return }
        
        isSessionActive = true
        print("CV session started")
        
        // Request camera permission first
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            if granted {
                DispatchQueue.main.async {
                    self?.setupCamera()
                    self?.startCamera()
                }
            } else {
                print("❌ Camera permission denied")
            }
        }
    }
    
    func stopSession() {
        isSessionActive = false
        print("CV session stopped")
        
        stopCamera()
        
        // Clean up resources
        cancellables.removeAll()
    }
    
    // MARK: - Camera Setup
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        // Get front camera with ultra-wide preference
        guard let camera = getFrontFacingCamera() else {
            print("❌ No front camera available")
            return
        }
        
        print("📱 Using camera: \(camera.localizedName)")
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession?.canAddInput(input) ?? false {
                captureSession?.addInput(input)
            }
            
            // Configure for highest resolution
            configureForHighestResolution(camera)
            
            // Set session preset after adding input
            let preferredPresets: [AVCaptureSession.Preset] = [.hd4K3840x2160, .hd1920x1080, .hd1280x720, .high]
            for preset in preferredPresets {
                if captureSession?.canSetSessionPreset(preset) ?? false {
                    captureSession?.sessionPreset = preset
                    print("✅ Selected camera session preset: \(preset)")
                    break
                }
            }
            
            // Video output
            videoOutput = AVCaptureVideoDataOutput()
            videoOutput?.setSampleBufferDelegate(self, queue: videoQueue)
            videoOutput?.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput?.alwaysDiscardsLateVideoFrames = true
            
            if captureSession?.canAddOutput(videoOutput!) ?? false {
                captureSession?.addOutput(videoOutput!)
                
                // Configure connection for front camera
                if let connection = videoOutput?.connection(with: .video) {
                    if #available(iOS 17.0, *) {
                        connection.videoRotationAngle = 90 // portrait
                    } else {
                        connection.videoOrientation = .portrait
                    }
                    // Mirror front camera for natural selfie view
                    connection.isVideoMirrored = true
                    print("🪞 Front camera mirroring enabled")
                }
            }
            
        } catch {
            print("❌ Camera setup failed: \(error)")
        }
    }
    
    private func startCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if !(self?.captureSession?.isRunning ?? false) {
                self?.captureSession?.startRunning()
            }
        }
    }
    
    private func stopCamera() {
        if captureSession?.isRunning ?? false {
            captureSession?.stopRunning()
        }
        captureSession = nil
        videoOutput = nil
    }
    
    // MARK: - Camera Selection Helpers
    
    private func getFrontFacingCamera() -> AVCaptureDevice? {
        print("🔍 Searching for front-facing cameras...")
        
        // Use discovery session to find all front cameras
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInUltraWideCamera,
                .builtInWideAngleCamera,
                .builtInTrueDepthCamera,
                .builtInDualWideCamera,
                .builtInTripleCamera
            ],
            mediaType: .video,
            position: .front
        )
        
        let frontCameras = discoverySession.devices
        print("📱 Found \(frontCameras.count) front camera(s)")
        
        // Priority selection
        // 1. Try ultra-wide first
        if let ultraWide = frontCameras.first(where: { $0.deviceType == .builtInUltraWideCamera }) {
            print("✅ Selected: Ultra-wide front camera")
            return ultraWide
        }
        
        // 2. Try wide-angle
        if let wide = frontCameras.first(where: { $0.deviceType == .builtInWideAngleCamera }) {
            print("✅ Selected: Wide-angle front camera")
            return wide
        }
        
        // 3. Try TrueDepth
        if let trueDepth = frontCameras.first(where: { $0.deviceType == .builtInTrueDepthCamera }) {
            print("✅ Selected: TrueDepth front camera")
            return trueDepth
        }
        
        // 4. Use any available front camera
        if let anyFront = frontCameras.first {
            print("✅ Selected: Default front camera")
            return anyFront
        }
        
        print("❌ No front cameras found!")
        return nil
    }
    
    private func configureForHighestResolution(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            
            print("🔧 Configuring camera for highest resolution...")
            
            // Find the highest resolution format that supports 30 FPS
            var bestFormat: AVCaptureDevice.Format? = nil
            var bestArea: Int32 = 0
            
            for format in device.formats {
                let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let area = dims.width * dims.height
                
                let supports30fps = format.videoSupportedFrameRateRanges.contains { range in
                    range.minFrameRate <= 30.0 && 30.0 <= range.maxFrameRate
                }
                
                if supports30fps && area > bestArea {
                    bestArea = area
                    bestFormat = format
                }
            }
            
            if let format = bestFormat {
                device.activeFormat = format
                // Lock to 30 FPS
                let desired = CMTime(value: 1, timescale: 30)
                device.activeVideoMinFrameDuration = desired
                device.activeVideoMaxFrameDuration = desired
                
                let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                print("✅ Set format: \(dims.width)x\(dims.height) @30fps")
            }
        } catch {
            print("❌ Failed to configure camera: \(error)")
        }
    }
    
    // MARK: - Calibration
    
    func startCalibration() -> AnyPublisher<CalibrationResult, CVError> {
        // Stub implementation for calibration
        return Future<CalibrationResult, CVError> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                let result = CalibrationResult(
                    isSuccessful: true,
                    playAreaBounds: CGRect(x: 0, y: 0, width: 1000, height: 1000),
                    lightingQuality: .good
                )
                promise(.success(result))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Frame Processing
    
    func processFrame(_ image: CIImage) {
        guard isSessionActive else { return }
        
        // In a real implementation, this would:
        // 1. Pass the frame to Alan CV Kit
        // 2. Get recognized objects
        // 3. Convert to RecognizedPiece models
        // 4. Publish results
    }
    
    // MARK: - Frustration Detection
    
    func detectFrustration(from image: CIImage) -> AnyPublisher<Float, Never> {
        // Stub implementation for frustration detection
        // Returns a value between 0.0 (calm) and 1.0 (frustrated)
        return Just(0.2)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    private func mapDetectionToPieceType(_ classId: Int) -> TangramPieceType? {
        switch classId {
        case 0: return .parallelogram
        case 1: return .square
        case 2: return .largeTriangle1
        case 3: return .largeTriangle2
        case 4: return .mediumTriangle
        case 5: return .smallTriangle1
        case 6: return .smallTriangle2
        default: return nil
        }
    }
    
    private func convertDetectionsToRecognizedPieces(_ detections: [TPDetection]) -> [RecognizedPiece] {
        var pieces: [RecognizedPiece] = []
        
        for detection in detections {
            if let pieceType = mapDetectionToPieceType(Int(detection.classId)) {
                // Convert normalized bbox to position
                // For now, we'll use the center of the bounding box
                let centerX = detection.bbox.origin.x + detection.bbox.width / 2
                let centerY = detection.bbox.origin.y + detection.bbox.height / 2
                
                let piece = RecognizedPiece(
                    id: UUID().uuidString,
                    pieceTypeId: pieceType.rawValue, // Assumes TangramPieceType has a String raw value
                    position: CGPoint(x: centerX, y: centerY),
                    rotation: 0, // We'll get this from tangramResult if available
                    velocity: .zero,
                    isMoving: false,
                    confidence: Double(detection.confidence),
                    timestamp: Date(),
                    frameNumber: 0 // TODO: Pass real frame number if available
                )
                pieces.append(piece)
            }
        }
        
        return pieces
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CVService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let pipeline = pipelineWrapper.pipeline,
              isSessionActive else { return }
        
        // Process frame through integrated pipeline
        let startTime = CACurrentMediaTime()
        
        let options = TPTangramOptions()
        options.renderOverlays = true
        options.lockingEnabled = true
        
        // Get a reasonable view size (we're not displaying, so use a standard size)
        let viewSize = CGSize(width: 1080, height: 1920) // Portrait iPhone size
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            do {
                pipeline.enablePortraitCropping = true
                let result = try pipeline.processFrame(
                    pixelBuffer,
                    viewSize: viewSize,
                    confidenceThreshold: 0.6,
                    options: options
                )
                
                let processingTime = (CACurrentMediaTime() - startTime) * 1000
                let fps = 1000.0 / processingTime
                
                // Convert detections to recognized pieces
                let recognizedPieces = self.convertDetectionsToRecognizedPieces(result.detections)
                
                // Publish recognized pieces
                if !recognizedPieces.isEmpty {
                    self.recognizedPiecesSubject.send(recognizedPieces)
                }
                
                // Create overlay image if available
                var overlayImage: UIImage?
                if let combinedOverlay = result.combinedOverlay {
                    let ciImage = CIImage(cvPixelBuffer: combinedOverlay)
                    let context = CIContext()
                    if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                        overlayImage = UIImage(cgImage: cgImage)
                    }
                }
                
                // Publish full detection results
                let detectionResult = CVDetectionResult(
                    detections: result.detections,
                    tangramResult: result.tangramResult,
                    overlayImage: overlayImage,
                    processingTimeMs: processingTime,
                    fps: fps
                )
                
                self.detectionResultsSubject.send(detectionResult)
                
                // Note: noisy per-frame logs disabled to avoid console spam
                // If needed for debugging, re-enable under a debug flag
            } catch {
                print("❌ Processing error: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

struct CalibrationResult {
    let isSuccessful: Bool
    let playAreaBounds: CGRect
    let lightingQuality: LightingQuality
    
    enum LightingQuality {
        case poor
        case fair
        case good
        case excellent
    }
}
