import fs from 'node:fs';

function patchFile(file, transform) {
  const before = fs.readFileSync(file, 'utf8');
  const after = transform(before);
  if (after !== before) fs.writeFileSync(file, after);
}

function insertOnce(source, marker, replacement, proof) {
  if (source.includes(proof)) return source;
  if (!source.includes(marker)) throw new Error(`patch marker not found: ${marker}`);
  return source.replace(marker, replacement);
}

patchFile('third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/payment_api.rs', (input) => {
  let source = input;
  source = insertOnce(
    source,
    'fn normalize_rail(value: &str) -> Result<&\'static str> {',
    'include!("payout_orchestration.rs");\n\nfn normalize_rail(value: &str) -> Result<&\'static str> {',
    'include!("payout_orchestration.rs");'
  );
  source = source.replace(
    '    if !matches!(provider.as_str(), "web" | "merchant") {',
    '    if !matches!(provider.as_str(), "web" | "merchant" | "stripe_connect" | "adyen_platform" | "paypal_multiparty" | "wechat_platform" | "alipay_platform" | "lianlian_account_plus" | "huifu_dougong") {'
  );
  source = source.replace(
    '    let input: AdminSettlementRequest = request.json().await?;\n',
    '    let input: AdminSettlementRequest = request.json().await?;\n'
  );
  source = insertOnce(
    source,
    '    validate_identifier(&input.payment_id)?;\n',
    '    validate_identifier(&input.payment_id)?;\n    if input.payment_id.len() > 0 {\n        let database = context.env.d1(DATABASE_BINDING)?;\n        if let Some(payment) = payment_by_id(&database, &input.payment_id).await? {\n            if payment.currency != CREDITS_CURRENCY {\n                return error_response(409, "reconciliation_required", "fiat developer settlement must use the reconciliation waterfall");\n            }\n        }\n    }\n',
    'fiat developer settlement must use the reconciliation waterfall'
  );
  return source;
});

patchFile('third_party/mahayana/mahayana-rs/mahayana-pay-worker/src/lib.rs', (input) => {
  let source = input;
  source = source.replace(
    '        if !matches!(provider.as_str(), "web" | "merchant") {',
    '        if !matches!(provider.as_str(), "web" | "merchant" | "stripe_connect" | "adyen_platform" | "paypal_multiparty" | "wechat_platform" | "alipay_platform" | "lianlian_account_plus" | "huifu_dougong") {'
  );
  source = insertOnce(
    source,
    '        .post_async(\n            "/v1/pay/admin/settlements/release",\n            payment_api::admin_release_settlement,\n        )\n',
    '        .post_async(\n            "/v1/pay/admin/settlements/release",\n            payment_api::admin_release_settlement,\n        )\n        .post_async(\n            "/v1/pay/admin/settlements/reconcile",\n            payment_api::admin_reconcile_settlement,\n        )\n',
    '"/v1/pay/admin/settlements/reconcile"'
  );
  source = source.replace(
    '            payment_api::admin_upsert_payout_account,',
    '            payment_api::admin_upsert_payout_account_v2,'
  );
  source = source.replace(
    '        .post_async("/v1/pay/admin/payouts", payment_api::admin_create_payout)\n',
    '        .post_async("/v1/pay/admin/payouts", payment_api::admin_create_payout_v2)\n        .post_async(\n            "/v1/pay/admin/payouts/:payout_id/dispatch",\n            payment_api::admin_dispatch_payout,\n        )\n        .post_async(\n            "/v1/pay/admin/payout-routes/:route_id",\n            payment_api::admin_set_payout_route,\n        )\n'
  );
  return source;
});

