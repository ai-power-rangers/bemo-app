import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Environment
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

type Transform = { a: number; b: number; c: number; d: number; tx: number; ty: number }
type Piece = { id: string; type?: string; pieceType?: string; transform: Transform }
type Connection = { id: string; type: unknown; constraint?: { type?: string } }

type PuzzleRow = {
  puzzle_id: string
  name: string
  difficulty: number
  puzzle_data: Record<string, unknown>
  tags: string[] | null
  metadata: Record<string, unknown> | null
}

type SkillProfile = {
  shape_matching: number
  mental_rotation: number
  reflection: number
  decomposition: number
  planning_sequencing: number
}

function atan2Deg(b: number, a: number): number {
  const ang = Math.atan2(b, a)
  return (ang * 180) / Math.PI
}

function rotationMetrics(pieces: Piece[]) {
  const epsilonDeg = 5
  let nonZero = 0
  let sumNorm = 0
  for (const p of pieces) {
    const deg = Math.abs(atan2Deg(p.transform.b, p.transform.a))
    const isZero = deg < epsilonDeg
    if (!isZero) nonZero += 1
    // normalize by 90° (π/2) cap
    const capped = Math.min(deg, 90)
    sumNorm += capped / 90
  }
  const count = Math.max(1, pieces.length)
  return {
    fraction: nonZero / count,
    intensity: sumNorm / count,
  }
}

function isFlipped(t: Transform): boolean {
  const det = t.a * t.d - t.b * t.c
  return det < 0
}

function reflectionMetric(pieces: Piece[]) {
  let flipped = 0
  let parallelogramFlipBonus = 0
  for (const p of pieces) {
    if (isFlipped(p.transform)) {
      flipped += 1
      const kind = (p.type || p.pieceType || '').toLowerCase()
      if (kind.includes('parallelogram')) parallelogramFlipBonus += 0.05
    }
  }
  const frac = flipped / Math.max(1, pieces.length)
  return Math.min(1, frac + parallelogramFlipBonus)
}

function decompositionMetric(pieces: Piece[], connections?: Connection[]) {
  if (!connections || !Array.isArray(connections) || connections.length === 0) return 0
  // Approximate density by edges per piece
  const density = connections.length / Math.max(1, pieces.length)
  // heuristically clamp to [0,1] assuming ~3 edges per piece is "high"
  return Math.min(1, density / 3)
}

function planningMetric(pieces: Piece[], connections?: Connection[]) {
  // Heuristic: more constraints + more orientation diversity → higher planning
  let fixedCount = 0
  let rotationBucketSet = new Set<number>()
  for (const p of pieces) {
    const deg = Math.abs(atan2Deg(p.transform.b, p.transform.a))
    // bucket by 45°
    const bucket = Math.round(deg / 45)
    rotationBucketSet.add(bucket)
  }
  if (connections && Array.isArray(connections)) {
    for (const c of connections) {
      const t = (c as any)?.constraint?.type
      if (typeof t === 'string' && t.toLowerCase().includes('fixed')) fixedCount += 1
    }
  }
  const diversity = Math.min(1, rotationBucketSet.size / 4) // up to 4 buckets contributes fully
  const fixedScore = Math.min(1, fixedCount / Math.max(1, pieces.length))
  return Math.min(1, 0.6 * diversity + 0.4 * fixedScore)
}

function computeSkillProfile(puzzle: PuzzleRow, classifierVersion: string): { profile: SkillProfile; tags: string[] } {
  const data = puzzle.puzzle_data || {}
  const pieces = (data as any).pieces as Piece[] | undefined
  const connections = (data as any).connections as Connection[] | undefined
  if (!pieces || !Array.isArray(pieces) || pieces.length === 0) {
    const prof: SkillProfile = {
      shape_matching: 1,
      mental_rotation: 0,
      reflection: 0,
      decomposition: 0,
      planning_sequencing: 0,
    }
    return { profile: prof, tags: ['matching_only'] }
  }

  const rot = rotationMetrics(pieces)
  const refl = reflectionMetric(pieces)
  const decomp = decompositionMetric(pieces, connections)
  const plan = planningMetric(pieces, connections)

  // Raw others before normalization
  let mental_rotation = Math.min(1, 0.5 * rot.fraction + 0.5 * rot.intensity)
  let reflection = Math.min(1, refl)
  let decomposition = Math.min(1, decomp)
  let planning_sequencing = Math.min(1, plan)

  // shape matching baseline
  let others = mental_rotation + reflection + decomposition + planning_sequencing
  let shape_matching = Math.max(0.1, 1 - others)

  // Normalize sum to 1 (allow slight slack due to baseline)
  const sum = shape_matching + others
  if (sum > 1.00001) {
    shape_matching /= sum
    mental_rotation /= sum
    reflection /= sum
    decomposition /= sum
    planning_sequencing /= sum
  }

  const profile: SkillProfile = { shape_matching, mental_rotation, reflection, decomposition, planning_sequencing }

  // Tags
  const tags: string[] = []
  if (mental_rotation >= 0.3) tags.push('rotation_30plus')
  if (reflection >= 0.1) tags.push('reflection_present')
  if (decomposition >= 0.3) tags.push('decomp_high')
  if (planning_sequencing >= 0.3) tags.push('plan_high')

  return { profile, tags }
}

