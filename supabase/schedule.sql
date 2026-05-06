-- ═══════════════════════════════════════════════════
-- KOK Pipeline Scheduling via pg_cron + pg_net
-- Run in Supabase SQL Editor AFTER deploying Edge Functions
-- ═══════════════════════════════════════════════════

-- Replace YOUR_SUPABASE_URL with your actual Supabase URL
-- Replace YOUR_SERVICE_ROLE_KEY with your service role key

-- Helper function to invoke pipeline stages
CREATE OR REPLACE FUNCTION invoke_pipeline_stage(stage_name TEXT)
RETURNS VOID AS $$
BEGIN
  PERFORM net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/kok-pipeline',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    ),
    body := jsonb_build_object('stage', stage_name)
  );
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════
-- Collection Schedule (KST = UTC+9)
-- ═══════════════════════════════════

-- Nate Pann: 06:00, 09:00, 12:00, 15:00, 18:00, 21:00 KST (6x/day)
SELECT cron.schedule('collect_pann_1', '0 21 * * *', $$SELECT invoke_pipeline_stage('collect_pann')$$);
SELECT cron.schedule('collect_pann_2', '0 0 * * *', $$SELECT invoke_pipeline_stage('collect_pann')$$);
SELECT cron.schedule('collect_pann_3', '0 3 * * *', $$SELECT invoke_pipeline_stage('collect_pann')$$);
SELECT cron.schedule('collect_pann_4', '0 6 * * *', $$SELECT invoke_pipeline_stage('collect_pann')$$);
SELECT cron.schedule('collect_pann_5', '0 9 * * *', $$SELECT invoke_pipeline_stage('collect_pann')$$);
SELECT cron.schedule('collect_pann_6', '0 12 * * *', $$SELECT invoke_pipeline_stage('collect_pann')$$);

-- TheQoo Square: 07:00, 10:00, 13:00, 16:00, 19:00, 22:00 KST (6x/day)
SELECT cron.schedule('collect_theqoo_sq_1', '0 22 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_square')$$);
SELECT cron.schedule('collect_theqoo_sq_2', '0 1 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_square')$$);
SELECT cron.schedule('collect_theqoo_sq_3', '0 4 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_square')$$);
SELECT cron.schedule('collect_theqoo_sq_4', '0 7 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_square')$$);
SELECT cron.schedule('collect_theqoo_sq_5', '0 10 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_square')$$);
SELECT cron.schedule('collect_theqoo_sq_6', '0 13 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_square')$$);

-- TheQoo Ktalk: 10:00, 15:00, 21:00 KST (3x/day)
SELECT cron.schedule('collect_theqoo_kt_1', '0 1 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_ktalk')$$);
SELECT cron.schedule('collect_theqoo_kt_2', '0 6 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_ktalk')$$);
SELECT cron.schedule('collect_theqoo_kt_3', '0 12 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_ktalk')$$);

-- Nate Entertainment: 08:00, 12:00, 17:00, 21:00 KST (4x/day)
SELECT cron.schedule('collect_nate_ent_1', '0 23 * * *', $$SELECT invoke_pipeline_stage('collect_nate_ent')$$);
SELECT cron.schedule('collect_nate_ent_2', '0 3 * * *', $$SELECT invoke_pipeline_stage('collect_nate_ent')$$);
SELECT cron.schedule('collect_nate_ent_3', '0 8 * * *', $$SELECT invoke_pipeline_stage('collect_nate_ent')$$);
SELECT cron.schedule('collect_nate_ent_4', '0 12 * * *', $$SELECT invoke_pipeline_stage('collect_nate_ent')$$);

-- YouTube: 11:00, 23:00 KST (2x/day)
SELECT cron.schedule('collect_youtube_1', '0 2 * * *', $$SELECT invoke_pipeline_stage('collect_youtube')$$);
SELECT cron.schedule('collect_youtube_2', '0 14 * * *', $$SELECT invoke_pipeline_stage('collect_youtube')$$);

-- ═══════════════════════════════════
-- Processing Schedule
-- ═══════════════════════════════════

