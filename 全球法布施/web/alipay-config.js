// 支付宝当面付配置
export const ALIPAY_CONFIG = {
  // 支付宝网关地址
  GATEWAY_URL: 'https://openapi.alipay.com/gateway.do',
  // 支付宝沙箱网关地址
  SANDBOX_GATEWAY_URL: 'https://openapi-sandbox.dl.alipaydev.com/gateway.do',
  
  // 获取当前环境的网关地址
  getGatewayUrl: function() {
    return this.APP_CONFIG.sandbox ? this.SANDBOX_GATEWAY_URL : this.GATEWAY_URL;
  },
  
  // 回调地址配置
  CALLBACK_CONFIG: {
    // 应用网关地址 - 用于接收支付宝异步通知
    // 注意：这个地址必须是外网可访问的，本地开发时可以使用 ngrok 等工具进行内网穿透
    NOTIFY_URL: '/api/alipay/notify',
    
    // 授权回调地址 - 用户支付完成后跳转回应用的地址
    RETURN_URL: '/membership.html',
  },
  
  // 当面付产品码
  PRODUCT_CODE: 'FACE_TO_FACE_PAYMENT',
  
  // 会员价格配置
  MEMBERSHIP_PRICES: {
    monthly: {
      amount: "21.00", // 21元/月
      duration: 30 * 24 * 60 * 60 * 1000, // 30天
      name: '月度会员'
    },
    quarterly: {
      amount: "63.00", // 63元/季度
      duration: 90 * 24 * 60 * 60 * 1000, // 90天
      name: '季度会员'
    },
    yearly: {
      amount: "252.00", // 252元/年
      duration: 365 * 24 * 60 * 60 * 1000, // 365天
      name: '年度会员'
    }
  },
  
  CURRENCY: 'CNY',
  
  // 订单超时时间 (分钟)
  TIMEOUT_EXPRESS: '30m',

  // 应用配置 (将从环境变量安全加载)
  APP_CONFIG: {
    charset: 'utf-8',
    sign_type: 'RSA2',
    version: '1.0',
    sandbox: false, // 沙箱环境开关, 将由环境变量 ALIPAY_SANDBOX 控制
    // app_id, merchant_private_key, alipay_public_key 将从 env 中动态获取
    // notify_url, return_url 将在 worker 中动态构建或从 env 获取
  }
};
