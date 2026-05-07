SELECT a.id, a.issue_title_en, a.content_type,
  (SELECT count(*) FROM top_reactions tr WHERE tr.article_id = a.id) as reaction_count
FROM articles a
ORDER BY a.published_at DESC
LIMIT 10;
