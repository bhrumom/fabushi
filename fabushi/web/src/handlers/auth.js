import { jsonResponse } from '../utils/response.js';
import { generateToken, verifyToken } from '../../auth-utils.js';

function serializeUser(user) {
  return {
    id: user.id,
    userId: user.id,
    username: user.username,
    email: user.email || '',
    nickname: user.nickname || user.username,
    avatar: user.avatar || user.alipay_avatar || user.wechat_headimgurl || null,
    phoneNumber: user.phone_number || null,
    firebaseUid: user.firebase_uid || null,
    alipayUserId: user.alipay_user_id || null,
    hasPassword: Boolean(user.password_hash && user.salt),
    createdAt: user.created_at,
    emailVerified: user.email_verified === 1,
    membership: {
      type: user.membership_type || 'expired',
      expiresAt: user.membership_expires_at || user.free_trial_end_date || null
    }
  };
}

async function resolveAuthenticatedUser(db, tokenData) {
  if (tokenData?.userId !== undefined && tokenData?.userId !== null && db.getUserById) {
    const user = await db.getUserById(tokenData.userId);
    if (user) return user;
  }
  if (tokenData?.username) return await db.getUser(tokenData.username);
  return null;
}

export async function handleGetUserInfo(request, env, db) {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) return jsonResponse({ error: '未提供认证信息' }, 401);
  const tokenData = await verifyToken(authHeader.substring(7), env);
  if (!tokenData) return jsonResponse({ error: '认证失败' }, 401);
  const user = await resolveAuthenticatedUser(db, tokenData);
  if (!user) return jsonResponse({ error: '用户不存在' }, 404);
  return jsonResponse(serializeUser(user));
}

export async function handleFirebasePhoneLogin(request, env, db) {
  const { phoneNumber, firebaseUid, isNewUser } = await request.json();
  if (!phoneNumber || !firebaseUid) return jsonResponse({ error: '缺少必要参数' }, 400);

  let user = await db.getUserByPhone(phoneNumber);
  if (!user) user = await db.getUserByFirebaseUid(firebaseUid);

  if (user) {
    if (user.firebase_uid !== firebaseUid || user.phone_number !== phoneNumber) {
      if (db.updateUserById) {
        await db.updateUserById(user.id, { firebase_uid: firebaseUid, phone_number: phoneNumber });
      } else {
        await db.updateUser(user.username, { firebase_uid: firebaseUid, phone_number: phoneNumber });
      }
      user = db.getUserById ? await db.getUserById(user.id) : await db.getUser(user.username);
    }
    return jsonResponse({
      success: true,
      token: await generateToken({ id: user.id, username: user.username }, env),
      username: user.username,
      userId: user.id,
      isNewUser: false,
      user: serializeUser(user)
    });
  }

  const createdUser = await db.createPhoneUser({
    username: `user_${Date.now().toString(36)}`,
    email: `${firebaseUid}@phone.user`,
    phoneNumber,
    firebaseUid,
    membershipType: 'trial',
    freeTrialEndDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
    createdAt: new Date().toISOString()
  });

  return jsonResponse({
    success: true,
    token: await generateToken({ id: createdUser.id, username: createdUser.username }, env),
    username: createdUser.username,
    userId: createdUser.id,
    isNewUser: isNewUser ?? true,
    user: serializeUser(createdUser)
  });
}

export async function handleAppleLogin(request, env, db) {
  const { appleUserId, email } = await request.json();
  if (!appleUserId) return jsonResponse({ error: '缺少必要参数 (appleUserId)' }, 400);

  let user = await db.getUserByAppleId(appleUserId);
  if (user) {
    return jsonResponse({
      success: true,
      token: await generateToken({ id: user.id, username: user.username }, env),
      username: user.username,
      userId: user.id,
      isNewUser: false,
      user: serializeUser(user)
    });
  }

  const existingEmailUser = email ? await db.getUserByEmail(email.toLowerCase()) : null;
  if (existingEmailUser) {
    if (db.updateUserById) {
      await db.updateUserById(existingEmailUser.id, { apple_user_id: appleUserId });
    } else {
      await db.updateUser(existingEmailUser.username, { apple_user_id: appleUserId });
    }
    user = db.getUserById ? await db.getUserById(existingEmailUser.id) : await db.getUser(existingEmailUser.username);
    return jsonResponse({
      success: true,
      token: await generateToken({ id: user.id, username: user.username }, env),
      username: user.username,
      userId: user.id,
      isNewUser: false,
      user: serializeUser(user)
    });
  }

  const createdUser = await db.createAppleUser({
    username: `apple_${Date.now().toString(36)}`,
    email: email?.toLowerCase() || `${appleUserId.substring(0, 16)}@apple.user`,
    appleUserId,
    nickname: null,
    membershipType: 'trial',
    membershipExpiresAt: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
    createdAt: new Date().toISOString()
  });

  return jsonResponse({
    success: true,
    token: await generateToken({ id: createdUser.id, username: createdUser.username }, env),
    username: createdUser.username,
    userId: createdUser.id,
    isNewUser: true,
    user: serializeUser(createdUser)
  });
}
