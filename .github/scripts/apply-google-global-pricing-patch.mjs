import fs from 'node:fs';

const file = 'third_party/mahayana/mahayana-rs/mahayana-commerce-control-worker/src/worker_v2.rs';
let source = fs.readFileSync(file, 'utf8');
const start = source.indexOf('async fn sync_google(');
const end = source.indexOf('\n\n#[event(fetch', start);
if (start < 0 || end < 0) throw new Error('sync_google patch markers not found');
if (source.includes('build_google_price_conversion_request(&spec)')) process.exit(0);

const replacement = String.raw`async fn send_google_json(
    method: Method,
    url: &str,
    body: &serde_json::Value,
    token: &str,
) -> Result<(u16, Vec<u8>)> {
    let headers = Headers::new();
    headers.set("Authorization", &format!("Bearer {token}"))?;
    headers.set("Content-Type", "application/json")?;
    let mut init = RequestInit::new();
    init.with_method(method)
        .with_headers(headers)
        .with_body(Some(JsValue::from_str(&body.to_string())));
    let outbound = Request::new_with_init(url, &init)?;
    let mut response = Fetch::Request(outbound).send().await?;
    let status = response.status_code();
    let bytes = response.bytes().await?;
    Ok((status, bytes))
}

async fn sync_google(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let user = require_developer(&req, &ctx.env)?;
    if !env_enabled(&ctx.env, "GOOGLE_PLAY_CATALOG_SYNC_ENABLED") {
        return Response::error("Google catalog sync is not enabled", 503);
    }
    let app_id = ctx
        .param("mini_app_id")
        .ok_or_else(|| worker::Error::RustError("missing app".into()))?;
    let product_id = ctx
        .param("product_id")
        .ok_or_else(|| worker::Error::RustError("missing product".into()))?;
    app_access(&ctx.env, &user, app_id, true).await?;
    let p = product_row(&ctx.env, app_id, product_id).await?;
    let external = google_product_id(app_id, &p.sku);
    let spec = GoogleCatalogProduct {
        package_name: env_text(&ctx.env, "GOOGLE_PLAY_PACKAGE_NAME")?,
        product_id: external.clone(),
        display_name: p.display_name,
        description: p.description,
        product_kind: p.product_kind,
        currency: p.currency,
        amount_minor: p.amount,
        product_tax_category_code: p.tax_code,
    };
    let token = google_token(&ctx.env).await?;

    let conversion_call = build_google_price_conversion_request(&spec)
        .map_err(|e| worker::Error::RustError(e.to_string()))?;
    let (conversion_status, conversion_body) = send_google_json(
        Method::Post,
        &conversion_call.url,
        &conversion_call.body,
        &token,
    )
    .await?;
    if !(200..300).contains(&conversion_status) {
        let error = String::from_utf8_lossy(&conversion_body)
            .chars()
            .take(500)
            .collect::<String>();
        let t = now();
        worker::query!(&ctx.env.d1(DB)?,"UPDATE payment_provider_bindings SET sync_state='error',last_error=?1,updated_at=?2 WHERE product_id=?3 AND provider='google_play'",&error,t,product_id)?.run().await?;
        return Response::from_json(&json!({"ok":false,"stage":"convertRegionPrices","status":conversion_status,"error":error}));
    }
    let converted: GoogleConvertedPrices = serde_json::from_slice(&conversion_body)
        .map_err(|_| worker::Error::RustError("invalid Google converted pricing response".into()))?;
    let call = build_google_sync_request(&spec, &converted)
        .map_err(|e| worker::Error::RustError(e.to_string()))?;
    let method = if call.method == "POST" { Method::Post } else { Method::Patch };
    let (status, body) = send_google_json(method, &call.url, &call.body, &token).await?;
    let t = now();
    if !(200..300).contains(&status) {
        let error = String::from_utf8_lossy(&body)
            .chars()
            .take(500)
            .collect::<String>();
        worker::query!(&ctx.env.d1(DB)?,"UPDATE payment_provider_bindings SET sync_state='error',last_error=?1,updated_at=?2 WHERE product_id=?3 AND provider='google_play'",&error,t,product_id)?.run().await?;
        return Response::from_json(&json!({"ok":false,"stage":"catalogSync","status":status,"error":error}));
    }
    let metadata = serde_json::json!({
        "regionVersion": converted.region_version.version,
        "convertedRegionCount": converted.converted_region_prices.len(),
    }).to_string();
    worker::query!(&ctx.env.d1(DB)?,"UPDATE payment_provider_bindings SET sync_state='active',external_product_ref=?1,metadata_json=?2,last_error=NULL,last_synced_at=?3,updated_at=?3 WHERE product_id=?4 AND provider='google_play'",&external,&metadata,t,product_id)?.run().await?;
    Response::from_json(&json!({
        "ok": true,
        "provider": "google_play",
        "externalProductRef": external,
        "status": status,
        "regionVersion": converted.region_version.version,
        "convertedRegionCount": converted.converted_region_prices.len()
    }))
}`;

source = source.slice(0, start) + replacement + source.slice(end);
fs.writeFileSync(file, source);
