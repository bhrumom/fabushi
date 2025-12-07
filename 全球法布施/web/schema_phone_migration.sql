-- D1 Database Migration: Add phone authentication fields
-- Migration date: 2025-12-07
-- Description: Support Firebase phone authentication for Douyin-style login

-- Add phone_number column to users table
ALTER TABLE users ADD COLUMN phone_number TEXT;

-- Add firebase_uid column to users table
ALTER TABLE users ADD COLUMN firebase_uid TEXT;

-- Create indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone_number);
CREATE INDEX IF NOT EXISTS idx_users_firebase_uid ON users(firebase_uid);

-- Note: Run this migration using Cloudflare Wrangler:
-- wrangler d1 execute global-dharma-db --file=./schema_phone_migration.sql
