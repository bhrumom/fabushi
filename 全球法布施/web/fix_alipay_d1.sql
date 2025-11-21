-- 添加支付宝相关字段到 users 表（如果不存在）
-- 注意：SQLite 不支持 IF NOT EXISTS 在 ALTER TABLE 中，如果字段已存在会报错但不影响后续操作
ALTER TABLE users ADD COLUMN alipay_open_id TEXT;
ALTER TABLE users ADD COLUMN alipay_avatar TEXT;

-- 创建支付宝绑定表（如果不存在）
CREATE TABLE IF NOT EXISTS alipay_bindings (
  alipay_user_id TEXT PRIMARY KEY,
  username TEXT NOT NULL,
  bound_at TEXT NOT NULL,
  FOREIGN KEY (username) REFERENCES users(username)
);

-- 创建支付宝 state 表（用于验证登录回调）
CREATE TABLE IF NOT EXISTS alipay_states (
  state TEXT PRIMARY KEY,
  state_data TEXT NOT NULL,
  expires_at TEXT NOT NULL
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_alipay_bindings_username ON alipay_bindings(username);
CREATE INDEX IF NOT EXISTS idx_users_alipay_user_id ON users(alipay_user_id);
CREATE INDEX IF NOT EXISTS idx_alipay_states_expires ON alipay_states(expires_at);
