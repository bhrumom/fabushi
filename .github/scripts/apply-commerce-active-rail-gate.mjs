import fs from 'node:fs';

const workerFile = 'third_party/mahayana/mahayana-rs/mahayana-commerce-control-worker/src/worker_v2.rs';
let source = fs.readFileSync(workerFile, 'utf8');

if (!source.includes('if p.sync_state != "active"')) {
  const marker = '    for p in plans {\n        let rail = match p.provider.as_str() {';
  if (!source.includes(marker)) throw new Error('pay_rails_json marker missing');
  source = source.replace(marker, '    for p in plans {\n        if p.sync_state != "active" {\n            continue;\n        }\n        let rail = match p.provider.as_str() {');
}

if (!source.includes('struct PayRailConfigRow')) {
  const marker = '#[derive(Debug, Clone, Deserialize)]\nstruct AppleIntentRow {';
  if (!source.includes(marker)) throw new Error('PayRailConfigRow marker missing');
  source = source.replace(marker, `#[derive(Debug, Clone, Deserialize)]\nstruct PayRailConfigRow {\n    allowed_rails_json: String,\n    provider_product_refs_json: String,\n}\n\n${marker}`);
}

if (!source.includes('async fn activate_google_pay_rail')) {
  const marker = 'async fn send_google_json(';
  if (!source.includes(marker)) throw new Error('activate google marker missing');
  const helper = `async fn activate_google_pay_rail(\n    env: &Env,\n    product_id: &str,\n    external_product_ref: &str,\n    metadata: &str,\n    synced_at: i64,\n) -> Result<()> {\n    let db = env.d1(DB)?;\n    let row = worker::query!(\n        &db,\n        "SELECT allowed_rails_json, provider_product_refs_json FROM payment_product_config WHERE product_id=?1 LIMIT 1",\n        product_id\n    )?\n    .first::<PayRailConfigRow>(None)\n    .await?\n    .ok_or_else(|| worker::Error::RustError("payment product config not found".into()))?;\n    let mut rails: Vec<String> = serde_json::from_str(&row.allowed_rails_json)\n        .map_err(|_| worker::Error::RustError("invalid allowed rails configuration".into()))?;\n    let mut refs: std::collections::BTreeMap<String, String> =\n        serde_json::from_str(&row.provider_product_refs_json)\n            .map_err(|_| worker::Error::RustError("invalid provider product references".into()))?;\n    if !rails.iter().any(|rail| rail == "google_play_billing") {\n        rails.push("google_play_billing".into());\n    }\n    refs.insert("google_play_billing".into(), external_product_ref.to_string());\n    let rails_json = serde_json::to_string(&rails)\n        .map_err(|e| worker::Error::RustError(e.to_string()))?;\n    let refs_json = serde_json::to_string(&refs)\n        .map_err(|e| worker::Error::RustError(e.to_string()))?;\n\n    // Fail closed: make the provider binding active first, and only then expose the\n    // rail to PaymentIntent creation. If the second statement fails, pay core stays blocked.\n    worker::query!(\n        &db,\n        "UPDATE payment_provider_bindings SET sync_state='active',external_product_ref=?1,metadata_json=?2,last_error=NULL,last_synced_at=?3,updated_at=?3 WHERE product_id=?4 AND provider='google_play'",\n        external_product_ref, metadata, synced_at, product_id\n    )?\n    .run()\n    .await?;\n    worker::query!(\n        &db,\n        "UPDATE payment_product_config SET allowed_rails_json=?1,provider_product_refs_json=?2,updated_at=?3 WHERE product_id=?4",\n        &rails_json, &refs_json, synced_at, product_id\n    )?\n    .run()\n    .await?;\n    Ok(())\n}\n\n`;
  source = source.replace(marker, helper + marker);
}

const oldSuccess = `    worker::query!(&ctx.env.d1(DB)?,"UPDATE payment_provider_bindings SET sync_state='active',external_product_ref=?1,metadata_json=?2,last_error=NULL,last_synced_at=?3,updated_at=?3 WHERE product_id=?4 AND provider='google_play'",&external,&metadata,t,product_id)?.run().await?;`;
if (source.includes(oldSuccess)) {
  source = source.replace(oldSuccess, `    activate_google_pay_rail(&ctx.env, product_id, &external, &metadata, t).await?;`);
}

fs.writeFileSync(workerFile, source);

const payFile = 'third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/payment_api.rs';
let pay = fs.readFileSync(payFile, 'utf8');
if (!pay.includes('"advancedCommercePath"')) {
  const marker = `            "verifyPath": format!("/v1/pay/intents/{}/apple/verify", payment.payment_id),`;
  if (!pay.includes(marker)) throw new Error('Apple checkout marker missing');
  pay = pay.replace(marker, `${marker}\n            "advancedCommercePath": format!("/v1/pay/intents/{}/apple/advanced-commerce", payment.payment_id),`);
}
fs.writeFileSync(payFile, pay);
