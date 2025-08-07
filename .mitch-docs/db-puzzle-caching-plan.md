# Database Puzzle Data Quality & Caching Implementation Plan

## Executive Summary

This plan addresses two critical issues:
1. **Data Corruption**: The database contains corrupted puzzle data with boolean values in numeric fields
2. **No Caching**: Puzzles are loaded fresh from database every time, causing delays

The root cause is in `Bemo/Services/SupabaseService.swift` where `AnyCodable` incorrectly encodes numeric values as booleans.

## Current Architecture Analysis

### Data Flow
```
TangramEditor → TangramPuzzle → SupabaseService (AnyCodable) → Database
                                        ↓
                                  [CORRUPTION HERE]
                                        ↓
Database → TangramDatabaseLoader → PuzzleDataConverter → GamePuzzleData → TangramGame
```

### Existing Services

1. **TangramEditor Side**:
   - `PuzzlePersistenceService` (Has caching, but only used by editor)
   - Location: `Bemo/Features/Game/Games/TangramEditor/Services/PuzzlePersistenceService.swift`
   - Features: 1-hour cache, local storage, Supabase sync

2. **TangramGame Side**:
   - `TangramDatabaseLoader` (No caching, direct DB calls)
   - Location: `Bemo/Features/Game/Games/Tangram/Services/TangramDatabaseLoader.swift`
   - `PuzzleLibraryService` (Unused, has some caching logic)
   - Location: `Bemo/Features/Game/Games/Tangram/Services/PuzzleLibraryService.swift`

3. **App Level**:
   - `DependencyContainer` - Central service registry
   - Location: `Bemo/Core/DependencyContainer.swift`
   - `SupabaseService` - Database connection (contains the bug)
   - Location: `Bemo/Services/SupabaseService.swift`

## Data Corruption Issue

### Root Cause
In `Bemo/Services/SupabaseService.swift`, the `AnyCodable.encode()` method (lines 953-973):

```swift
func encode(to encoder: Encoder) throws {
    switch value {
    case let bool as Bool:      // Line 962 - Checked BEFORE numbers!
        try container.encode(bool)
    case let int as Int:         // Line 964
        try container.encode(int)
    case let double as Double:   // Line 966
        try container.encode(double)
```

**Problem**: Swift's type system allows numeric literals like `1` and `0` to match `Bool` type.
When encoding CGAffineTransform values:
- `transform.a = 1.0` becomes `"a": true`
- `transform.b = 0.0` becomes `"b": false`

### Evidence from cat.json
```json
"transform": {
  "a": true,      // Should be 1.0
  "b": false,     // Should be 0.0
  "c": false,     // Should be 0.0
  "d": true,      // Should be 1.0
  "tx": 239.177,
  "ty": 420.366
}
```

Also:
- `"zIndex": false` (should be `0`)
- `"isLocked": true` (field exists despite being removed from model)
- **Duplicate pieces**: Multiple pieces with same type and identical transforms (e.g., two `smallTriangle1` with same position)

## Implementation Plan

### Phase 1: Fix Data Corruption (Priority: CRITICAL)

#### 1.1 Fix AnyCodable Encoding Order
**File**: `Bemo/Services/SupabaseService.swift`
**Lines**: 953-973

```swift
func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch value {
    case let dict as [String: Any]:
        try container.encode(dict.mapValues { AnyCodable($0) })
    case let array as [Any]:
        try container.encode(array.map { AnyCodable($0) })
    case let string as String:
        try container.encode(string)
    case let double as Double:    // MOVE BEFORE BOOL
        try container.encode(double)
    case let float as Float:      // ADD FLOAT SUPPORT
        try container.encode(float)
    case let int as Int:          // MOVE BEFORE BOOL
        try container.encode(int)
    case let bool as Bool:        // MOVE TO LAST
        try container.encode(bool)
    case is NSNull:
        try container.encodeNil()
    default:
        throw EncodingError.invalidValue(...)
    }
}
```

#### 1.2 Add Float Support to Decoding
**File**: `Bemo/Services/SupabaseService.swift`
**Lines**: 932-951

