# Tangram Puzzle Storage Migration Plan

## Executive Summary
Migrate Tangram puzzle storage from local-only (Documents directory) to Supabase with offline caching, enabling cloud sync for official puzzles created via the editor.

## Current State

### Local Storage Structure
```
Documents/
├── TangramPuzzles/
│   ├── puzzle_{id}.json       # Individual puzzle files
│   ├── puzzles.index          # Metadata index
│   └── thumbnails/
│       └── thumb_{id}.png     # Puzzle thumbnails
```

### Puzzle Data Model
- **TangramPuzzle**: Core puzzle with pieces, connections, metadata
- **File Size**: ~5-10KB per puzzle JSON
- **Thumbnail Size**: ~20-50KB per PNG
- **Current Storage**: PuzzlePersistenceService using FileManager

## Target Architecture

### Supabase Storage Structure
```
Supabase Cloud:
├── Database Tables:
│   └── tangram_puzzles (main puzzle data)
├── Storage Buckets:
│   └── puzzle-thumbnails (PNG images)
└── Local Cache (unchanged):
    └── Documents/TangramPuzzles/
```

### Data Flow
1. **Create/Edit**: Save to Supabase → Cache locally
2. **Load**: Check cache → Fetch from Supabase if needed
3. **Offline**: Use cached version
4. **Sync**: On app launch, sync official puzzles

## Implementation Plan

### Phase 1: Database Schema Migration

**IMPORTANT**: This MUST be done through proper Supabase migrations to maintain database integrity.

#### Step 1: Create Migration File
```bash
# Generate new migration file with timestamp
supabase migration new add_tangram_puzzles_storage
```

This will create: `supabase/migrations/[timestamp]_add_tangram_puzzles_storage.sql`

#### Step 2: Migration Content
```sql
-- Migration: Add Tangram Puzzles Storage
-- This migration must be atomic and reversible

BEGIN;

-- Create tangram puzzles table
CREATE TABLE IF NOT EXISTS public.tangram_puzzles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    puzzle_id TEXT UNIQUE NOT NULL,  -- Legacy ID (official_cat, etc)
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    difficulty INTEGER NOT NULL CHECK (difficulty BETWEEN 1 AND 5),
    pieces JSONB NOT NULL,            -- Array of TangramPiece
    connections JSONB NOT NULL,       -- Array of Connection
    solution_checksum TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    modified_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    tags TEXT[] DEFAULT '{}',
    is_official BOOLEAN DEFAULT false,
    metadata JSONB DEFAULT '{}',      -- Extra fields for future use
    
    CONSTRAINT valid_pieces CHECK (jsonb_typeof(pieces) = 'array'),
    CONSTRAINT valid_connections CHECK (jsonb_typeof(connections) = 'array')
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_puzzles_official ON public.tangram_puzzles (is_official);
CREATE INDEX IF NOT EXISTS idx_puzzles_category ON public.tangram_puzzles (category);
CREATE INDEX IF NOT EXISTS idx_puzzles_difficulty ON public.tangram_puzzles (difficulty);
CREATE INDEX IF NOT EXISTS idx_puzzles_created_by ON public.tangram_puzzles (created_by);

-- Enable RLS
ALTER TABLE public.tangram_puzzles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (idempotent)
DROP POLICY IF EXISTS "Read official puzzles" ON public.tangram_puzzles;
DROP POLICY IF EXISTS "Update own puzzles" ON public.tangram_puzzles;
DROP POLICY IF EXISTS "Insert puzzles" ON public.tangram_puzzles;

-- Create RLS policies
CREATE POLICY "Read official puzzles" ON public.tangram_puzzles
    FOR SELECT USING (is_official = true AND auth.uid() IS NOT NULL);

CREATE POLICY "Update own puzzles" ON public.tangram_puzzles
    FOR UPDATE USING (created_by = auth.uid());

CREATE POLICY "Insert puzzles" ON public.tangram_puzzles
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND created_by = auth.uid());

-- Create storage bucket for thumbnails (only if not exists)
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('puzzle-thumbnails', 'puzzle-thumbnails', false, 5242880) -- 5MB limit
ON CONFLICT (id) DO NOTHING;

-- Storage policies (drop and recreate for idempotency)
DROP POLICY IF EXISTS "Read thumbnails" ON storage.objects;
DROP POLICY IF EXISTS "Upload thumbnails" ON storage.objects;
DROP POLICY IF EXISTS "Update thumbnails" ON storage.objects;
DROP POLICY IF EXISTS "Delete thumbnails" ON storage.objects;

CREATE POLICY "Read thumbnails" ON storage.objects
    FOR SELECT USING (bucket_id = 'puzzle-thumbnails' AND auth.uid() IS NOT NULL);

CREATE POLICY "Upload thumbnails" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'puzzle-thumbnails' AND auth.uid() IS NOT NULL);

CREATE POLICY "Update thumbnails" ON storage.objects
    FOR UPDATE USING (bucket_id = 'puzzle-thumbnails' AND auth.uid() = owner);

CREATE POLICY "Delete thumbnails" ON storage.objects
    FOR DELETE USING (bucket_id = 'puzzle-thumbnails' AND auth.uid() = owner);

COMMIT;

-- Add comment for documentation
COMMENT ON TABLE public.tangram_puzzles IS 'Stores tangram puzzle configurations created in the editor';
COMMENT ON COLUMN public.tangram_puzzles.is_official IS 'True for developer-created official puzzles, false for user puzzles';
```

