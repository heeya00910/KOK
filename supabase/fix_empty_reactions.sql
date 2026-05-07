DELETE FROM articles
WHERE id IN (
  SELECT DISTINCT a.id
  FROM articles a
  JOIN top_reactions tr ON tr.article_id = a.id
  WHERE tr.content_en = '' AND tr.content_es = ''
);