function uniq<T>(arr: T[]): T[] {
  return Array.from(new Set(arr))
}

serve(async (req) => {
  try {
    const url = new URL(req.url)
    const dryRun = (url.searchParams.get('dry_run') ?? 'true') === 'true'
    const limit = parseInt(url.searchParams.get('limit') ?? '50', 10)
    const onlyMissing = (url.searchParams.get('only_missing') ?? 'true') === 'true'
    const classifierVersion = url.searchParams.get('classifier_version') ?? 'v1'

    // Auth: require service role key bearer for manual invocations
    const authHeader = req.headers.get('Authorization')
    if (!authHeader || authHeader !== `Bearer ${SERVICE_ROLE_KEY}`) {
      return new Response('Unauthorized', { status: 401 })
    }

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)

    // Build filter for missing/outdated
    const orFilter = onlyMissing
      ? 'metadata->>skill_profile.is.null'
      : `metadata->>skill_profile.is.null,metadata->>classifier_version.neq.${classifierVersion}`

    let query = supabase
      .from('tangram_puzzles')
      .select('puzzle_id,name,difficulty,puzzle_data,tags,metadata')
      .eq('is_official', true)
      .not('puzzle_data', 'is', null)
      .or(orFilter)
      .order('created_at', { ascending: true })
      .limit(limit)

    const { data, error } = await query
    if (error) {
      console.error('Query error:', error)
      return new Response(JSON.stringify({ error: error.message }), { status: 500 })
    }

    const rows = (data || []) as PuzzleRow[]
    console.log(`Classifying puzzles: count=${rows.length}, dry_run=${dryRun}, only_missing=${onlyMissing}, classifier_version=${classifierVersion}`)

    let updated = 0
    const results: Array<{ puzzle_id: string; weights: SkillProfile; tags: string[] }> = []

    for (const row of rows) {
      const { profile, tags } = computeSkillProfile(row, classifierVersion)

      // Compose new metadata and tags
      const existingMeta = row.metadata || {}
      const newMeta = { ...existingMeta, skill_profile: profile, classifier_version: classifierVersion }
      const existingTags = row.tags || []
      const newTags = uniq([...existingTags, ...tags])

      console.log(
        JSON.stringify({
          puzzle_id: row.puzzle_id,
          name: row.name,
          piece_count: (row.puzzle_data as any)?.pieces?.length ?? 0,
          weights: profile,
          tags: newTags,
          dry_run: dryRun,
        }),
      )

      results.push({ puzzle_id: row.puzzle_id, weights: profile, tags: newTags })

      if (!dryRun) {
        const { error: updErr } = await supabase
          .from('tangram_puzzles')
          .update({ metadata: newMeta, tags: newTags })
          .eq('puzzle_id', row.puzzle_id)

        if (updErr) {
          console.error('Update failed for puzzle_id', row.puzzle_id, updErr)
        } else {
          updated += 1
        }
      }
    }

    return new Response(
      JSON.stringify({
        processed: rows.length,
        updated,
        dry_run: dryRun,
        classifier_version: classifierVersion,
        sample: results.slice(0, 10),
      }),
      { headers: { 'Content-Type': 'application/json' }, status: 200 },
    )
  } catch (err) {
    console.error('Function error:', err)
    const msg = err instanceof Error ? err.message : String(err)
    return new Response(JSON.stringify({ error: msg }), { status: 500 })
  }
})


