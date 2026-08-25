import fs from 'node:fs';

const edgeFile='desktop/electron/native-edge.cjs';
let edge=fs.readFileSync(edgeFile,'utf8');
if(!edge.includes('createDeveloperPayoutOnboarding:')){
  const marker="  devRestart: { args: 'none' },";
  if(!edge.includes(marker)) throw new Error('native edge onboarding marker missing');
  edge=edge.replace(marker,`  createDeveloperPayoutOnboarding: { args: 'object' },\n${marker}`);
}
fs.writeFileSync(edgeFile,edge);

const handlersFile='desktop/electron/native-capability-handlers.cjs';
let handlers=fs.readFileSync(handlersFile,'utf8');
if(!handlers.includes('async createDeveloperPayoutOnboarding(params)')){
  const marker='    async getSharingState(params) {';
  if(!handlers.includes(marker)) throw new Error('native onboarding handler marker missing');
  const block=`    async createDeveloperPayoutOnboarding(params) {\n      const provider = cleanString(params.provider, 48);\n      const purpose = cleanString(params.purpose, 48);\n      const providers = new Set(['stripe_connect','adyen_platform','paypal_multiparty','paypal_payouts','wechat_platform','alipay_platform','lianlian_account_plus','huifu_dougong']);\n      const purposes = new Set(['original_order_split','external_proceeds_payout','marketplace_payout']);\n      if (!providers.has(provider) || !purposes.has(purpose)) throw new Error('Invalid payout onboarding route.');\n      return platformRequest('POST', '/v1/developer/commerce/payout/onboarding', { body: { provider, purpose } });\n    },\n\n`;
  handlers=handlers.replace(marker,block+marker);
}
fs.writeFileSync(handlersFile,handlers);
