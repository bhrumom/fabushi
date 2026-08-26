import fs from 'node:fs';

const file = 'third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/payment_api.rs';
let source = fs.readFileSync(file, 'utf8');

function insertOnce(marker, replacement, proof) {
  if (source.includes(proof)) return;
  if (!source.includes(marker)) throw new Error(`reconciled-refund patch marker not found: ${marker}`);
  source = source.replace(marker, replacement);
}

insertOnce(
  'include!("payout_orchestration.rs");\n',
  'include!("payout_orchestration.rs");\ninclude!("reconciled_refund.rs");\n',
  'include!("reconciled_refund.rs");'
);

const refundMarker = `    if !matches!(payment.status.as_str(), "succeeded" | "partially_refunded") {\n        return Err(worker::Error::RustError("payment is not refundable".into()));\n    }\n    let new_refunded = payment.refunded_amount.saturating_add(amount);\n`;
const refundReplacement = `    if !matches!(payment.status.as_str(), "succeeded" | "partially_refunded") {\n        return Err(worker::Error::RustError("payment is not refundable".into()));\n    }\n    if let Some(reconciliation) = reconciled_refund_row(database, &payment.payment_id).await? {\n        return apply_refund_after_reconciliation(\n            database,\n            payment,\n            &reconciliation,\n            provider,\n            refund_reference,\n            amount,\n            event_id,\n            occurred_at,\n        )\n        .await;\n    }\n    let new_refunded = payment.refunded_amount.saturating_add(amount);\n`;
insertOnce(refundMarker, refundReplacement, 'reconciled_refund_row(database, &payment.payment_id)');

fs.writeFileSync(file, source);
