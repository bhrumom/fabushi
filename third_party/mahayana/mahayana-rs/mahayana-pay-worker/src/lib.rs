#![cfg_attr(not(target_arch = "wasm32"), allow(dead_code))]

#[cfg(target_arch = "wasm32")]
mod worker_api {
    use jsonwebtoken::{Algorithm, DecodingKey, Validation, decode};
    use serde::Deserialize;
    use worker::{Env, Request, Result};

    const ACCESS_TOKEN_ISSUER: &str = "https://api.ombhrum.com";
    const ACCESS_TOKEN_AUDIENCE: &str = "mahayana-platform";

    #[derive(Debug, Deserialize)]
    struct AccessTokenClaims {
        sub: String,
        #[serde(default)]
        scope: Vec<String>,
        token_use: String,
    }

    pub(crate) fn authenticated_user(request: &Request, env: &Env) -> Result<String> {
        let authorization = request
            .headers()
            .get("Authorization")?
            .ok_or_else(|| worker::Error::RustError("missing Authorization header".into()))?;
        let token = authorization
            .strip_prefix("Bearer ")
            .filter(|value| !value.trim().is_empty())
            .ok_or_else(|| worker::Error::RustError("invalid Authorization header".into()))?;
        let public_key = env.secret("ACCESS_TOKEN_PUBLIC_KEY_PEM")?.to_string();
        let key = DecodingKey::from_rsa_pem(public_key.as_bytes()).map_err(jwt_error)?;
        let mut validation = Validation::new(Algorithm::RS256);
        validation.set_issuer(&[ACCESS_TOKEN_ISSUER]);
        validation.set_audience(&[ACCESS_TOKEN_AUDIENCE]);
        let claims = decode::<AccessTokenClaims>(token, &key, &validation)
            .map_err(jwt_error)?
            .claims;
        if claims.token_use != "access"
            || !claims.scope.iter().any(|scope| scope == "commerce.purchase")
        {
            return Err(worker::Error::RustError(
                "access token cannot perform payment operations".into(),
            ));
        }
        Ok(claims.sub)
    }

    fn jwt_error(error: jsonwebtoken::errors::Error) -> worker::Error {
        worker::Error::RustError(format!("invalid account access token: {error}"))
    }
}

#[cfg(target_arch = "wasm32")]
mod payment_api {
    include!("../../mahayana-platform-worker/src/payment_api.rs");

    impl serde::Serialize for PayoutRow {
        fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
        where
            S: serde::Serializer,
        {
            use serde::ser::SerializeStruct;
            let mut state = serializer.serialize_struct("PayoutRow", 6)?;
            state.serialize_field("payoutId", &self.payout_id)?;
            state.serialize_field("developerId", &self.developer_id)?;
            state.serialize_field("payoutAccountId", &self.payout_account_id)?;
            state.serialize_field("currency", &self.currency)?;
            state.serialize_field("amount", &self.amount)?;
            state.serialize_field("status", &self.status)?;
            state.end()
        }
    }

    #[derive(Debug, Deserialize)]
    #[serde(rename_all = "camelCase", deny_unknown_fields)]
    struct AdminProductRequest {
        product_id: String,
        price_id: String,
        mini_app_id: String,
        sku: String,
        developer_id: String,
        capability: String,
        product_kind: String,
        currency: String,
        amount: i64,
        platform_fee_bps: u16,
        allowed_rails: Vec<String>,
        #[serde(default)]
        provider_product_refs: BTreeMap<String, String>,
    }

