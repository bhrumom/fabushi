async fn lookup_login_user(
    database: &worker::D1Database,
    identifier: &str,
) -> Result<Option<AccountUserRow>> {
    let select = "SELECT u.id, u.user_no, u.username, u.username_changed_at, u.email,
                         u.nickname, u.avatar, u.phone_number, u.firebase_uid,
                         u.alipay_user_id, u.alipay_nickname, u.alipay_avatar,
                         u.wechat_headimgurl, u.password_hash, u.salt, u.iterations, u.algo,
                         c.password_phc AS upgraded_password_phc,
                         u.main_practice_title, u.main_practice_file_path,
                         u.main_practice_selected_at, u.created_at, u.email_verified,
                         u.membership_type, u.membership_expires_at, u.free_trial_end_date
                  FROM users u
                  LEFT JOIN account_password_credentials c ON c.user_id = CAST(u.id AS TEXT)";
    let (where_clause, normalized) = if identifier.contains('@') {
        ("LOWER(u.email) = ?1", identifier.to_ascii_lowercase())
    } else if looks_like_phone(identifier) {
        ("u.phone_number = ?1", identifier.to_string())
    } else {
        ("u.username = ?1", identifier.to_string())
    };
    let query = format!("{select} WHERE {where_clause} LIMIT 1");
    worker::query!(database, &query, normalized)?
        .first::<AccountUserRow>(None)
        .await
}

async fn lookup_account_user_by_id(
    database: &worker::D1Database,
    user_id: &str,
) -> Result<Option<AccountUserRow>> {
    worker::query!(
        database,
        "SELECT u.id, u.user_no, u.username, u.username_changed_at, u.email,
                u.nickname, u.avatar, u.phone_number, u.firebase_uid,
                u.alipay_user_id, u.alipay_nickname, u.alipay_avatar,
                u.wechat_headimgurl, u.password_hash, u.salt, u.iterations, u.algo,
                c.password_phc AS upgraded_password_phc,
                u.main_practice_title, u.main_practice_file_path,
                u.main_practice_selected_at, u.created_at, u.email_verified,
                u.membership_type, u.membership_expires_at, u.free_trial_end_date
         FROM users u
         LEFT JOIN account_password_credentials c ON c.user_id = CAST(u.id AS TEXT)
         WHERE CAST(u.id AS TEXT) = ?1 OR u.username = ?1
         LIMIT 1",
        user_id
    )?
    .first::<AccountUserRow>(None)
    .await
}

fn looks_like_phone(value: &str) -> bool {
    let value = value.strip_prefix('+').unwrap_or(value);
    (6..=20).contains(&value.len()) && value.bytes().all(|byte| byte.is_ascii_digit())
}

fn normalize_device_id(device_id: Option<&str>) -> Result<String> {
    let device_id = device_id.map(str::trim).filter(|value| !value.is_empty());
    let Some(device_id) = device_id else {
        return Ok(format!("device:{}", Uuid::new_v4()));
    };
    if device_id.len() > 128
        || !device_id
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-' | b':'))
    {
        return Err(worker::Error::RustError("invalid device id".into()));
    }
    Ok(device_id.to_string())
}

fn issue_account_access_token(
    env: &Env,
    user_id: &str,
    device_id: &str,
    session_id: &str,
    now: i64,
) -> Result<(String, i64, String)> {
    let expires_at = now + ACCESS_TOKEN_SECONDS;
    let jti = Uuid::new_v4().to_string();
    let claims = AccountAccessTokenClaims {
        iss: ACCESS_TOKEN_ISSUER.to_string(),
        sub: user_id.to_string(),
        aud: ACCESS_TOKEN_AUDIENCE.to_string(),
        scope: vec![
            "account.read".to_string(),
            "marketplace.read".to_string(),
            "marketplace.publish".to_string(),
            "wallet.read".to_string(),
            "commerce.purchase".to_string(),
            "model.invoke".to_string(),
        ],
        device_id: device_id.to_string(),
        sid: session_id.to_string(),
        jti: jti.clone(),
        iat: usize::try_from(now).unwrap_or_default(),
        exp: usize::try_from(expires_at).unwrap_or(usize::MAX),
        token_use: "access".to_string(),
    };
    let private_key = env.secret("ACCESS_TOKEN_PRIVATE_KEY_PEM")?.to_string();
    let key = EncodingKey::from_rsa_pem(private_key.as_bytes()).map_err(jwt_error)?;
    let mut header = Header::new(Algorithm::RS256);
    header.typ = Some("JWT".to_string());
    header.kid = Some(env.var("ACCESS_TOKEN_KEY_ID")?.to_string());
    let token = encode(&header, &claims, &key).map_err(jwt_error)?;
    Ok((token, expires_at, jti))
}

fn serialize_account_user(user: &AccountUserRow) -> serde_json::Value {
    let avatar = user
        .avatar
        .as_ref()
        .or(user.alipay_avatar.as_ref())
        .or(user.wechat_headimgurl.as_ref());
    let main_practice = user.main_practice_title.as_ref().map(|title| {
        json!({
            "title": title,
            "filePath": user.main_practice_file_path,
            "selectedAt": user.main_practice_selected_at,
        })
    });
    json!({
        "id": user.id,
        "userId": user.id,
        "userNo": user.user_no.unwrap_or(user.id),
        "username": user.username,
        "usernameChangedAt": user.username_changed_at,
        "email": user.email.as_deref().unwrap_or_default(),
        "nickname": user.nickname.as_deref().unwrap_or(&user.username),
        "avatar": avatar,
        "phoneNumber": user.phone_number,
        "firebaseUid": user.firebase_uid,
        "alipayProviderSubject": user.alipay_user_id,
        "alipayUserId": user.alipay_user_id,
        "alipayNickname": user.alipay_nickname,
        "alipayAvatar": user.alipay_avatar,
        "hasPassword": user.password_hash.is_some() && user.salt.is_some(),
        "mainPractice": main_practice,
        "createdAt": user.created_at,
        "emailVerified": user.email_verified == Some(1),
        "membership": {
            "type": user.membership_type.as_deref().unwrap_or("expired"),
            "expiresAt": user.membership_expires_at.as_ref().or(user.free_trial_end_date.as_ref()),
        },
    })
}

