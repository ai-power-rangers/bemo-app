//
//  PuzzlePersistenceService.swift
//  Bemo
//
//  Service for saving and loading tangram puzzles with Supabase cloud sync and local caching
//

import Foundation
import SwiftUI
import OSLog

class PuzzlePersistenceService {
    
    private let documentsDirectory: URL
    private let puzzlesDirectory: URL
    private let thumbnailsDirectory: URL
    // Using shared PuzzleThumbnailService instead of local ThumbnailGenerator
    private let supabaseService: SupabaseService?
    
    // Cache management
    private var officialPuzzlesCache: [TangramPuzzle] = []
    private var lastSyncDate: Date?
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour
    
    init(supabaseService: SupabaseService? = nil) {
        self.supabaseService = supabaseService
        Logger.tangramEditorPersistence.info("Initialized with SupabaseService: \(supabaseService != nil ? "available" : "not available")")
        
        // Get documents directory
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, 
                                                      in: .userDomainMask)[0]
        puzzlesDirectory = documentsDirectory.appendingPathComponent("TangramPuzzles")
        thumbnailsDirectory = puzzlesDirectory.appendingPathComponent("thumbnails")
        
        // Create directories if needed
        createDirectoriesIfNeeded()
        
        // Load official puzzles from cloud on init
        Task { [weak self] in
            await self?.syncOfficialPuzzles()
        }
    }
    
    private func createDirectoriesIfNeeded() {
        try? FileManager.default.createDirectory(at: puzzlesDirectory, 
                                                 withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thumbnailsDirectory, 
                                                 withIntermediateDirectories: true)
    }
    
    // MARK: - Public Methods
    
    /// Save puzzle with cloud sync (all puzzles are official)
    func savePuzzle(_ puzzle: TangramPuzzle) async throws -> TangramPuzzle {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        var updatedPuzzle = puzzle
        
        // Generate and save thumbnail using shared service
        if let thumbnailData = await generateThumbnailData(for: puzzle) {
            try saveThumbnail(thumbnailData, for: puzzle.id)
            updatedPuzzle.thumbnailData = thumbnailData
        }
        
        // Save puzzle to file
        let data = try encoder.encode(updatedPuzzle)
        let fileURL = puzzlesDirectory.appendingPathComponent("puzzle_\(updatedPuzzle.id).json")
        try data.write(to: fileURL)
        
        // Update local index
        try await updatePuzzleIndex(updatedPuzzle)
        
        // Sync to Supabase - all editor puzzles are official
        if let supabase = supabaseService {
            Logger.tangramEditor.debug("[PuzzlePersistenceService] Syncing puzzle to Supabase - ID: \(updatedPuzzle.id), Name: \(updatedPuzzle.name)")
            do {
                // Convert to DTO and save to cloud
                let dto = try TangramPuzzleDTO(from: updatedPuzzle)
                try await supabase.saveTangramPuzzle(dto)
                
                // Upload thumbnail if available
                if let thumbnailData = updatedPuzzle.thumbnailData {
                    let thumbnailURL = try await supabase.uploadTangramThumbnail(
                        puzzleId: updatedPuzzle.id,
                        thumbnailData: thumbnailData
                    )
                    Logger.tangramEditorPersistence.debug("Thumbnail uploaded to: \(thumbnailURL)")
                }
                
                Logger.tangramEditorPersistence.info("Puzzle successfully synced to cloud: \(updatedPuzzle.id)")
            } catch {
                // Log but don't fail - local save succeeded
                Logger.tangramEditorPersistence.error("Failed to sync puzzle to cloud: \(error.localizedDescription)")
                // Continue with local-only save
            }
        } else {
            Logger.tangramEditorPersistence.warning("No Supabase service available - saving locally only")
        }
        
        return updatedPuzzle
    }
    
    func loadPuzzle(id: String) async throws -> TangramPuzzle {
        let fileURL = puzzlesDirectory.appendingPathComponent("puzzle_\(id).json")
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode(TangramPuzzle.self, from: data)
    }
    
    func deletePuzzle(id: String) async throws {
        // Delete from local storage first
        let fileURL = puzzlesDirectory.appendingPathComponent("puzzle_\(id).json")
        try FileManager.default.removeItem(at: fileURL)
        
        let thumbURL = thumbnailsDirectory.appendingPathComponent("thumb_\(id).png")
        try? FileManager.default.removeItem(at: thumbURL)
        
        try await removeFromIndex(id: id)
        
        // Also delete from Supabase if available
        if let supabase = supabaseService {
            do {
                try await supabase.deleteTangramPuzzle(puzzleId: id)
                Logger.tangramEditor.info("Puzzle deleted from Supabase: \(id)")
            } catch {
                // Log but don't fail - local delete succeeded
                Logger.tangramEditor.error("Failed to delete puzzle from cloud: \(error.localizedDescription)")
            }
        }
    }
    
    func listPuzzles() async throws -> [PuzzleMetadata] {
        let indexURL = puzzlesDirectory.appendingPathComponent("puzzles.index")
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: indexURL)
        return try JSONDecoder().decode([PuzzleMetadata].self, from: data)
    }
    
    func puzzleExists(id: String) -> Bool {
        let fileURL = puzzlesDirectory.appendingPathComponent("puzzle_\(id).json")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    // MARK: - Private Methods
    
    private func updatePuzzleIndex(_ puzzle: TangramPuzzle) async throws {
        var index = (try? await listPuzzles()) ?? []
        
        let metadata = PuzzleMetadata(
            id: puzzle.id,
            name: puzzle.name,
            category: puzzle.category,
            difficulty: puzzle.difficulty,
            createdDate: puzzle.createdDate,
            modifiedDate: puzzle.modifiedDate,
            pieceCount: puzzle.pieces.count
        )
        
        // Update or append
        if let existingIndex = index.firstIndex(where: { $0.id == puzzle.id }) {
            index[existingIndex] = metadata
        } else {
            index.append(metadata)
        }
        
        // Save index
        let indexURL = puzzlesDirectory.appendingPathComponent("puzzles.index")
        let data = try JSONEncoder().encode(index)
        try data.write(to: indexURL)
    }
    
    private func removeFromIndex(id: String) async throws {
        var index = (try? await listPuzzles()) ?? []
        index.removeAll { $0.id == id }
        
        let indexURL = puzzlesDirectory.appendingPathComponent("puzzles.index")
        let data = try JSONEncoder().encode(index)
        try data.write(to: indexURL)
    }
    
    func loadAllPuzzles() async throws -> [TangramPuzzle] {
        let puzzles = try await listPuzzles()
        var loadedPuzzles: [TangramPuzzle] = []
        
        for metadata in puzzles {
            if let puzzle = try? await loadPuzzle(id: metadata.id) {
                loadedPuzzles.append(puzzle)
            }
        }
        
        return loadedPuzzles
    }
    
    // MARK: - Thumbnail Support
    
    func saveThumbnail(_ data: Data, for puzzleId: String) throws {
        let thumbURL = thumbnailsDirectory.appendingPathComponent("thumb_\(puzzleId).png")
        try data.write(to: thumbURL)
    }
    
    func loadThumbnail(for puzzleId: String) -> Data? {
        let thumbURL = thumbnailsDirectory.appendingPathComponent("thumb_\(puzzleId).png")
        return try? Data(contentsOf: thumbURL)
    }
    
    // MARK: - Thumbnail Generation
    
    /// Generate thumbnail data using direct rendering (shared service requires GamePuzzleData)
    private func generateThumbnailData(for puzzle: TangramPuzzle, size: CGSize = CGSize(width: 200, height: 200)) async -> Data? {
        return await MainActor.run {
            // Create thumbnail view directly
            let puzzleView = EditorThumbnailView(puzzle: puzzle)
                .frame(width: size.width, height: size.height)
                .background(Color.white)
            
            // Render to image using ImageRenderer
            let renderer = ImageRenderer(content: puzzleView)
            renderer.scale = 2.0 // Retina quality
            
            guard let uiImage = renderer.uiImage else { return nil }
            return uiImage.pngData()
        }
    }
    
    // MARK: - Supabase Sync
    
    /// Sync official puzzles from Supabase to local cache
    func syncOfficialPuzzles() async {
        guard let supabase = supabaseService else {
            Logger.tangramEditor.debug("No Supabase service available - using local cache only")
            return
        }
        
        // Check if cache is still valid
        if let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < cacheExpirationInterval,
           !officialPuzzlesCache.isEmpty {
            Logger.tangramEditor.debug("Using cached official puzzles (last sync: \(lastSync))")
            return
        }
        
        do {
            // Fetch official puzzles from Supabase
            let puzzleDTOs = try await supabase.fetchOfficialTangramPuzzles()
            Logger.tangramEditor.info("Fetched \(puzzleDTOs.count) official puzzles from Supabase")
            
            // Convert DTOs to puzzle models and cache locally
            var syncedPuzzles: [TangramPuzzle] = []
            for dto in puzzleDTOs {
                do {
                    let puzzle = try dto.toTangramPuzzle()
                    
                    // Cache puzzle locally
                    _ = try await savePuzzleLocally(puzzle)
                    
                    // Download and cache thumbnail if available
                    if dto.thumbnail_path != nil {
                        do {
                            let thumbnailData = try await supabase.downloadTangramThumbnail(puzzleId: puzzle.id)
                            try saveThumbnail(thumbnailData, for: puzzle.id)
                        } catch {
                            Logger.tangramEditor.error("Failed to download thumbnail for \(puzzle.id): \(error.localizedDescription)")
                        }
                    }
                    
                    syncedPuzzles.append(puzzle)
                } catch {
                    Logger.tangramEditor.error("Failed to convert puzzle DTO \(dto.puzzle_id): \(error.localizedDescription)")
                }
            }
            
            // Update cache
            officialPuzzlesCache = syncedPuzzles
            lastSyncDate = Date()
            
            Logger.tangramEditor.info("Successfully synced \(syncedPuzzles.count) official puzzles")
            
        } catch {
            Logger.tangramEditor.error("Failed to sync official puzzles from Supabase: \(error.localizedDescription)")
            // Fall back to local cache
            officialPuzzlesCache = (try? await loadAllLocalPuzzles()) ?? []
        }
    }
    
    /// Load official puzzles (from cache or Supabase)
    func loadOfficialPuzzles() async throws -> [TangramPuzzle] {
        // Try to sync from Supabase first
        await syncOfficialPuzzles()
        
        // Return cached puzzles
        if !officialPuzzlesCache.isEmpty {
            return officialPuzzlesCache
        }
        
        // Fall back to local storage
        return try await loadAllLocalPuzzles()
    }
    
    /// Save puzzle locally without cloud sync
    private func savePuzzleLocally(_ puzzle: TangramPuzzle) async throws -> TangramPuzzle {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        var updatedPuzzle = puzzle
        
        // Generate and save thumbnail locally
        if updatedPuzzle.thumbnailData == nil {
            if let thumbnailData = await generateThumbnailData(for: puzzle) {
                try saveThumbnail(thumbnailData, for: puzzle.id)
                updatedPuzzle.thumbnailData = thumbnailData
            }
        }
        
        // Save puzzle to file
        let data = try encoder.encode(updatedPuzzle)
        let fileURL = puzzlesDirectory.appendingPathComponent("puzzle_\(updatedPuzzle.id).json")
        try data.write(to: fileURL)
        
        // Update local index
        try await updatePuzzleIndex(updatedPuzzle)
        
        return updatedPuzzle
    }
    
    /// Load all puzzles from local storage only
    private func loadAllLocalPuzzles() async throws -> [TangramPuzzle] {
        let puzzles = try await listPuzzles()
        var loadedPuzzles: [TangramPuzzle] = []
        
        for metadata in puzzles {
            if let puzzle = try? await loadPuzzle(id: metadata.id) {
                loadedPuzzles.append(puzzle)
            }
        }
        
        return loadedPuzzles
    }
    
    func getAllPuzzles() async throws -> [TangramPuzzle] {
        // Load official puzzles (with Supabase sync)
        return try await loadOfficialPuzzles()
    }
    
    // All puzzles are official - no need to filter by source
}