    pub async fn admin_upsert_product(
        mut request: Request,
        context: RouteContext<()>,
    ) -> Result<Response> {
        require_bearer_secret(&request, &context.env, "FABUSHI_PAY_ADMIN_TOKEN")?;
        let input: AdminProductRequest = request.json().await?;
        for value in [
            input.product_id.as_str(),
            input.price_id.as_str(),
            input.mini_app_id.as_str(),
            input.sku.as_str(),
            input.developer_id.as_str(),
            input.capability.as_str(),
            input.currency.as_str(),
        ] {
            validate_identifier(value)?;
        }
        if input.amount <= 0 {
            return error_response(400, "invalid_amount", "product amount must be positive");
        }
        let product_kind = match input.product_kind.as_str() {
            "digitalConsumable" | "digital_consumable" => "digital_consumable",
            "digitalDurable" | "digital_durable" => "digital_durable",
            "subscription" => "subscription",
            "physical" => "physical",
            "service" => "service",
            _ => {
                return error_response(
                    400,
                    "invalid_product_kind",
                    "unsupported payment product kind",
                );
            }
        };
        if input.allowed_rails.is_empty() {
            return error_response(
                400,
                "missing_payment_rails",
                "at least one payment rail must be enabled",
            );
        }
        let mut rails = Vec::with_capacity(input.allowed_rails.len());
        for rail in &input.allowed_rails {
            let normalized = normalize_rail(rail)?.to_string();
            if !rails.contains(&normalized) {
                rails.push(normalized);
            }
        }
        let mut provider_refs = BTreeMap::<String, String>::new();
        for (rail, product_ref) in &input.provider_product_refs {
            validate_identifier(product_ref)?;
            provider_refs.insert(normalize_rail(rail)?.to_string(), product_ref.clone());
        }
        for rail in &rails {
            if rail != "credits" && !provider_refs.contains_key(rail) {
                return error_response(
                    400,
                    "provider_product_missing",
                    "every external payment rail requires a provider product identifier",
                );
            }
        }
        if rails.iter().any(|rail| rail == "credits") && input.currency != CREDITS_CURRENCY {
            return error_response(
                400,
                "credits_currency_mismatch",
                "credits-enabled products must be priced in FBC",
            );
        }

        let rails_json = serde_json::to_string(&rails).map_err(|error| {
            worker::Error::RustError(format!("failed to encode payment rail policy: {error}"))
        })?;
        let provider_refs_json = serde_json::to_string(&provider_refs).map_err(|error| {
            worker::Error::RustError(format!("failed to encode provider product policy: {error}"))
        })?;
        let consumption_mode = if product_kind == "digital_consumable" {
            "consumable"
        } else {
            "durable"
        };
        let database = context.env.d1(DATABASE_BINDING)?;
        let now = now_seconds();
        database
            .batch(vec![
                worker::query!(
                    &database,
                    "INSERT INTO products
                     (product_id, plugin_id, sku, seller_user_id, entitlement_capability,
                      consumption_mode, active, created_at, updated_at)
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6, 1, ?7, ?7)
                     ON CONFLICT(product_id) DO UPDATE SET
                       plugin_id = excluded.plugin_id,
                       sku = excluded.sku,
                       seller_user_id = excluded.seller_user_id,
                       entitlement_capability = excluded.entitlement_capability,
                       consumption_mode = excluded.consumption_mode,
                       active = 1,
                       updated_at = excluded.updated_at",
                    &input.product_id,
                    &input.mini_app_id,
                    &input.sku,
                    &input.developer_id,
                    &input.capability,
                    consumption_mode,
                    now
                )?,
                worker::query!(
                    &database,
                    "UPDATE prices SET active = 0, ends_at = COALESCE(ends_at, ?1)
                     WHERE product_id = ?2 AND currency = ?3 AND active = 1 AND price_id <> ?4",
                    now,
                    &input.product_id,
                    &input.currency,
                    &input.price_id
                )?,
                worker::query!(
                    &database,
                    "INSERT INTO prices
                     (price_id, product_id, currency, amount, active, starts_at, ends_at, created_at)
                     VALUES (?1, ?2, ?3, ?4, 1, ?5, NULL, ?5)
                     ON CONFLICT(price_id) DO UPDATE SET
                       product_id = excluded.product_id,
                       currency = excluded.currency,
                       amount = excluded.amount,
                       active = 1,
                       starts_at = excluded.starts_at,
                       ends_at = NULL",
                    &input.price_id,
                    &input.product_id,
                    &input.currency,
                    input.amount,
                    now
                )?,
                worker::query!(
                    &database,
                    "INSERT INTO payment_product_config
                     (product_id, developer_id, product_kind, platform_fee_bps,
                      allowed_rails_json, provider_product_refs_json, active, created_at, updated_at)
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6, 1, ?7, ?7)
                     ON CONFLICT(product_id) DO UPDATE SET
                       developer_id = excluded.developer_id,
                       product_kind = excluded.product_kind,
                       platform_fee_bps = excluded.platform_fee_bps,
                       allowed_rails_json = excluded.allowed_rails_json,
                       provider_product_refs_json = excluded.provider_product_refs_json,
                       active = 1,
                       updated_at = excluded.updated_at",
                    &input.product_id,
                    &input.developer_id,
                    product_kind,
                    i64::from(input.platform_fee_bps),
                    &rails_json,
                    &provider_refs_json,
                    now
                )?,
            ])
            .await?;

        Response::from_json(&json!({
            "ok": true,
            "productId": input.product_id,
            "priceId": input.price_id,
            "miniAppId": input.mini_app_id,
            "sku": input.sku,
            "developerId": input.developer_id,
            "productKind": product_kind,
            "currency": input.currency,
            "amount": input.amount,
            "platformFeeBps": input.platform_fee_bps,
            "allowedRails": rails,
            "providerProductRefs": provider_refs,
        }))
    }
}

#[cfg(target_arch = "wasm32")]
use worker::{Context, Env, Request, Response, Result, Router, event};

#[cfg(target_arch = "wasm32")]
#[event(fetch, respond_with_errors)]
pub async fn main(request: Request, env: Env, _context: Context) -> Result<Response> {
    Router::new()
        .get("/health", |_, _| {
            Response::from_json(&serde_json::json!({
                "ok": true,
                "service": "fabushi-pay",
                "schema": "mahayana.miniapp.payment.v1"
            }))
        })
        .post_async(
            "/v1/miniapps/:mini_app_id/pay/intents",
            payment_api::create_intent,
        )
        .get_async("/v1/pay/intents/:payment_id", payment_api::get_intent)
        .post_async(
            "/v1/pay/intents/:payment_id/checkout",
            payment_api::checkout_action,
        )
        .post_async(
            "/v1/pay/intents/:payment_id/credits/confirm",
            payment_api::confirm_credits,
        )
        .post_async(
            "/v1/pay/intents/:payment_id/apple/verify",
            payment_api::verify_apple,
        )
        .post_async(
            "/v1/pay/intents/:payment_id/google/verify",
            payment_api::verify_google,
        )
        .post_async(
            "/v1/pay/providers/:provider/webhook",
            payment_api::provider_webhook,
        )
        .post_async(
            "/v1/pay/admin/products",
            payment_api::admin_upsert_product,
        )
        .post_async(
            "/v1/pay/admin/settlements/release",
            payment_api::admin_release_settlement,
        )
        .post_async(
            "/v1/pay/admin/payout-accounts",
            payment_api::admin_upsert_payout_account,
        )
        .post_async("/v1/pay/admin/payouts", payment_api::admin_create_payout)
        .get_async(
            "/v1/pay/admin/developers/:developer_id/balance/:currency",
            payment_api::admin_developer_balance,
        )
        .run(request, env)
        .await
}

#[cfg(test)]
mod tests {
    #[test]
    fn payment_service_is_intentionally_standalone() {
        assert_eq!(env!("CARGO_PKG_NAME"), "mahayana-pay-worker");
    }
}
