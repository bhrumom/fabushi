import fs from 'node:fs';

const workerPath = 'third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api.rs';
const testsPath = 'third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/schema_tests.rs';

const duplicateBlock = `        .get_async("/v1/developer/commerce/profile", developer_commerce_proxy)\n        .post_async("/v1/developer/commerce/profile", developer_commerce_proxy)\n        .get_async("/v1/developer/commerce/miniapps", developer_commerce_proxy)\n        .post_async(\n            "/v1/developer/commerce/miniapps/:mini_app_id",\n            developer_commerce_proxy,\n        )\n        .get_async(\n            "/v1/developer/commerce/miniapps/:mini_app_id/products",\n            developer_commerce_proxy,\n        )\n        .post_async(\n            "/v1/developer/commerce/miniapps/:mini_app_id/products",\n            developer_commerce_proxy,\n        )\n        .post_async(\n            "/v1/developer/commerce/miniapps/:mini_app_id/products/:product_id",\n            developer_commerce_proxy,\n        )\n        .post_async(\n            "/v1/developer/commerce/miniapps/:mini_app_id/products/:product_id/google/sync",\n            developer_commerce_proxy,\n        )\n        .post_async(\n            "/v1/pay/intents/:payment_id/apple/advanced-commerce",\n            developer_commerce_proxy,\n        )\n`;

let workerSource = fs.readFileSync(workerPath, 'utf8');
const duplicateCount = workerSource.split(duplicateBlock).length - 1;
if (duplicateCount === 1) {
  workerSource = workerSource.replace(duplicateBlock, '');
  fs.writeFileSync(workerPath, workerSource);
} else if (duplicateCount !== 0) {
  throw new Error(`Expected zero or one duplicate developer-commerce route block, found ${duplicateCount}.`);
}

const testMarker = 'fn worker_router_rejects_duplicate_developer_commerce_regressions()';
let tests = fs.readFileSync(testsPath, 'utf8');
if (!tests.includes(testMarker)) {
  tests += `\n#[test]\nfn worker_router_rejects_duplicate_developer_commerce_regressions() {\n    let source = include_str!("worker_api.rs");\n    for route in [\n        ".get_async(\\\"/v1/developer/commerce/profile\\\"",\n        ".post_async(\\\"/v1/developer/commerce/profile\\\"",\n        ".get_async(\\\"/v1/developer/commerce/miniapps\\\"",\n        "\\\"/v1/developer/commerce/miniapps/:mini_app_id\\\"",\n        "\\\"/v1/developer/commerce/miniapps/:mini_app_id/products\\\"",\n        "\\\"/v1/developer/commerce/miniapps/:mini_app_id/products/:product_id\\\"",\n        "\\\"/v1/developer/commerce/miniapps/:mini_app_id/products/:product_id/google/sync\\\"",\n        "\\\"/v1/pay/intents/:payment_id/apple/advanced-commerce\\\"",\n    ] {\n        assert_eq!(\n            source.matches(route).count(),\n            1,\n            "duplicate Mahayana Worker router registration: {route}"\n        );\n    }\n}\n`;
  fs.writeFileSync(testsPath, tests);
}

console.log('Removed duplicate Mahayana Worker routes and added a regression guard.');
