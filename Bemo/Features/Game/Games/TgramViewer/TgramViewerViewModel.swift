//
//  TgramViewerViewModel.swift
//  Bemo
//
//  ViewModel for the TgramViewer game
//

// WHAT: Manages loading and processing CV JSON data for visualization
// ARCHITECTURE: ViewModel in MVVM-S pattern, uses @Observable for state management
// USAGE: Created by TgramViewerGame with GameDelegate, loads JSON and converts to display pieces

import SwiftUI
import Observation

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
    }
    
    var pieces: [DisplayPiece] = []
    var isLoading = false
    var errorMessage: String?
    var canvasSize: CGSize = CGSize(width: 600, height: 600)
    
    // MARK: - CV Data Structure
    
    struct CVData: Codable {
        let homography: [[Double]]
        let scale: Double
        let objects: [CVObject]
    }
    
    struct CVObject: Codable {
        let name: String
        let class_id: Int
        let pose: CVPose
        let vertices: [[Double]]
    }
    
    struct CVPose: Codable {
        let rotation_degrees: Double
        let translation: [Double]
    }
    
    // MARK: - Dependencies
    
    private weak var delegate: GameDelegate?
    
    // MARK: - File Cycling State
    
    private let fileIndexRange = 1...9
    var currentFileIndex: Int = 9
    private var currentFileBaseName: String { String(format: "%012d_plane_coords", currentFileIndex) }
    
    // MARK: - Initialization
    
    init(delegate: GameDelegate) {
        self.delegate = delegate
        // Data will be loaded by the view when the canvas size is available.
    }
    
    // MARK: - Data Loading
    
    func loadCVData() {
        isLoading = true
        errorMessage = nil
        
        // Load from bundle resources
        guard let url = Bundle.main.url(forResource: currentFileBaseName, withExtension: "json", subdirectory: "cv-output-cat") else {
            // Try without subdirectory if the above fails
            guard let fallbackUrl = Bundle.main.url(forResource: currentFileBaseName, withExtension: "json") else {
                errorMessage = "Could not find CV data file: \(currentFileBaseName).json"
                isLoading = false
                return
            }
            // Use the fallback URL
            do {
                let data = try Data(contentsOf: fallbackUrl)
                let cvData = try JSONDecoder().decode(CVData.self, from: data)
                processCVData(cvData)
            } catch {
                errorMessage = "Failed to load CV data: \(error.localizedDescription)"
                print("Error loading CV data: \(error)")
            }
            isLoading = false
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let cvData = try JSONDecoder().decode(CVData.self, from: data)
            processCVData(cvData)
        } catch {
            errorMessage = "Failed to load CV data: \(error.localizedDescription)"
            print("Error loading CV data: \(error)")
        }
        
        isLoading = false
    }
    
    func updateCanvasSize(to newSize: CGSize) {
        // Only reload if the size has meaningfully changed to avoid unnecessary processing.
        guard self.canvasSize != newSize, newSize != .zero else { return }

        self.canvasSize = newSize
        print("Canvas size updated to: \(newSize). Reloading CV data.")
        loadCVData()
    }
    
    // MARK: - Data Processing
    
    private func processCVData(_ cvData: CVData) {
        guard !cvData.objects.isEmpty, canvasSize.width > 0, canvasSize.height > 0 else {
            pieces = []
            return
        }

        // Step 1: Calculate the bounding box from vertices ONLY.
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for obj in cvData.objects {
            for vertex in obj.vertices {
                let x = CGFloat(vertex[0])
                let y = CGFloat(vertex[1])
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        // Step 2: Calculate world dimensions and aspect-fit scale.
        let worldWidth = maxX - minX
        let worldHeight = maxY - minY
        
        guard worldWidth > 0, worldHeight > 0 else {
            pieces = []
            return
        }
        
        // Use 90% of canvas for padding.
        let fittingSize = CGSize(width: canvasSize.width * 0.9, height: canvasSize.height * 0.9)
        let scale = min(fittingSize.width / worldWidth, fittingSize.height / worldHeight)

        // Step 3: Use a simplified transformation based on centering the world box.
        let worldCenterX = minX + worldWidth / 2
        let worldCenterY = minY + worldHeight / 2
        let canvasCenterX = canvasSize.width / 2
        let canvasCenterY = canvasSize.height / 2
        
        let transformPoint = { (point: [Double]) -> CGPoint in
            let jsonX = CGFloat(point[0])
            let jsonY = CGFloat(point[1])
            
            // Center the world point at (0,0), scale it, then move to canvas center.
            let x = (jsonX - worldCenterX) * scale + canvasCenterX
            let y = (jsonY - worldCenterY) * scale + canvasCenterY
            
            return CGPoint(x: x, y: y)
        }

        var processedPieces: [DisplayPiece] = []
        for (index, obj) in cvData.objects.enumerated() {
            guard let pieceType = mapClassIdToPieceType(obj.class_id) else { continue }

            // 1. Transform vertices to absolute screen coordinates.
            let screenVertices = obj.vertices.map(transformPoint)
            
            // 2. Calculate the piece's geometric center on the screen.
            guard !screenVertices.isEmpty else { continue }
            let sum = screenVertices.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            let screenCentroid = CGPoint(x: sum.x / CGFloat(screenVertices.count), y: sum.y / CGFloat(screenVertices.count))

            // 3. Create the display piece. Rotation is 0 because the vertices are already oriented.
            //    The vertices are now absolute screen coordinates.
            let piece = DisplayPiece(
                id: "\(pieceType.rawValue)_\(index)",
                pieceType: pieceType,
                position: screenCentroid,
                rotation: 0,
                vertices: screenVertices,
                color: pieceType.color
            )
            
            processedPieces.append(piece)
        }
        
        self.pieces = processedPieces
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
    
    /// Reloads the CV data using the current canvas size.
    func reset() {
        loadCVData()
    }
    
    func quit() {
        delegate?.gameDidRequestQuit()
    }
    
    /// Cycles to the next available CV data file and reloads the view.
    func cycleToNextFile() {
        if let first = fileIndexRange.first, let last = fileIndexRange.last {
            currentFileIndex = (currentFileIndex >= last) ? first : (currentFileIndex + 1)
        }
        loadCVData()
    }
}

// MARK: - Piece Color Extension
