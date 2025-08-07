-- Migration: Add Tangram Puzzles Storage
-- Description: Creates storage for official tangram puzzles created by developers
-- Author: Bemo Team
-- Date: 2025-08-06

BEGIN;

-- =============================================================================
-- TANGRAM PUZZLES TABLE
-- =============================================================================

-- Create tangram puzzles table for storing official puzzles
CREATE TABLE IF NOT EXISTS public.tangram_puzzles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    puzzle_id TEXT UNIQUE NOT NULL,              -- Unique identifier (e.g., 'official_cat')
    name TEXT NOT NULL,                          -- Display name
    category TEXT NOT NULL,                      -- Category (animals, shapes, etc.)
    difficulty INTEGER NOT NULL CHECK (difficulty BETWEEN 1 AND 5),
    
    -- Puzzle data as JSONB for flexibility
    pieces JSONB NOT NULL,                       -- Array of piece configurations
    connections JSONB NOT NULL DEFAULT '[]',     -- Array of piece connections
    solution_checksum TEXT,                      -- For solution validation
    
    -- Metadata
    is_official BOOLEAN DEFAULT true,            -- All puzzles are official (dev-created)
    tags TEXT[] DEFAULT '{}',                    -- Searchable tags
    order_index INTEGER DEFAULT 0,               -- Display order in category
    
    -- Thumbnail reference
    thumbnail_path TEXT,                         -- Path in storage bucket
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    published_at TIMESTAMP WITH TIME ZONE,       -- When made available to users
    
    -- Additional metadata for future extensibility
    metadata JSONB DEFAULT '{}',
    
    -- Constraints
    CONSTRAINT valid_pieces CHECK (jsonb_typeof(pieces) = 'array'),
    CONSTRAINT valid_connections CHECK (jsonb_typeof(connections) = 'array'),
    CONSTRAINT valid_metadata CHECK (jsonb_typeof(metadata) = 'object')
);

-- Create indexes for query performance
CREATE INDEX IF NOT EXISTS idx_tangram_puzzles_category ON public.tangram_puzzles (category);
CREATE INDEX IF NOT EXISTS idx_tangram_puzzles_difficulty ON public.tangram_puzzles (difficulty);
CREATE INDEX IF NOT EXISTS idx_tangram_puzzles_official ON public.tangram_puzzles (is_official) WHERE is_official = true;
CREATE INDEX IF NOT EXISTS idx_tangram_puzzles_published ON public.tangram_puzzles (published_at) WHERE published_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tangram_puzzles_tags ON public.tangram_puzzles USING GIN (tags);
CREATE INDEX IF NOT EXISTS idx_tangram_puzzles_order ON public.tangram_puzzles (category, order_index);

-- =============================================================================
-- STORAGE BUCKET FOR THUMBNAILS
-- =============================================================================

