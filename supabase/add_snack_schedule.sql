-- ═══════════════════════════════════════════════════════════
-- Add generate_snacks schedule (4x/day, after ai_generate)
-- Run each one 15 minutes after the corresponding ai_generate
-- ai_generate runs at 02:00, 08:00, 14:00 UTC
-- generate_snacks runs at 02:15, 08:15, 14:15, 20:15 UTC
-- ═══════════════════════════════════════════════════════════

SELECT cron.schedule('generate_snacks_1', '15 2 * * *', $$SELECT invoke_pipeline_stage('generate_snacks')$$);
SELECT cron.schedule('generate_snacks_2', '15 8 * * *', $$SELECT invoke_pipeline_stage('generate_snacks')$$);
SELECT cron.schedule('generate_snacks_3', '15 14 * * *', $$SELECT invoke_pipeline_stage('generate_snacks')$$);
SELECT cron.schedule('generate_snacks_4', '15 20 * * *', $$SELECT invoke_pipeline_stage('generate_snacks')$$);

-- ═══════════════════════════════════════════════════════════
-- Update budget reset: increase Cerebras budget to use it fully
-- Cerebras: 100 → 150 (snacks are cheap, ~400 tokens each)
-- ═══════════════════════════════════════════════════════════

SELECT cron.unschedule('reset_ai_budgets');

SELECT cron.schedule('reset_ai_budgets', '0 15 * * *', $$
  INSERT INTO ai_daily_budgets (provider, budget_date, max_calls) VALUES
    ('cerebras', CURRENT_DATE, 150),
    ('groq', CURRENT_DATE, 50),
    ('gemini', CURRENT_DATE, 30)
  ON CONFLICT (provider, budget_date) DO UPDATE SET
    used_calls = 0,
    used_tokens_estimated = 0,
    is_exhausted = false,
    updated_at = NOW();
$$);
