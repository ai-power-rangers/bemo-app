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
import CoreGraphics

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
        let validation: PlacedPiece.ValidationState
    }
    
    var pieces: [DisplayPiece] = []
    var isLoading = false
    var errorMessage: String?
    var canvasSize: CGSize = CGSize(width: 600, height: 600)
    var statusText: String?
    var targetOutlines: [[CGPoint]] = []
    
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
    private let container: TangramDependencyContainer
    private let initialPuzzleId: String
    private var selectedPuzzle: GamePuzzleData?
    private var pieceAssignments: [String: String] = [:]
    private var cvGroupId = UUID()
    private let tolerantValidator: TangramPieceValidator
    private var anchorInfo: (id: String, posSK: CGPoint, rotSK: CGFloat, isFlipped: Bool, type: TangramPieceType, index: Int)?
    
    // MARK: - File Cycling State
    
    private let fileIndexRange = 1...9
    var currentFileIndex: Int = 9
    private var currentFileBaseName: String { String(format: "%012d_plane_coords", currentFileIndex) }
    
    // MARK: - Initialization
    
    init(delegate: GameDelegate, container: TangramDependencyContainer, initialPuzzleId: String) {
        self.delegate = delegate
        self.container = container
        self.initialPuzzleId = initialPuzzleId
        self.tolerantValidator = TangramPieceValidator(
            positionTolerance: 120,
            rotationTolerance: 45
        )
        // Data will be loaded by the view when the canvas size is available.
    }

    convenience init(delegate: GameDelegate) {
        self.init(
            delegate: delegate,
            container: TangramDependencyContainer(),
            initialPuzzleId: "puzzle_26D26F42-0D65-4D85-9405-15E9CFBA3098"
        )
    }
    
    // MARK: - Data Loading
    
    func loadCVData() {
        isLoading = true
        errorMessage = nil
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Ensure puzzle is loaded first
            if self.selectedPuzzle == nil {
                await self.loadPuzzleById(self.initialPuzzleId)
            }
            
            // If still no puzzle, bail
            guard self.selectedPuzzle != nil else {
                self.errorMessage = "Failed to load puzzle: \(self.initialPuzzleId)"
                self.isLoading = false
                return
            }
            
            // Load from bundle resources
            let dataURL: URL?
            if let url = Bundle.main.url(forResource: self.currentFileBaseName, withExtension: "json", subdirectory: "cv-output-cat") {
                dataURL = url
            } else {
                dataURL = Bundle.main.url(forResource: self.currentFileBaseName, withExtension: "json")
            }
            
            guard let dataURL else {
                self.errorMessage = "Could not find CV data file: \(self.currentFileBaseName).json"
                self.isLoading = false
                return
            }
            
            do {
                let data = try Data(contentsOf: dataURL)
                let cvData = try JSONDecoder().decode(CVData.self, from: data)
                self.processCVData(cvData)
            } catch {
                self.errorMessage = "Failed to load CV data: \(error.localizedDescription)"
            }
            
            self.isLoading = false
        }
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

        // Unscale all CV object data upfront to work in a consistent coordinate space.
        let scaleFactor = cvData.scale
        guard scaleFactor != 0 else {
            self.errorMessage = "CV data has a scale of 0."
            self.isLoading = false
            return
        }

        let unscaledObjects = cvData.objects.map { obj -> CVObject in
            let unscaledVertices = obj.vertices.map { v in [v[0] / scaleFactor, v[1] / scaleFactor] }
            let unscaledTranslation = [obj.pose.translation[0] / scaleFactor, obj.pose.translation[1] / scaleFactor]
            let unscaledPose = CVPose(rotation_degrees: obj.pose.rotation_degrees, translation: unscaledTranslation)
            return CVObject(name: obj.name, class_id: obj.class_id, pose: unscaledPose, vertices: unscaledVertices)
        }

        // Step 1: Calculate the bounding box from UN-SCALED vertices ONLY for display scaling and scale estimation.
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for obj in unscaledObjects {
            for vertex in obj.vertices {
                let x = CGFloat(vertex[0])
                let y = CGFloat(vertex[1])
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        // Step 2: Calculate world dimensions and aspect-fit scale for display.
        let worldWidth = maxX - minX
        let worldHeight = maxY - minY
        
        guard worldWidth > 0, worldHeight > 0 else {
            pieces = []
            return
        }
        
        // Use 90% of canvas for display padding.
        let fittingSize = CGSize(width: canvasSize.width * 0.9, height: canvasSize.height * 0.9)
        let scale = min(fittingSize.width / worldWidth, fittingSize.height / worldHeight)

        // Step 3: Use a simplified transformation based on centering the world box for display.
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

        // Prepare display pieces and also run validation against selected puzzle (if available)
        var processedPieces: [DisplayPiece] = []
        let puzzle = selectedPuzzle

        // Choose an anchor in CV space for mapping if we have a puzzle
        anchorInfo = nil
        if let _ = puzzle {
            // Pick the largest or most central piece as anchor
            if let best = pickAnchor(from: unscaledObjects) {
                anchorInfo = best
            }
        }

        // Reset group for each new file to avoid stale assignments
        cvGroupId = UUID()

        // Establish mapping if possible
        var mapping: AnchorMapping? = nil
        var anchorTargetId: String?
        if let puzzle, let anchorInfo {
            // Preselect best anchor target using rotation-first, then distance
            let candidates: [(target: GamePuzzleData.TargetPiece, centroidScene: CGPoint, expectedZ: CGFloat, isFlipped: Bool, rotDiff: CGFloat, dist: CGFloat)] = puzzle.targetPieces
                .filter { $0.pieceType == anchorInfo.type }
                .map { t in
                    let verts = TangramBounds.computeSKTransformedVertices(for: t)
                    let centroid = CGPoint(x: verts.map { $0.x }.reduce(0, +) / CGFloat(verts.count), y: verts.map { $0.y }.reduce(0, +) / CGFloat(verts.count))
                    let rawAng = TangramPoseMapper.rawAngle(from: t.transform)
                    let expectedZ = TangramPoseMapper.spriteKitAngle(fromRawAngle: rawAng)
                    let det = t.transform.a * t.transform.d - t.transform.b * t.transform.c
                    // Normalize rotation difference to [-pi, pi]
                    var dRot = expectedZ - anchorInfo.rotSK
                    while dRot > .pi { dRot -= 2 * .pi }
                    while dRot < -.pi { dRot += 2 * .pi } // Corrected: this should be -= 2 * .pi
                    let dPos = hypot(anchorInfo.posSK.x - centroid.x, anchorInfo.posSK.y - centroid.y)
                    return (t, centroid, expectedZ, det < 0, abs(dRot), dPos)
                }
                .sorted { lhs, rhs in
                    if abs(lhs.rotDiff - rhs.rotDiff) > (.pi / 90) { // ~2 degrees priority on rotation
                        return lhs.rotDiff < rhs.rotDiff
                    }
                    return lhs.dist < rhs.dist
                }

            if let best = candidates.first {
                anchorTargetId = best.target.id
                mapping = container.mappingService.establishOrUpdateMapping(
                    groupId: cvGroupId,
                    groupPieceIds: Set(unscaledObjects.enumerated().map { "cv_\($0.offset)" }),
                    pickAnchor: { () -> (anchorPieceId: String, anchorPositionScene: CGPoint, anchorRotation: CGFloat, anchorIsFlipped: Bool, anchorPieceType: TangramPieceType) in
                        return (anchorInfo.id, anchorInfo.posSK, anchorInfo.rotSK, anchorInfo.isFlipped, anchorInfo.type)
                    },
                    candidateTargets: { () -> [(target: GamePuzzleData.TargetPiece, centroidScene: CGPoint, expectedZ: CGFloat, isFlipped: Bool)] in
                        return [(best.target, best.centroidScene, best.expectedZ, best.isFlipped)]
                    }
                )
            }
        }

        // Reset outlines for redraw
        self.targetOutlines = []

        // For each CV object, create display piece and validate if possible
        var correctCount = 0
        for (index, obj) in unscaledObjects.enumerated() {
            guard let pieceType = mapClassIdToPieceType(obj.class_id) else { continue }
            let screenVertices = obj.vertices.map(transformPoint)
            guard !screenVertices.isEmpty else { continue }
            let sum = screenVertices.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            let screenCentroid = CGPoint(x: sum.x / CGFloat(screenVertices.count), y: sum.y / CGFloat(screenVertices.count))

            // Default validation state
            var validation: PlacedPiece.ValidationState = .pending

            if let puzzle, let mapping, let anchorInfo {
                // Map this piece's pose into target space and validate
                let pieceId = "cv_\(index)"
                // Use centroid of raw vertices for position to be robust against pose origin differences
                let centroidRaw = obj.vertices.reduce(CGPoint.zero) { acc, v in
                    CGPoint(x: acc.x + CGFloat(v[0]), y: acc.y + CGFloat(v[1]))
                }.applying(CGAffineTransform(scaleX: 1.0 / CGFloat(max(obj.vertices.count, 1)), y: 1.0 / CGFloat(max(obj.vertices.count, 1))))
                let pieceSKPos = TangramPoseMapper.spriteKitPosition(fromRawPosition: centroidRaw)
                let rawAngleRad = CGFloat(obj.pose.rotation_degrees * .pi / 180.0)
                let pieceSKRot = TangramPoseMapper.spriteKitAngle(fromRawAngle: rawAngleRad)
                let pieceIsFlipped = false

                let mapped = container.mappingService.mapPieceToTargetSpace(
                    piecePositionScene: pieceSKPos,
                    pieceRotation: pieceSKRot,
                    pieceIsFlipped: pieceIsFlipped,
                    mapping: mapping,
                    anchorPositionScene: anchorInfo.posSK
                )

                // Validate against assigned target if exists, else find best valid unconsumed target
                if let assignedId = pieceAssignments[pieceId], let target = puzzle.targetPieces.first(where: { $0.id == assignedId }) {
                    let verts = TangramBounds.computeSKTransformedVertices(for: target)
                    let centroid = CGPoint(x: verts.map { $0.x }.reduce(0, +) / CGFloat(verts.count), y: verts.map { $0.y }.reduce(0, +) / CGFloat(verts.count))
                    let isValid = container.mappingService.validateMapped(
                        mappedPose: (mapped.positionSK, mapped.rotationSK, mapped.isFlipped),
                        pieceType: pieceType,
                        target: target,
                        targetCentroidScene: centroid,
                        validator: tolerantValidator
                    )
                    validation = isValid ? .correct : .incorrect
                    if isValid { container.mappingService.markTargetConsumed(groupId: cvGroupId, targetId: target.id) }
                } else {
                    var best: (id: String, dist: CGFloat)?
                    for t in puzzle.targetPieces where t.pieceType == pieceType && !container.mappingService.consumedTargets(groupId: cvGroupId).contains(t.id) {
                        let verts = TangramBounds.computeSKTransformedVertices(for: t)
                        let centroid = CGPoint(x: verts.map { $0.x }.reduce(0, +) / CGFloat(verts.count), y: verts.map { $0.y }.reduce(0, +) / CGFloat(verts.count))
                        let isValid = container.mappingService.validateMapped(
                            mappedPose: (mapped.positionSK, mapped.rotationSK, mapped.isFlipped),
                            pieceType: pieceType,
                            target: t,
                            targetCentroidScene: centroid,
                            validator: tolerantValidator
                        )
                        if isValid {
                            let d = hypot(mapped.positionSK.x - centroid.x, mapped.positionSK.y - centroid.y)
                            if best == nil || d < best!.dist { best = (t.id, d) }
                        }
                    }
                    if let best, let target = puzzle.targetPieces.first(where: { $0.id == best.id }) {
                        validation = .correct
                        pieceAssignments[pieceId] = target.id
                        container.mappingService.markTargetConsumed(groupId: cvGroupId, targetId: target.id)
                    } else {
                        validation = .incorrect
                    }
                }
            }

            if validation == .correct { correctCount += 1 }

            let piece = DisplayPiece(
                id: "\(pieceType.rawValue)_\(index)",
                pieceType: pieceType,
                position: screenCentroid,
                rotation: 0,
                vertices: screenVertices,
                color: pieceType.color,
                validation: validation
            )
            processedPieces.append(piece)
        }

        self.pieces = processedPieces
        if let puzzle, let mapping, let anchorInfo, let anchorTargetId {
            self.statusText = "Correct: \(correctCount) / \(puzzle.targetPieces.count)"
            // Build scaled, mapped outlines into display space
            let rawToDisplay: (CGPoint) -> CGPoint = { raw in
                let x = (raw.x - worldCenterX) * scale + canvasCenterX
                let y = (raw.y - worldCenterY) * scale + canvasCenterY
                return CGPoint(x: x, y: y)
            }

            var unalignedOutlines: [[CGPoint]] = []
            for target in puzzle.targetPieces {
                let vertsSK = TangramBounds.computeSKTransformedVertices(for: target)
                let mappedToCVRaw: [CGPoint] = vertsSK.map { v in
                    container.mappingService.inverseMapTargetToPhysical(
                        mapping: mapping,
                        anchorScenePos: anchorInfo.posSK,
                        targetScenePos: v
                    )
                }
                let displayVerts = mappedToCVRaw.map(rawToDisplay)
                unalignedOutlines.append(displayVerts)
            }

            // Correction logic: force anchor outline to align with anchor piece
            if let anchorTargetIndex = puzzle.targetPieces.firstIndex(where: { $0.id == anchorTargetId }),
               unalignedOutlines.indices.contains(anchorTargetIndex),
               self.pieces.indices.contains(anchorInfo.index)
            {
                let anchorPiece = self.pieces[anchorInfo.index]
                let anchorOutline = unalignedOutlines[anchorTargetIndex]

                guard !anchorOutline.isEmpty else {
                    self.targetOutlines = unalignedOutlines
                    return
                }

                let anchorOutlineCentroid = anchorOutline.reduce(CGPoint.zero) {
                    CGPoint(x: $0.x + $1.x, y: $0.y + $1.y)
                }.applying(CGAffineTransform(scaleX: 1.0 / CGFloat(anchorOutline.count), y: 1.0 / CGFloat(anchorOutline.count)))

                let correction = CGVector(dx: anchorPiece.position.x - anchorOutlineCentroid.x, dy: anchorPiece.position.y - anchorOutlineCentroid.y)

                self.targetOutlines = unalignedOutlines.map { outline in
                    outline.map { point in
                        CGPoint(x: point.x + correction.dx, y: point.y + correction.dy)
                    }
                }
            } else {
                self.targetOutlines = unalignedOutlines
            }

        } else {
            self.statusText = nil
            self.targetOutlines = []
        }
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


// MARK: - Private Helpers

extension TgramViewerViewModel {
    private func pickAnchor(from objects: [CVObject]) -> (id: String, posSK: CGPoint, rotSK: CGFloat, isFlipped: Bool, type: TangramPieceType, index: Int)? {
        // Prefer largest piece types: large triangles > medium > square/parallelogram > small
        let ranked = objects.enumerated().compactMap { (idx, obj) -> (idx: Int, type: TangramPieceType)? in
            guard let t = mapClassIdToPieceType(obj.class_id) else { return nil }
            return (idx, t)
        }.sorted { lhs, rhs in
            areaRank(for: lhs.type) > areaRank(for: rhs.type)
        }
        guard let first = ranked.first else { return nil }

        // Use centroid of vertices for position, for consistency with validation logic
        let anchorObject = objects[first.idx]
        let centroidRaw = anchorObject.vertices.reduce(CGPoint.zero) { acc, v in
            CGPoint(x: acc.x + CGFloat(v[0]), y: acc.y + CGFloat(v[1]))
        }.applying(CGAffineTransform(scaleX: 1.0 / CGFloat(max(anchorObject.vertices.count, 1)), y: 1.0 / CGFloat(max(anchorObject.vertices.count, 1))))
        let posSK = TangramPoseMapper.spriteKitPosition(fromRawPosition: centroidRaw)

        let rawAngleRad = CGFloat(anchorObject.pose.rotation_degrees * .pi / 180.0)
        let rotSK = TangramPoseMapper.spriteKitAngle(fromRawAngle: rawAngleRad)
        return (id: "cv_\(first.idx)", posSK: posSK, rotSK: rotSK, isFlipped: false, type: first.type, index: first.idx)
    }

    private func areaRank(for type: TangramPieceType) -> Double {
        switch type {
        case .largeTriangle1, .largeTriangle2: return 4.0
        case .mediumTriangle: return 2.0
        case .square, .parallelogram: return 2.0
        case .smallTriangle1, .smallTriangle2: return 1.0
        }
    }

    private func loadPuzzleById(_ id: String) async {
        // Try cache-first via PuzzleManagementService, else DB loader
        if let management = container.puzzleManagementService {
            let puzzles = await management.getTangramPuzzles()
            if let found = puzzles.first(where: { $0.id == id }) {
                await MainActor.run { self.selectedPuzzle = found }
                return
            }
        }
        // Fallback to direct DB
        if let puzzle = try? await container.databaseLoader.loadPuzzle(id: id) {
            await MainActor.run { self.selectedPuzzle = puzzle }
        }
    }
}
