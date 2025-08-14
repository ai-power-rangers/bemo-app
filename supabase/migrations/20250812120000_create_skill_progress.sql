-- Migration: Create skill_progress table for per-skill aggregates and mastery
-- Description: Stores per-child, per-game, per-skill progress, rolling metrics, and mastery state
-- Author: Bemo Team
-- Date: 2025-08-12

BEGIN;

-- ============================================================================
-- ENUM TYPES (idempotent creation)
-- ============================================================================

DO $$ BEGIN
    CREATE TYPE skill_key AS ENUM (
        'shape_matching',
        'mental_rotation',
        'reflection',
        'decomposition',
        'planning_sequencing'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE mastery_state AS ENUM (
        'none',
        'candidate',
        'mastered',
        'regressing'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================================
-- TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.skill_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_profile_id UUID NOT NULL REFERENCES public.child_profiles(id) ON DELETE CASCADE,
    game_id TEXT NOT NULL,
    skill_key skill_key NOT NULL,

    -- Aggregates
    xp_total INTEGER NOT NULL DEFAULT 0 CHECK (xp_total >= 0),
    level INTEGER NOT NULL DEFAULT 0 CHECK (level >= 0),
    sample_count INTEGER NOT NULL DEFAULT 0 CHECK (sample_count >= 0),

    -- Rolling 7d metrics (client-computed for now)
    success_rate_7d NUMERIC NOT NULL DEFAULT 0 CHECK (success_rate_7d >= 0 AND success_rate_7d <= 1),
    avg_time_ms_7d INTEGER,
    avg_hints_7d NUMERIC NOT NULL DEFAULT 0 CHECK (avg_hints_7d >= 0),
    completions_no_hint_7d INTEGER NOT NULL DEFAULT 0 CHECK (completions_no_hint_7d >= 0),

    -- Mastery
    mastery_state mastery_state NOT NULL DEFAULT 'none',
    mastery_score NUMERIC NOT NULL DEFAULT 0 CHECK (mastery_score >= 0 AND mastery_score <= 1),
    first_mastered_at TIMESTAMPTZ,
    last_mastery_event_at TIMESTAMPTZ,

    -- Classifier/threshold bookkeeping
    classifier_version TEXT,
    mastery_threshold_version TEXT,

    -- Bookkeeping
    last_assessed_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_child_game_skill UNIQUE (child_profile_id, game_id, skill_key)
);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_skill_progress_child ON public.skill_progress (child_profile_id);
CREATE INDEX IF NOT EXISTS idx_skill_progress_game_skill ON public.skill_progress (game_id, skill_key);
CREATE INDEX IF NOT EXISTS idx_skill_progress_mastery_state ON public.skill_progress (mastery_state);
CREATE INDEX IF NOT EXISTS idx_skill_progress_last_assessed_at ON public.skill_progress (last_assessed_at);
CREATE INDEX IF NOT EXISTS idx_skill_progress_metadata_gin ON public.skill_progress USING GIN (metadata);

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

ALTER TABLE public.skill_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Parents can view own children skill progress" ON public.skill_progress;
CREATE POLICY "Parents can view own children skill progress"
ON public.skill_progress FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.child_profiles cp
    WHERE cp.id = skill_progress.child_profile_id
      AND cp.parent_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "System can insert skill progress for own children" ON public.skill_progress;
CREATE POLICY "System can insert skill progress for own children"
ON public.skill_progress FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.child_profiles cp
    WHERE cp.id = skill_progress.child_profile_id
      AND cp.parent_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Parents can update own children skill progress" ON public.skill_progress;
CREATE POLICY "Parents can update own children skill progress"
ON public.skill_progress FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.child_profiles cp
    WHERE cp.id = skill_progress.child_profile_id
      AND cp.parent_user_id = auth.uid()
  )
);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

DROP TRIGGER IF EXISTS update_skill_progress_updated_at ON public.skill_progress;
CREATE TRIGGER update_skill_progress_updated_at
  BEFORE UPDATE ON public.skill_progress
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE public.skill_progress IS 'Per-child, per-game, per-skill aggregates and mastery state';
COMMENT ON COLUMN public.skill_progress.skill_key IS 'Skill taxonomy key';
COMMENT ON COLUMN public.skill_progress.mastery_state IS 'Mastery state: none, candidate, mastered, regressing';
COMMENT ON COLUMN public.skill_progress.metadata IS 'Aux JSON for window stats, family_ids used for confirmation, etc.';

COMMIT;