-- Create storage bucket for puzzle thumbnails (idempotent)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'tangram-thumbnails',
    'tangram-thumbnails', 
    true,  -- Public bucket since these are official puzzles
    5242880, -- 5MB limit per thumbnail
    ARRAY['image/png', 'image/jpeg', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

-- Enable RLS on tangram_puzzles table
ALTER TABLE public.tangram_puzzles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Public read for published puzzles" ON public.tangram_puzzles;
DROP POLICY IF EXISTS "Authenticated users can read all puzzles" ON public.tangram_puzzles;

-- Policy: All authenticated users can read published official puzzles
CREATE POLICY "Public read for published puzzles" ON public.tangram_puzzles
    FOR SELECT
    USING (
        is_official = true 
        AND published_at IS NOT NULL 
        AND published_at <= NOW()
    );

-- Policy: Authenticated users can read all puzzles (including unpublished for testing)
-- This is for internal developer testing
CREATE POLICY "Authenticated users can read all puzzles" ON public.tangram_puzzles
    FOR SELECT
    USING (
        auth.uid() IS NOT NULL
        AND is_official = true
    );

-- Note: No INSERT/UPDATE/DELETE policies as puzzles are managed by developers only
-- through direct database access or admin tools

-- =============================================================================
-- STORAGE POLICIES
-- =============================================================================

-- Since the bucket is public, we only need basic policies
-- Drop existing policies first
DROP POLICY IF EXISTS "Public read access for thumbnails" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated upload for thumbnails" ON storage.objects;

-- Anyone can read thumbnails (they're for official puzzles)
CREATE POLICY "Public read access for thumbnails" ON storage.objects
    FOR SELECT
    USING (bucket_id = 'tangram-thumbnails');

-- Only authenticated users can upload (for developer use)
CREATE POLICY "Authenticated upload for thumbnails" ON storage.objects
    FOR INSERT
    WITH CHECK (
        bucket_id = 'tangram-thumbnails' 
        AND auth.uid() IS NOT NULL
    );

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- Function to get puzzles by category with proper ordering
CREATE OR REPLACE FUNCTION get_tangram_puzzles_by_category(
    p_category TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    puzzle_id TEXT,
    name TEXT,
    category TEXT,
    difficulty INTEGER,
    pieces JSONB,
    connections JSONB,
    solution_checksum TEXT,
    thumbnail_path TEXT,
    tags TEXT[],
    order_index INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tp.id,
        tp.puzzle_id,
        tp.name,
        tp.category,
        tp.difficulty,
        tp.pieces,
        tp.connections,
        tp.solution_checksum,
        tp.thumbnail_path,
        tp.tags,
        tp.order_index
    FROM public.tangram_puzzles tp
    WHERE 
        tp.is_official = true
        AND tp.published_at IS NOT NULL
        AND tp.published_at <= NOW()
        AND (p_category IS NULL OR tp.category = p_category)
    ORDER BY 
        tp.category,
        tp.order_index,
        tp.difficulty,
        tp.name;
END;
$$;

-- Function to get all available categories
CREATE OR REPLACE FUNCTION get_tangram_categories()
RETURNS TABLE (
    category TEXT,
    puzzle_count INTEGER,
    min_difficulty INTEGER,
    max_difficulty INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tp.category,
        COUNT(*)::INTEGER as puzzle_count,
        MIN(tp.difficulty)::INTEGER as min_difficulty,
        MAX(tp.difficulty)::INTEGER as max_difficulty
    FROM public.tangram_puzzles tp
    WHERE 
        tp.is_official = true
        AND tp.published_at IS NOT NULL
        AND tp.published_at <= NOW()
    GROUP BY tp.category
    ORDER BY tp.category;
END;
$$;

-- =============================================================================
-- UPDATE TRIGGER FOR updated_at
-- =============================================================================

-- Create trigger function for updating timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS update_tangram_puzzles_updated_at ON public.tangram_puzzles;
CREATE TRIGGER update_tangram_puzzles_updated_at
    BEFORE UPDATE ON public.tangram_puzzles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================================================

COMMENT ON TABLE public.tangram_puzzles IS 'Stores official tangram puzzles created by developers for the Bemo app';
COMMENT ON COLUMN public.tangram_puzzles.puzzle_id IS 'Unique string identifier for the puzzle (e.g., official_cat, official_house)';
COMMENT ON COLUMN public.tangram_puzzles.pieces IS 'JSONB array of piece configurations including type, position, and rotation';
COMMENT ON COLUMN public.tangram_puzzles.connections IS 'JSONB array defining how pieces can connect to each other';
COMMENT ON COLUMN public.tangram_puzzles.solution_checksum IS 'Hash of the solution for validation purposes';
COMMENT ON COLUMN public.tangram_puzzles.is_official IS 'Always true - all puzzles are official developer-created content';
COMMENT ON COLUMN public.tangram_puzzles.order_index IS 'Display order within category (lower numbers appear first)';
COMMENT ON COLUMN public.tangram_puzzles.published_at IS 'When the puzzle becomes available to users (NULL = unpublished/draft)';

COMMENT ON FUNCTION get_tangram_puzzles_by_category IS 'Retrieves published tangram puzzles optionally filtered by category';
COMMENT ON FUNCTION get_tangram_categories IS 'Returns all available puzzle categories with statistics';

COMMIT;

-- =============================================================================
-- ROLLBACK SCRIPT (Save separately)
-- =============================================================================
-- To rollback this migration, run:
/*
BEGIN;

-- Drop triggers
DROP TRIGGER IF EXISTS update_tangram_puzzles_updated_at ON public.tangram_puzzles;

-- Drop functions
DROP FUNCTION IF EXISTS get_tangram_puzzles_by_category(TEXT);
DROP FUNCTION IF EXISTS get_tangram_categories();
DROP FUNCTION IF EXISTS update_updated_at_column();

-- Drop policies
DROP POLICY IF EXISTS "Public read for published puzzles" ON public.tangram_puzzles;
DROP POLICY IF EXISTS "Authenticated users can read all puzzles" ON public.tangram_puzzles;
DROP POLICY IF EXISTS "Public read access for thumbnails" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated upload for thumbnails" ON storage.objects;

-- Drop indexes
DROP INDEX IF EXISTS idx_tangram_puzzles_category;
DROP INDEX IF EXISTS idx_tangram_puzzles_difficulty;
DROP INDEX IF EXISTS idx_tangram_puzzles_official;
DROP INDEX IF EXISTS idx_tangram_puzzles_published;
DROP INDEX IF EXISTS idx_tangram_puzzles_tags;
DROP INDEX IF EXISTS idx_tangram_puzzles_order;

-- Drop table
DROP TABLE IF EXISTS public.tangram_puzzles;

-- Note: Storage bucket 'tangram-thumbnails' is not dropped to preserve any uploaded files
-- To fully remove: DELETE FROM storage.buckets WHERE id = 'tangram-thumbnails';

COMMIT;
*/