// MARK: - Supporting Types

// PuzzleMetadata moved to Models/TangramPuzzleData.swift

// MARK: - Editor Thumbnail View

/// Simple thumbnail view for TangramPuzzle that doesn't require GamePuzzleData conversion
private struct EditorThumbnailView: View {
    let puzzle: TangramPuzzle
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(puzzle.pieces) { piece in
                    EditorPieceShape(piece: piece, puzzleBounds: calculatePuzzleBounds())
                        .fill(piece.type.color.opacity(0.8))
                        .overlay(
                            EditorPieceShape(piece: piece, puzzleBounds: calculatePuzzleBounds())
                                .stroke(Color.black, lineWidth: 0.5)
                        )
                }
            }
            .scaleEffect(calculateScale(for: geometry.size))
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
    
    func calculatePuzzleBounds() -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for piece in puzzle.pieces {
            let vertices = TangramGeometry.vertices(for: piece.type)
            let scaledVertices = vertices.map { 
                CGPoint(x: $0.x * TangramConstants.visualScale, 
                        y: $0.y * TangramConstants.visualScale)
            }
            let transformed = scaledVertices.map { $0.applying(piece.transform) }
            
            for vertex in transformed {
                minX = min(minX, vertex.x)
                minY = min(minY, vertex.y)
                maxX = max(maxX, vertex.x)
                maxY = max(maxY, vertex.y)
            }
        }
        
        guard minX < CGFloat.greatestFiniteMagnitude else {
            return .zero
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    func calculateScale(for size: CGSize) -> CGFloat {
        let bounds = calculatePuzzleBounds()
        guard bounds.width > 0 && bounds.height > 0 else { return 1.0 }
        
        return min(
            size.width / bounds.width * 0.8,
            size.height / bounds.height * 0.8
        )
    }
}

