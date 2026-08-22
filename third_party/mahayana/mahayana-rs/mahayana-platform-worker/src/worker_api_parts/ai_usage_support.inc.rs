async fn current_usage_status(
    database: &worker::D1Database,
    env: &Env,
    user_id: &str,
    now: i64,
) -> Result<AccountUsageStatus> {
    let window_start = usage_window_start(now);
    let window_end = window_start + USAGE_WINDOW_SECONDS;
    let row = worker::query!(
        database,
        "SELECT window_start, window_end, token_limit, used_tokens, reserved_tokens
         FROM ai_usage_budgets WHERE user_id = ?1 AND window_start = ?2",
        user_id,
        window_start
    )?
    .first::<UsageBudgetRow>(None)
    .await?;
    let (token_limit, used_tokens, reserved_tokens) = match row {
        Some(row) => {
            debug_assert_eq!(row.window_start, window_start);
            debug_assert_eq!(row.window_end, window_end);
            (row.token_limit, row.used_tokens, row.reserved_tokens)
        }
        None => (default_usage_limit(env)?, 0, 0),
    };
    Ok(AccountUsageStatus {
        window_start,
        window_end,
        token_limit,
        used_tokens,
        reserved_tokens,
        remaining_tokens: token_limit
            .saturating_sub(used_tokens)
            .saturating_sub(reserved_tokens),
    })
}

async fn usage_reservation_by_request(
    database: &worker::D1Database,
    user_id: &str,
    request_id: &str,
) -> Result<Option<UsageReservationRow>> {
    worker::query!(
        database,
        "SELECT reservation_id, request_id, reserved_tokens, expires_at, state
         FROM ai_usage_reservations WHERE user_id = ?1 AND request_id = ?2",
        user_id,
        request_id
    )?
    .first::<UsageReservationRow>(None)
    .await
}

async fn usage_reservation_by_id(
    database: &worker::D1Database,
    user_id: &str,
    reservation_id: &str,
) -> Result<Option<UsageReservationRow>> {
    worker::query!(
        database,
        "SELECT reservation_id, request_id, reserved_tokens, expires_at, state
         FROM ai_usage_reservations WHERE user_id = ?1 AND reservation_id = ?2",
        user_id,
        reservation_id
    )?
    .first::<UsageReservationRow>(None)
    .await
}

async fn usage_event_by_response(
    database: &worker::D1Database,
    provider_response_id: &str,
) -> Result<Option<UsageEventRow>> {
    worker::query!(
        database,
        "SELECT reservation_id FROM ai_usage_events WHERE provider_response_id = ?1",
        provider_response_id
    )?
    .first::<UsageEventRow>(None)
    .await
}

async fn expire_usage_reservations(
    database: &worker::D1Database,
    user_id: &str,
    now: i64,
) -> Result<()> {
    database
        .batch(vec![
            worker::query!(
                database,
                "UPDATE ai_usage_budgets
                 SET reserved_tokens = reserved_tokens - COALESCE((
                         SELECT SUM(r.reserved_tokens) FROM ai_usage_reservations r
                         WHERE r.user_id = ?1 AND r.window_start = ai_usage_budgets.window_start
                           AND r.state = 'reserved' AND r.expires_at <= ?2
                     ), 0),
                     updated_at = ?2
                 WHERE user_id = ?1
                   AND EXISTS (
                       SELECT 1 FROM ai_usage_reservations r
                       WHERE r.user_id = ?1 AND r.window_start = ai_usage_budgets.window_start
                         AND r.state = 'reserved' AND r.expires_at <= ?2
                   )",
                user_id,
                now
            )?,
            worker::query!(
                database,
                "UPDATE ai_usage_reservations SET state = 'expired', updated_at = ?1
                 WHERE user_id = ?2 AND state = 'reserved' AND expires_at <= ?1
                   AND EXISTS (
                       SELECT 1 FROM ai_usage_budgets b
                       WHERE b.user_id = ?2 AND b.window_start = ai_usage_reservations.window_start
                   )",
                now,
                user_id
            )?,
        ])
        .await?;
    Ok(())
}

pub(super) fn d1_changes(result: Option<&worker::D1Result>) -> usize {
    result
        .and_then(|result| result.meta().ok().flatten())
        .and_then(|meta| meta.changes)
        .unwrap_or_default()
}

fn usage_window_start(now: i64) -> i64 {
    now - now.rem_euclid(USAGE_WINDOW_SECONDS)
}

fn default_usage_limit(env: &Env) -> Result<i64> {
    let value = env.var("DEFAULT_AI_TOKEN_LIMIT")?.to_string();
    value
        .parse::<i64>()
        .ok()
        .filter(|limit| *limit >= 0)
        .ok_or_else(|| worker::Error::RustError("DEFAULT_AI_TOKEN_LIMIT is invalid".into()))
}

fn require_model_gateway(request: &Request, env: &Env) -> Result<()> {
    let supplied = request
        .headers()
        .get("X-Mahayana-Model-Gateway")?
        .ok_or_else(|| worker::Error::RustError("missing model gateway credential".into()))?;
    let expected = env.secret("MODEL_GATEWAY_TOKEN")?.to_string();
    if !constant_time_eq(supplied.as_bytes(), expected.as_bytes()) {
        return Err(worker::Error::RustError(
            "invalid model gateway credential".into(),
        ));
    }
    Ok(())
}

fn constant_time_eq(left: &[u8], right: &[u8]) -> bool {
    if left.len() != right.len() {
        return false;
    }
    left.iter()
        .zip(right)
        .fold(0_u8, |difference, (left, right)| {
            difference | (left ^ right)
        })
        == 0
}

fn usage_limit_response(status: &AccountUsageStatus) -> Result<Response> {
    Ok(Response::from_json(&json!({
        "error": {
            "type": "usage_limit_reached",
            "message": "Mahayana model token limit reached",
            "resets_at": status.window_end,
        },
        "usage": status,
    }))?
    .with_status(429))
}
