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
