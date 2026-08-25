import fs from 'node:fs';

const file = 'third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/payout_orchestration.rs';
let source = fs.readFileSync(file, 'utf8');

if (!source.includes("SET compliance_state=CASE WHEN EXISTS")) {
  const marker = '    Response::from_json(&json!({"ok":true,"payoutAccountId":input.payout_account_id,"state":state,"kycStatus":input.kyc_status,"payoutsEnabled":input.payouts_enabled}))\n';
  if (!source.includes(marker)) throw new Error('payout capability response marker missing');
  source = source.replace(marker,
    `    worker::query!(&database,"UPDATE developer_payout_profiles SET compliance_state=CASE WHEN EXISTS (SELECT 1 FROM developer_payout_accounts a WHERE a.developer_id=?1 AND a.state='active' AND a.kyc_status='verified' AND a.payouts_enabled=1) THEN 'eligible' ELSE 'pending' END,updated_at=?2 WHERE developer_id=?1",&input.developer_id,now)?.run().await?;\n${marker}`
  );
}
fs.writeFileSync(file, source);
