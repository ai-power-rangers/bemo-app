//
//  TgramViewerViewModel.swift
//  Bemo
//
//  ViewModel for the TgramViewer game
//

// WHAT: Manages CV service for real-time tangram detection visualization
// ARCHITECTURE: ViewModel in MVVM-S pattern, uses @Observable for state management
// USAGE: Created by TgramViewerGame with GameDelegate, manages CV service lifecycle and displays detection results

import SwiftUI
import Observation
import Combine
import UIKit

@Observable
class TgramViewerViewModel {
    
    // MARK: - Display State
    
    struct DisplayPiece: Identifiable {
        let id: String
        let pieceType: TangramPieceType
        let position: CGPoint  // Position of the piece's calculated geometric center
        let rotation: Double   // In degrees
        let vertices: [CGPoint] // Absolute screen coordinates for vertices
        let color: Color
        let confidence: Float
    }
    
    var pieces: [DisplayPiece] = []
    var isLoading = false
    var errorMessage: String?
    var canvasSize: CGSize = CGSize(width: 600, height: 600)
    
    // CV Live Data
    var isSessionActive = false
    var overlayImage: UIImage?
    var fps: Double = 0
    var detectionCount: Int = 0
    
    // MARK: - Recording State
    
    struct RecordedFrame {
        let timestamp: TimeInterval
        let detections: [CVService.CVDetectionResult]
        let overlayImage: UIImage?
    }
    
    var isRecording = false
    var recordedFrames: [RecordedFrame] = []
    var isPlayingRecording = false
    var playbackIndex: Int = 0
    
    // MARK: - Dependencies
    
    private weak var delegate: GameDelegate?
    private let cvService: CVService
    private var cancellables = Set<AnyCancellable>()
    private var playbackTimer: Timer?
    
    // MARK: - Initialization
    
    init(delegate: GameDelegate, cvService: CVService) {
        self.delegate = delegate
        self.cvService = cvService
        setupCVSubscriptions()
    }
    
    deinit {
        // Ensure CV session is stopped when view model is deallocated
        if isSessionActive {
            cvService.stopSession()
        }
        playbackTimer?.invalidate()
    }
    
    private func setupCVSubscriptions() {
        // Subscribe to CV detection results
        cvService.detectionResultsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.handleCVDetectionResult(result)
            }
            .store(in: &cancellables)
        
