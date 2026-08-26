import fs from 'node:fs';

const file = 'third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/payout_orchestration.rs';
let source = fs.readFileSync(file, 'utf8');

if (!source.includes("SET compliance_state=CASE WHEN EXISTS")) {
  const start = source.indexOf('pub async fn admin_upsert_payout_account_v2');
  const end = source.indexOf('pub async fn admin_set_payout_route', start);
  if (start < 0 || end < 0) throw new Error('payout capability function boundary missing');
  const block = source.slice(start, end);
  const response = block.lastIndexOf('    Response::from_json(');
  if (response < 0) throw new Error('payout capability response boundary missing');
  const absolute = start + response;
  const update = `    worker::query!(&database,
        "UPDATE developer_payout_profiles SET compliance_state=CASE WHEN EXISTS (SELECT 1 FROM developer_payout_accounts a WHERE a.developer_id=?1 AND a.state='active' AND a.kyc_status='verified' AND a.payouts_enabled=1) THEN 'eligible' ELSE 'pending' END,updated_at=?2 WHERE developer_id=?1",
        &input.developer_id,now)?.run().await?;\n`;
  source = source.slice(0, absolute) + update + source.slice(absolute);
}
fs.writeFileSync(file, source);
