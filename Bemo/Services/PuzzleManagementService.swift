//
//  PuzzleManagementService.swift
//  Bemo
//
//  Centralized puzzle caching and management service for all games
//

// WHAT: App-level service that caches puzzles from database, provides fast access to all games
// ARCHITECTURE: Service in MVVM-S pattern, manages puzzle data caching with 1-hour expiration
// USAGE: Injected via DependencyContainer, preloaded on app launch, used by all puzzle-based games

import Foundation
import Observation

@Observable
class PuzzleManagementService {
    // MARK: - Properties
    
    // Cache storage for different puzzle types
    private var tangramPuzzlesCache: [GamePuzzleData] = []
    // Future: Add caches for other puzzle types as needed
    
    // Cache metadata
    private var lastTangramSyncDate: Date?
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour
    
    // Services
    private let supabaseService: SupabaseService?
    private let errorTracking: ErrorTrackingService?
    
    // Local storage paths
    private let documentsDirectory: URL
    private let puzzlesDirectory: URL
    
    // Loading states
    var isSyncingTangrams = false
    var tangramSyncError: String?
    
    // MARK: - Initialization
    
    init(supabaseService: SupabaseService?, errorTracking: ErrorTrackingService?) {
        self.supabaseService = supabaseService
        self.errorTracking = errorTracking
        
        // Setup local storage directories
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        puzzlesDirectory = documentsDirectory.appendingPathComponent("CachedPuzzles")
        
        // Create directories if they don't exist
        try? FileManager.default.createDirectory(at: puzzlesDirectory, withIntermediateDirectories: true)
        
        // Load any existing local cache
        loadLocalCache()
    }
    
    // MARK: - Public Methods
    
    /// Preload all puzzle types on app launch
    func preloadAllPuzzles() async {
        print("[PuzzleManagement] Starting puzzle preload...")
        await syncTangramPuzzles()
        // Future: Add other puzzle types here
        print("[PuzzleManagement] Puzzle preload complete")
    }
    
    /// Get cached Tangram puzzles (for game use)
    func getTangramPuzzles() async -> [GamePuzzleData] {
        // Check if cache needs refresh
        if shouldRefreshTangramCache() {
            print("[PuzzleManagement] Cache expired, refreshing from database...")
            await syncTangramPuzzles()
        } else {
            print("[PuzzleManagement] Using cached puzzles: \(tangramPuzzlesCache.count) puzzles")
        }
        return tangramPuzzlesCache
    }
    
    /// Force refresh of Tangram puzzles
    func refreshTangramPuzzles() async {
        await syncTangramPuzzles()
    }
    
    // MARK: - Private Methods
    
    private func shouldRefreshTangramCache() -> Bool {
        guard let lastSync = lastTangramSyncDate else { return true }
        return Date().timeIntervalSince(lastSync) > cacheExpirationInterval
    }
    
    private func syncTangramPuzzles() async {
        guard let supabase = supabaseService else {
            print("[PuzzleManagement] No Supabase service available - using local cache only")
            return
        }
        
        // Check if already syncing
        guard !isSyncingTangrams else {
            print("[PuzzleManagement] Already syncing Tangram puzzles, skipping")
            return
        }
        
        await MainActor.run {
            isSyncingTangrams = true
            tangramSyncError = nil
        }
        
        do {
            // Use TangramDatabaseLoader to fetch and convert puzzles
            let loader = TangramDatabaseLoader(supabaseService: supabase)
            let puzzles = try await loader.loadOfficialPuzzles()
            
            print("[PuzzleManagement] Fetched \(puzzles.count) Tangram puzzles from database")
            
            // Cache locally
            await savePuzzlesToLocalCache(puzzles, type: "tangram")
            
            // Update memory cache
            await MainActor.run {
                self.tangramPuzzlesCache = puzzles
                self.lastTangramSyncDate = Date()
                self.isSyncingTangrams = false
            }
            
        } catch {
            print("[PuzzleManagement] Failed to sync Tangram puzzles: \(error)")
            errorTracking?.trackError(error, context: ErrorContext(
                feature: "PuzzleManagement",
                action: "syncTangramPuzzles"
            ))
            
            await MainActor.run {
                self.tangramSyncError = error.localizedDescription
                self.isSyncingTangrams = false
            }
            
            // Fall back to local cache
            loadTangramPuzzlesFromLocalCache()
        }
    }
    
