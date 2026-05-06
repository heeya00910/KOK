# KOK Pipeline Deployment Guide

## 1. Install Supabase CLI

```powershell
npm install -g supabase
```

## 2. Login & Link Project

```powershell
supabase login
supabase link --project-ref lwetcjkgspurlhyfufbz
```

## 3. Run Database Migration

Go to Supabase Dashboard → SQL Editor → paste contents of:
```
supabase/migrations/001_pipeline_schema.sql
```

## 4. Set Edge Function Secrets

```powershell
supabase secrets set CEREBRAS_API_KEY=your_key
supabase secrets set GROQ_API_KEY=your_key
supabase secrets set GEMINI_API_KEY=your_key
supabase secrets set NAVER_CLIENT_ID=your_id
supabase secrets set NAVER_CLIENT_SECRET=your_secret
supabase secrets set YOUTUBE_API_KEY=your_key
```

## 5. Deploy Edge Function

```powershell
supabase functions deploy kok-pipeline --no-verify-jwt
```

The `--no-verify-jwt` flag allows pg_cron to call it without auth headers.
For production, use service_role_key in the cron job headers instead.

## 6. Set up pg_cron Scheduling

Go to Supabase Dashboard → SQL Editor → Enable extensions:
1. Enable `pg_cron` extension
2. Enable `pg_net` extension

Then set the app settings (replace with your actual values):
```sql
ALTER DATABASE postgres SET app.settings.supabase_url = 'https://lwetcjkgspurlhyfufbz.supabase.co';
ALTER DATABASE postgres SET app.settings.service_role_key = 'your_service_role_key';
```

Then paste and run:
```
supabase/schedule.sql
```

## 7. Test the Pipeline

Test individual stages:
```powershell
curl -X POST https://lwetcjkgspurlhyfufbz.supabase.co/functions/v1/kok-pipeline -H "Content-Type: application/json" -d "{\"stage\":\"collect_pann\"}"
```

Test full pipeline:
```powershell
curl -X POST https://lwetcjkgspurlhyfufbz.supabase.co/functions/v1/kok-pipeline -H "Content-Type: application/json" -d "{\"stage\":\"full\"}"
```

## 8. Monitor

Check pipeline runs:
```sql
SELECT * FROM pipeline_runs ORDER BY started_at DESC LIMIT 10;
```

Check AI budgets:
```sql
SELECT * FROM ai_daily_budgets WHERE budget_date = CURRENT_DATE;
```

Check generated cards:
```sql
SELECT * FROM kok_cards WHERE status = 'published' ORDER BY published_at DESC;
```

## Pipeline Schedule (KST)

| Stage | Time (KST) | Frequency |
|---|---|---|
| Nate Pann | 06,09,12,15,18,21 | 6x/day |
| TheQoo Square | 07,10,13,16,19,22 | 6x/day |
| TheQoo Ktalk | 10:00, 15:00, 21:00 | 3x/day |
| Nate Ent | 08,12,17,21 | 4x/day |
| YouTube | 11:00, 23:00 | 2x/day |
| Keyword Extract | after collection | 3x/day |
| Build Clusters | after keywords | 3x/day |
| Filter Clusters | after clusters | 3x/day |
| Naver Validate | 10:00, 19:00 | 2x/day |
| Cerebras Screen | 10,16,22 | 3x/day |
| Groq Analyze | 10:30,16:30,22:30 | 3x/day |
| Gemini Generate | 11,17,23 | 3x/day |
| Cleanup | 03:00 | 1x/day |
| Budget Reset | 00:00 | 1x/day |

## Daily Budget (Free Tier Safe)

| Provider | Daily Limit | Free Tier Actual | Usage per Card |
|---|---|---|---|
| Cerebras | 100 calls | ~unlimited | ~1 call |
| Groq | 50 calls | ~14,400/day | ~1 call |
| Gemini | 30 calls | ~1,500/day | ~1 call |

**No card limit** — every cluster passing quality filters gets published.