Add float case in `init(from decoder:)`:
```swift
} else if let float = try? container.decode(Float.self) {
    self.value = float
```

#### 1.3 Fix Duplicate Piece Bug
**File**: `Bemo/Features/Game/Games/TangramEditor/ViewModels/TangramEditorViewModel+PieceOperations.swift`
**Line**: 78

**Problem**: Pieces are being added TWICE when placing connected pieces:
1. Line 78: `puzzle.pieces.append(preview)` 
2. Then coordinator.placeConnectedPiece() is called which ALSO appends at line 120 of TangramEditorCoordinator.swift

**Fix**: Remove line 78 - let the coordinator handle the append:
```swift
// DELETE THIS LINE:
// puzzle.pieces.append(preview)

// The coordinator.placeConnectedPiece will add it
```

**Alternative Fix**: Or modify coordinator to not append if piece already exists.

**Why Square Wasn't Duplicated**: The square was likely placed as the FIRST piece using the `manipulatingFirstPiece` flow (line 49-68) which correctly appends only once at line 57. All subsequent pieces went through the `selectingPendingConnections` flow (lines 70-134) which has the double-append bug.

#### 1.4 Clean Existing Database Data
**Action Required**: Manual database cleanup or migration script
- Fix all boolean values in transform matrices
- Remove `isLocked` field from all records
- Fix `zIndex` boolean values
- **Remove duplicate pieces** (keep only one of each type per puzzle)

### Phase 2: Create App-Level Puzzle Service (Priority: HIGH)

#### 2.1 Create PuzzleManagementService
**New File**: `Bemo/Services/PuzzleManagementService.swift`

```swift
import Foundation
import Observation

@Observable
class PuzzleManagementService {
    // Cache storage
    private var tangramPuzzlesCache: [GamePuzzleData] = []
    private var lastSyncDate: Date?
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour
    
    // Services
    private let supabaseService: SupabaseService?
    private let errorTracking: ErrorTrackingService?
    
    // Local storage paths
    private let documentsDirectory: URL
    private let puzzlesDirectory: URL
    
    init(supabaseService: SupabaseService?, errorTracking: ErrorTrackingService?) {
        self.supabaseService = supabaseService
        self.errorTracking = errorTracking
        
        // Setup directories
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        puzzlesDirectory = documentsDirectory.appendingPathComponent("GamePuzzles")
        
        // Create directories if needed
        try? FileManager.default.createDirectory(at: puzzlesDirectory, withIntermediateDirectories: true)
    }
    
    // Called on app launch
    func preloadPuzzles() async {
        await syncTangramPuzzles()
        // Future: Add other game puzzles here
    }
    
    // Get cached Tangram puzzles (for game)
    func getTangramPuzzles() async -> [GamePuzzleData] {
        if shouldRefreshCache() {
            await syncTangramPuzzles()
        }
        return tangramPuzzlesCache
    }
    
    private func syncTangramPuzzles() async {
        // Implementation: Fetch from Supabase, convert, cache locally
    }
}
```

#### 2.2 Add to DependencyContainer
**File**: `Bemo/Core/DependencyContainer.swift`
**Add after line 21**:

```swift
let puzzleManagementService: PuzzleManagementService
```

**In init(), after line 32**:
```swift
self.puzzleManagementService = PuzzleManagementService(
    supabaseService: supabaseService,
    errorTracking: errorTrackingService
)
```

#### 2.3 Preload on App Launch
**File**: `Bemo/Core/AppCoordinator.swift`
**In `start()` method (line 36)**:

```swift
func start() {
    // Preload puzzles in background
    Task {
        await dependencyContainer.puzzleManagementService.preloadPuzzles()
    }
    checkAuthenticationAndNavigate()
}
```

### Phase 3: Update TangramGame to Use Cache (Priority: HIGH)

#### 3.1 Update TangramGame Constructor
**File**: `Bemo/Features/Game/Games/Tangram/TangramGame.swift`
**Lines**: 38-45

