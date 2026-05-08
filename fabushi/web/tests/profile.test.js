import test from 'node:test';
import assert from 'node:assert/strict';

import { generateToken } from '../auth-utils.js';
import { handleUpdateProfile } from '../src/handlers/profile.js';

function createDbMock() {
  const users = new Map();
  const emailMapping = new Map();
  const statements = [];

  const db = {
    users,
    emailMapping,
    statements,
    async getUser(username) {
      const user = users.get(username);
      return user ? { ...user } : null;
    },
    async getUserByEmail(email) {
      const username = emailMapping.get(email);
      if (!username) return null;
      const user = users.get(username);
      return user ? { ...user } : null;
    },
    async getUserByPhone(phoneNumber) {
      for (const user of users.values()) {
        if (user.phone_number === phoneNumber) return { ...user };
      }
      return null;
    },
    prepare(sql) {
      const normalizedSql = sql.trimStart();

      const execute = async (params = []) => {
        statements.push({ sql, params });

        if (params.some((param) => param === undefined)) {
          throw new TypeError("D1_TYPE_ERROR: Type 'undefined' not supported for value 'undefined'");
        }

        if (normalizedSql.startsWith('SELECT * FROM users WHERE username = ?')) {
          const user = users.get(params[0]);
          return user ? { ...user } : null;
        }

        if (normalizedSql.startsWith('SELECT username FROM email_username_mapping WHERE email = ?')) {
          const username = emailMapping.get(params[0]);
          return username ? { username } : null;
        }

        if (normalizedSql.startsWith('SELECT * FROM users WHERE phone_number = ?')) {
          for (const user of users.values()) {
            if (user.phone_number === params[0]) return { ...user };
          }
          return null;
        }

        if (normalizedSql.startsWith('UPDATE users SET')) {
          const username = params.at(-1);
          const user = users.get(username);
          if (!user) return;

          const assignments = normalizedSql
            .slice('UPDATE users SET'.length, normalizedSql.indexOf('WHERE username = ?'))
            .split(',')
            .map((part) => part.trim())
            .filter(Boolean);

          assignments.forEach((assignment, index) => {
            const match = assignment.match(/^([a-zA-Z0-9_]+)\s*=\s*\?$/);
            if (match) {
              user[match[1]] = params[index];
            }
          });
          return;
        }

        if (normalizedSql.startsWith('DELETE FROM email_username_mapping')) {
          emailMapping.delete(params[0]);
          return;
        }

        if (normalizedSql.startsWith('INSERT OR REPLACE INTO email_username_mapping')) {
          emailMapping.set(params[0], params[1]);
        }
      };

      return {
        async run() {
          return execute();
        },
        bind(...params) {
          return {
            async run() {
              return execute(params);
            },
            async first() {
              return execute(params);
            },
            async all() {
              return { results: (await execute(params)) ?? [] };
            }
          };
        },
        first() {
          return execute();
        },
        all() {
          return { results: [] };
        }
      };
    }
  };

  return db;
}

function seedUser(db, username, email, phoneNumber, extra = {}) {
  db.users.set(username, {
    username,
    email,
    password_hash: '',
    salt: '',
    iterations: 0,
    algo: '',
    email_verified: 1,
    alipay_user_id: extra.alipay_user_id ?? null,
    alipay_nickname: null,
    alipay_avatar: null,
    alipay_bound_at: null,
    wechat_openid: null,
    wechat_nickname: null,
    wechat_headimgurl: null,
    wechat_bound_at: null,
    phone_number: phoneNumber,
    firebase_uid: extra.firebase_uid ?? null,
    apple_user_id: null,
    nickname: extra.nickname ?? username,
    avatar: extra.avatar ?? null,
    bio: null,
    main_practice_title: extra.main_practice_title ?? null,
    main_practice_file_path: extra.main_practice_file_path ?? null,
    main_practice_selected_at: extra.main_practice_selected_at ?? null,
    membership_type: 'trial',
    membership_expires_at: null,
    free_trial_end_date: '2026-05-31T00:00:00Z',
    stripe_customer_id: null,
    subscription_id: null,
    total_transferred_bytes: extra.total_transferred_bytes ?? 0,
    last_transfer_at: extra.last_transfer_at ?? null,
    sync_version: extra.sync_version ?? 1,
    extra_data: null,
    created_at: '2026-05-01T00:00:00Z',
    updated_at: '2026-05-04T00:00:00Z'
  });
  db.emailMapping.set(email, username);
}

