-- Add topic context fields to issue_clusters for better content alignment
ALTER TABLE issue_clusters ADD COLUMN IF NOT EXISTS topic_context TEXT;
ALTER TABLE issue_clusters ADD COLUMN IF NOT EXISTS context_snippets TEXT;
ALTER TABLE issue_clusters ADD COLUMN IF NOT EXISTS all_titles JSONB DEFAULT '[]';