        // Subscribe to recognized pieces for backward compatibility
        cvService.recognizedPiecesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pieces in
                self?.handleRecognizedPieces(pieces)
            }
            .store(in: &cancellables)
    }
    
    private func handleCVDetectionResult(_ result: CVService.CVDetectionResult) {
        // Update overlay image
        self.overlayImage = result.overlayImage
        
        // Update metrics
        self.fps = result.fps
        self.detectionCount = result.detections.count
        
        // Record frame if recording
        if isRecording {
            let frame = RecordedFrame(
                timestamp: Date().timeIntervalSinceReferenceDate,
                detections: [result],
                overlayImage: result.overlayImage
            )
            recordedFrames.append(frame)
        }
        
        // Convert detections to display pieces
        var displayPieces: [DisplayPiece] = []
        
        for (index, detection) in result.detections.enumerated() {
            if let pieceType = mapClassIdToPieceType(Int(detection.classId)) {
                // Convert normalized bbox to canvas coordinates
                let centerX = (detection.bbox.origin.x + detection.bbox.width / 2) * canvasSize.width
                let centerY = (detection.bbox.origin.y + detection.bbox.height / 2) * canvasSize.height
                
                // Create vertices from bbox for now (we'll get actual vertices from tangramResult later)
                let width = detection.bbox.width * canvasSize.width
                let height = detection.bbox.height * canvasSize.height
                let vertices = [
                    CGPoint(x: centerX - width/2, y: centerY - height/2),
                    CGPoint(x: centerX + width/2, y: centerY - height/2),
                    CGPoint(x: centerX + width/2, y: centerY + height/2),
                    CGPoint(x: centerX - width/2, y: centerY + height/2)
                ]
                
                let piece = DisplayPiece(
                    id: "\(pieceType.rawValue)_\(index)",
                    pieceType: pieceType,
                    position: CGPoint(x: centerX, y: centerY),
                    rotation: 0,
                    vertices: vertices,
                    color: pieceType.color,
                    confidence: detection.confidence
                )
                
                displayPieces.append(piece)
            }
        }
        
        self.pieces = displayPieces
    }
    
    private func handleRecognizedPieces(_ pieces: [RecognizedPiece]) {
        // Handle recognized pieces if needed
        print("Received \(pieces.count) recognized pieces")
    }
    
    // MARK: - Canvas Management
    
    func updateCanvasSize(to newSize: CGSize) {
        // Only update if the size has meaningfully changed
        guard self.canvasSize != newSize, newSize != .zero else { return }
        self.canvasSize = newSize
        print("Canvas size updated to: \(newSize)")
    }
    
    // MARK: - CV Session Management
    
    func startCVSession() {
        guard !isSessionActive else { return }
        
        isSessionActive = true
        isLoading = false
        errorMessage = nil
        pieces = []
        
        // Start the CV service
        cvService.startSession()
        print("🎥 CV session started")
    }
    
    func stopCVSession() {
        guard isSessionActive else { return }
        
        isSessionActive = false
        cvService.stopSession()
        print("🛑 CV session stopped")
    }
    
    // MARK: - Recording Management
    
    func startRecording() {
        guard isSessionActive else {
            errorMessage = "Start CV session before recording"
            return
        }
        
        isRecording = true
        recordedFrames = []
        print("🔴 Recording started")
    }
    
    func stopRecording() {
        isRecording = false
        print("⏹️ Recording stopped. Captured \(recordedFrames.count) frames")
    }
    
    func playRecording() {
        guard !recordedFrames.isEmpty else {
            errorMessage = "No recording available"
            return
        }
        
        // Stop live session if active
        if isSessionActive {
            stopCVSession()
        }
        
        isPlayingRecording = true
        playbackIndex = 0
        
        // Start playback timer
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.playNextFrame()
        }
    }
    
    func stopPlayback() {
        isPlayingRecording = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        pieces = []
        overlayImage = nil
    }
    
    private func playNextFrame() {
        guard isPlayingRecording, playbackIndex < recordedFrames.count else {
            stopPlayback()
            return
        }
        
        let frame = recordedFrames[playbackIndex]
        
        // Display the recorded frame
        if let result = frame.detections.first {
            handleCVDetectionResult(result)
        }
        
        playbackIndex += 1
    }
    
    // MARK: - Mapping Functions
    
    private func mapClassIdToPieceType(_ classId: Int) -> TangramPieceType? {
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
    
    // MARK: - Actions
    
    /// Resets the current state
    func reset() {
        pieces = []
        overlayImage = nil
        fps = 0
        detectionCount = 0
        errorMessage = nil
        
        // Stop any active sessions
        if isSessionActive {
            stopCVSession()
        }
        if isPlayingRecording {
            stopPlayback()
        }
    }
    
    func quit() {
        // Clean up any active sessions
        if isSessionActive {
            stopCVSession()
        }
        if isPlayingRecording {
            stopPlayback()
        }
        
        delegate?.gameDidRequestQuit()
    }
    
    /// Toggles between live CV mode and recording playback
    func toggleMode() {
        if isSessionActive {
            // Currently live, stop it
            stopCVSession()
            
            // If we have a recording, play it
            if !recordedFrames.isEmpty {
                playRecording()
            }
        } else if isPlayingRecording {
            // Currently playing recording, stop it and go live
            stopPlayback()
            startCVSession()
        } else {
            // Nothing active, start live session
            startCVSession()
        }
    }
    
    /// Toggles recording on/off
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
}

// MARK: - Piece Color Extension
