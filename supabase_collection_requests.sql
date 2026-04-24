-- ========================================================
-- Run ONLY this — the table + realtime already exist.
-- This adds the missing RLS policies (if any).
-- ========================================================

-- Drop existing policies first (safe to run even if they don't exist)
DROP POLICY IF EXISTS "Users can insert own requests" ON collection_requests;
DROP POLICY IF EXISTS "Workers can view all requests" ON collection_requests;
DROP POLICY IF EXISTS "Workers can update requests" ON collection_requests;

-- Enable RLS
ALTER TABLE collection_requests ENABLE ROW LEVEL SECURITY;

-- Policy: Any logged-in user can INSERT their own deposit
CREATE POLICY "Users can insert own requests"
  ON collection_requests FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Policy: Any logged-in user can SELECT (workers need to see all)
CREATE POLICY "Workers can view all requests"
  ON collection_requests FOR SELECT
  TO authenticated
  USING (true);

-- Policy: Any logged-in user can UPDATE (workers approve/reject)
CREATE POLICY "Workers can update requests"
  ON collection_requests FOR UPDATE
  TO authenticated
  USING (true);
