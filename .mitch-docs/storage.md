# Tangram Puzzle Storage Architecture

## Current State Analysis

### Two Separate Systems
1. **TangramGame** - Gameplay for kids (hardcoded single puzzle)
2. **TangramEditorGame** - Puzzle creation for parents (full persistence)

### Critical Gap
- No integration between editor and game
- Kids can't play parent-created puzzles
- No bundled puzzle system exists

## Proposed Storage Architecture

### Directory Structure
```
Bemo.app/
├── Resources/
│   └── Puzzles/
│       └── Tangram/
│           ├── official/
│           │   ├── animals/
│           │   │   ├── cat.json
│           │   │   ├── dog.json
│           │   │   └── bird.json
│           │   ├── shapes/
│           │   │   ├── house.json
│           │   │   ├── rocket.json
│           │   │   └── tree.json
│           │   ├── objects/
│           │   │   ├── boat.json
│           │   │   └── car.json
│           │   └── manifest.json
│           └── README.md

Application Support/ (Runtime)
└── Bemo/
    └── Puzzles/
        └── Tangram/
            ├── official/      # Cached bundled puzzles
            ├── user/          # Parent-created puzzles
            └── index.json     # Combined puzzle index
```

## Implementation Plan

### Phase 1: Unified Puzzle System

#### 1.1 Create Shared Puzzle Model
```swift
// Shared/Models/Puzzles/UnifiedTangramPuzzle.swift
struct UnifiedTangramPuzzle: Codable {
    let id: String
    let name: String
    let category: PuzzleCategory
    let difficulty: PuzzleDifficulty
    let source: PuzzleSource
    let isEditable: Bool
    let solutionData: TangramSolution
    let thumbnailData: Data?
    let metadata: PuzzleMetadata
}

enum PuzzleSource: String, Codable {
    case bundled = "bundled"      // Ships with app
    case official = "official"    // Developer-created
    case user = "user"           // Parent-created
}

struct TangramSolution: Codable {
    let pieces: [SolvedPiece]
    let checksum: String
}
```

#### 1.2 Update PuzzlePersistenceService
```swift
class UnifiedPuzzleService {
    // Load from all sources
    func loadAllPuzzles() async -> [UnifiedTangramPuzzle] {
        let bundled = loadBundledPuzzles()
        let user = await loadUserPuzzles()
        return bundled + user
    }
    
    // Bundled puzzles (read-only)
    private func loadBundledPuzzles() -> [UnifiedTangramPuzzle] {
        guard let bundleURL = Bundle.main.url(
            forResource: "official",
            withExtension: nil,
            subdirectory: "Puzzles/Tangram"
        ) else { return [] }
        
        // Load and cache to Application Support on first launch
        // Mark as source: .bundled, isEditable: false
    }
    
    // User puzzles (read-write)
    private func loadUserPuzzles() async -> [UnifiedTangramPuzzle] {
        // Load from Application Support/Bemo/Puzzles/Tangram/user/
        // Mark as source: .user, isEditable: true
    }
}
```

### Phase 2: Bridge Editor and Game

#### 2.1 Update TangramGame to Use Unified Puzzles
```swift
// TangramGame.swift
class TangramGame: Game {
    private var availablePuzzles: [UnifiedTangramPuzzle] = []
    private var currentPuzzle: UnifiedTangramPuzzle?
    
    func loadPuzzles() async {
        availablePuzzles = await UnifiedPuzzleService.shared.loadAllPuzzles()
    }
    
    func selectPuzzle(_ puzzle: UnifiedTangramPuzzle) {
        currentPuzzle = puzzle
        loadPuzzleIntoGame(puzzle.solutionData)
    }
}
```

#### 2.2 Add Puzzle Selection to Game
- Create puzzle selection view in TangramGame
- Show both bundled and user puzzles
- Group by category with visual indicators for source

### Phase 3: Developer Workflow

#### 3.1 Developer Puzzle Creation
1. **Create in Editor** (development mode)
   ```swift
   // Add to TangramEditorViewModel
   var isDeveloperMode: Bool {
       #if DEBUG
       return true
       #else
       return false
       #endif
   }
   
   func exportForBundling() -> Data? {
       // Export puzzle as JSON for Resources/
   }
   ```

