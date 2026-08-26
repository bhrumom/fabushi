import fs from 'node:fs';

function patchFile(file, transform) {
  const before = fs.readFileSync(file, 'utf8');
  const after = transform(before);
  if (after !== before) fs.writeFileSync(file, after);
}

function insertOnce(source, marker, replacement, proof) {
  if (source.includes(proof)) return source;
  if (!source.includes(marker)) throw new Error(`payout-maintenance marker not found: ${marker}`);
  return source.replace(marker, replacement);
}

patchFile('third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/payment_api.rs', (input) => {
  let source = input;
  source = insertOnce(
    source,
    'include!("reconciled_refund.rs");\n',
    'include!("reconciled_refund.rs");\ninclude!("reserve_release.rs");\n',
    'include!("reserve_release.rs");'
  );
  source = source.replace(
    `        "payoutPaid" => {\n            let payout_id = required_event_value(event.payout_id.as_deref(), "payoutId")?;\n            worker::query!(database,\n                "UPDATE developer_payouts SET status = 'paid', provider_reference = COALESCE(?1, provider_reference), updated_at = ?2\n                 WHERE payout_id = ?3 AND status IN ('pending', 'processing')",\n                event.provider_reference.as_deref(), occurred_at, payout_id)?.run().await?;\n            Ok(None)\n        }\n        "payoutFailed" => {\n            let payout_id = required_event_value(event.payout_id.as_deref(), "payoutId")?;\n            reverse_failed_payout(database, payout_id, occurred_at).await?;\n            Ok(None)\n        }`,
    `        "payoutPaid" => {\n            let payout_id = required_event_value(event.payout_id.as_deref(), "payoutId")?;\n            worker::query!(database,\n                "UPDATE developer_payouts SET status = 'paid', provider_reference = COALESCE(?1, provider_reference), updated_at = ?2\n                 WHERE payout_id = ?3 AND status IN ('pending', 'processing')",\n                event.provider_reference.as_deref(), occurred_at, payout_id)?.run().await?;\n            worker::query!(database,\n                "UPDATE developer_payout_attempts SET state='paid',provider_reference=COALESCE(?1,provider_reference),last_error=NULL,updated_at=?2 WHERE payout_id=?3 AND state IN ('created','submitted','processing')",\n                event.provider_reference.as_deref(),occurred_at,payout_id)?.run().await?;\n            Ok(None)\n        }\n        "payoutFailed" => {\n            let payout_id = required_event_value(event.payout_id.as_deref(), "payoutId")?;\n            reverse_failed_payout(database, payout_id, occurred_at).await?;\n            worker::query!(database,\n                "UPDATE developer_payout_attempts SET state='failed',last_error=COALESCE(last_error,'provider reported payout failure'),updated_at=?1 WHERE payout_id=?2 AND state NOT IN ('paid','cancelled')",\n                occurred_at,payout_id)?.run().await?;\n            Ok(None)\n        }`
  );
  return source;
});

