-- Migration: Add helpful indexes for tangram_puzzles metadata and tags
-- Description: Optimizes queries over tags and metadata.skill_profile
-- Author: Bemo Team
-- Date: 2025-08-12

BEGIN;

-- Ensure JSONB metadata GIN index exists (useful for skill_profile queries)
CREATE INDEX IF NOT EXISTS idx_tangram_puzzles_metadata_gin
  ON public.tangram_puzzles USING GIN (metadata);

COMMIT;


