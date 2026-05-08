async function safeRun(db, sql, ...params) {
  try {
    await db.prepare(sql).bind(...params).run();
  } catch (error) {
    console.warn('账户资料引用更新跳过:', error?.message || error);
  }
}

export class AccountUserRepository {
  constructor(db) {
    this.db = db;
  }

  async getByUsername(username) {
    return await this.db.getUser(username);
  }

  async getById(userId) {
    if (!this.db.getUserById) return null;
    return await this.db.getUserById(userId);
  }

  async getByEmail(email) {
    return await this.db.getUserByEmail(email);
  }

  async getByPhone(phoneNumber) {
    return await this.db.getUserByPhone(phoneNumber);
  }

  async createRegisteredUser(user) {
    return await this.db.createUser(user);
  }

  async resolveTokenUser(tokenData) {
    if (tokenData?.userId !== undefined && tokenData?.userId !== null && this.db.getUserById) {
      const user = await this.db.getUserById(tokenData.userId);
      if (user) return user;
    }
    if (tokenData?.username) {
      return await this.db.getUser(tokenData.username);
    }
    return null;
  }

  async updateById(userId, updates) {
    const fields = Object.keys(updates);
    if (!fields.length) return;

    const assignments = fields.map((key) => `${key} = ?`).join(', ');
    const values = fields.map((key) => updates[key]);
    await this.db.prepare(`UPDATE users SET ${assignments}, updated_at = ? WHERE id = ?`)
      .bind(...values, new Date().toISOString(), Number(userId))
      .run();
  }

  async replaceEmailMapping({ userId, username, oldEmail, newEmail }) {
    if (oldEmail) {
      await safeRun(this.db, 'DELETE FROM email_username_mapping WHERE email = ?', oldEmail.toLowerCase());
    }
    if (userId !== undefined && userId !== null) {
      await safeRun(this.db, 'DELETE FROM email_username_mapping WHERE user_id = ?', userId);
    }
    if (newEmail) {
      await safeRun(
        this.db,
        'INSERT OR REPLACE INTO email_username_mapping (email, username, user_id) VALUES (?, ?, ?)',
        newEmail,
        username,
        userId
      );
    }
  }

  async withTransaction(action) {
    await this.db.prepare('BEGIN TRANSACTION').run();
    try {
      const result = await action();
      await this.db.prepare('COMMIT').run();
      return result;
    } catch (error) {
      try {
        await this.db.prepare('ROLLBACK').run();
      } catch (rollbackError) {
        console.warn('账户事务回滚失败:', rollbackError?.message || rollbackError);
      }
      throw error;
    }
  }

  async deleteAccountArtifacts({ userId, username, email }) {
    const normalizedEmail = String(email || '').trim().toLowerCase();
    const resolvedUserId = userId ?? username;
    const deletions = [
      ['DELETE FROM meditation_group_members WHERE group_id IN (SELECT id FROM meditation_groups WHERE owner_username = ?)', username],
      ['DELETE FROM meditation_groups WHERE owner_username = ?', username],
      ['DELETE FROM meditation_group_members WHERE username = ?', username],
      ['DELETE FROM meditation_records WHERE username = ?', username],
      ['DELETE FROM meditation_goals WHERE username = ?', username],
      ['DELETE FROM meditation_settings WHERE username = ?', username],
      ['DELETE FROM user_practice_privacy WHERE username = ?', username],
      ['DELETE FROM user_follows WHERE follower_username = ? OR following_username = ?', username, username],
      ['DELETE FROM notifications WHERE username = ? OR related_username = ?', username, username],
      ['DELETE FROM sync_log WHERE username = ?', username],
      ['DELETE FROM user_sync_state WHERE username = ?', username],
      ['DELETE FROM comments WHERE user_id = ? OR username = ?', resolvedUserId, username],
      ['DELETE FROM likes WHERE username = ?', username],
      ['DELETE FROM favorites WHERE username = ?', username],
      ['DELETE FROM content_likes WHERE user_id = ? OR username = ?', resolvedUserId, username],
      ['DELETE FROM content_favorites WHERE username = ?', username],
      ['DELETE FROM content_reports WHERE reporter_user_id = ?', resolvedUserId],
      ['DELETE FROM user_blocks WHERE blocked_user_id = ?', resolvedUserId],
      ['DELETE FROM email_username_mapping WHERE username = ?', username],
    ];

    if (normalizedEmail) {
      deletions.push(['DELETE FROM email_username_mapping WHERE email = ?', normalizedEmail]);
    }

    for (const [sql, ...params] of deletions) {
      await safeRun(this.db, sql, ...params);
    }
  }

  async deleteByUsername(username) {
    if (this.db.deleteUser) {
      return await this.db.deleteUser(username);
    }
    return await this.db.prepare('DELETE FROM users WHERE username = ?').bind(username).run();
  }
}
