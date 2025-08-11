-- Migration: Add RLS Policies for Tangram Editor
-- Description: Adds INSERT, UPDATE, and DELETE policies to allow service role and authenticated users to manage tangram puzzles
-- Author: Bemo Team
-- Date: 2025-08-09

BEGIN;

-- =============================================================================
-- RLS POLICIES FOR TANGRAM EDITOR
-- =============================================================================

-- Drop any existing write policies (for idempotency)
DROP POLICY IF EXISTS "Service role can insert puzzles" ON public.tangram_puzzles;
DROP POLICY IF EXISTS "Service role can update puzzles" ON public.tangram_puzzles;
DROP POLICY IF EXISTS "Service role can delete puzzles" ON public.tangram_puzzles;
DROP POLICY IF EXISTS "Authenticated users can insert puzzles" ON public.tangram_puzzles;
DROP POLICY IF EXISTS "Authenticated users can update puzzles" ON public.tangram_puzzles;
DROP POLICY IF EXISTS "Authenticated users can delete puzzles" ON public.tangram_puzzles;

-- =============================================================================
-- INSERT POLICIES
-- =============================================================================

-- Policy: Authenticated users can insert new puzzles
-- This allows the Tangram Editor (using service role key) to create new puzzles
CREATE POLICY "Authenticated users can insert puzzles" ON public.tangram_puzzles
    FOR INSERT
    WITH CHECK (
        auth.uid() IS NOT NULL  -- Must be authenticated (includes service role)
    );

-- =============================================================================
-- UPDATE POLICIES
-- =============================================================================

-- Policy: Authenticated users can update puzzles
-- This allows the Tangram Editor to save changes to existing puzzles
CREATE POLICY "Authenticated users can update puzzles" ON public.tangram_puzzles
    FOR UPDATE
    USING (
        auth.uid() IS NOT NULL  -- Must be authenticated
    )
    WITH CHECK (
        auth.uid() IS NOT NULL  -- Must be authenticated
    );

-- =============================================================================
-- DELETE POLICIES
-- =============================================================================

-- Policy: Authenticated users can delete puzzles
-- This allows the Tangram Editor to delete puzzles
CREATE POLICY "Authenticated users can delete puzzles" ON public.tangram_puzzles
    FOR DELETE
    USING (
        auth.uid() IS NOT NULL  -- Must be authenticated
    );

-- =============================================================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================================================

COMMENT ON POLICY "Authenticated users can insert puzzles" ON public.tangram_puzzles 
    IS 'Allows authenticated users (including service role) to create new tangram puzzles via the editor';

COMMENT ON POLICY "Authenticated users can update puzzles" ON public.tangram_puzzles 
    IS 'Allows authenticated users (including service role) to update existing tangram puzzles via the editor';

COMMENT ON POLICY "Authenticated users can delete puzzles" ON public.tangram_puzzles 
    IS 'Allows authenticated users (including service role) to delete tangram puzzles via the editor';

COMMIT;

-- =============================================================================
-- VERIFICATION QUERIES (Run these after migration to verify)
-- =============================================================================
-- To verify the policies are in place:
/*
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'tangram_puzzles'
ORDER BY policyname;
*/

-- =============================================================================
-- ROLLBACK SCRIPT (Save separately)
-- =============================================================================
-- To rollback this migration, run:
/*
BEGIN;

-- Drop the write policies
DROP POLICY IF EXISTS "Authenticated users can insert puzzles" ON public.tangram_puzzles;
DROP POLICY IF EXISTS "Authenticated users can update puzzles" ON public.tangram_puzzles;
DROP POLICY IF EXISTS "Authenticated users can delete puzzles" ON public.tangram_puzzles;

COMMIT;
*/