#### Step 3: Test Migration Locally
```bash
# Reset local database to test migration
supabase db reset

# Or just run the new migration
supabase migration up
```

#### Step 4: Deploy Migration
```bash
# Deploy to production (after testing!)
supabase db push
```

#### Migration Rollback Plan
Create corresponding rollback migration:
```sql
-- Rollback: Remove Tangram Puzzles Storage
BEGIN;

-- Drop policies first
DROP POLICY IF EXISTS "Read official puzzles" ON public.tangram_puzzles;
DROP POLICY IF EXISTS "Update own puzzles" ON public.tangram_puzzles;
DROP POLICY IF EXISTS "Insert puzzles" ON public.tangram_puzzles;

-- Drop table
DROP TABLE IF EXISTS public.tangram_puzzles;

-- Note: We don't drop the storage bucket as it may contain data
-- Manual cleanup of storage bucket required if full rollback needed

COMMIT;
```

### Phase 2: SupabaseService Extensions

Add to `SupabaseService.swift`:
```swift
// MARK: - Tangram Puzzle Storage

func fetchOfficialPuzzles() async throws -> [TangramPuzzle] {
    let response = try await client
        .from("tangram_puzzles")
        .select()
        .eq("is_official", value: true)
        .execute()
    
    return try JSONDecoder().decode([TangramPuzzleDTO].self, from: response.data)
        .map { $0.toPuzzle() }
}

func savePuzzle(_ puzzle: TangramPuzzle, thumbnail: Data?) async throws {
    // Convert to DTO for database
    let dto = TangramPuzzleDTO(from: puzzle)
    
    // Save puzzle data
    try await client
        .from("tangram_puzzles")
        .upsert(dto)
        .execute()
    
    // Upload thumbnail if provided
    if let thumbnail = thumbnail {
        let path = "thumbnails/\(puzzle.id).png"
        try await client.storage
            .from("puzzle-thumbnails")
            .upload(path: path, file: thumbnail, options: FileOptions(contentType: "image/png"))
    }
}

func downloadThumbnail(for puzzleId: String) async throws -> Data {
    let path = "thumbnails/\(puzzleId).png"
    return try await client.storage
        .from("puzzle-thumbnails")
        .download(path: path)
}
```

### Phase 3: Update PuzzlePersistenceService

Modify `PuzzlePersistenceService.swift`:
```swift
class PuzzlePersistenceService {
    private let supabaseService: SupabaseService?
    
    init(supabaseService: SupabaseService? = nil) {
        self.supabaseService = supabaseService
        // ... existing init
    }
    
    // Hybrid save: Cloud + Local cache
    func savePuzzle(_ puzzle: TangramPuzzle) async throws -> TangramPuzzle {
        // 1. Save locally first (for offline support)
        let localPuzzle = try await saveLocally(puzzle)
        
        // 2. If online and authenticated, sync to Supabase
        if let supabase = supabaseService,
           puzzle.source == .bundled {  // Only sync official puzzles
            do {
                try await supabase.savePuzzle(localPuzzle, thumbnail: localPuzzle.thumbnailData)
            } catch {
                // Log but don't fail - local save succeeded
                print("Failed to sync to cloud: \(error)")
            }
        }
        
        return localPuzzle
    }
    
    // Load with fallback
    func loadOfficialPuzzles() async throws -> [TangramPuzzle] {
        // 1. Try loading from Supabase
        if let supabase = supabaseService {
            do {
                let cloudPuzzles = try await supabase.fetchOfficialPuzzles()
                // Cache them locally
                for puzzle in cloudPuzzles {
                    try await cacheLocally(puzzle)
                }
                return cloudPuzzles
            } catch {
                print("Failed to fetch from cloud, using cache: \(error)")
            }
        }
        
        // 2. Fallback to local cache
        return try await loadLocalOfficialPuzzles()
    }
}
```

