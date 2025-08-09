-- Migration: Configure Storage Bucket for Tangram Thumbnails
-- Description: Updates bucket configuration for proper thumbnail handling
-- Author: Bemo Team
-- Date: 2025-08-09

BEGIN;

-- Configure the tangram-thumbnails bucket
UPDATE storage.buckets 
SET public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/webp']::text[]
WHERE id = 'tangram-thumbnails';

COMMIT;