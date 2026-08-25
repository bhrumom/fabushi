import fs from 'node:fs';

const workerFile = 'third_party/mahayana/mahayana-rs/mahayana-commerce-control-worker/src/worker_v2.rs';
let worker = fs.readFileSync(workerFile, 'utf8');
const brokenQuery = 'ORDER BY p.developer_id,a.is_default DESC,a.created_at ASC")?.all().await?.results::<AutoPayoutCandidate>()?;';
const fixedQuery = 'ORDER BY p.developer_id,a.is_default DESC,a.created_at ASC").all().await?.results::<AutoPayoutCandidate>()?;';
if (worker.includes(brokenQuery)) worker = worker.replace(brokenQuery, fixedQuery);
if (!worker.includes(fixedQuery)) throw new Error('automatic payout candidate query was not repaired');
fs.writeFileSync(workerFile, worker);

const payFile = 'third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/payment_api.rs';
let pay = fs.readFileSync(payFile, 'utf8');
if (!pay.includes('include!("payout_finalize.rs");')) {
  const marker = 'include!("reserve_release.rs");\n';
  if (!pay.includes(marker)) throw new Error('payout finalize include marker missing');
  pay = pay.replace(marker, marker + 'include!("payout_finalize.rs");\n');
}
if (!pay.includes('| "paypal_payouts"')) {
  pay = pay.replace(
    '| "paypal_multiparty" | "wechat_platform"',
    '| "paypal_multiparty" | "paypal_payouts" | "wechat_platform"'
  );
}
const payoutPaid = /        "payoutPaid" => \{[\s\S]*?\n        \}\n        "payoutFailed" => \{/;
const replacement = `        "payoutPaid" => {\n            let payout_id = required_event_value(event.payout_id.as_deref(), "payoutId")?;\n            finalize_paid_payout(\n                database,\n                payout_id,\n                event.provider_reference.as_deref(),\n                occurred_at,\n            )\n            .await?;\n            Ok(None)\n        }\n        "payoutFailed" => {`;
if (!pay.includes('finalize_paid_payout(')) {
  if (!payoutPaid.test(pay)) throw new Error('payoutPaid branch marker missing');
  pay = pay.replace(payoutPaid, replacement);
}
if (!pay.includes('finalize_paid_payout(')) throw new Error('payout paid finalization was not installed');
fs.writeFileSync(payFile, pay);
