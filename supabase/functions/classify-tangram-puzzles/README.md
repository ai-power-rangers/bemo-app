# classify-tangram-puzzles (Edge Function)

Classifies existing `tangram_puzzles` with a `metadata.skill_profile` and tags, without touching game code.

## What it does
- Scans `public.tangram_puzzles` selecting puzzles missing `metadata.skill_profile` or with outdated `classifier_version`.
- Computes weights for: shape_matching, mental_rotation, reflection, decomposition, planning_sequencing.
- Optionally updates `tags` with coarse labels (e.g., `rotation_30plus`, `reflection_present`).
- Supports dry runs and batch limits.

## Deploy
```bash
supabase functions deploy classify-tangram-puzzles
```

Set secrets (recommended):
```bash
supabase secrets set SERVICE_ROLE_KEY=your_service_role_key
```

## Invoke
Authorized server-side only (bearer must be service role):
```bash
# Dry run, only missing, first 50
curl -X POST \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  'https://<project-ref>.functions.supabase.co/classify-tangram-puzzles?dry_run=true&limit=50'

# Apply updates for 100 rows
curl -X POST \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  'https://<project-ref>.functions.supabase.co/classify-tangram-puzzles?dry_run=false&limit=100'

# Reclassify regardless of existing metadata (bump version)
curl -X POST \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  'https://<project-ref>.functions.supabase.co/classify-tangram-puzzles?dry_run=false&only_missing=false&classifier_version=v2'
```

## Notes
- Uses `puzzle_data.pieces[].transform` (a,b,c,d,tx,ty) for rotation/reflection.
- If `connections` present, affects decomposition and planning.
- Writes: `metadata.skill_profile`, `metadata.classifier_version`, updates `tags` (merged + deduped).
- Logs detailed JSON lines for each processed row: puzzle_id, piece_count, weights, tags, dry_run.


