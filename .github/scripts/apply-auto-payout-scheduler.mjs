import fs from 'node:fs';

const file = 'third_party/mahayana/mahayana-rs/mahayana-commerce-control-worker/src/worker_v2.rs';
let source = fs.readFileSync(file, 'utf8');

function insertOnce(marker, replacement, proof) {
  if (source.includes(proof)) return;
  if (!source.includes(marker)) throw new Error(`auto-payout marker not found: ${marker}`);
  source = source.replace(marker, replacement);
}

source = source.replace(
  '    Context, Env, Fetch, Headers, Method, Request, RequestInit, Response, Result, RouteContext,\n    Router, event,\n',
  '    Context, Env, Fetch, Headers, Method, Request, RequestInit, Response, Result, RouteContext,\n    Router, ScheduleContext, ScheduledEvent, event,\n'
);

const code = `
#[derive(Debug, Clone, Deserialize)]
struct AutoPayoutCandidate {
    developer_id: String,
    preferred_currency: String,
    payout_schedule: String,
    minimum_payout_amount: i64,
    last_scheduled_payout_at: Option<i64>,
    payout_account_id: String,
}

fn payout_schedule_seconds(schedule: &str) -> Option<i64> {
    match schedule {
        "daily" => Some(86_400),
        "weekly" => Some(604_800),
        "monthly" => Some(2_592_000),
        _ => None,
    }
}

fn payout_schedule_due(schedule: &str, last: Option<i64>, current: i64) -> bool {
    let Some(period) = payout_schedule_seconds(schedule) else { return false; };
    last.map(|value| current.saturating_sub(value) >= period).unwrap_or(true)
}

async fn pay_admin_json(env: &Env, path: &str, body: Option<Value>) -> Result<(u16, Value)> {
    let base = env.var("FABUSHI_PAY_INTERNAL_URL").ok().map(|value| value.to_string()).unwrap_or_else(|| "https://pay.ombhrum.com".into());
    if !base.starts_with("https://") || base.contains(char::is_whitespace) {
        return Err(worker::Error::RustError("invalid FABUSHI_PAY_INTERNAL_URL".into()));
    }
    let token = env_text(env, "FABUSHI_PAY_ADMIN_TOKEN")?;
    let headers = Headers::new();
    headers.set("Authorization", &format!("Bearer {token}"))?;
    headers.set("Content-Type", "application/json")?;
    let mut init = RequestInit::new();
    init.with_method(Method::Post).with_headers(headers);
    if let Some(body) = body { init.with_body(Some(JsValue::from_str(&body.to_string()))); }
    let request = Request::new_with_init(&format!("{}{}", base.trim_end_matches('/'), path), &init)?;
    let mut response = Fetch::Request(request).send().await?;
    let status = response.status_code();
    let bytes = response.bytes().await?;
    let value = serde_json::from_slice(&bytes).unwrap_or_else(|_| json!({"raw":String::from_utf8_lossy(&bytes)}));
    Ok((status, value))
}

async fn run_payout_maintenance(env: &Env) -> Result<()> {
    // Release matured risk reserves first so the sweep sees the final available balance.
    let (reserve_status, _) = pay_admin_json(env, "/v1/pay/admin/settlements/reserves/release-due", None).await?;
    if !(200..300).contains(&reserve_status) {
        return Err(worker::Error::RustError(format!("reserve release sweep failed with HTTP {reserve_status}")));
    }

    let database = env.d1(DB)?;
    let candidates = worker::query!(&database,
        "SELECT p.developer_id,p.preferred_currency,p.payout_schedule,p.minimum_payout_amount,p.last_scheduled_payout_at,a.payout_account_id
         FROM developer_payout_profiles p
         JOIN developer_payout_accounts a ON a.developer_id=p.developer_id
         WHERE p.compliance_state='eligible' AND p.payout_schedule<>'manual'
           AND a.is_default=1 AND a.state='active' AND a.onboarding_state='verified'
           AND a.kyc_status='verified' AND a.payouts_enabled=1
           AND EXISTS (SELECT 1 FROM json_each(a.currencies_json) WHERE value=p.preferred_currency)
           AND EXISTS (SELECT 1 FROM json_each(a.purposes_json) WHERE value='marketplace_payout')
           AND EXISTS (
             SELECT 1 FROM payout_provider_routes r
             WHERE r.region_code=CASE WHEN p.country_code='CN' THEN 'CN' ELSE 'GLOBAL' END
               AND r.purpose='marketplace_payout' AND r.provider=a.provider AND r.state='active'
           )
         ORDER BY p.developer_id,a.is_default DESC,a.created_at ASC")?.all().await?.results::<AutoPayoutCandidate>()?;
    let current = now();
    let mut seen = std::collections::BTreeSet::new();
    for candidate in candidates {
        if !seen.insert(candidate.developer_id.clone()) || !payout_schedule_due(&candidate.payout_schedule, candidate.last_scheduled_payout_at, current) {
            continue;
        }
        let account_id = format!("developer-available:{}:{}", candidate.developer_id, candidate.preferred_currency);
        let balance = worker::query!(&database,"SELECT balance FROM wallet_balances WHERE account_id=?1 LIMIT 1",&account_id)?.first::<Value>(None).await?
            .and_then(|value| value.get("balance").and_then(Value::as_i64)).unwrap_or(0);
        let minimum = candidate.minimum_payout_amount.max(1);
        if balance < minimum { continue; }
        let period = payout_schedule_seconds(&candidate.payout_schedule).unwrap_or(86_400);
        let bucket = current / period;
        let idempotency_key = format!("auto:{}:{}:{}", candidate.developer_id, candidate.preferred_currency, bucket);
        let create_body = json!({
            "idempotencyKey": idempotency_key,
            "developerId": candidate.developer_id,
            "payoutAccountId": candidate.payout_account_id,
            "currency": candidate.preferred_currency,
            "amount": balance
        });
        let (create_status, created) = pay_admin_json(env, "/v1/pay/admin/payouts", Some(create_body)).await?;
        if !(200..300).contains(&create_status) { continue; }
        let payout_id = created.get("payout").and_then(|value| value.get("payoutId")).and_then(Value::as_str)
            .or_else(|| created.get("payoutId").and_then(Value::as_str));
        let Some(payout_id) = payout_id else { continue; };
        let (dispatch_status, _) = pay_admin_json(env, &format!("/v1/pay/admin/payouts/{}/dispatch", payout_id), Some(json!({}))).await?;
        if (200..300).contains(&dispatch_status) {
            worker::query!(&database,"UPDATE developer_payout_profiles SET last_scheduled_payout_at=?1,updated_at=?1 WHERE developer_id=?2",current,&candidate.developer_id)?.run().await?;
        }
    }
    Ok(())
}
`;
insertOnce('#[event(fetch, respond_with_errors)]\npub async fn main', `${code}\n#[event(fetch, respond_with_errors)]\npub async fn main`, 'async fn run_payout_maintenance(');

if (!source.includes('#[event(scheduled)]')) {
  source += `\n#[event(scheduled)]\npub async fn scheduled(_event: ScheduledEvent, env: Env, _ctx: ScheduleContext) {\n    if let Err(error) = run_payout_maintenance(&env).await {\n        worker::console_error!("developer payout maintenance failed: {}", error);\n    }\n}\n`;
}

fs.writeFileSync(file, source);
