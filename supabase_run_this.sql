-- ============================================================
-- KOK Supabase 전체 SQL — Supabase SQL Editor에 복사 후 실행
-- ============================================================

-- ── 1. 테이블 ──

CREATE TABLE IF NOT EXISTS articles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  issue_title_en TEXT NOT NULL,
  issue_title_es TEXT NOT NULL,
  what_happened_en TEXT NOT NULL,
  what_happened_es TEXT NOT NULL,
  why_it_matters_en TEXT NOT NULL,
  why_it_matters_es TEXT NOT NULL,
  korean_reaction_summary_en TEXT NOT NULL,
  korean_reaction_summary_es TEXT NOT NULL,
  context_for_fans_en TEXT NOT NULL,
  context_for_fans_es TEXT NOT NULL,
  image_url TEXT DEFAULT '',
  issue_tags TEXT[] DEFAULT '{}',
  artist_tags TEXT[] DEFAULT '{}',
  sentiment TEXT DEFAULT 'neutral',
  reaction_sample_size INT DEFAULT 0,
  view_count INT DEFAULT 0,
  safety_level TEXT DEFAULT 'safe',
  source_url_hash TEXT UNIQUE,
  published_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_articles_published ON articles(published_at DESC);
CREATE INDEX IF NOT EXISTS idx_articles_tags ON articles USING GIN(issue_tags);
CREATE INDEX IF NOT EXISTS idx_articles_artists ON articles USING GIN(artist_tags);

CREATE TABLE IF NOT EXISTS top_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  content_en TEXT NOT NULL,
  content_es TEXT NOT NULL,
  likes INT DEFAULT 0,
  source TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_reactions_article ON top_reactions(article_id);

CREATE TABLE IF NOT EXISTS source_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  type TEXT DEFAULT 'article'
);
CREATE INDEX IF NOT EXISTS idx_sources_article ON source_links(article_id);

CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nickname TEXT DEFAULT '',
  nationality TEXT DEFAULT '',
  favorite_tags TEXT[] DEFAULT '{}',
  role TEXT DEFAULT 'user',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  nickname TEXT NOT NULL,
  nationality TEXT DEFAULT '',
  fandom TEXT DEFAULT '',
  content TEXT NOT NULL,
  likes INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  edited_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_comments_article ON user_comments(article_id);
CREATE INDEX IF NOT EXISTS idx_comments_user ON user_comments(user_id);

CREATE TABLE IF NOT EXISTS processed_urls (
  url_hash TEXT PRIMARY KEY,
  original_url TEXT NOT NULL,
  processed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pipeline_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  candidates_found INT DEFAULT 0,
  articles_generated INT DEFAULT 0,
  articles_blocked INT DEFAULT 0,
  groq_calls INT DEFAULT 0,
  gemini_calls INT DEFAULT 0,
  status TEXT DEFAULT 'running',
  error_message TEXT
);

-- ── 2. RPC Functions ──

