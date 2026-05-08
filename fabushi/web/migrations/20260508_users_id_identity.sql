-- Migrate user relations away from editable/display usernames.
-- `users.id` is the canonical account identity. Legacy username columns remain
-- for read/display compatibility only and must not be used as relationship keys.

-- Mapping tables
ALTER TABLE email_username_mapping ADD COLUMN user_id INTEGER;
UPDATE email_username_mapping
SET user_id = (SELECT id FROM users WHERE users.username = email_username_mapping.username)
WHERE user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_email_username_mapping_user_id ON email_username_mapping(user_id);

ALTER TABLE alipay_bindings ADD COLUMN user_id INTEGER;
UPDATE alipay_bindings
SET user_id = (SELECT id FROM users WHERE users.username = alipay_bindings.username)
WHERE user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_alipay_bindings_user_id ON alipay_bindings(user_id);

-- Payment / entitlement tables
ALTER TABLE orders ADD COLUMN account_user_id INTEGER;
UPDATE orders
SET account_user_id = (SELECT id FROM users WHERE users.username = orders.user_id OR users.username = orders.username)
WHERE account_user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_orders_account_user_id ON orders(account_user_id);

ALTER TABLE purchase_history ADD COLUMN user_id INTEGER;
UPDATE purchase_history
SET user_id = (SELECT id FROM users WHERE users.username = purchase_history.username)
WHERE user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_purchase_history_user_id ON purchase_history(user_id);

ALTER TABLE redeem_history ADD COLUMN user_id INTEGER;
UPDATE redeem_history
SET user_id = (SELECT id FROM users WHERE users.username = redeem_history.username)
WHERE user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_redeem_history_user_id ON redeem_history(user_id);

ALTER TABLE memberships ADD COLUMN user_id INTEGER;
UPDATE memberships
SET user_id = (SELECT id FROM users WHERE users.username = memberships.username)
WHERE user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_memberships_user_id ON memberships(user_id);

-- Practice / group tables
ALTER TABLE meditation_records ADD COLUMN user_id INTEGER;
UPDATE meditation_records
SET user_id = (SELECT id FROM users WHERE users.username = meditation_records.username)
WHERE user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_meditation_records_user_id ON meditation_records(user_id);

ALTER TABLE meditation_goals ADD COLUMN user_id INTEGER;
UPDATE meditation_goals
SET user_id = (SELECT id FROM users WHERE users.username = meditation_goals.username)
WHERE user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_meditation_goals_user_id ON meditation_goals(user_id);

ALTER TABLE meditation_settings ADD COLUMN user_id INTEGER;
UPDATE meditation_settings
SET user_id = (SELECT id FROM users WHERE users.username = meditation_settings.username)
WHERE user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_meditation_settings_user_id ON meditation_settings(user_id);

ALTER TABLE meditation_groups ADD COLUMN owner_user_id INTEGER;
UPDATE meditation_groups
SET owner_user_id = (SELECT id FROM users WHERE users.username = meditation_groups.owner_username)
WHERE owner_user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_meditation_groups_owner_user_id ON meditation_groups(owner_user_id);

ALTER TABLE meditation_group_members ADD COLUMN user_id INTEGER;
UPDATE meditation_group_members
SET user_id = (SELECT id FROM users WHERE users.username = meditation_group_members.username)
WHERE user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_meditation_group_members_user_id ON meditation_group_members(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_meditation_group_members_group_user_id ON meditation_group_members(group_id, user_id);

-- Social / notification / sync tables
ALTER TABLE user_follows ADD COLUMN follower_user_id INTEGER;
ALTER TABLE user_follows ADD COLUMN following_user_id INTEGER;
UPDATE user_follows
SET follower_user_id = (SELECT id FROM users WHERE users.username = user_follows.follower_username),
    following_user_id = (SELECT id FROM users WHERE users.username = user_follows.following_username)
WHERE follower_user_id IS NULL OR following_user_id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_follows_user_ids ON user_follows(follower_user_id, following_user_id);

ALTER TABLE notifications ADD COLUMN user_id INTEGER;
ALTER TABLE notifications ADD COLUMN related_user_id INTEGER;
UPDATE notifications
SET user_id = (SELECT id FROM users WHERE users.username = notifications.username),
    related_user_id = (SELECT id FROM users WHERE users.username = notifications.related_username)
WHERE user_id IS NULL OR related_user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_related_user_id ON notifications(related_user_id);

ALTER TABLE sync_log ADD COLUMN user_id INTEGER;
UPDATE sync_log
SET user_id = (SELECT id FROM users WHERE users.username = sync_log.username)
WHERE user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_sync_log_user_id ON sync_log(user_id);

ALTER TABLE user_sync_state ADD COLUMN user_id INTEGER;
UPDATE user_sync_state
SET user_id = (SELECT id FROM users WHERE users.username = user_sync_state.username)
WHERE user_id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_sync_state_user_id ON user_sync_state(user_id);

-- Content / moderation tables
ALTER TABLE comments ADD COLUMN account_user_id INTEGER;
UPDATE comments
SET account_user_id = (SELECT id FROM users WHERE users.username = comments.user_id OR users.username = comments.username)
WHERE account_user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_comments_account_user_id ON comments(account_user_id);

ALTER TABLE likes ADD COLUMN user_id INTEGER;
UPDATE likes
SET user_id = (SELECT id FROM users WHERE users.username = likes.username)
WHERE user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_likes_user_id ON likes(user_id);

ALTER TABLE favorites ADD COLUMN user_id INTEGER;
UPDATE favorites
SET user_id = (SELECT id FROM users WHERE users.username = favorites.username)
WHERE user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);

ALTER TABLE content_likes ADD COLUMN account_user_id INTEGER;
UPDATE content_likes
SET account_user_id = (SELECT id FROM users WHERE users.username = content_likes.user_id OR users.username = content_likes.username)
WHERE account_user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_content_likes_account_user_id ON content_likes(account_user_id);

ALTER TABLE content_favorites ADD COLUMN user_id INTEGER;
UPDATE content_favorites
SET user_id = (SELECT id FROM users WHERE users.username = content_favorites.username)
WHERE user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_content_favorites_user_id ON content_favorites(user_id);

ALTER TABLE content_reports ADD COLUMN reporter_user_id_int INTEGER;
UPDATE content_reports
SET reporter_user_id_int = (SELECT id FROM users WHERE users.username = content_reports.reporter_user_id)
WHERE reporter_user_id_int IS NULL;
CREATE INDEX IF NOT EXISTS idx_content_reports_reporter_user_id_int ON content_reports(reporter_user_id_int);

ALTER TABLE user_blocks ADD COLUMN blocked_user_id_int INTEGER;
UPDATE user_blocks
SET blocked_user_id_int = (SELECT id FROM users WHERE users.username = user_blocks.blocked_user_id)
WHERE blocked_user_id_int IS NULL;
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked_user_id_int ON user_blocks(blocked_user_id_int);
