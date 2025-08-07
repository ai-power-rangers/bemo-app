-- Migration: Cleanup Tangram Puzzles Table
-- Description: Simplify table structure - remove unused connections column and rename pieces to puzzle_data
-- Author: Bemo Team
-- Date: 2025-08-06

BEGIN;

-- Drop the unused connections column
ALTER TABLE public.tangram_puzzles 
DROP COLUMN IF EXISTS connections;

-- Rename pieces column to puzzle_data for clarity
ALTER TABLE public.tangram_puzzles 
RENAME COLUMN pieces TO puzzle_data;

-- Update the constraint name to match new column name
ALTER TABLE public.tangram_puzzles 
DROP CONSTRAINT IF EXISTS valid_pieces;

ALTER TABLE public.tangram_puzzles 
ADD CONSTRAINT valid_puzzle_data CHECK (jsonb_typeof(puzzle_data) = 'object');

-- Update comments
COMMENT ON COLUMN public.tangram_puzzles.puzzle_data IS 'Complete TangramPuzzle object stored as JSONB including all pieces, connections, and configuration';

-- Drop the existing function first (required when changing return type)
DROP FUNCTION IF EXISTS get_tangram_puzzles_by_category(TEXT);

-- Recreate the helper function with new column name
CREATE OR REPLACE FUNCTION get_tangram_puzzles_by_category(
    p_category TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    puzzle_id TEXT,
    name TEXT,
    category TEXT,
    difficulty INTEGER,
    puzzle_data JSONB,  -- Changed from pieces
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
        tp.puzzle_data,  -- Changed from pieces
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

COMMIT;

-- Rollback script (if needed):
/*
BEGIN;

-- Rename column back
ALTER TABLE public.tangram_puzzles 
RENAME COLUMN puzzle_data TO pieces;

-- Re-add connections column
ALTER TABLE public.tangram_puzzles 
ADD COLUMN connections JSONB NOT NULL DEFAULT '[]';

-- Restore original constraint
ALTER TABLE public.tangram_puzzles 
DROP CONSTRAINT IF EXISTS valid_puzzle_data;

ALTER TABLE public.tangram_puzzles 
ADD CONSTRAINT valid_pieces CHECK (jsonb_typeof(pieces) = 'array');

COMMIT;
*/