### Phase 4: App Initialization Updates

Update `TangramEditorDependencyContainer.swift`:
```swift
class TangramEditorDependencyContainer {
    init(supabaseService: SupabaseService? = nil) {
        // Pass Supabase to persistence service
        self.persistenceService = PuzzlePersistenceService(
            supabaseService: supabaseService
        )
    }
}
```

Update `TangramEditorGame.swift`:
```swift
class TangramEditorGame: Game {
    private let supabaseService: SupabaseService?
    
    init(supabaseService: SupabaseService? = nil) {
        self.supabaseService = supabaseService
    }
    
    @MainActor
    private func initializeViewModel(delegate: GameDelegate) async {
        if dependencyContainer == nil {
            dependencyContainer = TangramEditorDependencyContainer(
                supabaseService: supabaseService
            )
        }
        // ... rest of init
    }
}
```

### Phase 5: Sync on App Launch

Add to puzzle library loading:
```swift
func loadSavedPuzzles() async {
    do {
        // Load official puzzles from cloud/cache
        let officialPuzzles = try await persistenceService.loadOfficialPuzzles()
        
        await MainActor.run {
            self.savedPuzzles = officialPuzzles
        }
    } catch {
        print("Failed to load puzzles: \(error)")
    }
}
```

## Migration Steps

### Pre-Migration Checklist
- [ ] Backup existing local puzzles
- [ ] Test migration on local Supabase instance
- [ ] Review migration SQL for syntax errors
- [ ] Ensure rollback plan is ready

### Migration Execution

1. **Generate & Test Migration Locally**
   ```bash
   # Create migration file
   supabase migration new add_tangram_puzzles_storage
   
   # Copy SQL from this plan to the migration file
   
   # Test locally
   supabase db reset  # WARNING: Clears local DB
   
   # Verify migration applied
   supabase migration list
   ```

2. **Deploy Database Migration**
   ```bash
   # Deploy to staging/production
   supabase db push --linked
   
   # Verify tables created
   supabase db dump --schema-only | grep tangram_puzzles
   ```

3. **Update Application Code**
   - Add Supabase methods to SupabaseService
   - Update PuzzlePersistenceService with hybrid storage
   - Wire dependencies through TangramEditorDependencyContainer

4. **Test Migration Integrity**
   - Create test puzzle with developer mode ON
   - Verify puzzle appears in `tangram_puzzles` table
   - Verify thumbnail in storage bucket
   - Test with airplane mode (offline)
   - Restart app and verify puzzle loads from cloud

### Post-Migration Validation
- [ ] Official puzzles sync across devices
- [ ] Offline mode works with cached puzzles
- [ ] No data loss from existing local puzzles
- [ ] RLS policies prevent unauthorized access

## Benefits

1. **Automatic Distribution**: Official puzzles available to all authenticated users
2. **Version Control**: Changes to puzzles automatically propagate
3. **Offline Support**: Local cache ensures gameplay without internet
4. **No Manual Files**: No need to manage Resources folder
5. **Future Expansion**: Ready for user puzzle sharing, discovery features

## Rollback Plan

If issues occur:
1. Disable Supabase sync (feature flag)
2. Continue using local-only storage
3. Puzzles remain in local cache
4. No data loss as local storage remains primary

## Success Metrics

- [ ] Official puzzles sync across devices
- [ ] Offline play works with cached puzzles
- [ ] Editor saves trigger cloud sync
- [ ] Thumbnails load from cloud storage
- [ ] No performance degradation

## Timeline

- **Phase 1-2**: 2-3 hours (Database & Service setup)
- **Phase 3-4**: 2-3 hours (Integration & wiring)
- **Phase 5**: 1 hour (Testing & validation)
- **Total**: ~6-7 hours

## Notes

- Maintains backward compatibility with existing local storage
- Non-blocking sync (failures don't break the app)
- Official puzzles require authentication (as requested)
- Parent-created puzzles stay local-only (simplification as requested)