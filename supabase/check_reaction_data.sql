SELECT tr.id, tr.article_id, tr.source, tr.likes, tr.content_en, tr.content_es
FROM top_reactions tr
JOIN articles a ON a.id = tr.article_id
WHERE a.content_type = 'KOREAN_COMMENT_MOOD'
ORDER BY tr.created_at DESC
LIMIT 10;
