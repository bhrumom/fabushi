-- 添加排行榜功能所需的字段
-- 执行日期: 2025-11-04

-- 添加总传输字节数字段
ALTER TABLE users ADD COLUMN total_transferred_bytes INTEGER DEFAULT 0;

-- 添加最后传输时间字段
ALTER TABLE users ADD COLUMN last_transfer_at TEXT;

-- 验证字段已添加
-- SELECT username, total_transferred_bytes, last_transfer_at FROM users LIMIT 5;
