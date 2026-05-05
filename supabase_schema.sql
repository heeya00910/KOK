-- ============================================================
-- KOK Supabase Schema (v2)
-- 댓글 수정/삭제, 관리자 시스템, 스케줄링 충돌방지 포함
-- ============================================================

-- ── 1. Articles (AI 파이프라인이 생성) ──

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

-- ── 2. Top reactions (번역된 한국인 반응) ──

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

-- ── 3. Original source links ──

CREATE TABLE IF NOT EXISTS source_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  type TEXT DEFAULT 'article'
);

CREATE INDEX IF NOT EXISTS idx_sources_article ON source_links(article_id);

-- ── 4. User profiles (role 컬럼 추가: 'user' | 'admin') ──

CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nickname TEXT DEFAULT '',
  nationality TEXT DEFAULT '',
  favorite_tags TEXT[] DEFAULT '{}',
  role TEXT DEFAULT 'user',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 5. User comments (edited_at 컬럼 추가) ──

CREATE TABLE IF NOT EXISTS user_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  nickname TEXT NOT NULL,
  content TEXT NOT NULL,
  likes INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  edited_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_comments_article ON user_comments(article_id);
CREATE INDEX IF NOT EXISTS idx_comments_user ON user_comments(user_id);

-- ── 6. Processed URL hashes (중복 처리 방지) ──

CREATE TABLE IF NOT EXISTS processed_urls (
  url_hash TEXT PRIMARY KEY,
  original_url TEXT NOT NULL,
  processed_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 7. Pipeline runs (실행 로그 + 충돌 방지) ──

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

-- ============================================================
-- RPC Functions
-- ============================================================

-- 댓글 좋아요
CREATE OR REPLACE FUNCTION increment_comment_likes(comment_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE user_comments SET likes = likes + 1 WHERE id = comment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 기사 조회수
CREATE OR REPLACE FUNCTION increment_view_count(article_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE articles SET view_count = view_count + 1 WHERE id = article_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 관리자 여부 확인 헬퍼
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- 관리자: 댓글 삭제 (RLS 우회)
CREATE OR REPLACE FUNCTION admin_delete_comment(target_comment_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Permission denied: admin only';
  END IF;
  DELETE FROM user_comments WHERE id = target_comment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 관리자: 기사 삭제 (RLS 우회)
CREATE OR REPLACE FUNCTION admin_delete_article(target_article_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Permission denied: admin only';
  END IF;
  DELETE FROM articles WHERE id = target_article_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 파이프라인 충돌 방지: 최근 30분 내 running 상태가 있으면 실행 불가
CREATE OR REPLACE FUNCTION can_run_pipeline()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN NOT EXISTS (
    SELECT 1 FROM pipeline_runs
    WHERE status = 'running'
      AND started_at > NOW() - INTERVAL '30 minutes'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ============================================================
-- Row Level Security
-- ============================================================

ALTER TABLE articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE top_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE source_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE processed_urls ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_runs ENABLE ROW LEVEL SECURITY;

-- Articles: 모두 읽기 가능, 관리자만 수정/삭제
CREATE POLICY "Articles are viewable by everyone"
  ON articles FOR SELECT USING (true);

CREATE POLICY "Admins can insert articles"
  ON articles FOR INSERT WITH CHECK (is_admin());

CREATE POLICY "Admins can update articles"
  ON articles FOR UPDATE USING (is_admin());

CREATE POLICY "Admins can delete articles"
  ON articles FOR DELETE USING (is_admin());

-- Reactions: 모두 읽기 가능
CREATE POLICY "Reactions are viewable by everyone"
  ON top_reactions FOR SELECT USING (true);

CREATE POLICY "Admins can manage reactions"
  ON top_reactions FOR ALL USING (is_admin());

-- Source links: 모두 읽기 가능
CREATE POLICY "Sources are viewable by everyone"
  ON source_links FOR SELECT USING (true);

CREATE POLICY "Admins can manage source links"
  ON source_links FOR ALL USING (is_admin());

-- Profiles: 본인 읽기/수정, role 컬럼은 관리자만 변경 가능
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Comments: 모두 읽기, 본인만 쓰기/수정, 본인+관리자 삭제
CREATE POLICY "Comments are viewable by everyone"
  ON user_comments FOR SELECT USING (true);

CREATE POLICY "Authenticated users can insert comments"
  ON user_comments FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own comments"
  ON user_comments FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own comments"
  ON user_comments FOR DELETE USING (auth.uid() = user_id);

-- Processed URLs: 관리자/서비스 롤만
CREATE POLICY "Admins can manage processed urls"
  ON processed_urls FOR ALL USING (is_admin());

CREATE POLICY "Anyone can read processed urls"
  ON processed_urls FOR SELECT USING (true);

-- Pipeline runs: 관리자/서비스 롤만
CREATE POLICY "Admins can manage pipeline runs"
  ON pipeline_runs FOR ALL USING (is_admin());

CREATE POLICY "Anyone can read pipeline runs"
  ON pipeline_runs FOR SELECT USING (true);

-- ============================================================
-- 관리자 계정 설정 (최초 1회: 본인 Supabase user ID로 교체)
-- ============================================================

-- ── 관리자 자동 설정 (heeya00910@gmail.com 로그인 시) ──

CREATE OR REPLACE FUNCTION auto_assign_admin()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = NEW.id
      AND email = 'heeya00910@gmail.com'
  ) THEN
    NEW.role := 'admin';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS set_admin_on_profile_insert ON profiles;
CREATE TRIGGER set_admin_on_profile_insert
BEFORE INSERT ON profiles
FOR EACH ROW
EXECUTE FUNCTION auto_assign_admin();

-- 이미 프로필이 있는 경우 수동 설정:
-- UPDATE profiles SET role = 'admin'
-- WHERE id = (SELECT id FROM auth.users WHERE email = 'heeya00910@gmail.com');

-- ── 댓글에 국적/팬덤 컬럼 추가 ──

ALTER TABLE user_comments ADD COLUMN IF NOT EXISTS nationality TEXT DEFAULT '';
ALTER TABLE user_comments ADD COLUMN IF NOT EXISTS fandom TEXT DEFAULT '';

-- ── 파이프라인: 인증된 사용자도 기사 삽입 가능 (관리자 실행용) ──

CREATE OR REPLACE FUNCTION insert_pipeline_article(article_data JSONB)
RETURNS UUID AS $$
DECLARE
  new_id UUID;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Permission denied: admin only';
  END IF;

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

  RETURN new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
