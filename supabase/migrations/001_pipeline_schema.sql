-- ═══════════════════════════════════════════════════
-- KOK V2 Pipeline Schema
-- Run this in Supabase SQL Editor
-- ═══════════════════════════════════════════════════

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ═══════════════════════════════════
-- 1. source_configs
-- ═══════════════════════════════════
CREATE TABLE IF NOT EXISTS source_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_name TEXT NOT NULL UNIQUE,
  source_type TEXT NOT NULL,
  base_url TEXT NOT NULL,
  collection_method TEXT NOT NULL DEFAULT 'html_scrape',
  is_active BOOLEAN NOT NULL DEFAULT true,
  crawl_interval_minutes INTEGER,
  scheduled_times JSONB,
  risk_level TEXT NOT NULL DEFAULT 'low',
  ttl_hours INTEGER NOT NULL DEFAULT 72,
  source_weight INTEGER NOT NULL DEFAULT 20,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO source_configs (source_name, source_type, base_url, collection_method, scheduled_times, source_weight) VALUES
  ('nate_pann_enttalk', 'community', 'https://pann.nate.com/talk/c20028', 'html_scrape', '["08:00","14:00","21:00"]', 35),
  ('theqoo_square', 'community', 'https://theqoo.net/square', 'html_scrape', '["08:10","14:10","21:10"]', 30),
  ('theqoo_ktalk', 'community', 'https://theqoo.net/ktalk', 'html_scrape', '["12:00","22:00"]', 20),
  ('nate_ent', 'news', 'https://news.nate.com/ent/subsection?mid=e1100', 'html_scrape', '["09:00","18:00"]', 15),
  ('youtube_kbs_kpop', 'youtube', 'https://www.youtube.com/@KBSKpop', 'youtube_api', '["23:00"]', 20),
  ('youtube_mnet', 'youtube', 'https://www.youtube.com/@Mnet/videos', 'youtube_api', '["23:00"]', 20),
  ('youtube_dispatch', 'youtube', 'https://www.youtube.com/@koreadispatch/videos', 'youtube_api', '["23:00"]', 22),
  ('naver_search', 'api', 'https://openapi.naver.com/v1/search/news.json', 'naver_api', '["10:00","19:00"]', 25),
  ('naver_datalab', 'api', 'https://openapi.naver.com/v1/datalab/search', 'naver_api', '["19:30"]', 25)
ON CONFLICT (source_name) DO NOTHING;

-- ═══════════════════════════════════
-- 2. raw_source_items
-- ═══════════════════════════════════
CREATE TABLE IF NOT EXISTS raw_source_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_name TEXT NOT NULL,
  source_type TEXT NOT NULL,
  url TEXT NOT NULL,
  external_id TEXT,
  title TEXT NOT NULL,
  normalized_title TEXT,
  snippet TEXT,
  raw_metrics JSONB DEFAULT '{}',
  raw_payload JSONB,
  collected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  published_at TIMESTAMPTZ,
  content_hash TEXT NOT NULL UNIQUE,
  extracted_keywords JSONB DEFAULT '[]',
  artist_tags JSONB DEFAULT '[]',
  agency_tags JSONB DEFAULT '[]',
  noise_flags JSONB DEFAULT '{}',
  ttl_expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '72 hours'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_raw_source_collected ON raw_source_items (collected_at DESC);
CREATE INDEX IF NOT EXISTS idx_raw_source_name ON raw_source_items (source_name);
CREATE INDEX IF NOT EXISTS idx_raw_source_ttl ON raw_source_items (ttl_expires_at);

-- ═══════════════════════════════════
-- 3. raw_reaction_items
-- ═══════════════════════════════════
CREATE TABLE IF NOT EXISTS raw_reaction_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_name TEXT NOT NULL,
  source_type TEXT NOT NULL,
  source_url TEXT NOT NULL,
  parent_item_id UUID REFERENCES raw_source_items(id) ON DELETE SET NULL,
  cluster_id UUID,
  original_text_ko TEXT NOT NULL,
  sanitized_text_ko TEXT,
  like_count INTEGER DEFAULT 0,
  reply_count INTEGER DEFAULT 0,
  recommend_count INTEGER DEFAULT 0,
  oppose_count INTEGER DEFAULT 0,
  korean_ratio NUMERIC DEFAULT 0,
  toxicity_score NUMERIC DEFAULT 0,
  rumor_risk_score NUMERIC DEFAULT 0,
  context_value_score NUMERIC DEFAULT 0,
  sentiment TEXT,
  is_selected BOOLEAN DEFAULT false,
  rejection_reason TEXT,
  collected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ttl_expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '72 hours'),
  content_hash TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reaction_cluster ON raw_reaction_items (cluster_id);
CREATE INDEX IF NOT EXISTS idx_reaction_selected ON raw_reaction_items (is_selected) WHERE is_selected = true;