CREATE OR REPLACE FUNCTION increment_comment_likes(comment_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE user_comments SET likes = likes + 1 WHERE id = comment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION increment_view_count(article_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE articles SET view_count = view_count + 1 WHERE id = article_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION admin_delete_comment(target_comment_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  DELETE FROM user_comments WHERE id = target_comment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_delete_article(target_article_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  DELETE FROM articles WHERE id = target_article_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION can_run_pipeline()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN NOT EXISTS (
    SELECT 1 FROM pipeline_runs
    WHERE status = 'running' AND started_at > NOW() - INTERVAL '30 minutes'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- 파이프라인 기사 삽입 (관리자 전용, RLS 우회)
-- 기사 + top_reactions + source_links 한 번에 저장
CREATE OR REPLACE FUNCTION insert_pipeline_article(article_data JSONB)
RETURNS UUID AS $$
DECLARE
  new_id UUID;
  reaction JSONB;
  src JSONB;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;

  INSERT INTO articles (
    issue_title_en, issue_title_es,
    what_happened_en, what_happened_es,
    why_it_matters_en, why_it_matters_es,
    korean_reaction_summary_en, korean_reaction_summary_es,
    context_for_fans_en, context_for_fans_es,
    image_url, issue_tags, artist_tags,
    sentiment, reaction_sample_size, safety_level
  ) VALUES (
    article_data->>'issue_title_en', article_data->>'issue_title_es',
    article_data->>'what_happened_en', article_data->>'what_happened_es',
    article_data->>'why_it_matters_en', article_data->>'why_it_matters_es',
    article_data->>'korean_reaction_summary_en', article_data->>'korean_reaction_summary_es',
    article_data->>'context_for_fans_en', article_data->>'context_for_fans_es',
    COALESCE(article_data->>'image_url', ''),
    COALESCE(ARRAY(SELECT jsonb_array_elements_text(article_data->'issue_tags')), '{}'),
    COALESCE(ARRAY(SELECT jsonb_array_elements_text(article_data->'artist_tags')), '{}'),
    COALESCE(article_data->>'sentiment', 'neutral'),
    COALESCE((article_data->>'reaction_sample_size')::INT, 0),
    COALESCE(article_data->>'safety_level', 'safe')
  ) RETURNING id INTO new_id;

  -- top_reactions 삽입
  IF article_data ? 'top_reactions' AND jsonb_typeof(article_data->'top_reactions') = 'array' THEN
    FOR reaction IN SELECT * FROM jsonb_array_elements(article_data->'top_reactions')
    LOOP
      INSERT INTO top_reactions (article_id, content_en, content_es, likes, source)
      VALUES (
        new_id,
        COALESCE(reaction->>'content_en', ''),
        COALESCE(reaction->>'content_es', ''),
        COALESCE((reaction->>'likes')::INT, 0),
        COALESCE(reaction->>'source', '')
      );
    END LOOP;
  END IF;

  -- source_links 삽입
  IF article_data ? 'original_sources' AND jsonb_typeof(article_data->'original_sources') = 'array' THEN
    FOR src IN SELECT * FROM jsonb_array_elements(article_data->'original_sources')
    LOOP
      INSERT INTO source_links (article_id, title, url, type)
      VALUES (
        new_id,
        COALESCE(src->>'title', ''),
        COALESCE(src->>'url', ''),
        COALESCE(src->>'type', 'article')
      );
    END LOOP;
  END IF;

  RETURN new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 3. 관리자 자동 설정 (heeya00910@gmail.com) ──

CREATE OR REPLACE FUNCTION auto_assign_admin()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM auth.users WHERE id = NEW.id AND email = 'heeya00910@gmail.com'
  ) THEN
    NEW.role := 'admin';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS set_admin_on_profile_insert ON profiles;
CREATE TRIGGER set_admin_on_profile_insert
BEFORE INSERT ON profiles
FOR EACH ROW EXECUTE FUNCTION auto_assign_admin();

-- 이미 존재하는 프로필에 관리자 즉시 적용 (1회만 실행하면 됨)
UPDATE profiles SET role = 'admin'
WHERE id IN (SELECT id FROM auth.users WHERE email = 'heeya00910@gmail.com')
  AND role != 'admin';

-- ── 4. 7일 지난 기사 자동 삭제 함수 ──

CREATE OR REPLACE FUNCTION cleanup_old_articles()
RETURNS INT AS $$
DECLARE
  deleted_count INT;
BEGIN
  DELETE FROM articles WHERE published_at < NOW() - INTERVAL '14 days';
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- pg_cron 자동 삭제 (Supabase에서 pg_cron 확장 활성화 필요)
-- Database > Extensions > pg_cron 검색 후 Enable
-- 그 다음 아래 실행:

-- SELECT cron.schedule(
--   'cleanup-old-kok-articles',
--   '0 */6 * * *',
--   $$ SELECT cleanup_old_articles(); $$
-- );

-- ── 5. Row Level Security ──

ALTER TABLE articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE top_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE source_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE processed_urls ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_runs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  -- Articles
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Articles viewable by everyone') THEN
    CREATE POLICY "Articles viewable by everyone" ON articles FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins insert articles') THEN
    CREATE POLICY "Admins insert articles" ON articles FOR INSERT WITH CHECK (is_admin());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins update articles') THEN
    CREATE POLICY "Admins update articles" ON articles FOR UPDATE USING (is_admin());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins delete articles') THEN
    CREATE POLICY "Admins delete articles" ON articles FOR DELETE USING (is_admin());
  END IF;

  -- Reactions
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Reactions viewable') THEN
    CREATE POLICY "Reactions viewable" ON top_reactions FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins manage reactions') THEN
    CREATE POLICY "Admins manage reactions" ON top_reactions FOR ALL USING (is_admin());
  END IF;

  -- Source links
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Sources viewable') THEN
    CREATE POLICY "Sources viewable" ON source_links FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins manage sources') THEN
    CREATE POLICY "Admins manage sources" ON source_links FOR ALL USING (is_admin());
  END IF;

  -- Profiles
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'View own profile') THEN
    CREATE POLICY "View own profile" ON profiles FOR SELECT USING (auth.uid() = id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Update own profile') THEN
    CREATE POLICY "Update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Insert own profile') THEN
    CREATE POLICY "Insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
  END IF;

  -- Comments
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Comments viewable') THEN
    CREATE POLICY "Comments viewable" ON user_comments FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Auth users insert comments') THEN
    CREATE POLICY "Auth users insert comments" ON user_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Update own comments') THEN
    CREATE POLICY "Update own comments" ON user_comments FOR UPDATE USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Delete own comments') THEN
    CREATE POLICY "Delete own comments" ON user_comments FOR DELETE USING (auth.uid() = user_id);
  END IF;

  -- Processed URLs
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Read processed urls') THEN
    CREATE POLICY "Read processed urls" ON processed_urls FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins manage urls') THEN
    CREATE POLICY "Admins manage urls" ON processed_urls FOR ALL USING (is_admin());
  END IF;

  -- Pipeline runs
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Read pipeline runs') THEN
    CREATE POLICY "Read pipeline runs" ON pipeline_runs FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins manage runs') THEN
    CREATE POLICY "Admins manage runs" ON pipeline_runs FOR ALL USING (is_admin());
  END IF;
END $$;

-- ── Chart: 아티스트 차트 테이블 ──

CREATE TABLE IF NOT EXISTS chart_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  artist_name TEXT NOT NULL,
  week_start DATE NOT NULL DEFAULT (date_trunc('week', NOW() AT TIME ZONE 'Asia/Seoul'))::date,
  voted_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chart_votes_week ON chart_votes(week_start, artist_name);
CREATE INDEX IF NOT EXISTS idx_chart_votes_user ON chart_votes(user_id, week_start);

ALTER TABLE chart_votes ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Read chart votes') THEN
    CREATE POLICY "Read chart votes" ON chart_votes FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users vote') THEN
    CREATE POLICY "Users vote" ON chart_votes FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- 이번 주 차트 순위 조회 함수
CREATE OR REPLACE FUNCTION get_weekly_chart()
RETURNS TABLE(artist_name TEXT, vote_count BIGINT, rank BIGINT) AS $$
BEGIN
  RETURN QUERY
  SELECT
    cv.artist_name,
    COUNT(*)::BIGINT AS vote_count,
    RANK() OVER (ORDER BY COUNT(*) DESC)::BIGINT AS rank
  FROM chart_votes cv
  WHERE cv.week_start = (date_trunc('week', NOW() AT TIME ZONE 'Asia/Seoul'))::date
  GROUP BY cv.artist_name
  ORDER BY vote_count DESC
  LIMIT 50;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 오늘 투표 횟수 조회 (기본 1회 + 광고 보너스)
CREATE OR REPLACE FUNCTION get_today_vote_count(p_user_id UUID)
RETURNS INT AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INT FROM chart_votes
    WHERE user_id = p_user_id
    AND (voted_at AT TIME ZONE 'Asia/Seoul')::date = (NOW() AT TIME ZONE 'Asia/Seoul')::date
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 투표 실행 (max_votes = 1 + 광고 보너스)
CREATE OR REPLACE FUNCTION cast_chart_vote(p_artist_name TEXT, p_max_votes INT DEFAULT 1)
RETURNS BOOLEAN AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_today DATE := (NOW() AT TIME ZONE 'Asia/Seoul')::date;
  v_week_start DATE := (date_trunc('week', NOW() AT TIME ZONE 'Asia/Seoul'))::date;
  v_count INT;
BEGIN
  IF v_user_id IS NULL THEN RETURN FALSE; END IF;

  SELECT COUNT(*)::INT INTO v_count FROM chart_votes
  WHERE user_id = v_user_id
  AND (voted_at AT TIME ZONE 'Asia/Seoul')::date = v_today;

  IF v_count >= p_max_votes THEN RETURN FALSE; END IF;

  INSERT INTO chart_votes (user_id, artist_name, week_start)
  VALUES (v_user_id, p_artist_name, v_week_start);

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Artist Chat Board ──

CREATE TABLE IF NOT EXISTS artist_chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_name TEXT NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  nickname TEXT NOT NULL DEFAULT 'Anonymous',
  nationality TEXT NOT NULL DEFAULT '',
  fandom TEXT NOT NULL DEFAULT '',
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_artist_chats_artist ON artist_chats(artist_name, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_artist_chats_cleanup ON artist_chats(created_at);

ALTER TABLE artist_chats ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Read artist chats') THEN
    CREATE POLICY "Read artist chats" ON artist_chats FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users send chat') THEN
    CREATE POLICY "Users send chat" ON artist_chats FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users delete own chat') THEN
    CREATE POLICY "Users delete own chat" ON artist_chats FOR DELETE USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users update own chat') THEN
    CREATE POLICY "Users update own chat" ON artist_chats FOR UPDATE USING (auth.uid() = user_id);
  END IF;
END $$;

-- 24시간 롤링 윈도우 + 아티스트당 300개 제한
CREATE OR REPLACE FUNCTION cleanup_old_chats()
RETURNS void AS $$
BEGIN
  DELETE FROM artist_chats WHERE created_at < NOW() - INTERVAL '24 hours';

  DELETE FROM artist_chats WHERE id IN (
    SELECT id FROM (
      SELECT id, ROW_NUMBER() OVER (PARTITION BY artist_name ORDER BY created_at DESC) AS rn
      FROM artist_chats
    ) sub WHERE rn > 300
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════
-- 신고(Report) 시스템
-- ═══════════════════════════════════

CREATE TABLE IF NOT EXISTS chat_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL,
  reporter_id UUID NOT NULL,
  reason TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS comment_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id TEXT NOT NULL,
  reporter_id UUID NOT NULL,
  reason TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed BOOLEAN NOT NULL DEFAULT false
);

ALTER TABLE chat_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE comment_reports ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users create chat reports') THEN
    CREATE POLICY "Users create chat reports" ON chat_reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users create comment reports') THEN
    CREATE POLICY "Users create comment reports" ON comment_reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
  END IF;
END $$;