patchFile('third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/payout_orchestration.rs', (input) => {
  let source = input;
  source = insertOnce(
    source,
    '    #[serde(default)]\n    reserve_bps: u16,\n',
    '    #[serde(default)]\n    reserve_bps: u16,\n    #[serde(default)]\n    reserve_hold_seconds: i64,\n',
    'reserve_hold_seconds: i64'
  );
  source = source.replace(
    '            | "paypal_multiparty"\n            | "wechat_platform"',
    '            | "paypal_multiparty"\n            | "paypal_payouts"\n            | "wechat_platform"'
  );
  source = source.replace(
    '        "paypal_multiparty" => Some("PAYOUT_PAYPAL_MULTIPARTY_EXECUTOR_URL"),\n',
    '        "paypal_multiparty" => Some("PAYOUT_PAYPAL_MULTIPARTY_EXECUTOR_URL"),\n        "paypal_payouts" => Some("PAYOUT_PAYPAL_PAYOUTS_EXECUTOR_URL"),\n'
  );
  source = insertOnce(
    source,
    '    if input.reserve_bps > 10_000 {\n',
    '    let reserve_hold_seconds = if input.reserve_bps > 0 && input.reserve_hold_seconds == 0 { 604800 } else { input.reserve_hold_seconds };\n    if reserve_hold_seconds < 0 || reserve_hold_seconds > 7_776_000 {\n        return error_response(400, "invalid_reserve_hold", "reserveHoldSeconds must be between 0 and 90 days");\n    }\n    if input.reserve_bps > 10_000 {\n',
    'reserveHoldSeconds must be between 0 and 90 days'
  );
  source = insertOnce(
    source,
    '    let now = now_seconds();\n\n    let mut statements = vec![',
    '    let now = now_seconds();\n    let reserve_release_after = now.saturating_add(reserve_hold_seconds);\n\n    let mut statements = vec![',
    'let reserve_release_after = now.saturating_add(reserve_hold_seconds);'
  );
  source = source.replace(
    'currency,gross_amount,tax_amount,provider_fee_amount,refund_amount,chargeback_amount,net_receipts,platform_fee_bps,platform_fee_amount,reserve_bps,reserve_amount,developer_payable_amount,provider_settlement_reference,status,created_at,updated_at)\n             VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13,?14,?15,?16,?17,?18,?19,\'reconciled\',?20,?20)',
    'currency,gross_amount,tax_amount,provider_fee_amount,refund_amount,chargeback_amount,net_receipts,platform_fee_bps,platform_fee_amount,reserve_bps,reserve_amount,reserve_release_after,developer_payable_amount,provider_settlement_reference,status,created_at,updated_at)\n             VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13,?14,?15,?16,?17,?18,?19,?20,\'reconciled\',?21,?21)'
  );
  source = source.replace(
    'i64::from(input.reserve_bps),reserve_amount,developer_payable,input.provider_settlement_reference.as_deref(),now',
    'i64::from(input.reserve_bps),reserve_amount,reserve_release_after,developer_payable,input.provider_settlement_reference.as_deref(),now'
  );
  source = source.replace(
    '        "reserveAmount": reserve_amount,\n        "developerPayableAmount": developer_payable,',
    '        "reserveAmount": reserve_amount,\n        "reserveReleaseAfter": reserve_release_after,\n        "developerPayableAmount": developer_payable,'
  );
  const missingConfig = `        let executor_url = match context.env.var(env_name) {\n            Ok(v) => v.to_string(),\n            Err(_) => {\n                worker::query!(\n                    &database,\n                    "UPDATE developer_payout_attempts SET state='configuration_required',last_error='executor URL is not configured',updated_at=?1 WHERE attempt_id=?2",\n                    now_seconds(),\n                    &attempt.attempt_id\n                )?\n                .run()\n                .await?;\n                return error_response(\n                    503,\n                    "payout_provider_not_configured",\n                    "payout provider executor is not configured",\n                );\n            }\n        };`;
  if (source.includes(missingConfig) && !source.includes('reverse_failed_payout(&database, payout_id, now_seconds()).await?;\n                return error_response(\n                    503')) {
    source = source.replace(
      missingConfig,
      missingConfig.replace('                return error_response(', '                reverse_failed_payout(&database, payout_id, now_seconds()).await?;\n                return error_response(')
    );
  }
  const invalidUrl = `    if !executor_url.starts_with("https://") || executor_url.contains(char::is_whitespace) {\n        return error_response(\n            500,\n            "invalid_executor_url",\n            "payout executor URL must be HTTPS",\n        );\n    }`;
  if (source.includes(invalidUrl)) {
    source = source.replace(
      invalidUrl,
      `    if !executor_url.starts_with("https://") || executor_url.contains(char::is_whitespace) {\n        worker::query!(&database,"UPDATE developer_payout_attempts SET state='configuration_required',last_error='executor URL must be HTTPS',updated_at=?1 WHERE attempt_id=?2",now_seconds(),&attempt.attempt_id)?.run().await?;\n        reverse_failed_payout(&database, payout_id, now_seconds()).await?;\n        return error_response(500,"invalid_executor_url","payout executor URL must be HTTPS");\n    }`
    );
  }
  return source;
});

patchFile('third_party/mahayana/mahayana-rs/mahayana-pay-worker/src/lib.rs', (input) => {
  let source = input;
  source = source.replace(
    '                | "paypal_multiparty"\n                | "wechat_platform"',
    '                | "paypal_multiparty"\n                | "paypal_payouts"\n                | "wechat_platform"'
  );
  source = insertOnce(
    source,
    '        .post_async(\n            "/v1/pay/admin/settlements/reconcile",\n            payment_api::admin_reconcile_settlement,\n        )\n',
    '        .post_async(\n            "/v1/pay/admin/settlements/reconcile",\n            payment_api::admin_reconcile_settlement,\n        )\n        .post_async(\n            "/v1/pay/admin/settlements/reserves/release-due",\n            payment_api::admin_release_due_reserves,\n        )\n        .post_async(\n            "/v1/pay/admin/settlements/reserves/:reconciliation_id/release",\n            payment_api::admin_release_reserve,\n        )\n',
    '"/v1/pay/admin/settlements/reserves/release-due"'
  );
  return source;
});