    private func savePuzzlesToLocalCache(_ puzzles: [GamePuzzleData], type: String) async {
        let cacheFile = puzzlesDirectory.appendingPathComponent("\(type)_puzzles.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(puzzles)
            try data.write(to: cacheFile)
            
            // Also save sync metadata
            let metadataFile = puzzlesDirectory.appendingPathComponent("\(type)_metadata.json")
            let metadata = CacheMetadata(lastSync: Date(), puzzleCount: puzzles.count)
            let metadataData = try encoder.encode(metadata)
            try metadataData.write(to: metadataFile)
            
            print("[PuzzleManagement] Saved \(puzzles.count) \(type) puzzles to local cache")
        } catch {
            print("[PuzzleManagement] Failed to save puzzles to local cache: \(error)")
        }
    }
    
    private func loadLocalCache() {
        loadTangramPuzzlesFromLocalCache()
        // Future: Load other puzzle types
    }
    
    private func loadTangramPuzzlesFromLocalCache() {
        let cacheFile = puzzlesDirectory.appendingPathComponent("tangram_puzzles.json")
        let metadataFile = puzzlesDirectory.appendingPathComponent("tangram_metadata.json")
        
        do {
            // Load metadata first
            if let metadataData = try? Data(contentsOf: metadataFile) {
                let metadata = try JSONDecoder().decode(CacheMetadata.self, from: metadataData)
                lastTangramSyncDate = metadata.lastSync
            }
            
            // Load puzzles
            let data = try Data(contentsOf: cacheFile)
            let puzzles = try JSONDecoder().decode([GamePuzzleData].self, from: data)
            tangramPuzzlesCache = puzzles
            
            print("[PuzzleManagement] Loaded \(puzzles.count) Tangram puzzles from local cache")
        } catch {
            print("[PuzzleManagement] No local cache available or failed to load: \(error)")
            tangramPuzzlesCache = []
        }
    }
    
    // MARK: - Cache Management
    
    /// Clear all cached puzzles
    func clearAllCaches() {
        tangramPuzzlesCache.removeAll()
        lastTangramSyncDate = nil
        
        // Remove local files
        try? FileManager.default.removeItem(at: puzzlesDirectory)
        try? FileManager.default.createDirectory(at: puzzlesDirectory, withIntermediateDirectories: true)
        
        print("[PuzzleManagement] All caches cleared")
    }
    
    /// Invalidate Tangram cache to force refresh from database
    /// Call this when puzzles are modified in the editor or deleted from database
    func invalidateTangramCache() {
        tangramPuzzlesCache.removeAll()
        lastTangramSyncDate = nil
        
        // Remove local tangram cache files
        let tangramCacheFile = puzzlesDirectory.appendingPathComponent("tangram_puzzles.json")
        let tangramMetadataFile = puzzlesDirectory.appendingPathComponent("tangram_metadata.json")
        try? FileManager.default.removeItem(at: tangramCacheFile)
        try? FileManager.default.removeItem(at: tangramMetadataFile)
        
        print("[PuzzleManagement] Tangram cache invalidated - will refresh on next access")
    }
    
    /// Force immediate refresh of Tangram puzzles from database
    /// Use after saving/deleting puzzles in editor
    func forceRefreshTangramPuzzles() async {
        invalidateTangramCache()
        await syncTangramPuzzles()
    }
    
