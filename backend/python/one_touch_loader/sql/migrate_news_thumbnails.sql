ALTER TABLE news_articles
  ADD COLUMN thumbnail_digest CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER image_url;