-- Extract keywords: after each major collection
SELECT cron.schedule('extract_keywords_1', '20 23 * * *', $$SELECT invoke_pipeline_stage('extract_keywords')$$);
SELECT cron.schedule('extract_keywords_2', '20 5 * * *', $$SELECT invoke_pipeline_stage('extract_keywords')$$);
SELECT cron.schedule('extract_keywords_3', '20 12 * * *', $$SELECT invoke_pipeline_stage('extract_keywords')$$);

-- Build clusters
SELECT cron.schedule('build_clusters_1', '25 23 * * *', $$SELECT invoke_pipeline_stage('build_clusters')$$);
SELECT cron.schedule('build_clusters_2', '25 5 * * *', $$SELECT invoke_pipeline_stage('build_clusters')$$);
SELECT cron.schedule('build_clusters_3', '25 12 * * *', $$SELECT invoke_pipeline_stage('build_clusters')$$);

-- Filter clusters
SELECT cron.schedule('filter_clusters_1', '30 23 * * *', $$SELECT invoke_pipeline_stage('filter_clusters')$$);
SELECT cron.schedule('filter_clusters_2', '30 5 * * *', $$SELECT invoke_pipeline_stage('filter_clusters')$$);
SELECT cron.schedule('filter_clusters_3', '30 12 * * *', $$SELECT invoke_pipeline_stage('filter_clusters')$$);

-- Naver validation: 10:00, 19:00 KST → 01:00, 10:00 UTC
SELECT cron.schedule('validate_naver_1', '0 1 * * *', $$SELECT invoke_pipeline_stage('validate_naver')$$);
SELECT cron.schedule('validate_naver_2', '0 10 * * *', $$SELECT invoke_pipeline_stage('validate_naver')$$);

-- ═══════════════════════════════════
-- AI Processing Schedule
-- ═══════════════════════════════════

-- Cerebras screen: 10:00, 16:00, 22:00 KST (3x/day)
SELECT cron.schedule('ai_screen_1', '0 1 * * *', $$SELECT invoke_pipeline_stage('ai_screen')$$);
SELECT cron.schedule('ai_screen_2', '0 7 * * *', $$SELECT invoke_pipeline_stage('ai_screen')$$);
SELECT cron.schedule('ai_screen_3', '0 13 * * *', $$SELECT invoke_pipeline_stage('ai_screen')$$);

-- Groq analyze: 10:30, 16:30, 22:30 KST (3x/day)
SELECT cron.schedule('ai_analyze_1', '30 1 * * *', $$SELECT invoke_pipeline_stage('ai_analyze')$$);
SELECT cron.schedule('ai_analyze_2', '30 7 * * *', $$SELECT invoke_pipeline_stage('ai_analyze')$$);
SELECT cron.schedule('ai_analyze_3', '30 13 * * *', $$SELECT invoke_pipeline_stage('ai_analyze')$$);

-- Gemini generate: 11:00, 17:00, 23:00 KST (3x/day)
SELECT cron.schedule('ai_generate_1', '0 2 * * *', $$SELECT invoke_pipeline_stage('ai_generate')$$);
SELECT cron.schedule('ai_generate_2', '0 8 * * *', $$SELECT invoke_pipeline_stage('ai_generate')$$);
SELECT cron.schedule('ai_generate_3', '0 14 * * *', $$SELECT invoke_pipeline_stage('ai_generate')$$);

-- ═══════════════════════════════════
-- Cleanup Schedule
-- ═══════════════════════════════════

-- Cleanup: 03:00 KST → 18:00 UTC
SELECT cron.schedule('cleanup_expired', '0 18 * * *', $$SELECT invoke_pipeline_stage('cleanup')$$);

-- Reset daily AI budgets: 00:00 KST → 15:00 UTC
SELECT cron.schedule('reset_ai_budgets', '0 15 * * *', $$
  INSERT INTO ai_daily_budgets (provider, budget_date, max_calls) VALUES
    ('cerebras', CURRENT_DATE, 100),
    ('groq', CURRENT_DATE, 50),
    ('gemini', CURRENT_DATE, 30)
  ON CONFLICT (provider, budget_date) DO UPDATE SET
    used_calls = 0,
    used_tokens_estimated = 0,
    is_exhausted = false,
    updated_at = NOW();
$$);