    /// Update a single puzzle in the cache without full refresh
    /// More efficient for single puzzle edits
    func updateSinglePuzzle(_ puzzleId: String) async {
        print("[PuzzleManagement] updateSinglePuzzle called for: \(puzzleId)")
        guard let supabase = supabaseService else { 
            print("[PuzzleManagement] No Supabase service - cannot update puzzle")
            return 
        }
        
        do {
            // Load just this puzzle from database
            let loader = TangramDatabaseLoader(supabaseService: supabase)
            if let updatedPuzzle = try await loader.loadPuzzle(id: puzzleId) {
                print("[PuzzleManagement] Loaded updated puzzle from database: \(updatedPuzzle.name)")
                // Update in cache
                await MainActor.run {
                    // Remove old version if exists
                    let oldCount = tangramPuzzlesCache.count
                    tangramPuzzlesCache.removeAll { $0.id == puzzleId }
                    // Add updated version
                    tangramPuzzlesCache.append(updatedPuzzle)
                    print("[PuzzleManagement] Cache updated: \(oldCount) -> \(tangramPuzzlesCache.count) puzzles")
                    // Update local cache file
                    Task {
                        await savePuzzlesToLocalCache(tangramPuzzlesCache, type: "tangram")
                    }
                }
                print("[PuzzleManagement] Successfully updated single puzzle in cache: \(updatedPuzzle.name)")
            } else {
                print("[PuzzleManagement] Warning: Puzzle not found in database: \(puzzleId)")
            }
        } catch {
            print("[PuzzleManagement] Failed to update single puzzle: \(error)")
            // Fall back to full refresh if single update fails
            await forceRefreshTangramPuzzles()
        }
    }
    
    /// Add a new puzzle to the cache without full refresh
    func addNewPuzzle(_ puzzleId: String) async {
        print("[PuzzleManagement] addNewPuzzle called for: \(puzzleId)")
        guard let supabase = supabaseService else { 
            print("[PuzzleManagement] No Supabase service - cannot add puzzle")
            return 
        }
        
        do {
            // Load the new puzzle from database
            let loader = TangramDatabaseLoader(supabaseService: supabase)
            if let newPuzzle = try await loader.loadPuzzle(id: puzzleId) {
                print("[PuzzleManagement] Loaded new puzzle from database: \(newPuzzle.name)")
                // Add to cache
                await MainActor.run {
                    // Check if already exists (shouldn't happen for new)
                    if !tangramPuzzlesCache.contains(where: { $0.id == puzzleId }) {
                        tangramPuzzlesCache.append(newPuzzle)
                        print("[PuzzleManagement] Added puzzle to cache. Total puzzles: \(tangramPuzzlesCache.count)")
                        // Update local cache file
                        Task {
                            await savePuzzlesToLocalCache(tangramPuzzlesCache, type: "tangram")
                        }
                    } else {
                        print("[PuzzleManagement] Warning: Puzzle already exists in cache: \(puzzleId)")
                    }
                }
                print("[PuzzleManagement] Successfully added new puzzle to cache: \(newPuzzle.name)")
            } else {
                print("[PuzzleManagement] Warning: New puzzle not found in database: \(puzzleId)")
            }
        } catch {
            print("[PuzzleManagement] Failed to add new puzzle: \(error)")
            // Fall back to full refresh if add fails
            await forceRefreshTangramPuzzles()
        }
    }
    
    /// Remove a puzzle from the cache without full refresh
    func removePuzzle(_ puzzleId: String) async {
        await MainActor.run {
            tangramPuzzlesCache.removeAll { $0.id == puzzleId }
            // Update local cache file
            Task {
                await savePuzzlesToLocalCache(tangramPuzzlesCache, type: "tangram")
            }
        }
        print("[PuzzleManagement] Removed puzzle from cache: \(puzzleId)")
    }
    
    /// Get cache status information
    func getCacheStatus() -> CacheStatus {
        return CacheStatus(
            tangramPuzzleCount: tangramPuzzlesCache.count,
            lastTangramSync: lastTangramSyncDate,
            isSyncingTangrams: isSyncingTangrams,
            cacheDirectory: puzzlesDirectory
        )
    }
}

// MARK: - Supporting Types

private struct CacheMetadata: Codable {
    let lastSync: Date
    let puzzleCount: Int
}

struct CacheStatus {
    let tangramPuzzleCount: Int
    let lastTangramSync: Date?
    let isSyncingTangrams: Bool
    let cacheDirectory: URL
}

// Note: TangramDatabaseLoader is already defined in 
// Bemo/Features/Game/Games/Tangram/Services/TangramDatabaseLoader.swift
// We'll use it directly without redeclaring