async function updateProfile(db, username, body) {
  const env = { JWT_SECRET: 'test-secret' };
  const token = await generateToken(username, env);
  const request = new Request('https://flutter.ombhrum.com/api/auth/update-profile', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`
    },
    body: JSON.stringify(body)
  });
  return handleUpdateProfile(request, env, db);
}

test('handleUpdateProfile treats legacy username payload as display name and keeps identity username stable', async () => {
  const db = createDbMock();
  seedUser(db, 'stable_1', 'stable@example.com', '+8613800138000', {
    nickname: '旧昵称',
    firebase_uid: 'firebase-uid-1'
  });

  const response = await updateProfile(db, 'stable_1', {
    username: '新昵称',
    email: 'stable@example.com',
    phoneNumber: '+8613800138000'
  });

  assert.equal(response.status, 200);
  const payload = await response.json();
  assert.equal(payload.success, true);
  assert.equal(payload.user.username, 'stable_1');
  assert.equal(payload.user.nickname, '新昵称');
  assert.equal(payload.token, undefined);

  assert.equal(db.users.has('stable_1'), true);
  assert.equal(db.users.get('stable_1').nickname, '新昵称');
  assert.equal(db.users.get('stable_1').email, 'stable@example.com');
  assert.equal(db.users.get('stable_1').phone_number, '+8613800138000');
  assert.equal(db.emailMapping.get('stable@example.com'), 'stable_1');

  assert.equal(db.statements.some(({ sql }) => sql.trimStart().startsWith('INSERT INTO users')), false);
  assert.equal(db.statements.some(({ sql }) => sql.trimStart().startsWith('DELETE FROM users')), false);
  assert.equal(db.statements.some(({ sql }) => sql.includes('UPDATE users') && sql.includes('username = ?,')), false);
});

test('handleUpdateProfile accepts explicit nickname payload', async () => {
  const db = createDbMock();
  seedUser(db, 'alipay_stable', 'alipay@example.com', null, {
    alipay_user_id: '2088-alipay-user'
  });

  const response = await updateProfile(db, 'alipay_stable', {
    nickname: '千资啊',
    email: 'alipay@example.com',
    phoneNumber: ''
  });

  assert.equal(response.status, 200);
  const payload = await response.json();
  assert.equal(payload.success, true);
  assert.equal(payload.user.username, 'alipay_stable');
  assert.equal(payload.user.nickname, '千资啊');
  assert.equal(db.users.get('alipay_stable').phone_number, null);
});

test('handleUpdateProfile updates email mapping while preserving stable identity', async () => {
  const db = createDbMock();
  seedUser(db, 'email_user', 'old@example.com', '+8613800138111');

  const response = await updateProfile(db, 'email_user', {
    nickname: '邮箱用户',
    email: 'new@example.com',
    phoneNumber: '+8613800138111'
  });

  assert.equal(response.status, 200);
  assert.equal(db.users.get('email_user').email, 'new@example.com');
  assert.equal(db.emailMapping.has('old@example.com'), false);
  assert.equal(db.emailMapping.get('new@example.com'), 'email_user');
  assert.equal(db.users.has('email_user'), true);
});

test('handleUpdateProfile rejects duplicate email without changing identity', async () => {
  const db = createDbMock();
  seedUser(db, 'one', 'one@example.com', '+8613800138222');
  seedUser(db, 'two', 'two@example.com', '+8613800138333');

  const response = await updateProfile(db, 'one', {
    nickname: '用户一',
    email: 'two@example.com',
    phoneNumber: '+8613800138222'
  });

  assert.equal(response.status, 400);
  const payload = await response.json();
  assert.equal(payload.error, '该邮箱已被其他账号使用');
  assert.equal(db.users.get('one').username, 'one');
  assert.equal(db.users.get('one').email, 'one@example.com');
});
