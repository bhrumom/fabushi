-- 添加video_title字段到comments表，用于存储原视频标题
ALTER TABLE comments ADD COLUMN video_title TEXT;