patchFile('third_party/mahayana/mahayana-rs/mahayana-commerce-control-worker/src/worker_v2.rs', (input) => {
  let source = input;
  const code = `
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct PayoutProfileInput {
    country_code: String,
    legal_entity_type: String,
    preferred_currency: String,
    payout_schedule: String,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct DeveloperPayoutRequest {
    payout_account_id: String,
    currency: String,
    amount: i64,
    idempotency_key: String,
}

#[derive(Debug, Clone, Deserialize)]
struct DeveloperPayoutAccountRow {
    payout_account_id: String,
    developer_id: String,
    state: String,
    onboarding_state: String,
    kyc_status: String,
    payouts_enabled: i64,
    currencies_json: String,
}

async fn put_payout_profile(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let user = require_developer(&req, &ctx.env)?;
    let developer = profile(&ctx.env, &user).await?.ok_or_else(|| worker::Error::RustError("register developer profile first".into()))?;
    let input: PayoutProfileInput = req.json().await?;
    let country = input.country_code.trim().to_ascii_uppercase();
    let currency = input.preferred_currency.trim().to_ascii_uppercase();
    if country.len() != 2 || !country.bytes().all(|b| b.is_ascii_uppercase()) {
        return Response::error("countryCode must be ISO alpha-2", 400);
    }
    if currency.len() != 3 || !currency.bytes().all(|b| b.is_ascii_uppercase()) {
        return Response::error("preferredCurrency must be ISO alpha-3", 400);
    }
    if !matches!(input.legal_entity_type.as_str(), "individual" | "individual_business" | "company" | "nonprofit") {
        return Response::error("invalid legalEntityType", 400);
    }
    if !matches!(input.payout_schedule.as_str(), "manual" | "daily" | "weekly" | "monthly") {
        return Response::error("invalid payoutSchedule", 400);
    }
    let t = now();
    worker::query!(&ctx.env.d1(DB)?,
        "INSERT INTO developer_payout_profiles (developer_id,country_code,legal_entity_type,preferred_currency,payout_schedule,compliance_state,created_at,updated_at) VALUES (?1,?2,?3,?4,?5,'pending',?6,?6) ON CONFLICT(developer_id) DO UPDATE SET country_code=excluded.country_code,legal_entity_type=excluded.legal_entity_type,preferred_currency=excluded.preferred_currency,payout_schedule=excluded.payout_schedule,compliance_state=CASE WHEN developer_payout_profiles.country_code=excluded.country_code AND developer_payout_profiles.legal_entity_type=excluded.legal_entity_type THEN developer_payout_profiles.compliance_state ELSE 'pending' END,updated_at=excluded.updated_at",
        &developer.developer_id,&country,&input.legal_entity_type,&currency,&input.payout_schedule,t)?.run().await?;
    Response::from_json(&json!({"developerId":developer.developer_id,"countryCode":country,"legalEntityType":input.legal_entity_type,"preferredCurrency":currency,"payoutSchedule":input.payout_schedule,"complianceState":"pending"}))
}

async fn payout_overview(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let user = require_developer(&req, &ctx.env)?;
    let developer = profile(&ctx.env, &user).await?.ok_or_else(|| worker::Error::RustError("developer profile not found".into()))?;
    let db = ctx.env.d1(DB)?;
    let profile_row = worker::query!(&db,"SELECT developer_id,country_code,legal_entity_type,preferred_currency,payout_schedule,compliance_state FROM developer_payout_profiles WHERE developer_id=?1 LIMIT 1",&developer.developer_id)?.first::<Value>(None).await?;
    let accounts = worker::query!(&db,"SELECT payout_account_id,provider,country_code,legal_entity_type,state,onboarding_state,kyc_status,payouts_enabled,currencies_json,purposes_json,is_default,last_capability_sync_at FROM developer_payout_accounts WHERE developer_id=?1 ORDER BY is_default DESC,created_at DESC",&developer.developer_id)?.all().await?.results::<Value>()?;
    let pending_pattern=format!("developer-pending:{}:%",developer.developer_id);
    let available_pattern=format!("developer-available:{}:%",developer.developer_id);
    let reserved_pattern=format!("developer-reserved:{}:%",developer.developer_id);
    let balances=worker::query!(&db,"SELECT account_id,currency,balance FROM wallet_balances WHERE account_id LIKE ?1 OR account_id LIKE ?2 OR account_id LIKE ?3 ORDER BY currency,account_id",&pending_pattern,&available_pattern,&reserved_pattern)?.all().await?.results::<Value>()?;
    let settlements=worker::query!(&db,"SELECT reconciliation_id,payment_id,region_code,settlement_source,currency,gross_amount,tax_amount,provider_fee_amount,refund_amount,chargeback_amount,net_receipts,platform_fee_amount,reserve_amount,developer_payable_amount,status,created_at FROM developer_settlement_reconciliations WHERE developer_id=?1 ORDER BY created_at DESC LIMIT 100",&developer.developer_id)?.all().await?.results::<Value>()?;
    let payouts=worker::query!(&db,"SELECT p.payout_id,p.payout_account_id,p.currency,p.amount,p.status,p.provider_reference,p.created_at,p.updated_at,a.provider FROM developer_payouts p JOIN developer_payout_accounts a ON a.payout_account_id=p.payout_account_id WHERE p.developer_id=?1 ORDER BY p.created_at DESC LIMIT 100",&developer.developer_id)?.all().await?.results::<Value>()?;
    let region=profile_row.as_ref().and_then(|v|v.get("country_code")).and_then(Value::as_str).map(|v|if v=="CN"{"CN"}else{"GLOBAL"}).unwrap_or("GLOBAL");
    let routes=worker::query!(&db,"SELECT route_id,region_code,purpose,provider,priority,state FROM payout_provider_routes WHERE region_code=?1 ORDER BY purpose,priority",region)?.all().await?.results::<Value>()?;
    Response::from_json(&json!({"profile":profile_row,"balances":balances,"accounts":accounts,"settlements":settlements,"payouts":payouts,"routes":routes}))
}

async fn request_payout(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let user=require_developer(&req,&ctx.env)?;
    let developer=profile(&ctx.env,&user).await?.ok_or_else(||worker::Error::RustError("developer profile not found".into()))?;
    let input:DeveloperPayoutRequest=req.json().await?;
    if input.amount<=0 || input.currency.len()!=3 || !input.currency.bytes().all(|b|b.is_ascii_uppercase()) || !is_identifier(&input.payout_account_id) || !is_identifier(&input.idempotency_key) {
        return Response::error("invalid payout request",400);
    }
    let db=ctx.env.d1(DB)?;
    let account=worker::query!(&db,"SELECT payout_account_id,developer_id,state,onboarding_state,kyc_status,payouts_enabled,currencies_json FROM developer_payout_accounts WHERE payout_account_id=?1 AND developer_id=?2 LIMIT 1",&input.payout_account_id,&developer.developer_id)?.first::<DeveloperPayoutAccountRow>(None).await?
        .ok_or_else(||worker::Error::RustError("payout account not found".into()))?;
    let currencies:Vec<String>=serde_json::from_str(&account.currencies_json).map_err(|_|worker::Error::RustError("invalid payout account currencies".into()))?;
    if account.state!="active" || account.onboarding_state!="verified" || account.kyc_status!="verified" || account.payouts_enabled!=1 || !currencies.iter().any(|c|c==&input.currency) {
        return Response::error("payout account is not verified/enabled for this currency",409);
    }
    let base=ctx.env.var("FABUSHI_PAY_INTERNAL_URL").ok().map(|v|v.to_string()).unwrap_or_else(||"https://pay.ombhrum.com".into());
    if !base.starts_with("https://") { return Response::error("invalid internal pay URL",500); }
    let admin=env_text(&ctx.env,"FABUSHI_PAY_ADMIN_TOKEN")?;
    let headers=Headers::new();
    headers.set("Authorization",&format!("Bearer {admin}"))?;
    headers.set("Content-Type","application/json")?;
    let body=json!({"idempotencyKey":input.idempotency_key,"developerId":developer.developer_id,"payoutAccountId":input.payout_account_id,"currency":input.currency,"amount":input.amount});
    let mut init=RequestInit::new();
    init.with_method(Method::Post).with_headers(headers).with_body(Some(JsValue::from_str(&body.to_string())));
    let outbound=Request::new_with_init(&format!("{}/v1/pay/admin/payouts",base.trim_end_matches('/')),&init)?;
    let mut response=Fetch::Request(outbound).send().await?;
    let status=response.status_code();
    let bytes=response.bytes().await?;
    let mut result=Response::from_bytes(bytes)?.with_status(status);
    result.headers_mut().set("Content-Type","application/json")?;
    Ok(result)
}
`;
  source = insertOnce(source, '#[event(fetch, respond_with_errors)]\npub async fn main', `${code}\n#[event(fetch, respond_with_errors)]\npub async fn main`, 'async fn payout_overview(');
  source = insertOnce(
    source,
    '      .get_async("/v1/developer/commerce/profile",get_profile).post_async("/v1/developer/commerce/profile",put_profile)\n',
    '      .get_async("/v1/developer/commerce/profile",get_profile).post_async("/v1/developer/commerce/profile",put_profile)\n      .get_async("/v1/developer/commerce/payout",payout_overview).post_async("/v1/developer/commerce/payout/profile",put_payout_profile)\n      .post_async("/v1/developer/commerce/payout/request",request_payout)\n',
    '"/v1/developer/commerce/payout/request"'
  );
  return source;
});
