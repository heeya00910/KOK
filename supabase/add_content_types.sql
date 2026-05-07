ALTER TABLE kok_cards ADD COLUMN IF NOT EXISTS content_type text DEFAULT 'KOK_ISSUE_CARD';
ALTER TABLE kok_cards ADD COLUMN IF NOT EXISTS content_tier text DEFAULT 'heavy';
ALTER TABLE kok_cards ADD COLUMN IF NOT EXISTS verification_level text DEFAULT 'full_validation';
ALTER TABLE kok_cards ADD COLUMN IF NOT EXISTS confidence_level text DEFAULT 'high';
ALTER TABLE kok_cards ADD COLUMN IF NOT EXISTS is_snack boolean DEFAULT false;
ALTER TABLE kok_cards ADD COLUMN IF NOT EXISTS is_evergreen boolean DEFAULT false;
ALTER TABLE kok_cards ADD COLUMN IF NOT EXISTS generation_method text DEFAULT 'gemini';
ALTER TABLE kok_cards ADD COLUMN IF NOT EXISTS ai_cost_level text DEFAULT 'high';
ALTER TABLE kok_cards ADD COLUMN IF NOT EXISTS editorial_notes text;

ALTER TABLE articles ADD COLUMN IF NOT EXISTS content_type text DEFAULT 'KOK_ISSUE_CARD';
ALTER TABLE articles ADD COLUMN IF NOT EXISTS content_tier text DEFAULT 'heavy';
ALTER TABLE articles ADD COLUMN IF NOT EXISTS label_en text DEFAULT 'Issue';
ALTER TABLE articles ADD COLUMN IF NOT EXISTS label_es text DEFAULT 'Tema';
ALTER TABLE articles ADD COLUMN IF NOT EXISTS confidence_level text DEFAULT 'high';
ALTER TABLE articles ADD COLUMN IF NOT EXISTS extra_data jsonb DEFAULT '{}';
