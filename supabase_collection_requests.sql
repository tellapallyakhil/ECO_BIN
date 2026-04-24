-- ========================================================
-- FIX: Add missing columns to collection_requests table
-- Run this in Supabase SQL Editor
-- ========================================================

ALTER TABLE collection_requests ADD COLUMN IF NOT EXISTS bin_id TEXT;
ALTER TABLE collection_requests ADD COLUMN IF NOT EXISTS bin_location TEXT;
ALTER TABLE collection_requests ADD COLUMN IF NOT EXISTS user_name TEXT;
ALTER TABLE collection_requests ADD COLUMN IF NOT EXISTS weight DOUBLE PRECISION DEFAULT 0;