-- ═══════════════════════════════════
-- 4. keyword_candidates
-- ═══════════════════════════════════
CREATE TABLE IF NOT EXISTS keyword_candidates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  keyword TEXT NOT NULL,
  normalized_keyword TEXT NOT NULL,
  keyword_type TEXT NOT NULL DEFAULT 'unknown',
  source_count INTEGER DEFAULT 1,
  source_names JSONB DEFAULT '[]',
  first_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  mention_count INTEGER DEFAULT 1,
  trend_score NUMERIC DEFAULT 0,
  noise_score NUMERIC DEFAULT 0,
  is_blocked BOOLEAN DEFAULT false,
  block_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_keyword_normalized ON keyword_candidates (normalized_keyword);

-- ═══════════════════════════════════
-- 5. issue_clusters
-- ═══════════════════════════════════
CREATE TABLE IF NOT EXISTS issue_clusters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cluster_key TEXT NOT NULL UNIQUE,
  main_title_ko TEXT,
  main_keywords JSONB DEFAULT '[]',
  related_artists JSONB DEFAULT '[]',
  related_agencies JSONB DEFAULT '[]',
  source_item_ids JSONB DEFAULT '[]',
  source_count INTEGER DEFAULT 0,
  source_types JSONB DEFAULT '[]',
  first_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  pann_post_count INTEGER DEFAULT 0,
  theqoo_square_post_count INTEGER DEFAULT 0,
  theqoo_ktalk_post_count INTEGER DEFAULT 0,
  nate_article_count INTEGER DEFAULT 0,
  youtube_video_count INTEGER DEFAULT 0,
  youtube_korean_comment_count INTEGER DEFAULT 0,
  naver_search_result_count INTEGER DEFAULT 0,
  datalab_growth_score NUMERIC DEFAULT 0,
  reaction_strength NUMERIC DEFAULT 0,
  trend_score NUMERIC DEFAULT 0,
  publish_score NUMERIC DEFAULT 0,
  issue_clarity_score NUMERIC DEFAULT 0,
  korean_context_value NUMERIC DEFAULT 0,
  source_credibility NUMERIC DEFAULT 0,
  freshness NUMERIC DEFAULT 0,
  cross_source_overlap NUMERIC DEFAULT 0,
  noise_score NUMERIC DEFAULT 0,
  pr_score NUMERIC DEFAULT 0,
  legal_risk_score NUMERIC DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'new',
  status_reason TEXT,
  ai_review_json JSONB,
  manual_review_notes TEXT,
  ttl_expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '72 hours'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cluster_status ON issue_clusters (status);
CREATE INDEX IF NOT EXISTS idx_cluster_publish_score ON issue_clusters (publish_score DESC);

-- ═══════════════════════════════════
-- 6. naver_datalab_results
-- ═══════════════════════════════════
CREATE TABLE IF NOT EXISTS naver_datalab_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cluster_id UUID REFERENCES issue_clusters(id) ON DELETE SET NULL,
  keyword_group TEXT NOT NULL,
  keywords JSONB NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  time_unit TEXT NOT NULL DEFAULT 'date',
  result_data JSONB,
  growth_score NUMERIC DEFAULT 0,
  collected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════
-- 7. kok_cards (replaces old articles)
-- ═══════════════════════════════════
CREATE TABLE IF NOT EXISTS kok_cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cluster_id UUID REFERENCES issue_clusters(id) ON DELETE SET NULL,
  title_en TEXT NOT NULL,
  title_es TEXT NOT NULL DEFAULT '',
  what_people_are_talking_about_en TEXT NOT NULL DEFAULT '',
  what_people_are_talking_about_es TEXT NOT NULL DEFAULT '',
  what_happened_en TEXT NOT NULL DEFAULT '',
  what_happened_es TEXT NOT NULL DEFAULT '',
  korean_reaction_summary_en TEXT NOT NULL DEFAULT '',
  korean_reaction_summary_es TEXT NOT NULL DEFAULT '',
  context_for_global_fans_en TEXT NOT NULL DEFAULT '',
  context_for_global_fans_es TEXT NOT NULL DEFAULT '',
  representative_reactions_en JSONB DEFAULT '[]',
  representative_reactions_es JSONB DEFAULT '[]',
  source_links JSONB DEFAULT '[]',
  reaction_sources JSONB DEFAULT '[]',
  tags JSONB DEFAULT '[]',
  issue_type TEXT NOT NULL DEFAULT 'OTHER',
  reaction_tone TEXT NOT NULL DEFAULT 'mixed',
  risk_level TEXT NOT NULL DEFAULT 'low',
  status TEXT NOT NULL DEFAULT 'draft',
  prompt_version TEXT DEFAULT 'v2.0',
  model_versions JSONB DEFAULT '{}',
  image_url TEXT,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_kok_cards_status ON kok_cards (status);
CREATE INDEX IF NOT EXISTS idx_kok_cards_published ON kok_cards (published_at DESC) WHERE status = 'published';

