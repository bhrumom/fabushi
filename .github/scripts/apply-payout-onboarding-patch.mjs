import fs from 'node:fs';

function patchFile(file, transform) {
  const before = fs.readFileSync(file, 'utf8');
  const after = transform(before);
  if (after !== before) fs.writeFileSync(file, after);
}
function insertOnce(source, marker, replacement, proof) {
  if (source.includes(proof)) return source;
  if (!source.includes(marker)) throw new Error(`payout-onboarding marker not found: ${marker}`);
  return source.replace(marker, replacement);
}

patchFile('third_party/mahayana/mahayana-rs/mahayana-commerce-control-worker/src/worker_v2.rs', (input) => {
  let source = input;
  const code = `
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct PayoutOnboardingInput {
    provider: String,
    purpose: String,
}

fn allowed_onboarding_provider(region: &str, provider: &str, purpose: &str) -> bool {
    if region == "CN" {
        match purpose {
            "original_order_split" => matches!(provider, "wechat_platform" | "alipay_platform"),
            "external_proceeds_payout" | "marketplace_payout" => matches!(provider, "lianlian_account_plus" | "huifu_dougong"),
            _ => false,
        }
    } else {
        match purpose {
            "marketplace_payout" => matches!(provider, "stripe_connect" | "adyen_platform" | "paypal_multiparty" | "paypal_payouts"),
            "external_proceeds_payout" => matches!(provider, "stripe_connect" | "adyen_platform" | "paypal_payouts"),
            _ => false,
        }
    }
}

fn payout_onboarding_env(provider: &str) -> Option<&'static str> {
    match provider {
        "stripe_connect" => Some("PAYOUT_STRIPE_CONNECT_ONBOARDING_URL"),
        "adyen_platform" => Some("PAYOUT_ADYEN_PLATFORM_ONBOARDING_URL"),
        "paypal_multiparty" => Some("PAYOUT_PAYPAL_MULTIPARTY_ONBOARDING_URL"),
        "paypal_payouts" => Some("PAYOUT_PAYPAL_PAYOUTS_ONBOARDING_URL"),
        "wechat_platform" => Some("PAYOUT_WECHAT_PLATFORM_ONBOARDING_URL"),
        "alipay_platform" => Some("PAYOUT_ALIPAY_PLATFORM_ONBOARDING_URL"),
        "lianlian_account_plus" => Some("PAYOUT_LIANLIAN_ACCOUNT_PLUS_ONBOARDING_URL"),
        "huifu_dougong" => Some("PAYOUT_HUIFU_DOUGONG_ONBOARDING_URL"),
        _ => None,
    }
}

async fn create_payout_onboarding(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let user = require_developer(&req, &ctx.env)?;
    let developer = profile(&ctx.env, &user).await?.ok_or_else(|| worker::Error::RustError("developer profile not found".into()))?;
    let input: PayoutOnboardingInput = req.json().await?;
    let database = ctx.env.d1(DB)?;
    let payout_profile = worker::query!(&database,
        "SELECT country_code,legal_entity_type,preferred_currency,compliance_state FROM developer_payout_profiles WHERE developer_id=?1 LIMIT 1",
        &developer.developer_id)?.first::<Value>(None).await?
        .ok_or_else(|| worker::Error::RustError("configure payout profile first".into()))?;
    let country = payout_profile.get("country_code").and_then(Value::as_str).unwrap_or("ZZ");
    let region = if country == "CN" { "CN" } else { "GLOBAL" };
    if !allowed_onboarding_provider(region, &input.provider, &input.purpose) {
        return Response::error("provider/purpose is not eligible for this developer region", 400);
    }
    let active_route = worker::query!(&database,
        "SELECT route_id FROM payout_provider_routes WHERE region_code=?1 AND purpose=?2 AND provider=?3 AND state='active' LIMIT 1",
        region,&input.purpose,&input.provider)?.first::<Value>(None).await?;
    if active_route.is_none() { return Response::error("payout provider is not approved/configured for this route", 503); }
    let env_name = payout_onboarding_env(&input.provider).ok_or_else(|| worker::Error::RustError("unsupported payout onboarding provider".into()))?;
    let endpoint = ctx.env.var(env_name).map_err(|_| worker::Error::RustError(format!("missing {env_name}")))?.to_string();
    if !endpoint.starts_with("https://") || endpoint.contains(char::is_whitespace) { return Response::error("invalid payout onboarding endpoint", 500); }
    let token = env_text(&ctx.env,"PAYOUT_PROVIDER_EXECUTOR_TOKEN")?;
    let session_id = format!("onboard.{}",Uuid::new_v4().simple());
    let headers=Headers::new();
    headers.set("Authorization",&format!("Bearer {token}"))?;
    headers.set("Content-Type","application/json")?;
    let body=json!({"sessionId":session_id,"developerId":developer.developer_id,"provider":input.provider,"purpose":input.purpose,"countryCode":country,"legalEntityType":payout_profile.get("legal_entity_type").and_then(Value::as_str).unwrap_or("company"),"preferredCurrency":payout_profile.get("preferred_currency").and_then(Value::as_str).unwrap_or("USD")});
    let mut init=RequestInit::new();
    init.with_method(Method::Post).with_headers(headers).with_body(Some(JsValue::from_str(&body.to_string())));
    let outbound=Request::new_with_init(&endpoint,&init)?;
    let mut response=Fetch::Request(outbound).send().await?;
    let status=response.status_code();
    let bytes=response.bytes().await?;
    if !(200..300).contains(&status) {
        worker::query!(&database,"INSERT INTO developer_payout_onboarding_sessions (session_id,developer_id,provider,country_code,state,last_error,created_at,updated_at) VALUES (?1,?2,?3,?4,'failed',?5,?6,?6)",&session_id,&developer.developer_id,&input.provider,country,&String::from_utf8_lossy(&bytes).chars().take(500).collect::<String>(),now())?.run().await?;
        return Response::error("provider onboarding request failed",502);
    }
    let payload:Value=serde_json::from_slice(&bytes).map_err(|_|worker::Error::RustError("invalid payout onboarding response".into()))?;
    let onboarding_url=payload.get("onboardingUrl").and_then(Value::as_str).ok_or_else(||worker::Error::RustError("provider onboarding response lacks onboardingUrl".into()))?;
    if !onboarding_url.starts_with("https://") { return Response::error("provider onboarding URL must be HTTPS",502); }
    let provider_session_reference=payload.get("providerSessionReference").and_then(Value::as_str);
    let payout_account_id=payload.get("payoutAccountId").and_then(Value::as_str);
    let expires_at=payload.get("expiresAt").and_then(Value::as_i64);
    let t=now();
    worker::query!(&database,"INSERT INTO developer_payout_onboarding_sessions (session_id,developer_id,provider,country_code,payout_account_id,provider_session_reference,state,expires_at,created_at,updated_at) VALUES (?1,?2,?3,?4,?5,?6,'pending',?7,?8,?8)",&session_id,&developer.developer_id,&input.provider,country,payout_account_id,provider_session_reference,expires_at,t)?.run().await?;
    Response::from_json(&json!({"sessionId":session_id,"provider":input.provider,"purpose":input.purpose,"onboardingUrl":onboarding_url,"expiresAt":expires_at,"state":"pending"}))
}
`;
  source = insertOnce(source, '#[event(fetch, respond_with_errors)]\npub async fn main', `${code}\n#[event(fetch, respond_with_errors)]\npub async fn main`, 'async fn create_payout_onboarding(');
  source = insertOnce(source, '      .get_async("/v1/developer/commerce/payout",payout_overview).post_async("/v1/developer/commerce/payout/profile",put_payout_profile)\n', '      .get_async("/v1/developer/commerce/payout",payout_overview).post_async("/v1/developer/commerce/payout/profile",put_payout_profile)\n      .post_async("/v1/developer/commerce/payout/onboarding",create_payout_onboarding)\n', '"/v1/developer/commerce/payout/onboarding"');
  return source;
});