```swift
private let puzzleManagementService: PuzzleManagementService?

init(supabaseService: SupabaseService? = nil, 
     puzzleManagementService: PuzzleManagementService? = nil) {
    self.supabaseService = supabaseService
    self.puzzleManagementService = puzzleManagementService
}
```

#### 3.2 Update TangramGameViewModel
**File**: `Bemo/Features/Game/Games/Tangram/ViewModels/TangramGameViewModel.swift`
**Lines**: 54-72

Replace direct database loading with cache:
```swift
init(delegate: GameDelegate, 
     supabaseService: SupabaseService? = nil,
     puzzleManagementService: PuzzleManagementService? = nil) {
    self.delegate = delegate
    self.puzzleManagementService = puzzleManagementService
    
    // Load puzzles from cache
    Task { @MainActor in
        if let service = puzzleManagementService {
            self.availablePuzzles = await service.getTangramPuzzles()
        } else {
            // Fallback to direct loading
            // ... existing code ...
        }
    }
}
```

#### 3.3 Update GameLobbyViewModel
**File**: `Bemo/Features/Lobby/GameLobbyViewModel.swift`
**Line**: 103

```swift
let tangramGame = TangramGame(
    supabaseService: supabaseService,
    puzzleManagementService: dependencyContainer.puzzleManagementService
)
```

### Phase 4: Unify Editor Cache (Priority: MEDIUM)

#### 4.1 Update PuzzlePersistenceService
Make it use the shared `PuzzleManagementService` for reading puzzles, while keeping its save functionality.

**File**: `Bemo/Features/Game/Games/TangramEditor/Services/PuzzlePersistenceService.swift`

Consider either:
1. Delegating read operations to `PuzzleManagementService`
2. Or keeping it separate since editor needs write access

### Phase 5: Remove Redundant Services (Priority: LOW)

After confirming everything works:
1. Remove `TangramDatabaseLoader` (replaced by PuzzleManagementService)
2. Remove unused `PuzzleLibraryService`
3. Clean up duplicate caching logic

## Testing Plan

1. **Fix AnyCodable first** - Test puzzle saving doesn't corrupt data
2. **Clean database** - Manually fix existing bad data
3. **Test caching** - Verify puzzles load instantly after first launch
4. **Test offline mode** - Ensure cached puzzles work without internet
5. **Test editor** - Ensure editor can still save puzzles correctly

## Migration Steps

1. **Immediate**: Fix AnyCodable bug to prevent new corrupted data
2. **Next**: Clean existing database records
3. **Then**: Implement PuzzleManagementService
4. **Finally**: Update games to use cached data

## Risk Mitigation

- **Backward Compatibility**: New code handles both old (corrupted) and new (fixed) data formats
- **Fallback Logic**: If cache fails, fall back to direct database loading
- **Gradual Rollout**: Fix data corruption first, then add caching
- **Keep Editor Separate**: Don't break editor's save functionality

## Success Metrics

1. **No Data Corruption**: All new puzzles save with correct numeric values
2. **Instant Loading**: Puzzles appear immediately (< 100ms) after first launch
3. **Offline Support**: Game works without internet after initial sync
4. **Memory Efficient**: Cache uses < 10MB for 100 puzzles

## File Locations Reference

- **Bug Location**: `Bemo/Services/SupabaseService.swift:953-973`
- **New Service**: `Bemo/Services/PuzzleManagementService.swift` (to be created)
- **DependencyContainer**: `Bemo/Core/DependencyContainer.swift`
- **AppCoordinator**: `Bemo/Core/AppCoordinator.swift`
- **TangramGame**: `Bemo/Features/Game/Games/Tangram/TangramGame.swift`
- **TangramGameViewModel**: `Bemo/Features/Game/Games/Tangram/ViewModels/TangramGameViewModel.swift`
- **GameLobbyViewModel**: `Bemo/Features/Lobby/GameLobbyViewModel.swift`

## Next Steps

1. ✅ Fix AnyCodable encoding order (CRITICAL - do immediately)
2. ✅ Test fix with new puzzle saves
3. 🔄 Clean existing database records
4. 🔄 Implement PuzzleManagementService
5. 🔄 Update games to use cache
6. 🔄 Test end-to-end flow