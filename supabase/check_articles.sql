SELECT id, content_type, label_en, issue_title_en, 
       CASE WHEN image_url IS NOT NULL AND image_url != '' THEN 'YES' ELSE 'NO' END as has_image,
       confidence_level, published_at
FROM articles
ORDER BY published_at DESC
LIMIT 8;