#[allow(clippy::too_many_arguments)]
fn account_session_response(
    user: &AccountUserRow,
    access_token: &str,
    refresh_token: &str,
    access_expires_at: i64,
    refresh_expires_at: i64,
    session_id: &str,
    device_id: &str,
) -> Result<Response> {
    Ok(Response::from_json(&json!({
        "accessToken": access_token,
        "refreshToken": refresh_token,
        "tokenType": "Bearer",
        "expiresIn": ACCESS_TOKEN_SECONDS,
        "accessTokenExpiresAt": access_expires_at,
        "refreshTokenExpiresAt": refresh_expires_at,
        "sessionId": session_id,
        "deviceId": device_id,
        "username": user.username,
        "userId": user.id,
        "userNo": user.user_no.unwrap_or(user.id),
        "user": serialize_account_user(user),
    }))?
    .with_headers(auth_headers()))
}

async fn record_auth_event(
    database: &worker::D1Database,
    user_id: Option<&str>,
    session_id: Option<&str>,
    event_type: &str,
    now: i64,
) -> Result<()> {
    worker::query!(
        database,
        "INSERT INTO account_auth_events
         (event_id, user_id, session_id, event_type, occurred_at, details_json)
         VALUES (?1, ?2, ?3, ?4, ?5, '{}')",
        Uuid::new_v4().to_string(),
        user_id,
        session_id,
        event_type,
        now
    )?
    .run()
    .await?;
    Ok(())
}

async fn account_login_is_rate_limited(
    database: &worker::D1Database,
    user_id: &str,
    now: i64,
) -> Result<bool> {
    let window_start = now - LOGIN_FAILURE_WINDOW_SECONDS;
    let count = worker::query!(
        database,
        "SELECT COUNT(*) AS failure_count
         FROM account_auth_events
         WHERE user_id = ?1 AND event_type = 'login_failed' AND occurred_at >= ?2",
        user_id,
        window_start
    )?
    .first::<LoginFailureCountRow>(None)
    .await?
    .map(|row| row.failure_count)
    .unwrap_or_default();
    Ok(count >= MAX_ACCOUNT_LOGIN_FAILURES)
}

async fn revoke_account_session(
    database: &worker::D1Database,
    session_id: &str,
    reason: &str,
    now: i64,
) -> Result<()> {
    let event_id = Uuid::new_v4().to_string();
    database
        .batch(vec![
            worker::query!(
                database,
                "UPDATE account_sessions
                 SET revoked_at = COALESCE(revoked_at, ?1), revoked_reason = COALESCE(revoked_reason, ?2)
                 WHERE session_id = ?3",
                now,
                reason,
                session_id
            )?,
            worker::query!(
                database,
                "UPDATE account_refresh_tokens SET state = 'revoked'
                 WHERE session_id = ?1 AND state = 'active'",
                session_id
            )?,
            worker::query!(
                database,
                "INSERT INTO account_auth_events
                 (event_id, user_id, session_id, event_type, occurred_at, details_json)
                 SELECT ?1, user_id, session_id, ?2, ?3, '{}'
                 FROM account_sessions WHERE session_id = ?4",
                &event_id,
                reason,
                now,
                session_id
            )?,
        ])
        .await?;
    Ok(())
}

fn authenticated_user(request: &Request, env: &Env) -> Result<String> {
    Ok(authenticated_account(request, env)?.user_id)
}

fn authenticated_account(request: &Request, env: &Env) -> Result<AuthenticatedAccount> {
    let authorization = request
        .headers()
        .get("Authorization")?
        .ok_or_else(|| worker::Error::RustError("missing Authorization header".into()))?;
    let token = authorization
        .strip_prefix("Bearer ")
        .ok_or_else(|| worker::Error::RustError("invalid Authorization scheme".into()))?;
    if let Ok(expected) = env.secret("TEST_ACCOUNT_TOKEN")
        && constant_time_eq(token.as_bytes(), expected.to_string().as_bytes())
    {
        return Ok(AuthenticatedAccount {
            user_id: "user:test_account".to_string(),
            session_id: None,
            scopes: vec![
                "marketplace.read".to_string(),
                "marketplace.publish".to_string(),
                "model.invoke".to_string(),
            ],
            is_test_account: true,
        });
    }
    let public_key = env.secret("ACCESS_TOKEN_PUBLIC_KEY_PEM")?.to_string();
    let key = DecodingKey::from_rsa_pem(public_key.as_bytes()).map_err(jwt_error)?;
    let mut validation = Validation::new(Algorithm::RS256);
    validation.set_issuer(&[ACCESS_TOKEN_ISSUER]);
    validation.set_audience(&[ACCESS_TOKEN_AUDIENCE]);
    let claims = decode::<AccountAccessTokenClaims>(token, &key, &validation)
        .map_err(jwt_error)?
        .claims;
    if claims.token_use != "access"
        || claims.sub.trim().is_empty()
        || claims.sid.trim().is_empty()
        || claims.device_id.trim().is_empty()
    {
        return Err(worker::Error::RustError(
            "invalid access token claims".into(),
        ));
    }
    Ok(AuthenticatedAccount {
        user_id: claims.sub,
        session_id: Some(claims.sid),
        scopes: claims.scope,
        is_test_account: false,
    })
}
