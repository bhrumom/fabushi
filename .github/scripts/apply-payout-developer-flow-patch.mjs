import fs from 'node:fs';

const file='third_party/mahayana/mahayana-rs/mahayana-commerce-control-worker/src/worker_v2.rs';
let source=fs.readFileSync(file,'utf8');

if(!source.includes('let paid_pattern = format!("developer-paid:')){
  source=source.replace(
    '    let reserved_pattern = format!("developer-reserved:{}:%", developer.developer_id);\n',
    '    let reserved_pattern = format!("developer-reserved:{}:%", developer.developer_id);\n    let paid_pattern = format!("developer-paid:{}:%", developer.developer_id);\n'
  );
  source=source.replace(
    'let balances=worker::query!(&db,"SELECT account_id,currency,balance FROM wallet_balances WHERE account_id LIKE ?1 OR account_id LIKE ?2 OR account_id LIKE ?3 ORDER BY currency,account_id",&pending_pattern,&available_pattern,&reserved_pattern)?.all().await?.results::<Value>()?;',
    'let balances=worker::query!(&db,"SELECT account_id,currency,balance FROM wallet_balances WHERE account_id LIKE ?1 OR account_id LIKE ?2 OR account_id LIKE ?3 OR account_id LIKE ?4 ORDER BY currency,account_id",&pending_pattern,&available_pattern,&reserved_pattern,&paid_pattern)?.all().await?.results::<Value>()?;'
  );
}
if(!source.includes('let original_splits=worker::query!')){
  const marker='    let payouts=worker::query!(&db,"SELECT p.payout_id,p.payout_account_id,p.currency,p.amount,p.status,p.provider_reference,p.created_at,p.updated_at,a.provider FROM developer_payouts p JOIN developer_payout_accounts a ON a.payout_account_id=p.payout_account_id WHERE p.developer_id=?1 ORDER BY p.created_at DESC LIMIT 100",&developer.developer_id)?.all().await?.results::<Value>()?;\n';
  if(!source.includes(marker)) throw new Error('payout overview payouts marker missing');
  source=source.replace(marker,marker+'    let original_splits=worker::query!(&db,"SELECT split_id,payment_id,provider,payout_account_id,currency,amount,platform_fee_amount,provider_reference,state,created_at FROM developer_original_order_splits WHERE developer_id=?1 ORDER BY created_at DESC LIMIT 100",&developer.developer_id)?.all().await?.results::<Value>()?;\n');
  source=source.replace(
    '&json!({"profile":profile_row,"balances":balances,"accounts":accounts,"settlements":settlements,"payouts":payouts,"routes":routes}),',
    '&json!({"profile":profile_row,"balances":balances,"accounts":accounts,"settlements":settlements,"payouts":payouts,"originalSplits":original_splits,"routes":routes}),' 
  );
}

if(!source.includes('"dispatch":dispatched')){
  const startMarker='    let admin = env_text(&ctx.env, "FABUSHI_PAY_ADMIN_TOKEN")?;\n';
  const start=source.indexOf(startMarker,source.indexOf('async fn request_payout'));
  const endMarker='    Ok(result)\n}';
  const end=source.indexOf(endMarker,start);
  if(start<0 || end<0) throw new Error('developer payout forwarding block missing');
  const replacement=`    let create_body=json!({"idempotencyKey":input.idempotency_key,"developerId":developer.developer_id,"payoutAccountId":input.payout_account_id,"currency":input.currency,"amount":input.amount});\n    let (create_status,created)=pay_admin_json(&ctx.env,"/v1/pay/admin/payouts",Some(create_body)).await?;\n    if !(200..300).contains(&create_status) {\n        return Ok(Response::from_json(&created)?.with_status(create_status));\n    }\n    let payout_id=created.get("payout").and_then(|value|value.get("payoutId")).and_then(Value::as_str)\n        .or_else(||created.get("payoutId").and_then(Value::as_str))\n        .ok_or_else(||worker::Error::RustError("pay service response lacks payoutId".into()))?;\n    let (dispatch_status,dispatched)=pay_admin_json(&ctx.env,&format!("/v1/pay/admin/payouts/{}/dispatch",payout_id),Some(json!({}))).await?;\n    if !(200..300).contains(&dispatch_status) {\n        return Ok(Response::from_json(&json!({"payout":created.get("payout"),"dispatch":dispatched}))?.with_status(dispatch_status));\n    }\n    Response::from_json(&json!({"payout":created.get("payout"),"dispatch":dispatched}))\n}`;
  source=source.slice(0,start)+replacement+source.slice(end+endMarker.length);
}

fs.writeFileSync(file,source);