-- ═══════════════════════════════════
-- 8. pipeline_runs
-- ═══════════════════════════════════
CREATE TABLE IF NOT EXISTS pipeline_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  run_type TEXT NOT NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  finished_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'running',
  items_collected INTEGER DEFAULT 0,
  clusters_created INTEGER DEFAULT 0,
  clusters_rejected INTEGER DEFAULT 0,
  clusters_manual_review INTEGER DEFAULT 0,
  cards_generated INTEGER DEFAULT 0,
  error_message TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════
-- 9. ai_usage_logs
-- ═══════════════════════════════════
CREATE TABLE IF NOT EXISTS ai_usage_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL,
  model TEXT NOT NULL,
  run_type TEXT NOT NULL,
  cluster_id UUID,
  input_tokens_estimated INTEGER DEFAULT 0,
  output_tokens_estimated INTEGER DEFAULT 0,
  total_tokens_estimated INTEGER DEFAULT 0,
  api_call_count INTEGER DEFAULT 1,
  success BOOLEAN DEFAULT true,
  error_message TEXT,
  prompt_version TEXT,
  input_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_usage_provider_date ON ai_usage_logs (provider, created_at);

-- ═══════════════════════════════════
-- 10. ai_daily_budgets
-- ═══════════════════════════════════
CREATE TABLE IF NOT EXISTS ai_daily_budgets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL,
  budget_date DATE NOT NULL DEFAULT CURRENT_DATE,
  max_calls INTEGER NOT NULL DEFAULT 10,
  used_calls INTEGER NOT NULL DEFAULT 0,
  max_tokens INTEGER,
  used_tokens_estimated INTEGER DEFAULT 0,
  is_exhausted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_budget_provider_date ON ai_daily_budgets (provider, budget_date);


-- ═══════════════════════════════════
-- RLS Policies
-- ═══════════════════════════════════
ALTER TABLE kok_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_usage_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_daily_budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_source_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_reaction_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE issue_clusters ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public read kok_cards') THEN
    CREATE POLICY "Public read kok_cards" ON kok_cards FOR SELECT USING (status = 'published');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service write kok_cards') THEN
    CREATE POLICY "Service write kok_cards" ON kok_cards FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service all raw_source_items') THEN
    CREATE POLICY "Service all raw_source_items" ON raw_source_items FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service all raw_reaction_items') THEN
    CREATE POLICY "Service all raw_reaction_items" ON raw_reaction_items FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service all issue_clusters') THEN
    CREATE POLICY "Service all issue_clusters" ON issue_clusters FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service all pipeline_runs') THEN
    CREATE POLICY "Service all pipeline_runs" ON pipeline_runs FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service all ai_usage_logs') THEN
    CREATE POLICY "Service all ai_usage_logs" ON ai_usage_logs FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service all ai_daily_budgets') THEN
    CREATE POLICY "Service all ai_daily_budgets" ON ai_daily_budgets FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

-- ═══════════════════════════════════
-- Helper Functions
-- ═══════════════════════════════════

-- Check AI budget before calling
CREATE OR REPLACE FUNCTION check_ai_budget(p_provider TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_exhausted BOOLEAN;
BEGIN
  SELECT is_exhausted INTO v_exhausted
  FROM ai_daily_budgets
  WHERE provider = p_provider AND budget_date = CURRENT_DATE;

  IF NOT FOUND THEN
    INSERT INTO ai_daily_budgets (provider, budget_date, max_calls)
    VALUES (
      p_provider,
      CURRENT_DATE,
      CASE p_provider
        WHEN 'cerebras' THEN 150
        WHEN 'groq' THEN 50
        WHEN 'gemini' THEN 30
        ELSE 50
      END
    );
    RETURN true;
  END IF;

  RETURN NOT COALESCE(v_exhausted, false);
END;
$$ LANGUAGE plpgsql;

-- Increment AI usage
CREATE OR REPLACE FUNCTION increment_ai_usage(
  p_provider TEXT,
  p_tokens INTEGER DEFAULT 0
) RETURNS VOID AS $$
BEGIN
  UPDATE ai_daily_budgets
  SET
    used_calls = used_calls + 1,
    used_tokens_estimated = used_tokens_estimated + p_tokens,
    is_exhausted = (used_calls + 1 >= max_calls),
    updated_at = NOW()
  WHERE provider = p_provider AND budget_date = CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- TTL Cleanup
CREATE OR REPLACE FUNCTION cleanup_expired_data()
RETURNS VOID AS $$
BEGIN
  DELETE FROM raw_source_items WHERE ttl_expires_at < NOW();
  DELETE FROM raw_reaction_items WHERE ttl_expires_at < NOW();
  DELETE FROM issue_clusters WHERE ttl_expires_at < NOW() AND status NOT IN ('published', 'manual_review');
END;
$$ LANGUAGE plpgsql;

-- Get published cards for Flutter
CREATE OR REPLACE FUNCTION get_published_cards(p_limit INTEGER DEFAULT 30)
RETURNS SETOF kok_cards AS $$
  SELECT * FROM kok_cards
  WHERE status = 'published'
  ORDER BY published_at DESC
  LIMIT p_limit;
$$ LANGUAGE sql STABLE;
