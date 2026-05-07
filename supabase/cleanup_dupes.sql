DELETE FROM articles
WHERE id NOT IN (
  SELECT DISTINCT ON (issue_title_en) id
  FROM articles
  ORDER BY issue_title_en, published_at DESC
);
