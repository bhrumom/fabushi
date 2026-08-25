import fs from 'node:fs';

const file='third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/payout_orchestration.rs';
let source=fs.readFileSync(file,'utf8');

if(!source.includes('include!("original_order_split.rs");')){
  const marker='use serde_json::Value;\n';
  // payout_orchestration is included into payment_api, so include the helper at
  // this file's first type boundary when the import marker is not local.
  if(source.includes(marker)) source=source.replace(marker,marker+'include!("original_order_split.rs");\n');
  else source='include!("original_order_split.rs");\n'+source;
}

if(!source.includes('let original_split = if matches!(')){
  const marker='    let reserve_release_after = now.saturating_add(reserve_hold_seconds);\n\n';
  if(!source.includes(marker)) throw new Error('reserve release timestamp marker missing; apply payout-maintenance first');
  source=source.replace(marker,marker+`    let original_split = if matches!(input.settlement_source.as_str(), "wechat_order" | "alipay_order") && developer_payable > 0 {\n        Some(execute_original_order_split(&context.env,&database,&payment,&input,developer_payable,desired_platform_fee).await?)\n    } else {\n        None\n    };\n    let paid_account = developer_paid_account(&payment.developer_id, &payment.currency);\n\n`);
}

if(!source.includes('"{}:paid", payment.developer_id')){
  const marker='    ];\n\n    if deductions > 0 {';
  if(!source.includes(marker)) throw new Error('reconciliation statement vector marker missing');
  source=source.replace(marker,`    ];\n    if original_split.is_some() {\n        statements.push(wallet_account_statement(&database,&paid_account,"developer",&format!("{}:paid", payment.developer_id),&payment.currency,now)?);\n    }\n\n    if deductions > 0 {`);
}

if(!source.includes('developer_original_order_splits')){
  const start=source.indexOf('    if developer_payable > 0 {');
  const endMarker='\n    statements.push(worker::query!(\n        &database,\n        "UPDATE payment_intents';
  const end=source.indexOf(endMarker,start);
  if(start<0 || end<0) throw new Error('developer payable release block not found');
  const replacement=`    if developer_payable > 0 {\n        statements.push(worker::query!(&database,\n            "INSERT INTO developer_settlement_releases (release_id,payment_id,idempotency_key,developer_id,currency,amount,released_at) VALUES (?1,?2,?3,?4,?5,?6,?7)",\n            &release_id,&payment.payment_id,&format!("release:{}",input.idempotency_key),&payment.developer_id,&payment.currency,developer_payable,now)?);\n        statements.push(worker::query!(&database,\n            "INSERT INTO journal_entries (entry_id,reference_type,reference_id,state,created_at) VALUES (?1,?2,?3,'draft',?4)",\n            &release_entry,if original_split.is_some(){"settlement_original_order_split"}else{"settlement_release"},&release_id,now)?);\n        statements.push(journal_line_statement(&database,&format!("{release_entry}:pending"),&release_entry,&pending_account,&payment.currency,-developer_payable,now)?);\n        if let Some(split)=original_split.as_ref() {\n            statements.push(journal_line_statement(&database,&format!("{release_entry}:paid"),&release_entry,&paid_account,&payment.currency,developer_payable,now)?);\n            statements.push(worker::query!(&database,\n                "INSERT INTO developer_original_order_splits (split_id,reconciliation_id,payment_id,developer_id,provider,payout_account_id,source_provider_reference,currency,amount,platform_fee_amount,idempotency_key,provider_reference,state,created_at,updated_at) VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,'paid',?13,?13)",\n                &split.split_id,&reconciliation_id,&payment.payment_id,&payment.developer_id,&split.provider,&split.payout_account_id,&split.source_provider_reference,&payment.currency,developer_payable,desired_platform_fee,&split.idempotency_key,&split.provider_reference,now)?);\n        } else {\n            statements.push(journal_line_statement(&database,&format!("{release_entry}:available"),&release_entry,&available_account,&payment.currency,developer_payable,now)?);\n        }\n        statements.push(post_balanced_entry_statement(&database,&release_entry,now)?);\n    }\n`;
  source=source.slice(0,start)+replacement+source.slice(end);
}

if(!source.includes('"settlementMode": if original_split.is_some()')){
  const marker='        "developerPayableAmount": developer_payable,\n';
  if(!source.includes(marker)) throw new Error('settlement response marker missing');
  source=source.replace(marker,marker+'        "settlementMode": if original_split.is_some() {"original_order_split"} else {"developer_payout"},\n        "originalSplitProviderReference": original_split.as_ref().map(|value| value.provider_reference.clone()),\n');
}

fs.writeFileSync(file,source);
