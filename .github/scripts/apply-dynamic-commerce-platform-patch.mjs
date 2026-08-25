import fs from 'node:fs';

const file = 'third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api.rs';
let source = fs.readFileSync(file, 'utf8');

function insertOnce(marker, replacement, proof) {
  if (source.includes(proof)) return;
  if (!source.includes(marker)) throw new Error(`patch marker not found: ${marker}`);
  source = source.replace(marker, replacement);
}

insertOnce(
  'mod commerce;\n',
  'mod commerce;\nmod developer_commerce_proxy;\n',
  'mod developer_commerce_proxy;'
);
insertOnce(
  'use commerce::*;\n',
  'use commerce::*;\nuse developer_commerce_proxy::*;\n',
  'use developer_commerce_proxy::*;'
);
insertOnce(
  '        .get_async("/v1/wallet/history", wallet_history)\n',
  `        .get_async("/v1/wallet/history", wallet_history)\n        .get_async("/v1/developer/commerce/profile", developer_commerce_proxy)\n        .post_async("/v1/developer/commerce/profile", developer_commerce_proxy)\n        .get_async("/v1/developer/commerce/miniapps", developer_commerce_proxy)\n        .post_async(\n            "/v1/developer/commerce/miniapps/:mini_app_id",\n            developer_commerce_proxy,\n        )\n        .get_async(\n            "/v1/developer/commerce/miniapps/:mini_app_id/products",\n            developer_commerce_proxy,\n        )\n        .post_async(\n            "/v1/developer/commerce/miniapps/:mini_app_id/products",\n            developer_commerce_proxy,\n        )\n        .post_async(\n            "/v1/developer/commerce/miniapps/:mini_app_id/products/:product_id",\n            developer_commerce_proxy,\n        )\n        .post_async(\n            "/v1/developer/commerce/miniapps/:mini_app_id/products/:product_id/google/sync",\n            developer_commerce_proxy,\n        )\n        .post_async(\n            "/v1/pay/intents/:payment_id/apple/advanced-commerce",\n            developer_commerce_proxy,\n        )\n`,
  '"/v1/pay/intents/:payment_id/apple/advanced-commerce"'
);

fs.writeFileSync(file, source);
