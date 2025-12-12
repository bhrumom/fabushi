-- 修行记录系统数据库Schema
-- 创建日期: 2025-12-11

-- 修行记录表
CREATE TABLE IF NOT EXISTS meditation_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL,
  sutra_name TEXT NOT NULL,           -- 功课名称（经文名或自定义名称）
  sutra_source TEXT DEFAULT 'custom', -- 来源: 'asset' 从素材库选择, 'custom' 手动输入
  duration INTEGER DEFAULT 0,          -- 修行时长（分钟）
  chant_count INTEGER DEFAULT 0,       -- 念诵/修行遍数
  record_date TEXT NOT NULL,           -- 记录日期 (YYYY-MM-DD)
  is_manual INTEGER DEFAULT 0,         -- 是否手动补录 0-实时记录 1-补录
  notes TEXT,                          -- 修行备注
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_meditation_records_username ON meditation_records(username);
CREATE INDEX IF NOT EXISTS idx_meditation_records_date ON meditation_records(record_date);
CREATE INDEX IF NOT EXISTS idx_meditation_records_sutra ON meditation_records(sutra_name);

-- 修行目标/发愿表
CREATE TABLE IF NOT EXISTS meditation_goals (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL,
  sutra_name TEXT NOT NULL,            -- 功课名称
  target_count INTEGER NOT NULL,       -- 发愿目标数量（部数）
  current_count INTEGER DEFAULT 0,     -- 当前已完成数量
  dedication TEXT,                     -- 回向文
  status TEXT DEFAULT 'active',        -- 状态: active/completed/abandoned
  created_at TEXT NOT NULL,
  updated_at TEXT,
  completed_at TEXT                    -- 完成时间
);

CREATE INDEX IF NOT EXISTS idx_meditation_goals_username ON meditation_goals(username);
CREATE INDEX IF NOT EXISTS idx_meditation_goals_status ON meditation_goals(status);

-- 用户修行设置表
CREATE TABLE IF NOT EXISTS meditation_settings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  default_sutra TEXT,                  -- 默认功课
  default_duration INTEGER DEFAULT 30, -- 默认修行时长（分钟）
  reminder_enabled INTEGER DEFAULT 0,  -- 是否开启提醒
  reminder_time TEXT,                  -- 提醒时间 (HH:MM)
  created_at TEXT NOT NULL,
  updated_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_meditation_settings_username ON meditation_settings(username);
