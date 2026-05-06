-- invoke function with hardcoded URL (no-verify-jwt deployed)
CREATE OR REPLACE FUNCTION invoke_pipeline_stage(stage_name TEXT)
RETURNS VOID AS $$
BEGIN
  PERFORM net.http_post(
    url := 'https://lwetcjkgspurlhyfufbz.supabase.co/functions/v1/kok-pipeline',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := jsonb_build_object('stage', stage_name)
  );
END;
$$ LANGUAGE plpgsql;

-- Nate Pann 6x/day
SELECT cron.schedule('collect_pann_1', '0 21 * * *', $$SELECT invoke_pipeline_stage('collect_pann')$$);
SELECT cron.schedule('collect_pann_2', '0 0 * * *', $$SELECT invoke_pipeline_stage('collect_pann')$$);
SELECT cron.schedule('collect_pann_3', '0 3 * * *', $$SELECT invoke_pipeline_stage('collect_pann')$$);
SELECT cron.schedule('collect_pann_4', '0 6 * * *', $$SELECT invoke_pipeline_stage('collect_pann')$$);
SELECT cron.schedule('collect_pann_5', '0 9 * * *', $$SELECT invoke_pipeline_stage('collect_pann')$$);
SELECT cron.schedule('collect_pann_6', '0 12 * * *', $$SELECT invoke_pipeline_stage('collect_pann')$$);

-- TheQoo Square 6x/day
SELECT cron.schedule('collect_theqoo_sq_1', '0 22 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_square')$$);
SELECT cron.schedule('collect_theqoo_sq_2', '0 1 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_square')$$);
SELECT cron.schedule('collect_theqoo_sq_3', '0 4 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_square')$$);
SELECT cron.schedule('collect_theqoo_sq_4', '0 7 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_square')$$);
SELECT cron.schedule('collect_theqoo_sq_5', '0 10 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_square')$$);
SELECT cron.schedule('collect_theqoo_sq_6', '0 13 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_square')$$);

-- TheQoo Ktalk 3x/day
SELECT cron.schedule('collect_theqoo_kt_1', '0 1 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_ktalk')$$);
SELECT cron.schedule('collect_theqoo_kt_2', '0 6 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_ktalk')$$);
SELECT cron.schedule('collect_theqoo_kt_3', '0 12 * * *', $$SELECT invoke_pipeline_stage('collect_theqoo_ktalk')$$);

-- Nate Ent 4x/day
SELECT cron.schedule('collect_nate_ent_1', '0 23 * * *', $$SELECT invoke_pipeline_stage('collect_nate_ent')$$);
SELECT cron.schedule('collect_nate_ent_2', '0 3 * * *', $$SELECT invoke_pipeline_stage('collect_nate_ent')$$);
SELECT cron.schedule('collect_nate_ent_3', '0 8 * * *', $$SELECT invoke_pipeline_stage('collect_nate_ent')$$);
SELECT cron.schedule('collect_nate_ent_4', '0 12 * * *', $$SELECT invoke_pipeline_stage('collect_nate_ent')$$);

-- YouTube 2x/day
SELECT cron.schedule('collect_youtube_1', '0 2 * * *', $$SELECT invoke_pipeline_stage('collect_youtube')$$);
SELECT cron.schedule('collect_youtube_2', '0 14 * * *', $$SELECT invoke_pipeline_stage('collect_youtube')$$);

-- Keywords 3x/day
SELECT cron.schedule('extract_keywords_1', '20 23 * * *', $$SELECT invoke_pipeline_stage('extract_keywords')$$);
SELECT cron.schedule('extract_keywords_2', '20 5 * * *', $$SELECT invoke_pipeline_stage('extract_keywords')$$);
SELECT cron.schedule('extract_keywords_3', '20 12 * * *', $$SELECT invoke_pipeline_stage('extract_keywords')$$);

-- Clusters 3x/day
SELECT cron.schedule('build_clusters_1', '25 23 * * *', $$SELECT invoke_pipeline_stage('build_clusters')$$);
SELECT cron.schedule('build_clusters_2', '25 5 * * *', $$SELECT invoke_pipeline_stage('build_clusters')$$);
SELECT cron.schedule('build_clusters_3', '25 12 * * *', $$SELECT invoke_pipeline_stage('build_clusters')$$);

-- Filter 3x/day
SELECT cron.schedule('filter_clusters_1', '30 23 * * *', $$SELECT invoke_pipeline_stage('filter_clusters')$$);
SELECT cron.schedule('filter_clusters_2', '30 5 * * *', $$SELECT invoke_pipeline_stage('filter_clusters')$$);
SELECT cron.schedule('filter_clusters_3', '30 12 * * *', $$SELECT invoke_pipeline_stage('filter_clusters')$$);

-- Naver 2x/day
SELECT cron.schedule('validate_naver_1', '0 1 * * *', $$SELECT invoke_pipeline_stage('validate_naver')$$);
SELECT cron.schedule('validate_naver_2', '0 10 * * *', $$SELECT invoke_pipeline_stage('validate_naver')$$);

-- Reactions: after filtering, before AI (3x/day)
SELECT cron.schedule('collect_reactions_1', '40 23 * * *', $$SELECT invoke_pipeline_stage('collect_reactions')$$);
SELECT cron.schedule('collect_reactions_2', '40 5 * * *', $$SELECT invoke_pipeline_stage('collect_reactions')$$);
SELECT cron.schedule('collect_reactions_3', '40 12 * * *', $$SELECT invoke_pipeline_stage('collect_reactions')$$);

-- Cerebras 3x/day
SELECT cron.schedule('ai_screen_1', '0 1 * * *', $$SELECT invoke_pipeline_stage('ai_screen')$$);
SELECT cron.schedule('ai_screen_2', '0 7 * * *', $$SELECT invoke_pipeline_stage('ai_screen')$$);
SELECT cron.schedule('ai_screen_3', '0 13 * * *', $$SELECT invoke_pipeline_stage('ai_screen')$$);

-- Groq 3x/day
SELECT cron.schedule('ai_analyze_1', '30 1 * * *', $$SELECT invoke_pipeline_stage('ai_analyze')$$);
SELECT cron.schedule('ai_analyze_2', '30 7 * * *', $$SELECT invoke_pipeline_stage('ai_analyze')$$);
SELECT cron.schedule('ai_analyze_3', '30 13 * * *', $$SELECT invoke_pipeline_stage('ai_analyze')$$);

-- Gemini 3x/day
SELECT cron.schedule('ai_generate_1', '0 2 * * *', $$SELECT invoke_pipeline_stage('ai_generate')$$);
SELECT cron.schedule('ai_generate_2', '0 8 * * *', $$SELECT invoke_pipeline_stage('ai_generate')$$);
SELECT cron.schedule('ai_generate_3', '0 14 * * *', $$SELECT invoke_pipeline_stage('ai_generate')$$);

-- Cleanup
SELECT cron.schedule('cleanup_expired', '0 18 * * *', $$SELECT invoke_pipeline_stage('cleanup')$$);

-- Budget reset
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