2. **Export Process**
   - Create puzzle in TangramEditor
   - Mark as "official" via developer mode
   - Export to JSON file
   - Add to `Resources/Puzzles/Tangram/official/[category]/`

3. **Bundle with App**
   - JSON files included in app bundle
   - Automatically loaded on app launch
   - Cached to Application Support for performance

#### 3.2 Manifest File Structure
```json
{
  "version": "1.0",
  "puzzles": [
    {
      "id": "official_house_001",
      "path": "shapes/house.json",
      "category": "shapes",
      "difficulty": "easy",
      "order": 1
    }
  ],
  "categories": {
    "animals": { "displayName": "Animals", "icon": "🦁" },
    "shapes": { "displayName": "Shapes", "icon": "🔷" },
    "objects": { "displayName": "Objects", "icon": "🚀" }
  }
}
```

### Phase 4: User Experience

#### 4.1 In TangramEditor (Parents)
```
Library View:
├── Official Puzzles (read-only)
│   ├── [View/Duplicate only]
│   └── Can duplicate to create variations
└── My Puzzles
    ├── [Full edit/delete]
    └── Created by parent
```

#### 4.2 In TangramGame (Kids)
```
Puzzle Selection:
├── All Puzzles (mixed display)
│   ├── 🔒 Official puzzles (bundled)
│   └── 👤 Family puzzles (parent-created)
└── Filtering by category/difficulty
```

## Migration Strategy

### Step 1: Prepare Data Models (No Breaking Changes)
- Add `PuzzleSource` enum to existing models
- Create migration for existing puzzles (mark as `source: .user`)
- Add `isEditable` computed property

### Step 2: Update Services
- Extend `PuzzlePersistenceService` with bundled puzzle loading
- Keep backward compatibility with existing save/load methods
- Add unified loading method

### Step 3: Bundle Initial Puzzles
- Create 10-15 official puzzles covering all categories
- Test in TangramEditor first
- Export and add to Resources/

### Step 4: Update UI
- Modify PuzzleLibraryView to show sections
- Add puzzle selection to TangramGame
- Implement read-only mode for official puzzles in editor

## Technical Details

### Storage Locations
```swift
// Bundled (read-only, ships with app)
Bundle.main.url(forResource: "official", withExtension: nil, subdirectory: "Puzzles/Tangram")

// Application Support (runtime cache & user puzzles)
FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("Bemo/Puzzles/Tangram")

// Documents (not used - reserved for user exports only)
```

### Puzzle ID Convention
- Bundled: `official_[category]_[name]_[number]` (e.g., `official_animals_cat_001`)
- User: `user_[uuid]` (e.g., `user_550e8400-e29b-41d4-a716-446655440000`)

### File Naming
- Bundled: `[descriptive-name].json` (e.g., `cat.json`, `house.json`)
- User: `puzzle_[id].json` (existing format maintained)

## Benefits

1. **Immediate Value**: Kids get puzzles to play right away
2. **Parental Engagement**: Parents can create custom puzzles
3. **No Backend Required**: Everything works offline
4. **Scalable**: Can add cloud sync later without breaking changes
5. **Clear Separation**: Official vs user content clearly distinguished
6. **Developer Control**: Can update official puzzles with app updates

## Next Steps

1. [ ] Create `UnifiedTangramPuzzle` model
2. [ ] Extend `PuzzlePersistenceService` with bundled loading
3. [ ] Create 5 sample official puzzles for testing
4. [ ] Update TangramGame to load unified puzzles
5. [ ] Add puzzle selection UI to TangramGame
6. [ ] Update PuzzleLibraryView to show sections
7. [ ] Test migration of existing user puzzles
8. [ ] Document puzzle JSON format for developers

## Future Enhancements

- **Phase 5**: CloudKit sync for user puzzles across devices
- **Phase 6**: Community sharing with moderation
- **Phase 7**: Puzzle packs as in-app purchases
- **Phase 8**: Seasonal/holiday puzzle updates via remote config

---

*This architecture provides a clean separation between developer-created content (bundled, read-only) and parent-created content (local, editable) while maintaining a unified experience for children playing the game.*