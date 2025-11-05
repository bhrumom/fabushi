import { jsonResponse } from '../utils/response.js';
import { verifyToken } from '../../auth-utils.js';
import { MEMBERSHIP_PLANS } from '../config/constants.js';
import { isAdmin } from '../utils/helpers.js';

// 创建支付宝订单
export async function handleCreateAlipayOrder(request, env, db) {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return jsonResponse({ error: '未提供认证信息' }, 401);
  }

  const token = authHeader.substring(7);
  const tokenData = await verifyToken(token, env);
  if (!tokenData) {
    return jsonResponse({ error: '认证失败' }, 401);
  }

  const { plan = 'monthly' } = await request.json();
  const planDetails = MEMBERSHIP_PLANS[plan];
  if (!planDetails) {
    return jsonResponse({ error: '无效的会员计划' }, 400);
  }

  const user = await db.getUser(tokenData.username);
  if (!user) {
    return jsonResponse({ error: '用户不存在' }, 404);
  }

  const isAdminUser = isAdmin(user.email);
  const finalAmount = isAdminUser ? planDetails.adminPrice : planDetails.price;
  const outTradeNo = `MEMBER_${tokenData.username}_${Date.now()}`;

  await db.createOrder({
    orderId: outTradeNo,
    userId: tokenData.username,
    plan,
    amount: finalAmount,
    originalAmount: planDetails.price,
    isAdminOrder: isAdminUser,
    status: 'PENDING',
    platform: 'alipay',
    createdAt: new Date().toISOString()
  });

  return jsonResponse({
    orderId: outTradeNo,
    amount: finalAmount,
    plan
  });
}

// 查询订单
export async function handleQueryAlipayOrder(request, env, db) {
  const url = new URL(request.url);
  const orderId = url.searchParams.get('orderId');
  
  if (!orderId) {
    return jsonResponse({ error: '订单ID不能为空' }, 400);
  }

  const order = await db.getOrder(orderId);
  if (!order) {
    return jsonResponse({ error: '订单不存在' }, 404);
  }

  return jsonResponse({
    orderId: order.order_id,
    userId: order.user_id,
    plan: order.plan,
    amount: order.amount,
    status: order.status,
    createdAt: order.created_at
  });
}

// 支付宝回调
export async function handleAlipayNotify(request, env, db) {
  const formData = await request.formData();
  const params = {};
  for (const [key, value] of formData.entries()) {
    params[key] = value;
  }

  if (params.trade_status === 'TRADE_SUCCESS' || params.trade_status === 'TRADE_FINISHED') {
    const outTradeNo = params.out_trade_no;
    const order = await db.getOrder(outTradeNo);
    
    if (!order) {
      return new Response('failure', { status: 404 });
    }

    if (order.status === 'PAID') {
      return new Response('success', { status: 200 });
    }

    await db.updateOrder(outTradeNo, {
      status: 'PAID',
      paid_at: new Date().toISOString(),
      trade_no: params.trade_no
    });

    const user = await db.getUser(order.user_id);
    const planDetails = MEMBERSHIP_PLANS[order.plan];
    const now = new Date();
    
    let startDate = now;
    if (user.membership_expires_at && new Date(user.membership_expires_at) > now) {
      startDate = new Date(user.membership_expires_at);
    }
    
    const endDate = new Date(startDate.getTime() + planDetails.duration);

    await db.updateUser(order.user_id, {
      membership_type: 'paid',
      membership_expires_at: endDate.toISOString()
    });

    await db.addPurchaseHistory({
      username: order.user_id,
      orderId: outTradeNo,
      plan: order.plan,
      amount: planDetails.price,
      currency: 'CNY',
      status: 'completed',
      paymentMethod: 'alipay',
      purchasedAt: now.toISOString(),
      validFrom: startDate.toISOString(),
      validTo: endDate.toISOString()
    });
  }

  return new Response('success', { status: 200 });
}