private struct EditorPieceShape: Shape {
    let piece: TangramPiece
    let puzzleBounds: CGRect
    
    func path(in rect: CGRect) -> Path {
        let vertices = TangramGeometry.vertices(for: piece.type)
        let scaledVertices = vertices.map { 
            CGPoint(x: $0.x * TangramConstants.visualScale, 
                    y: $0.y * TangramConstants.visualScale)
        }
        let transformed = scaledVertices.map { $0.applying(piece.transform) }
        
        var path = Path()
        
        if let first = transformed.first {
            let normalizedFirst = normalizePoint(first, in: rect)
            path.move(to: normalizedFirst)
            
            for vertex in transformed.dropFirst() {
                let normalizedVertex = normalizePoint(vertex, in: rect)
                path.addLine(to: normalizedVertex)
            }
            path.closeSubpath()
        }
        
        return path
    }
    
    func normalizePoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        guard puzzleBounds.width > 0 && puzzleBounds.height > 0 else {
            return CGPoint(x: rect.midX, y: rect.midY)
        }
        
        let normalizedX = (point.x - puzzleBounds.minX) / puzzleBounds.width
        let normalizedY = (point.y - puzzleBounds.minY) / puzzleBounds.height
        
        return CGPoint(
            x: normalizedX * rect.width,
            y: normalizedY * rect.height
        )
    }
}