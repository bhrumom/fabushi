use super::*;

const MARKETPLACE_INSTALL_PROTOCOL: &str = "fabushi.marketplace.install.v1";
const CHROME_EXTENSION_PLATFORM: &str = "chrome-extension";

// The Chrome extension has a separately released userscript runtime.  Keep
// this projection independent from the desktop Mini App release in D1: a
// Chrome client may still be running an older unpacked extension whose
// bundled fallback is stale, while desktop clients must continue to receive
// the approved Mini App package.  The immutable commit, byte count and
// digest are checked again by the extension before installation.
const CHATGPT_USERSCRIPT_PLUGIN_ID: &str = "chatgpt-auto-confirm";
const CHATGPT_USERSCRIPT_VERSION: &str = "2.9.31";
const CHATGPT_USERSCRIPT_REPOSITORY: &str =
    "https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript";
const CHATGPT_USERSCRIPT_COMMIT: &str = "5f7d1f26a9883e6806ec855f5f2177ad737aa07e";
const CHATGPT_USERSCRIPT_RELEASE_URL: &str =
    "https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.31";
const CHATGPT_USERSCRIPT_ARTIFACT_URL: &str = "https://raw.githubusercontent.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/5f7d1f26a9883e6806ec855f5f2177ad737aa07e/chatgpt-auto-confirm.user.js";
const CHATGPT_USERSCRIPT_SHA256: &str =
    "1e025a9b64bcba225059a0768fb08b5bcf818f902f8c7c4e5980505958e6fe2a";
const CHATGPT_USERSCRIPT_SIZE: i64 = 225_544;
const CHATGPT_USERSCRIPT_PUBLISHED_AT: i64 = 1_789_449_292;

const MARKETPLACE_SECURITY_TOKEN: &str = "MARKETPLACE_SECURITY_TOKEN";
const MARKETPLACE_SECURITY_SERVER_ID: &str = "MARKETPLACE_SECURITY_SERVER_ID";
const MARKETPLACE_SECURITY_SOURCE_SHA: &str = "MARKETPLACE_SECURITY_SOURCE_SHA";
const MARKETPLACE_SECURITY_SIGNER_PUBLIC_KEY_SHA256: &str =
    "MARKETPLACE_SECURITY_SIGNER_PUBLIC_KEY_SHA256";
const MARKETPLACE_SECURITY_SERVICE_NAME: &str = "fabushi-marketplace-security-gate";
const MARKETPLACE_SECURITY_SIGNER_KEY_ID: &str = "fabushi-marketplace-security-2026-09";
const MARKETPLACE_SECURITY_SCAN_INTERVAL_SECONDS: i64 = 24 * 60 * 60;
const MARKETPLACE_SECURITY_CLAIM_STALE_SECONDS: i64 = 30 * 60;
const MARKETPLACE_SECURITY_REPORT_MAX_BYTES: usize = 128 * 1024;
const MARKETPLACE_SECURITY_QUEUE_LIMIT: usize = 20;
const MARKETPLACE_SECURITY_CHECKS: [&str; 4] =
    ["malware", "dynamicSandbox", "secrets", "dependencies"];

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct MarketplaceSecurityClaimRequest {
    plugin_id: String,
    version: String,
    scan_run_id: String,
}

fn marketplace_security_token_matches(request: &Request, env: &Env) -> Result<Option<bool>> {
    let expected = match env.secret(MARKETPLACE_SECURITY_TOKEN) {
        Ok(secret) => secret.to_string(),
        Err(_) => return Ok(None),
    };
    let authorization = request.headers().get("Authorization")?.unwrap_or_default();
    let supplied = authorization
        .strip_prefix("Bearer ")
        .map(str::trim)
        .unwrap_or_default();
    Ok(Some(
        !supplied.is_empty() && constant_time_eq(supplied.as_bytes(), expected.as_bytes()),
    ))
}

fn valid_marketplace_security_run_id(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 160
        && value.bytes().all(|byte| {
            byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-')
        })
}

fn marketplace_security_check_status<'a>(report: &'a Value, name: &str) -> Option<&'a str> {
    report
        .get("checks")
        .and_then(Value::as_object)
        .and_then(|checks| checks.get(name))
        .and_then(Value::as_object)
        .and_then(|check| check.get("status"))
        .and_then(Value::as_str)
}

fn marketplace_security_checks_are_well_formed(report: &Value) -> bool {
    MARKETPLACE_SECURITY_CHECKS.iter().all(|name| {
        marketplace_security_check_status(report, name).is_some_and(|status| {
            matches!(status, "passed" | "failed" | "error" | "blocked" | "skipped")
        })
    })
}

fn marketplace_security_checks_pass(report: &Value) -> bool {
    MARKETPLACE_SECURITY_CHECKS.iter().all(|name| {
        marketplace_security_check_status(report, name) == Some("passed")
    })
}

fn bounded_report_string(value: Option<&Value>, max_len: usize) -> String {
    value
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty() && value.len() <= max_len && !value.chars().any(char::is_control))
        .unwrap_or("unknown")
        .to_string()
}

fn sanitized_marketplace_security_checks(report: &Value) -> Value {
    let mut checks = serde_json::Map::new();
    for name in MARKETPLACE_SECURITY_CHECKS {
        let check = report
            .get("checks")
            .and_then(Value::as_object)
            .and_then(|values| values.get(name))
            .and_then(Value::as_object);
        checks.insert(
            name.to_string(),
            json!({
                "status": check
                    .and_then(|value| value.get("status"))
                    .and_then(Value::as_str)
                    .unwrap_or("error"),
                "tool": bounded_report_string(check.and_then(|value| value.get("tool")), 120),
                "version": bounded_report_string(check.and_then(|value| value.get("version")), 80),
            }),
        );
    }
    Value::Object(checks)
}

fn marketplace_security_service_is_valid(report: &Value, env: &Env) -> bool {
    let Some(service) = report.get("service").and_then(Value::as_object) else {
        return false;
    };
    let Some(expected_server_id) = env
        .secret(MARKETPLACE_SECURITY_SERVER_ID)
        .ok()
        .map(|value| value.to_string().trim().to_string())
        .filter(|value| {
            !value.is_empty()
                && value.len() <= 128
                && value.bytes().all(|byte| {
                    byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-')
                })
        })
    else {
        return false;
    };
    let Some(expected_source_sha) = env
        .secret(MARKETPLACE_SECURITY_SOURCE_SHA)
        .ok()
        .map(|value| value.to_string().trim().to_ascii_lowercase())
        .filter(|value| is_git_object_id(value))
    else {
        return false;
    };
    service.get("serviceName").and_then(Value::as_str) == Some(MARKETPLACE_SECURITY_SERVICE_NAME)
        && service.get("serverId").and_then(Value::as_str) == Some(expected_server_id.as_str())
        && service
            .get("serverId")
            .and_then(Value::as_str)
            .is_some_and(|value| {
                !value.is_empty()
                    && value.len() <= 128
                    && value.bytes().all(|byte| {
                        byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-')
                })
            })
        && service.get("sourceSha").and_then(Value::as_str) == Some(expected_source_sha.as_str())
        && service
            .get("sourceSha")
            .and_then(Value::as_str)
            .is_some_and(is_git_object_id)
        && service
            .get("version")
            .and_then(Value::as_str)
            .is_some_and(|value| !value.is_empty() && value.len() <= 80 && !value.chars().any(char::is_control))
}

fn marketplace_security_signature_is_valid(
    report: &Value,
    package_sha256: &str,
    package_size: i64,
    env: &Env,
) -> bool {
    let Some(signature) = report.get("signature").and_then(Value::as_object) else {
        return false;
    };
    let Some(expected_public_key_sha256) = env
        .secret(MARKETPLACE_SECURITY_SIGNER_PUBLIC_KEY_SHA256)
        .ok()
        .map(|value| value.to_string().trim().to_ascii_lowercase())
        .filter(|value| value.len() == 64 && value.bytes().all(|byte| byte.is_ascii_hexdigit()))
    else {
        return false;
    };
    signature.get("type").and_then(Value::as_str) == Some("cosign-bundle")
        && signature.get("signerKeyId").and_then(Value::as_str)
            == Some(MARKETPLACE_SECURITY_SIGNER_KEY_ID)
        && signature.get("verified").and_then(Value::as_bool) == Some(true)
        && signature
            .get("packageSha256")
            .and_then(Value::as_str)
            .is_some_and(|value| value.eq_ignore_ascii_case(package_sha256))
        && signature.get("packageSize").and_then(Value::as_u64) == u64::try_from(package_size).ok()
        && signature
            .get("publicKeySha256")
            .and_then(Value::as_str)
            .is_some_and(|value| value.eq_ignore_ascii_case(&expected_public_key_sha256))
        && signature.get("bundle").is_some_and(Value::is_object)
}

fn sanitized_marketplace_security_report(
    report: &Value,
    plugin_id: &str,
    version: &str,
    package_sha256: &str,
    package_size: i64,
) -> Value {
    let service = report
        .get("service")
        .and_then(Value::as_object)
        .cloned()
        .unwrap_or_default();
    let signature = report
        .get("signature")
        .and_then(Value::as_object)
        .cloned()
        .unwrap_or_default();
    let mut sanitized_signature = json!({});
    if let Some(object) = sanitized_signature.as_object_mut() {
        if signature.get("type").and_then(Value::as_str) == Some("cosign-bundle") {
            object.insert("type".into(), Value::String("cosign-bundle".into()));
            object.insert(
                "signerKeyId".into(),
                Value::String(MARKETPLACE_SECURITY_SIGNER_KEY_ID.into()),
            );
            object.insert("packageSha256".into(), Value::String(package_sha256.into()));
            object.insert("packageSize".into(), json!(package_size));
            object.insert("verified".into(), json!(true));
            if let Some(public_key_sha256) = signature
                .get("publicKeySha256")
                .and_then(Value::as_str)
            {
                object.insert(
                    "publicKeySha256".into(),
                    Value::String(public_key_sha256.to_ascii_lowercase()),
                );
            }
            if let Some(bundle) = signature.get("bundle").filter(Value::is_object) {
                object.insert("bundle".into(), bundle.clone());
            }
        }
    }
    json!({
        "schemaVersion": 1,
        "pluginId": plugin_id,
        "version": version,
        "packageSha256": package_sha256,
        "packageSize": package_size,
        "status": report.get("verdict").and_then(Value::as_str).unwrap_or("failed"),
        "checks": sanitized_marketplace_security_checks(report),
        "service": {
            "serviceName": MARKETPLACE_SECURITY_SERVICE_NAME,
            "serverId": bounded_report_string(service.get("serverId"), 128),
            "sourceSha": bounded_report_string(service.get("sourceSha"), 40),
            "version": bounded_report_string(service.get("version"), 80),
        },
        "signature": sanitized_signature,
    })
}

fn marketplace_security_queue_item(row: MarketplaceSecurityQueueRow) -> Option<Value> {
    let package_size = exact_nonnegative_i64(row.package_size)?;
    (package_size > 0).then(|| {
        json!({
            "pluginId": row.plugin_id,
            "version": row.version,
            "artifactUrl": row.package_key,
            "packageSha256": row.package_sha256,
            "packageSize": package_size,
            "releaseStatus": row.release_status,
            "securityScanStatus": row.security_scan_status,
            "securityScannedAt": row.security_scanned_at.and_then(exact_nonnegative_i64),
            "securityNextScanAt": row.security_next_scan_at.and_then(exact_nonnegative_i64),
            "source": serde_json::from_str::<Value>(&row.source_json).unwrap_or(Value::Null),
            "releaseManifest": serde_json::from_str::<Value>(&row.release_manifest_json).unwrap_or(Value::Null),
        })
    })
}

fn chatgpt_userscript_projection() -> Value {
    let permissions = json!(["读取 ChatGPT 页面状态", "显示任务队列", "仅在匹配页面运行"]);
    let artifact = json!({
        "id": "chatgpt-auto-confirm-userscript",
        "runtime": "userscript",
        "platforms": [CHROME_EXTENSION_PLATFORM],
        "source": {
            "type": "https",
            "url": CHATGPT_USERSCRIPT_ARTIFACT_URL,
        },
        "sha256": CHATGPT_USERSCRIPT_SHA256,
        "size": CHATGPT_USERSCRIPT_SIZE,
        "format": "user-js",
        "entry": "chatgpt-auto-confirm.user.js",
    });
    let surfaces = json!([{
        "id": "userscript",
        "kind": "userscript",
        "title": "ChatGPT 网页油猴脚本",
        "entry": "chatgpt-auto-confirm.user.js",
        "platforms": [CHROME_EXTENSION_PLATFORM],
    }]);
    let source = json!({
        "provider": "github",
        "repository": CHATGPT_USERSCRIPT_REPOSITORY,
        "sourceRef": CHATGPT_USERSCRIPT_COMMIT,
        "releaseUrl": CHATGPT_USERSCRIPT_RELEASE_URL,
        "marketplaceHostsPackage": false,
    });
    let install = json!({
        "protocol": MARKETPLACE_INSTALL_PROTOCOL,
        "strategy": "github-immutable",
        "pluginId": CHATGPT_USERSCRIPT_PLUGIN_ID,
        "version": CHATGPT_USERSCRIPT_VERSION,
        "source": source.clone(),
        "artifacts": [artifact.clone()],
        "update": {
            "check": "marketplace-release",
            "comparison": "version-then-artifact-sha256",
            "allowDowngrade": false,
            "rollback": "previous-active",
        },
        "permissions": permissions.clone(),
    });
    let release_manifest = json!({
        "schemaVersion": 1,
        "protocol": "mahayana.external-release.v1",
        "pluginId": CHATGPT_USERSCRIPT_PLUGIN_ID,
        "version": CHATGPT_USERSCRIPT_VERSION,
        "runtimeForm": "userscript",
        "runtime": "userscript",
        "entry": "chatgpt-auto-confirm.user.js",
        "surfaces": surfaces.clone(),
        "permissions": permissions.clone(),
        "artifacts": [artifact.clone()],
        "source": source.clone(),
        "install": install.clone(),
    });
    let release_manifest_sha256 = canonical_json_sha256(&release_manifest).unwrap_or_default();
    json!({
        "pluginId": CHATGPT_USERSCRIPT_PLUGIN_ID,
        "displayName": "ChatGPT 自动确认",
        "description": "独立运行于 ChatGPT 网页的自动确认、对话和可恢复任务队列控制台，不依赖 Fabushi 桌面端。",
        "latestVersion": CHATGPT_USERSCRIPT_VERSION,
        "runtimeForm": "userscript",
        "installMode": "package",
        "platforms": [CHROME_EXTENSION_PLATFORM],
        "packageSha256": CHATGPT_USERSCRIPT_SHA256,
        "packageSize": CHATGPT_USERSCRIPT_SIZE,
        "deploymentUrl": CHATGPT_USERSCRIPT_ARTIFACT_URL,
        "publishedAt": CHATGPT_USERSCRIPT_PUBLISHED_AT,
        "source": source.clone(),
        "surfaces": surfaces.clone(),
        "commands": [],
        "permissions": permissions.clone(),
        "releaseManifest": release_manifest,
        "install": install,
        "releaseManifestSha256": release_manifest_sha256,
        "releaseStatus": "approved",
        "security": {
            "scanStatus": "passed",
            "mode": "legacy-official-baseline",
        },
    })
}

fn normalized_github_repository(value: &str) -> Option<String> {
    let value = value.trim();
    let repository = if value.starts_with("https://") {
        let url = Url::parse(value).ok()?;
        if url.scheme() != "https"
            || url.host_str()?.eq_ignore_ascii_case("github.com") == false
            || !url.username().is_empty()
            || url.password().is_some()
            || url.port().is_some()
            || url.query().is_some()
            || url.fragment().is_some()
        {
            return None;
        }
        url.path().trim_matches('/').to_string()
    } else {
        value.to_string()
    };
    let parts = repository.split('/').collect::<Vec<_>>();
    if parts.len() != 2
        || parts.iter().any(|part| part.is_empty())
        || repository.bytes().any(|byte| {
            !(byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-' | b'/'))
        })
    {
        return None;
    }
    Some(format!("https://github.com/{repository}"))
}

fn is_github_artifact_url(value: &str) -> bool {
    let Ok(url) = Url::parse(value.trim()) else {
        return false;
    };
    url.scheme() == "https"
        && url.host_str().is_some_and(|host| {
            host.eq_ignore_ascii_case("github.com")
                || host.eq_ignore_ascii_case("raw.githubusercontent.com")
        })
        && url.username().is_empty()
        && url.password().is_none()
        && url.port().is_none()
        && url.query().is_none()
        && url.fragment().is_none()
}

fn is_github_artifact_source(source: &Value) -> bool {
    match source.get("type").and_then(Value::as_str) {
        Some("https") => source
            .get("url")
            .and_then(Value::as_str)
            .is_some_and(is_github_artifact_url),
        Some("github-release") => {
            normalized_github_repository(
                source
                    .get("repository")
                    .and_then(Value::as_str)
                    .unwrap_or_default(),
            )
            .is_some()
                && source
                    .get("tag")
                    .and_then(Value::as_str)
                    .is_some_and(is_safe_github_release_component)
                && source
                    .get("asset")
                    .and_then(Value::as_str)
                    .is_some_and(is_safe_github_release_component)
        }
        _ => false,
    }
}

fn is_safe_github_release_component(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 255
        && value != "."
        && value != ".."
        && value.bytes().all(|byte| {
            byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-' | b'+')
        })
}

fn github_artifact_download_url(source: &Value) -> Option<String> {
    match source.get("type").and_then(Value::as_str) {
        Some("https") => source
            .get("url")
            .and_then(Value::as_str)
            .filter(|value| is_github_artifact_url(value))
            .map(str::to_string),
        Some("github-release") if is_github_artifact_source(source) => {
            let repository = source.get("repository").and_then(Value::as_str)?;
            let repository = normalized_github_repository(repository)?;
            let repository = repository.strip_prefix("https://github.com/")?;
            let tag = source.get("tag").and_then(Value::as_str)?;
            let asset = source.get("asset").and_then(Value::as_str)?;
            Some(format!(
                "https://github.com/{repository}/releases/download/{tag}/{asset}"
            ))
        }
        _ => None,
    }
}

fn release_supports_chrome_extension(release_manifest: &Value) -> bool {
    release_manifest
        .get("artifacts")
        .and_then(Value::as_array)
        .is_some_and(|artifacts| {
            artifacts.iter().any(|artifact| {
                artifact
                    .get("platforms")
                    .and_then(Value::as_array)
                    .is_some_and(|platforms| {
                        platforms.iter().any(|platform| {
                            matches!(
                                platform.as_str(),
                                Some("web" | "all" | CHROME_EXTENSION_PLATFORM)
                            )
                        })
                    })
            })
        })
}

fn add_chrome_extension_platform(release_manifest: &mut Value) {
    let Some(artifacts) = release_manifest
        .get_mut("artifacts")
        .and_then(Value::as_array_mut)
    else {
        return;
    };
    for artifact in artifacts {
        let Some(platforms) = artifact.get_mut("platforms").and_then(Value::as_array_mut) else {
            continue;
        };
        let web_compatible = platforms.iter().any(|platform| {
            matches!(
                platform.as_str(),
                Some("web" | "all" | CHROME_EXTENSION_PLATFORM)
            )
        });
        if web_compatible
            && !platforms
                .iter()
                .any(|platform| platform.as_str() == Some(CHROME_EXTENSION_PLATFORM))
        {
            platforms.push(Value::String(CHROME_EXTENSION_PLATFORM.to_string()));
        }
    }
}

fn github_install_contract(
    plugin_id: &str,
    version: &str,
    source: &Value,
    release_manifest: &Value,
) -> Option<Value> {
    let manifest_source = release_manifest.get("source");
    let repository = source
        .get("repository")
        .and_then(Value::as_str)
        .or_else(|| {
            manifest_source
                .and_then(|value| value.get("repository"))
                .and_then(Value::as_str)
        })
        .and_then(normalized_github_repository)?;
    let source_ref = source
        .get("sourceRef")
        .and_then(Value::as_str)
        .or_else(|| source.get("commit").and_then(Value::as_str))
        .or_else(|| {
            manifest_source
                .and_then(|value| value.get("sourceRef"))
                .and_then(Value::as_str)
        })
        .or_else(|| {
            manifest_source
                .and_then(|value| value.get("commit"))
                .and_then(Value::as_str)
        })
        .map(str::trim)
        .filter(|value| is_git_object_id(value))?
        .to_string();
    let artifacts = release_manifest.get("artifacts")?.as_array()?;
    if artifacts.is_empty()
        || artifacts.iter().any(|artifact| {
            artifact
                .get("source")
                .is_none_or(|value| !is_github_artifact_source(value))
                || artifact
                    .get("sha256")
                    .and_then(Value::as_str)
                    .is_none_or(|digest| {
                        digest.len() != 64 || !digest.bytes().all(|byte| byte.is_ascii_hexdigit())
                    })
                || artifact
                    .get("size")
                    .and_then(Value::as_u64)
                    .is_none_or(|size| size == 0)
        })
    {
        return None;
    }
    let manifest_url = source
        .get("manifestUrl")
        .and_then(Value::as_str)
        .or_else(|| {
            manifest_source
                .and_then(|value| value.get("manifestUrl"))
                .and_then(Value::as_str)
        });
    let permissions = release_manifest
        .get("permissions")
        .cloned()
        .or_else(|| release_manifest.get("requestedPermissions").cloned())
        .unwrap_or_else(|| json!([]));
    let mut install_source = json!({
        "provider": "github",
        "repository": repository,
        "sourceRef": source_ref,
        "marketplaceHostsPackage": false,
    });
    if let Some(manifest_url) = manifest_url.filter(|value| is_github_artifact_url(value)) {
        install_source["manifestUrl"] = Value::String(manifest_url.to_string());
    }
    Some(json!({
        "protocol": MARKETPLACE_INSTALL_PROTOCOL,
        "strategy": "github-immutable",
        "pluginId": plugin_id,
        "version": version,
        "source": install_source,
        "artifacts": artifacts,
        "update": {
            "check": "marketplace-release",
            "comparison": "version-then-artifact-sha256",
            "allowDowngrade": false,
            "rollback": "previous-active"
        },
        "permissions": permissions,
    }))
}

fn enrich_github_release(
    plugin_id: &str,
    version: &str,
    source: &Value,
    release_manifest: Value,
) -> (Value, Option<Value>) {
    let mut candidate = release_manifest.clone();
    add_chrome_extension_platform(&mut candidate);
    let Some(install) = github_install_contract(plugin_id, version, source, &candidate) else {
        return (release_manifest, None);
    };
    if let Some(object) = candidate.as_object_mut() {
        object.insert("install".into(), install.clone());
    }
    (candidate, Some(install))
}

pub(super) async fn marketplace_plugins(
    request: Request,
    context: RouteContext<()>,
) -> Result<Response> {
    let mut query = "%".to_string();
    let mut platform = None;
    for (key, value) in request.url()?.query_pairs() {
        if key == "q" && !value.trim().is_empty() {
            query = format!("%{}%", value.trim());
        } else if key == "platform" && !value.trim().is_empty() {
            let value = value.trim().to_string();
            let normalized_platform = match value.as_str() {
                "ios" | "android" => "mobile",
                "cli" | "desktop" | "mobile" | "web" | "chrome-extension" => value.as_str(),
                _ => {
                    return error_response(
                        400,
                        "invalid_marketplace_platform",
                        "platform must be cli, desktop, mobile, web, ios, android, or chrome-extension.",
                    );
                }
            };
            platform = Some(normalized_platform.to_string());
        }
    }
    // Older approved rows predate the Chrome surface and only advertise
    // `web`/`desktop` in platforms_json. Query those rows broadly, then apply
    // the compatibility check against the release manifest below so a rolling
    // deployment does not hide existing GitHub releases from Chrome clients.
    let platform_pattern = match platform.as_deref() {
        Some(CHROME_EXTENSION_PLATFORM) => "%".to_string(),
        Some(value) => format!("%\"{value}\"%"),
        None => "%".to_string(),
    };
    let database = context.env.d1(DATABASE_BINDING)?;
    let rows = worker::query!(
        &database,
        "SELECT mp.plugin_id, mp.display_name, mp.description, mp.latest_version,
                pr.package_sha256, pr.package_size, mp.platforms_json,
                pr.deployment_url, pr.published_at, pr.source_json,
                pr.release_manifest_json, pr.release_manifest_sha256, pr.release_status,
                pr.security_scan_status
         FROM marketplace_plugins mp
         JOIN plugin_releases pr
           ON pr.plugin_id = mp.plugin_id AND pr.version = mp.latest_version
         WHERE mp.visibility = 'public' AND mp.review_state = 'approved'
           AND pr.release_status = 'approved'
           AND pr.security_scan_status IN ('passed', 'running')
           AND pr.deployment_url <> ''
           AND (mp.display_name LIKE ?1 OR mp.description LIKE ?1 OR mp.plugin_id LIKE ?1)
           AND mp.platforms_json LIKE ?2
         ORDER BY mp.updated_at DESC LIMIT 100",
        &query,
        &platform_pattern
    )?
    .all()
    .await?
    .results::<MarketplacePluginRow>()?;
    let plugins = rows
        .into_iter()
        .filter_map(|row| {
            // The public Chrome catalog must expose the separately released
            // userscript even while the D1 row still points at the desktop
            // Mini App package.  Without this projection an older extension
            // merges its bundled 2.9.28 fallback over the 1.0.1 package and
            // incorrectly reports that it is up to date.
            if platform.as_deref() == Some(CHROME_EXTENSION_PLATFORM)
                && row.plugin_id == CHATGPT_USERSCRIPT_PLUGIN_ID
            {
                return Some(chatgpt_userscript_projection());
            }
            let platforms =
                serde_json::from_str::<Vec<String>>(&row.platforms_json).unwrap_or_default();
            let source = serde_json::from_str::<Value>(&row.source_json).unwrap_or(Value::Null);
            let stored_release_manifest =
                serde_json::from_str::<Value>(&row.release_manifest_json).unwrap_or(Value::Null);
            if platform.as_deref() == Some(CHROME_EXTENSION_PLATFORM)
                && !release_supports_chrome_extension(&stored_release_manifest)
            {
                return None;
            }
            let (release_manifest, install) = enrich_github_release(
                &row.plugin_id,
                row.latest_version.as_deref().unwrap_or_default(),
                &source,
                stored_release_manifest,
            );
            let release_manifest_sha256 = canonical_json_sha256(&release_manifest)
                .unwrap_or_else(|_| row.release_manifest_sha256.clone());
            let mut response_platforms = platforms;
            if install.is_some()
                && release_supports_chrome_extension(&release_manifest)
                && !response_platforms
                    .iter()
                    .any(|platform| platform == CHROME_EXTENSION_PLATFORM)
            {
                response_platforms.push(CHROME_EXTENSION_PLATFORM.to_string());
            }
            Some(json!({
                "pluginId": row.plugin_id,
                "displayName": row.display_name,
                "description": row.description,
                "latestVersion": row.latest_version,
                "packageSha256": row.package_sha256,
                "packageSize": row.package_size.and_then(exact_nonnegative_i64),
                "platforms": response_platforms,
                "deploymentUrl": row.deployment_url,
                "publishedAt": row.published_at.and_then(exact_nonnegative_i64),
                "source": source,
                "releaseManifest": release_manifest,
                "install": install,
                "releaseManifestSha256": release_manifest_sha256,
                "releaseStatus": row.release_status,
                "securityScanStatus": row.security_scan_status,
            }))
        })
        .collect::<Vec<_>>();
    Response::from_json(&json!({"plugins": plugins}))
}

fn marketplace_installed_projection(row: &MarketplaceInstalledPluginRow) -> Value {
    let mut projection = row
        .projection_json
        .as_deref()
        .and_then(|value| serde_json::from_str::<Value>(value).ok())
        .filter(Value::is_object)
        .unwrap_or_else(|| {
            json!({
                "id": row.plugin_id,
                "title": row.display_name,
                "description": row.description,
            })
        });
    if let Some(object) = projection.as_object_mut() {
        object.insert("id".into(), Value::String(row.plugin_id.clone()));
        object.insert("pluginId".into(), Value::String(row.plugin_id.clone()));
        object.insert("title".into(), Value::String(row.display_name.clone()));
        object.insert("description".into(), Value::String(row.description.clone()));
        if let Some(version) = row.latest_version.as_ref() {
            object.insert("version".into(), Value::String(version.clone()));
        }
    }
    projection
}

pub(super) async fn marketplace_added(
    request: Request,
    context: RouteContext<()>,
) -> Result<Response> {
    let account = match authenticated_account(&request, &context.env) {
        Ok(account) => account,
        Err(_) => {
            return error_response(
                401,
                "unauthorized",
                "A valid Mahayana account token is required to read installed marketplace apps.",
            );
        }
    };
    let database = context.env.d1(DATABASE_BINDING)?;
    let rows = worker::query!(
        &database,
        "SELECT mp.plugin_id, mp.display_name, mp.description, mp.latest_version,
                mpp.projection_json
         FROM account_marketplace_installs ami
         JOIN marketplace_plugins mp ON mp.plugin_id = ami.plugin_id
         JOIN plugin_releases pr
           ON pr.plugin_id = mp.plugin_id AND pr.version = mp.latest_version
         LEFT JOIN marketplace_plugin_projections mpp ON mpp.plugin_id = mp.plugin_id
         WHERE ami.account_user_id = ?1
           AND mp.visibility = 'public' AND mp.review_state = 'approved'
           AND pr.release_status = 'approved'
           AND pr.security_scan_status IN ('passed', 'running')
           AND pr.deployment_url <> ''
         ORDER BY ami.updated_at DESC, mp.plugin_id ASC",
        &account.user_id
    )?
    .all()
    .await?
    .results::<MarketplaceInstalledPluginRow>()?;
    let apps = rows
        .iter()
        .map(marketplace_installed_projection)
        .collect::<Vec<_>>();
    Response::from_json(&json!({
        "protocol": "fabushi.miniapp.marketplace.v2",
        "accountSynchronized": true,
        "apps": apps,
    }))
}

pub(super) async fn marketplace_plugin_add(
    mut request: Request,
    context: RouteContext<()>,
) -> Result<Response> {
    let account = match authenticated_account(&request, &context.env) {
        Ok(account) => account,
        Err(_) => {
            return error_response(
                401,
                "unauthorized",
                "A valid Mahayana account token is required to install marketplace apps.",
            );
        }
    };
    let plugin_id = route_identifier(&context, "plugin_id")?.to_string();
    let body = request.json::<Value>().await.unwrap_or(Value::Null);
    let platform = body
        .get("platform")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or("unknown");
    if platform.len() > 64
        || !platform
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-'))
    {
        return error_response(
            400,
            "invalid_marketplace_platform",
            "platform must be a normalized identifier.",
        );
    }
    let database = context.env.d1(DATABASE_BINDING)?;
    let row = worker::query!(
        &database,
        "SELECT mp.plugin_id, mp.display_name, mp.description, mp.latest_version,
                mpp.projection_json
         FROM marketplace_plugins mp
         JOIN plugin_releases pr
           ON pr.plugin_id = mp.plugin_id AND pr.version = mp.latest_version
         LEFT JOIN marketplace_plugin_projections mpp ON mpp.plugin_id = mp.plugin_id
         WHERE mp.plugin_id = ?1
           AND mp.visibility = 'public' AND mp.review_state = 'approved'
           AND pr.release_status = 'approved'
           AND pr.security_scan_status IN ('passed', 'running')
           AND pr.deployment_url <> ''",
        &plugin_id
    )?
    .first::<MarketplaceInstalledPluginRow>(None)
    .await?;
    let Some(row) = row else {
        return error_response(
            404,
            "marketplace_plugin_not_found",
            "The approved marketplace plugin does not exist.",
        );
    };
    let now = now_seconds();
    worker::query!(
        &database,
        "INSERT INTO account_marketplace_installs
         (account_user_id, plugin_id, platform, installed_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?4)
         ON CONFLICT(account_user_id, plugin_id) DO UPDATE SET
           platform = excluded.platform,
           updated_at = excluded.updated_at",
        &account.user_id,
        &plugin_id,
        platform,
        now
    )?
    .run()
    .await?;
    let app = marketplace_installed_projection(&row);
    Response::from_json(&json!({
        "added": true,
        "accountSynchronized": true,
        "pluginId": plugin_id,
        "bot": app.get("bot").cloned().unwrap_or(Value::Null),
        "app": app,
    }))
}

pub(super) async fn marketplace_plugin_route(
    mut request: Request,
    context: RouteContext<()>,
) -> Result<Response> {
    use crate::marketplace_route::{MarketplaceRouteError, route_marketplace_input};

    let account = match authenticated_account(&request, &context.env) {
        Ok(account) => account,
        Err(_) => {
            return error_response(
                401,
                "unauthorized",
                "A valid Mahayana account token is required to route marketplace app input.",
            );
        }
    };
    let plugin_id = route_identifier(&context, "plugin_id")?.to_string();
    let body = request.json::<Value>().await.unwrap_or(Value::Null);
    let input = body
        .get("input")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let database = context.env.d1(DATABASE_BINDING)?;
    let row = worker::query!(
        &database,
        "SELECT mp.plugin_id, mp.display_name, mp.description, mp.latest_version,
                mpp.projection_json
         FROM account_marketplace_installs ami
         JOIN marketplace_plugins mp ON mp.plugin_id = ami.plugin_id
         JOIN plugin_releases pr
           ON pr.plugin_id = mp.plugin_id AND pr.version = mp.latest_version
         LEFT JOIN marketplace_plugin_projections mpp ON mpp.plugin_id = mp.plugin_id
         WHERE ami.account_user_id = ?1 AND mp.plugin_id = ?2
           AND mp.visibility = 'public' AND mp.review_state = 'approved'
           AND pr.release_status = 'approved'
           AND pr.security_scan_status IN ('passed', 'running')
           AND pr.deployment_url <> ''",
        &account.user_id,
        &plugin_id
    )?
    .first::<MarketplaceInstalledPluginRow>(None)
    .await?;
    let Some(row) = row else {
        return error_response(
            404,
            "marketplace_plugin_not_installed",
            "The marketplace app is not installed for this account.",
        );
    };
    let projection = marketplace_installed_projection(&row);
    match route_marketplace_input(&plugin_id, &projection, input) {
        Ok(payload) => Response::from_json(&payload),
        Err(MarketplaceRouteError::InvalidInput) => error_response(
            400,
            "invalid_marketplace_input",
            "input must be non-empty and at most 10000 bytes.",
        ),
        Err(MarketplaceRouteError::CommandMismatch) => error_response(
            400,
            "marketplace_command_mismatch",
            "The slash command targets another marketplace app.",
        ),
        Err(MarketplaceRouteError::CommandNotFound) => error_response(
            400,
            "marketplace_command_not_found",
            "The requested marketplace command is not declared.",
        ),
        Err(MarketplaceRouteError::InvalidArguments) => error_response(
            400,
            "invalid_marketplace_command_arguments",
            "Slash command arguments must be a JSON object.",
        ),
        Err(MarketplaceRouteError::InvalidProjection) => error_response(
            409,
            "invalid_marketplace_route_projection",
            "The installed marketplace projection does not declare a valid command surface.",
        ),
    }
}

pub(super) async fn marketplace_release_publish(
    mut request: Request,
    context: RouteContext<()>,
) -> Result<Response> {
    const MAX_PACKAGE_BYTES: usize = 50 * 1024 * 1024;

    let account = match authenticated_account(&request, &context.env) {
        Ok(account) => account,
        Err(_) => {
            return error_response(
                401,
                "unauthorized",
                "A valid Mahayana account token is required to publish marketplace releases.",
            );
        }
    };
    if !account.is_test_account
        && !account
            .scopes
            .iter()
            .any(|scope| scope == "marketplace.publish")
    {
        return error_response(
            403,
            "marketplace_publish_forbidden",
            "The account token does not permit marketplace publishing.",
        );
    }

    let form = request.form_data().await?;
    let field = |name: &str| -> Result<String> {
        match form.get(name) {
            Some(FormEntry::Field(value)) if !value.trim().is_empty() => Ok(value),
            _ => Err(worker::Error::RustError(format!(
                "marketplace release field {name} is required"
            ))),
        }
    };
    let plugin_id = field("pluginId")?;
    let version = field("version")?;
    if !is_identifier(&plugin_id) || !is_version_identifier(&version) {
        return error_response(
            400,
            "invalid_marketplace_release_identifier",
            "pluginId and version must be normalized identifiers.",
        );
    }
    let database = context.env.d1(DATABASE_BINDING)?;
    let existing_plugin = worker::query!(
        &database,
        "SELECT publisher_user_id FROM marketplace_plugins WHERE plugin_id = ?1",
        &plugin_id
    )?
    .first::<MarketplacePluginOwnerRow>(None)
    .await?;
    if let Some(existing_plugin) = existing_plugin {
        if existing_plugin.publisher_user_id != account.user_id {
            return error_response(
                403,
                "marketplace_plugin_owner_mismatch",
                "The authenticated publisher does not own this plugin ID.",
            );
        }
    }
    let existing_release = worker::query!(
        &database,
        "SELECT package_sha256 FROM plugin_releases WHERE plugin_id = ?1 AND version = ?2",
        &plugin_id,
        &version
    )?
    .first::<MarketplaceExistingReleaseRow>(None)
    .await?;
    if let Some(existing_release) = existing_release {
        return error_response(
            409,
            "version_already_exists",
            &format!(
                "Release {plugin_id}@{version} is immutable and already exists with package SHA-256 {}.",
                existing_release.package_sha256
            ),
        );
    }
    let deployment_url = field("deploymentUrl")?;
    if !is_public_https_url(&deployment_url) {
        return error_response(
            400,
            "invalid_marketplace_deployment_url",
            "deploymentUrl must be a public HTTPS URL.",
        );
    }
    let expected_sha256 = field("packageSha256")?.to_ascii_lowercase();
    if expected_sha256.len() != 64 || !expected_sha256.bytes().all(|byte| byte.is_ascii_hexdigit())
    {
        return error_response(
            400,
            "invalid_marketplace_package_sha256",
            "packageSha256 must be a 64-character hexadecimal digest.",
        );
    }
    let expected_size = field("packageSize")?
        .parse::<usize>()
        .map_err(|_| worker::Error::RustError("invalid packageSize".into()))?;
    if expected_size == 0 || expected_size > MAX_PACKAGE_BYTES {
        return error_response(
            400,
            "invalid_marketplace_package_size",
            "packageSize must be between 1 byte and 50 MiB.",
        );
    }
    let platforms = serde_json::from_str::<Vec<String>>(&field("platforms")?)
        .map_err(|_| worker::Error::RustError("invalid marketplace platforms".into()))?;
    if platforms.is_empty()
        || platforms.iter().any(|platform| {
            !matches!(
                platform.as_str(),
                "cli" | "desktop" | "mobile" | "web" | "chrome-extension"
            )
        })
    {
        return error_response(
            400,
            "invalid_marketplace_platforms",
            "platforms must contain supported Mahayana targets.",
        );
    }
    let source = serde_json::from_str::<Value>(&field("source")?)
        .map_err(|_| worker::Error::RustError("invalid marketplace source".into()))?;
    if let Err(message) = validate_github_source_identity(&source) {
        return error_response(400, "invalid_marketplace_source", &message);
    }
    let submitted_release_manifest = serde_json::from_str::<Value>(&field("releaseManifest")?)
        .map_err(|_| worker::Error::RustError("invalid marketplace release manifest".into()))?;
    if let Err(message) = validate_multi_artifact_release_manifest(
        &submitted_release_manifest,
        &plugin_id,
        &version,
        &expected_sha256,
        expected_size,
        &platforms,
        &source,
    ) {
        return error_response(400, "invalid_marketplace_release_manifest", &message);
    }
    let submitted_release_manifest_sha256 = canonical_json_sha256(&submitted_release_manifest)
        .map_err(|error| worker::Error::RustError(error.to_string()))?;
    let (release_manifest, install) = enrich_github_release(
        &plugin_id,
        &version,
        &source,
        submitted_release_manifest.clone(),
    );
    let Some(install) = install else {
        return error_response(
            400,
            "invalid_marketplace_release_manifest",
            "Every marketplace package artifact must point to a GitHub-hosted immutable asset.",
        );
    };
    let source_json = serde_json::to_string(&source)
        .map_err(|error| worker::Error::RustError(error.to_string()))?;
    let release_manifest_bytes = canonical_json_bytes(&release_manifest)
        .map_err(|error| worker::Error::RustError(error.to_string()))?;
    let release_manifest_json = String::from_utf8(release_manifest_bytes)
        .map_err(|error| worker::Error::RustError(error.to_string()))?;
    let release_manifest_sha256 = canonical_json_sha256(&release_manifest)
        .map_err(|error| worker::Error::RustError(error.to_string()))?;
    let package = match form.get("package") {
        Some(FormEntry::File(file)) => file.bytes().await?,
        _ => {
            return error_response(
                400,
                "marketplace_package_missing",
                "The release package file is required.",
            );
        }
    };
    if package.len() != expected_size {
        return error_response(
            400,
            "marketplace_package_size_mismatch",
            "The uploaded package size does not match release metadata.",
        );
    }
    let actual_sha256 = format!("{:x}", Sha256::digest(&package));
    if actual_sha256 != expected_sha256 {
        return error_response(
            400,
            "marketplace_package_sha256_mismatch",
            "The uploaded package digest does not match release metadata.",
        );
    }

    let remote_package = match verified_marketplace_site_package_with_retry(
        &deployment_url,
        &plugin_id,
        &version,
        &actual_sha256,
        expected_size,
        &source,
        &submitted_release_manifest,
        &submitted_release_manifest_sha256,
    )
    .await
    {
        Ok(package) => package,
        Err(message) => {
            return error_response(400, "marketplace_deployment_verification_failed", &message);
        }
    };
    if remote_package != package {
        return error_response(
            400,
            "marketplace_deployment_package_mismatch",
            "The package served by the Cloudflare plugin site differs from the uploaded release package.",
        );
    }
    let package_key = release_manifest
        .get("artifacts")
        .and_then(Value::as_array)
        .and_then(|artifacts| artifacts.first())
        .and_then(|artifact| artifact.get("source"))
        .and_then(github_artifact_download_url)
        .ok_or_else(|| {
            worker::Error::RustError(
                "marketplace release is missing a GitHub-hosted primary artifact".into(),
            )
        })?;

    let now = now_seconds();
    let package_size = i64::try_from(expected_size)
        .map_err(|_| worker::Error::RustError("packageSize exceeds D1 integer range".into()))?;
    let platforms_json = serde_json::to_string(&platforms)
        .map_err(|error| worker::Error::RustError(error.to_string()))?;
    database
        .batch(vec![
            worker::query!(
                &database,
                "INSERT INTO marketplace_plugins
                 (plugin_id, display_name, description, publisher_user_id, latest_version,
                  visibility, review_state, created_at, updated_at, platforms_json)
                 VALUES (?1, ?1, ?2, ?3, NULL, 'unlisted', 'pending', ?4, ?4, ?5)
                 ON CONFLICT(plugin_id) DO UPDATE SET
                   display_name = excluded.display_name,
                   description = excluded.description,
                   updated_at = excluded.updated_at,
                   platforms_json = excluded.platforms_json",
                &plugin_id,
                &format!("Published from {deployment_url}"),
                &account.user_id,
                now,
                &platforms_json
            )?,
            worker::query!(
                &database,
                "INSERT INTO plugin_releases
                 (plugin_id, version, package_key, package_sha256, package_size,
                  tuf_target_path, published_at, deployment_url, source_json,
                  release_manifest_json, release_manifest_sha256, release_status,
                  security_scan_status, security_scan_json, security_scan_started_at,
                  security_scan_run_id, security_signature_json)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, 'pending',
                         'pending', '{}', NULL, '', '{}')",
                &plugin_id,
                &version,
                &package_key,
                &actual_sha256,
                package_size,
                &format!("plugins/{plugin_id}/{version}.tar.gz"),
                now,
                &deployment_url,
                &source_json,
                &release_manifest_json,
                &release_manifest_sha256
            )?,
        ])
        .await?;

    Response::from_json(&json!({
        "submitted": true,
        "published": false,
        "approved": false,
        "pluginId": plugin_id,
        "version": version,
        "deploymentUrl": deployment_url,
        "packageSha256": actual_sha256,
        "packageSize": package_size,
        "platforms": platforms,
        "source": source,
        "releaseManifest": release_manifest,
        "install": install,
        "releaseManifestSha256": release_manifest_sha256,
        "releaseStatus": "pending",
        "securityScanStatus": "pending",
    }))
}

pub(super) async fn marketplace_external_release_publish(
    mut request: Request,
    context: RouteContext<()>,
) -> Result<Response> {
    const MAX_ARTIFACT_BYTES: usize = 100 * 1024 * 1024;

    let account = match authenticated_account(&request, &context.env) {
        Ok(account) => account,
        Err(_) => {
            return error_response(
                401,
                "unauthorized",
                "A valid Mahayana account token is required to publish marketplace releases.",
            );
        }
    };
    if !account.is_test_account
        && !account
            .scopes
            .iter()
            .any(|scope| scope == "marketplace.publish")
    {
        return error_response(
            403,
            "marketplace_publish_forbidden",
            "The account token does not permit marketplace publishing.",
        );
    }

    let body: Value = match request.json().await {
        Ok(body) => body,
        Err(_) => {
            return error_response(
                400,
                "invalid_marketplace_release",
                "The external release request must be valid JSON.",
            );
        }
    };
    let plugin_id = match body.get("pluginId").and_then(Value::as_str) {
        Some(value) if is_identifier(value) => value.to_string(),
        _ => {
            return error_response(
                400,
                "invalid_marketplace_release_identifier",
                "pluginId must be a normalized identifier.",
            );
        }
    };
    let version = match body.get("version").and_then(Value::as_str) {
        Some(value) if is_version_identifier(value) => value.to_string(),
        _ => {
            return error_response(
                400,
                "invalid_marketplace_release_identifier",
                "version must be a normalized version identifier.",
            );
        }
    };
    let display_name = body
        .get("displayName")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty() && value.len() <= 120)
        .unwrap_or(&plugin_id)
        .to_string();
    let description = body
        .get("description")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| value.len() <= 2_000)
        .unwrap_or("")
        .to_string();
    let platforms = match body.get("platforms").and_then(Value::as_array) {
        Some(values) => values
            .iter()
            .filter_map(Value::as_str)
            .map(str::to_string)
            .collect::<Vec<_>>(),
        None => Vec::new(),
    };
    if platforms.is_empty()
        || platforms.iter().any(|platform| {
            !matches!(
                platform.as_str(),
                "cli" | "desktop" | "mobile" | "web" | "ios" | "android" | "chrome-extension"
            )
        })
    {
        return error_response(
            400,
            "invalid_marketplace_platforms",
            "platforms must contain supported Mahayana targets.",
        );
    }

    let release_manifest = match body.get("releaseManifest") {
        Some(value) => value.clone(),
        None => {
            return error_response(
                400,
                "invalid_marketplace_release_manifest",
                "releaseManifest is required.",
            );
        }
    };
    if let Err(message) = validate_external_release_manifest(
        &release_manifest,
        &plugin_id,
        &version,
        &platforms,
        MAX_ARTIFACT_BYTES,
    ) {
        return error_response(400, "invalid_marketplace_release_manifest", &message);
    }

    let database = context.env.d1(DATABASE_BINDING)?;
    if let Some(existing) = worker::query!(
        &database,
        "SELECT publisher_user_id FROM marketplace_plugins WHERE plugin_id = ?1",
        &plugin_id
    )?
    .first::<MarketplacePluginOwnerRow>(None)
    .await?
    {
        if existing.publisher_user_id != account.user_id {
            return error_response(
                403,
                "marketplace_plugin_owner_mismatch",
                "The authenticated publisher does not own this plugin ID.",
            );
        }
    }
    if let Some(existing) = worker::query!(
        &database,
        "SELECT package_sha256 FROM plugin_releases WHERE plugin_id = ?1 AND version = ?2",
        &plugin_id,
        &version
    )?
    .first::<MarketplaceExistingReleaseRow>(None)
    .await?
    {
        return error_response(
            409,
            "version_already_exists",
            &format!(
                "Release {plugin_id}@{version} is immutable and already exists with package SHA-256 {}.",
                existing.package_sha256
            ),
        );
    }

    // Admission verifies every external runtime artifact at its publisher URL.
    // The bytes are never persisted by the marketplace.
    let artifacts = release_manifest
        .get("artifacts")
        .and_then(Value::as_array)
        .expect("validated release manifest artifacts");
    let mut resolved_artifacts = Vec::with_capacity(artifacts.len());
    for artifact in artifacts {
        let resolved_url = match resolve_external_artifact_url(artifact).await {
            Ok(url) => url,
            Err(message) => {
                return error_response(400, "marketplace_artifact_resolution_failed", &message);
            }
        };
        let expected_size = artifact
            .get("size")
            .and_then(Value::as_u64)
            .and_then(|value| usize::try_from(value).ok())
            .expect("validated artifact size");
        let expected_sha256 = artifact
            .get("sha256")
            .and_then(Value::as_str)
            .expect("validated artifact sha256");
        if let Err(message) = verify_external_artifact(
            &resolved_url,
            expected_sha256,
            expected_size,
            MAX_ARTIFACT_BYTES,
        )
        .await
        {
            return error_response(400, "marketplace_artifact_verification_failed", &message);
        }
        resolved_artifacts.push(resolved_url);
    }

    let primary = artifacts.first().expect("validated non-empty artifacts");
    let package_sha256 = primary
        .get("sha256")
        .and_then(Value::as_str)
        .expect("validated primary sha")
        .to_ascii_lowercase();
    let package_size = primary
        .get("size")
        .and_then(Value::as_u64)
        .and_then(|value| i64::try_from(value).ok())
        .expect("validated primary size");
    let primary_url = resolved_artifacts
        .first()
        .expect("validated primary URL")
        .clone();
    let source = body
        .get("source")
        .cloned()
        .unwrap_or_else(|| json!({"provider":"external","artifact": primary.get("source").cloned().unwrap_or(Value::Null)}));
    let (release_manifest, install) =
        enrich_github_release(&plugin_id, &version, &source, release_manifest);
    let Some(install) = install else {
        return error_response(
            400,
            "invalid_marketplace_source",
            "Marketplace package releases must use a public GitHub repository, an immutable commit, and GitHub-hosted artifacts.",
        );
    };
    let release_manifest_json = serde_json::to_string(&release_manifest)
        .map_err(|error| worker::Error::RustError(error.to_string()))?;
    let release_manifest_sha256 = format!("{:x}", Sha256::digest(release_manifest_json.as_bytes()));
    let source_json = serde_json::to_string(&source)
        .map_err(|error| worker::Error::RustError(error.to_string()))?;
    let platforms_json = serde_json::to_string(&platforms)
        .map_err(|error| worker::Error::RustError(error.to_string()))?;
    let now = now_seconds();
    database
        .batch(vec![
            worker::query!(
                &database,
                "INSERT INTO marketplace_plugins
                 (plugin_id, display_name, description, publisher_user_id, latest_version,
                  visibility, review_state, created_at, updated_at, platforms_json)
                 VALUES (?1, ?2, ?3, ?4, NULL, 'unlisted', 'pending', ?5, ?5, ?6)
                 ON CONFLICT(plugin_id) DO UPDATE SET
                   display_name = excluded.display_name,
                   description = excluded.description,
                   updated_at = excluded.updated_at,
                   platforms_json = excluded.platforms_json",
                &plugin_id,
                &display_name,
                &description,
                &account.user_id,
                now,
                &platforms_json
            )?,
            worker::query!(
                &database,
                "INSERT INTO plugin_releases
                 (plugin_id, version, package_key, package_sha256, package_size,
                  tuf_target_path, published_at, deployment_url, source_json,
                  release_manifest_json, release_manifest_sha256, release_status,
                  security_scan_status, security_scan_json, security_scan_started_at,
                  security_scan_run_id, security_signature_json)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, 'pending',
                         'pending', '{}', NULL, '', '{}')",
                &plugin_id,
                &version,
                &primary_url,
                &package_sha256,
                package_size,
                &format!("external/{plugin_id}/{version}"),
                now,
                &primary_url,
                &source_json,
                &release_manifest_json,
                &release_manifest_sha256
            )?,
        ])
        .await?;

    Response::from_json(&json!({
        "submitted": true,
        "published": false,
        "approved": false,
        "storage": "external",
        "pluginId": plugin_id,
        "version": version,
        "platforms": platforms,
        "source": source,
        "releaseManifest": release_manifest,
        "install": install,
        "releaseManifestSha256": release_manifest_sha256,
        "resolvedArtifacts": resolved_artifacts,
        "releaseStatus": "pending",
        "securityScanStatus": "pending",
    }))
}

pub(super) async fn marketplace_security_queue(
    request: Request,
    context: RouteContext<()>,
) -> Result<Response> {
    match marketplace_security_token_matches(&request, &context.env)? {
        None => {
            return error_response(
                503,
                "marketplace_security_not_configured",
                "Marketplace security automation is not configured.",
            );
        }
        Some(false) => {
            return error_response(
                401,
                "marketplace_security_automation_unauthorized",
                "The marketplace security automation token is invalid.",
            );
        }
        Some(true) => {}
    }

    let mut limit = MARKETPLACE_SECURITY_QUEUE_LIMIT;
    for (key, value) in request.url()?.query_pairs() {
        if key == "limit" {
            limit = match value.parse::<usize>() {
                Ok(value) if value > 0 => value.min(MARKETPLACE_SECURITY_QUEUE_LIMIT),
                _ => {
                    return error_response(
                        400,
                        "invalid_marketplace_security_queue_limit",
                        "limit must be a positive integer.",
                    );
                }
            };
        }
    }

    let now = now_seconds();
    let database = context.env.d1(DATABASE_BINDING)?;
    let rows = worker::query!(
        &database,
        "SELECT pr.plugin_id, pr.version, pr.package_key, pr.package_sha256,
                pr.package_size, pr.release_status, pr.security_scan_status,
                pr.security_scanned_at, pr.security_next_scan_at,
                pr.security_scan_run_id, pr.source_json, pr.release_manifest_json
         FROM plugin_releases pr
         JOIN marketplace_plugins mp ON mp.plugin_id = pr.plugin_id
         WHERE (
             (pr.release_status IN ('pending', 'staged')
              AND pr.security_scan_status IN ('pending', 'failed'))
             OR (pr.release_status = 'approved'
                 AND pr.security_scan_status IN ('passed', 'running')
                 AND (pr.security_next_scan_at IS NULL OR pr.security_next_scan_at <= ?1))
             OR (pr.security_scan_status = 'running'
                 AND (pr.security_scan_started_at IS NULL
                      OR pr.security_scan_started_at <= ?1 - 1800))
         )
         AND (pr.security_scan_status <> 'running'
              OR pr.security_scan_started_at IS NULL
              OR pr.security_scan_started_at <= ?1 - 1800)
         ORDER BY pr.published_at ASC
         LIMIT 100",
        now
    )?
    .all()
    .await?
    .results::<MarketplaceSecurityQueueRow>()?;
    let Some(releases) = rows
        .into_iter()
        .take(limit)
        .map(marketplace_security_queue_item)
        .collect::<Option<Vec<_>>>()
    else {
        return error_response(
            503,
            "marketplace_security_queue_invalid",
            "A queued marketplace release has invalid package metadata.",
        );
    };
    Response::from_json(&json!({
        "schemaVersion": 1,
        "generatedAt": now,
        "releases": releases,
    }))
}

pub(super) async fn marketplace_security_claim(
    mut request: Request,
    context: RouteContext<()>,
) -> Result<Response> {
    match marketplace_security_token_matches(&request, &context.env)? {
        None => {
            return error_response(
                503,
                "marketplace_security_not_configured",
                "Marketplace security automation is not configured.",
            );
        }
        Some(false) => {
            return error_response(
                401,
                "marketplace_security_automation_unauthorized",
                "The marketplace security automation token is invalid.",
            );
        }
        Some(true) => {}
    }

    let input: MarketplaceSecurityClaimRequest = match request.json().await {
        Ok(input) => input,
        Err(_) => {
            return error_response(
                400,
                "invalid_marketplace_security_claim",
                "The marketplace security claim must be valid JSON.",
            );
        }
    };
    if !is_identifier(&input.plugin_id)
        || !is_version_identifier(&input.version)
        || !valid_marketplace_security_run_id(&input.scan_run_id)
    {
        return error_response(
            400,
            "invalid_marketplace_security_claim",
            "pluginId, version, and scanRunId are invalid.",
        );
    }

    let now = now_seconds();
    let database = context.env.d1(DATABASE_BINDING)?;
    let release = worker::query!(
        &database,
        "SELECT package_sha256, package_size, published_at, release_status,
                security_scan_status, security_next_scan_at,
                security_scan_started_at, security_scan_run_id
         FROM plugin_releases
         WHERE plugin_id = ?1 AND version = ?2",
        &input.plugin_id,
        &input.version
    )?
    .first::<MarketplaceSecurityReleaseRow>(None)
    .await?;
    let Some(release) = release else {
        return error_response(
            404,
            "marketplace_security_release_not_found",
            "The marketplace release does not exist.",
        );
    };

    let started_at = release
        .security_scan_started_at
        .and_then(exact_nonnegative_i64);
    let stale_running = release.security_scan_status == "running"
        && started_at.is_none_or(|started_at| started_at <= now - MARKETPLACE_SECURITY_CLAIM_STALE_SECONDS);
    if release.security_scan_status == "running"
        && release.security_scan_run_id == input.scan_run_id
    {
        return Response::from_json(&json!({
            "claimed": true,
            "pluginId": input.plugin_id,
            "version": input.version,
            "scanRunId": input.scan_run_id,
            "securityScanStatus": "running",
            "idempotent": true,
        }));
    }
    let due_rescan = release.release_status == "approved"
        && release.security_scan_status == "passed"
        && release
            .security_next_scan_at
            .and_then(exact_nonnegative_i64)
            .is_none_or(|next_scan_at| next_scan_at <= now);
    let pending_admission = matches!(release.release_status.as_str(), "pending" | "staged")
        && matches!(release.security_scan_status.as_str(), "pending" | "failed");
    if !(pending_admission || due_rescan || stale_running) {
        return error_response(
            409,
            "marketplace_security_release_busy",
            "The marketplace release is not currently eligible for a security scan claim.",
        );
    }

    let claim_result = worker::query!(
        &database,
        "UPDATE plugin_releases
         SET security_scan_status = 'running',
             security_scan_started_at = ?1,
             security_scan_run_id = ?2
         WHERE plugin_id = ?3 AND version = ?4
           AND (
               (release_status IN ('pending', 'staged')
                AND security_scan_status IN ('pending', 'failed'))
               OR (release_status = 'approved'
                   AND security_scan_status = 'passed'
                   AND (security_next_scan_at IS NULL OR security_next_scan_at <= ?1))
               OR (security_scan_status = 'running'
                   AND (security_scan_started_at IS NULL
                        OR security_scan_started_at <= ?1 - 1800))
           )",
        now,
        &input.scan_run_id,
        &input.plugin_id,
        &input.version
    )?
    .run()
    .await?;
    if claim_result.meta()?.and_then(|meta| meta.changes).unwrap_or(0) == 0 {
        return error_response(
            409,
            "marketplace_security_release_busy",
            "The marketplace release was claimed by another security worker.",
        );
    }

    Response::from_json(&json!({
        "claimed": true,
        "pluginId": input.plugin_id,
        "version": input.version,
        "scanRunId": input.scan_run_id,
        "securityScanStatus": "running",
        "packageSha256": release.package_sha256,
        "packageSize": exact_nonnegative_i64(release.package_size),
    }))
}

pub(super) async fn marketplace_security_result(
    mut request: Request,
    context: RouteContext<()>,
) -> Result<Response> {
    match marketplace_security_token_matches(&request, &context.env)? {
        None => {
            return error_response(
                503,
                "marketplace_security_not_configured",
                "Marketplace security automation is not configured.",
            );
        }
        Some(false) => {
            return error_response(
                401,
                "marketplace_security_automation_unauthorized",
                "The marketplace security automation token is invalid.",
            );
        }
        Some(true) => {}
    }

    let report: Value = match request.json().await {
        Ok(report) => report,
        Err(_) => {
            return error_response(
                400,
                "invalid_marketplace_security_report",
                "The marketplace security result must be valid JSON.",
            );
        }
    };
    let report_size = serde_json::to_vec(&report)
        .map_err(|error| worker::Error::RustError(error.to_string()))?
        .len();
    if report_size > MARKETPLACE_SECURITY_REPORT_MAX_BYTES {
        return error_response(
            413,
            "marketplace_security_report_too_large",
            "The marketplace security report exceeds the permitted size.",
        );
    }
    let plugin_id = match report.get("pluginId").and_then(Value::as_str) {
        Some(value) if is_identifier(value) => value.to_string(),
        _ => {
            return error_response(
                400,
                "invalid_marketplace_security_report",
                "pluginId is invalid.",
            );
        }
    };
    let version = match report.get("version").and_then(Value::as_str) {
        Some(value) if is_version_identifier(value) => value.to_string(),
        _ => {
            return error_response(
                400,
                "invalid_marketplace_security_report",
                "version is invalid.",
            );
        }
    };
    let package_sha256 = match report.get("packageSha256").and_then(Value::as_str) {
        Some(value)
            if value.len() == 64 && value.bytes().all(|byte| byte.is_ascii_hexdigit()) =>
        {
            value.to_ascii_lowercase()
        }
        _ => {
            return error_response(
                400,
                "invalid_marketplace_security_report",
                "packageSha256 must be a 64-character hexadecimal digest.",
            );
        }
    };
    let package_size = match report.get("packageSize").and_then(Value::as_u64) {
        Some(value) if value > 0 && value <= 100 * 1024 * 1024 => match i64::try_from(value) {
            Ok(value) => value,
            Err(_) => {
                return error_response(
                    400,
                    "invalid_marketplace_security_report",
                    "packageSize is out of range.",
                );
            }
        },
        _ => {
            return error_response(
                400,
                "invalid_marketplace_security_report",
                "packageSize is invalid.",
            );
        }
    };
    let verdict = match report.get("verdict").and_then(Value::as_str) {
        Some(value @ ("passed" | "failed")) => value,
        _ => {
            return error_response(
                400,
                "invalid_marketplace_security_report",
                "verdict must be passed or failed.",
            );
        }
    };
    let scan_run_id = match report.get("scanRunId").and_then(Value::as_str) {
        Some(value) if valid_marketplace_security_run_id(value) => value.to_string(),
        _ => {
            return error_response(
                400,
                "invalid_marketplace_security_report",
                "scanRunId is invalid.",
            );
        }
    };
    if report.get("schemaVersion").and_then(Value::as_u64) != Some(1)
        || !marketplace_security_checks_are_well_formed(&report)
        || !marketplace_security_service_is_valid(&report, &context.env)
        || (verdict == "passed" && !marketplace_security_checks_pass(&report))
    {
        return error_response(
            422,
            "marketplace_security_report_failed_validation",
            "The marketplace security report does not satisfy the required check and service contract.",
        );
    }

    let service_server_id = report
        .get("service")
        .and_then(|value| value.get("serverId"))
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    let now = now_seconds();
    let database = context.env.d1(DATABASE_BINDING)?;
    let release = worker::query!(
        &database,
        "SELECT package_sha256, package_size, published_at, release_status,
                security_scan_status, security_next_scan_at,
                security_scan_started_at, security_scan_run_id
         FROM plugin_releases
         WHERE plugin_id = ?1 AND version = ?2",
        &plugin_id,
        &version
    )?
    .first::<MarketplaceSecurityReleaseRow>(None)
    .await?;
    let Some(release) = release else {
        return error_response(
            404,
            "marketplace_security_release_not_found",
            "The marketplace release does not exist.",
        );
    };
    let Some(stored_package_size) = exact_nonnegative_i64(release.package_size) else {
        return error_response(
            503,
            "marketplace_security_package_metadata_invalid",
            "The marketplace release has invalid package metadata.",
        );
    };
    if !release.package_sha256.eq_ignore_ascii_case(&package_sha256)
        || stored_package_size != package_size
    {
        return error_response(
            409,
            "marketplace_security_package_mismatch",
            "The security report does not match the immutable marketplace package metadata.",
        );
    }
    if release.security_scan_run_id != scan_run_id {
        return error_response(
            409,
            "marketplace_security_claim_mismatch",
            "The security report does not match the active scan claim.",
        );
    }
    if verdict == "passed"
        && !marketplace_security_signature_is_valid(
            &report,
            &package_sha256,
            package_size,
            &context.env,
        )
    {
        return error_response(
            422,
            "marketplace_security_signature_invalid",
            "A valid server Cosign bundle bound to the pinned public key is required before publication.",
        );
    }
    if release.security_scan_status != "running" {
        let passed_retry = verdict == "passed"
            && release.security_scan_status == "passed"
            && release.release_status == "approved";
        let failed_retry = verdict == "failed"
            && release.security_scan_status == "failed"
            && matches!(release.release_status.as_str(), "rejected" | "revoked");
        if passed_retry || failed_retry {
            return Response::from_json(&json!({
                "accepted": true,
                "idempotent": true,
                "published": passed_retry,
                "revoked": failed_retry && release.release_status == "revoked",
                "pluginId": plugin_id,
                "version": version,
                "releaseStatus": release.release_status,
                "securityScanStatus": release.security_scan_status,
                "nextScanAt": release.security_next_scan_at.and_then(exact_nonnegative_i64),
            }));
        }
        return error_response(
            409,
            "marketplace_security_claim_mismatch",
            "The security report does not match the active scan claim.",
        );
    }

    let sanitized_report = sanitized_marketplace_security_report(
        &report,
        &plugin_id,
        &version,
        &package_sha256,
        package_size,
    );
    let sanitized_report_json = serde_json::to_string(&sanitized_report)
        .map_err(|error| worker::Error::RustError(error.to_string()))?;
    if sanitized_report_json.len() > MARKETPLACE_SECURITY_REPORT_MAX_BYTES {
        return error_response(
            413,
            "marketplace_security_report_too_large",
            "The sanitized marketplace security report exceeds the permitted size.",
        );
    }
    let signature_json = sanitized_report
        .get("signature")
        .cloned()
        .unwrap_or_else(|| json!({}));
    let signature_json = serde_json::to_string(&signature_json)
        .map_err(|error| worker::Error::RustError(error.to_string()))?;
    let audit_id = Uuid::new_v4().to_string();
    let subject_id = format!("{plugin_id}@{version}");

    if verdict == "passed" {
        let next_scan_at = now + MARKETPLACE_SECURITY_SCAN_INTERVAL_SECONDS;
        database
            .batch(vec![
                worker::query!(
                    &database,
                    "UPDATE plugin_releases
                     SET security_scan_status = 'passed',
                         security_scan_json = ?1,
                         security_scanned_at = ?2,
                         security_next_scan_at = ?3,
                         security_scan_started_at = NULL,
                         security_scan_run_id = ?4,
                         security_signature_json = ?5,
                         release_status = 'approved',
                         revoked_at = NULL,
                         revocation_reason = NULL
                     WHERE plugin_id = ?6 AND version = ?7
                       AND package_sha256 = ?8 AND package_size = ?9
                       AND release_status IN ('pending', 'staged', 'approved')
                       AND security_scan_status = 'running'
                       AND security_scan_run_id = ?4",
                    &sanitized_report_json,
                    now,
                    next_scan_at,
                    &scan_run_id,
                    &signature_json,
                    &plugin_id,
                    &version,
                    &package_sha256,
                    package_size
                )?,
                worker::query!(
                    &database,
                    "UPDATE marketplace_plugins
                     SET latest_version = CASE
                             WHEN latest_version IS NULL
                                  OR COALESCE((
                                      SELECT published_at FROM plugin_releases
                                      WHERE plugin_id = ?1 AND version = latest_version
                                        AND release_status = 'approved'
                                  ), -1) <= COALESCE((
                                      SELECT published_at FROM plugin_releases
                                      WHERE plugin_id = ?1 AND version = ?2
                                  ), -1)
                             THEN ?2 ELSE latest_version END,
                         visibility = 'public',
                         review_state = 'approved',
                         updated_at = ?4
                     WHERE plugin_id = ?1
                       AND EXISTS (
                           SELECT 1 FROM plugin_releases
                           WHERE plugin_id = ?1 AND version = ?2
                             AND release_status = 'approved'
                             AND security_scan_status = 'passed'
                             AND security_scan_run_id = ?3
                       )",
                    &plugin_id,
                    &version,
                    &scan_run_id,
                    now
                )?,
                worker::query!(
                    &database,
                    "INSERT OR IGNORE INTO audit_events
                     (event_id, actor_type, actor_id, event_type, subject_type, subject_id, payload_json, created_at)
                     VALUES (?1, 'automation', ?2, 'marketplace_security_passed',
                             'marketplace_release', ?3, ?4, ?5)",
                    &audit_id,
                    &service_server_id,
                    &subject_id,
                    &sanitized_report_json,
                    now
                )?,
            ])
            .await?;
        return Response::from_json(&json!({
            "accepted": true,
            "published": true,
            "pluginId": plugin_id,
            "version": version,
            "releaseStatus": "approved",
            "securityScanStatus": "passed",
            "nextScanAt": next_scan_at,
        }));
    }

    let active_rescan = release.release_status == "approved";
    let release_status = if active_rescan { "revoked" } else { "rejected" };
    let event_type = if active_rescan {
        "marketplace_security_revoked"
    } else {
        "marketplace_security_rejected"
    };
    database
        .batch(vec![
            worker::query!(
                &database,
                "UPDATE plugin_releases
                 SET security_scan_status = 'failed',
                     security_scan_json = ?1,
                     security_scanned_at = ?2,
                     security_next_scan_at = NULL,
                     security_scan_started_at = NULL,
                     security_scan_run_id = ?3,
                     security_signature_json = '{}',
                     release_status = CASE
                         WHEN release_status = 'approved' THEN 'revoked'
                         ELSE 'rejected'
                     END,
                     revoked_at = CASE
                         WHEN release_status = 'approved' THEN ?2
                         ELSE NULL
                     END,
                     revocation_reason = CASE
                         WHEN release_status = 'approved' THEN 'automated_security_failure'
                         ELSE NULL
                     END
                 WHERE plugin_id = ?4 AND version = ?5
                   AND package_sha256 = ?6 AND package_size = ?7
                   AND release_status IN ('pending', 'staged', 'approved')
                   AND security_scan_status = 'running'
                   AND security_scan_run_id = ?3",
                &sanitized_report_json,
                now,
                &scan_run_id,
                &plugin_id,
                &version,
                &package_sha256,
                package_size
            )?,
            worker::query!(
                &database,
                "UPDATE marketplace_plugins
                 SET latest_version = CASE
                         WHEN latest_version = ?2 THEN (
                             SELECT version FROM plugin_releases
                             WHERE plugin_id = ?1 AND release_status = 'approved'
                               AND security_scan_status = 'passed'
                             ORDER BY published_at DESC LIMIT 1
                         )
                         ELSE latest_version
                     END,
                     visibility = CASE
                         WHEN latest_version = ?2 OR latest_version IS NULL THEN CASE
                             WHEN EXISTS (
                                 SELECT 1 FROM plugin_releases
                                 WHERE plugin_id = ?1 AND release_status = 'approved'
                                   AND security_scan_status = 'passed'
                             ) THEN 'public' ELSE 'unlisted' END
                         ELSE visibility
                     END,
                     review_state = CASE
                         WHEN latest_version = ?2 OR latest_version IS NULL THEN CASE
                             WHEN EXISTS (
                                 SELECT 1 FROM plugin_releases
                                 WHERE plugin_id = ?1 AND release_status = 'approved'
                                   AND security_scan_status = 'passed'
                             ) THEN 'approved' ELSE 'rejected' END
                         ELSE review_state
                     END,
                     updated_at = ?3
                 WHERE plugin_id = ?1",
                &plugin_id,
                &version,
                now
            )?,
            worker::query!(
                &database,
                "INSERT OR IGNORE INTO audit_events
                 (event_id, actor_type, actor_id, event_type, subject_type, subject_id, payload_json, created_at)
                 VALUES (?1, 'automation', ?2, ?3, 'marketplace_release', ?4, ?5, ?6)",
                &audit_id,
                &service_server_id,
                event_type,
                &subject_id,
                &sanitized_report_json,
                now
            )?,
        ])
        .await?;

    Response::from_json(&json!({
        "accepted": true,
        "published": false,
        "revoked": active_rescan,
        "pluginId": plugin_id,
        "version": version,
        "releaseStatus": release_status,
        "securityScanStatus": "failed",
    }))
}

pub(super) async fn marketplace_release_metadata(
    _request: Request,
    context: RouteContext<()>,
) -> Result<Response> {
    let plugin_id = route_identifier(&context, "plugin_id")?;
    let version = route_version(&context)?;
    if plugin_id == CHATGPT_USERSCRIPT_PLUGIN_ID && version == CHATGPT_USERSCRIPT_VERSION {
        return Response::from_json(&chatgpt_userscript_projection());
    }
    let database = context.env.d1(DATABASE_BINDING)?;
    let row = worker::query!(
        &database,
        "SELECT pr.plugin_id, pr.version, pr.package_sha256, pr.package_size,
                pr.deployment_url, pr.published_at, mp.platforms_json,
                pr.source_json, pr.release_manifest_json, pr.release_manifest_sha256,
                pr.release_status, pr.revoked_at, pr.revocation_reason,
                pr.security_scan_status, pr.security_scanned_at,
                pr.security_next_scan_at, pr.security_signature_json
         FROM plugin_releases pr
         JOIN marketplace_plugins mp ON mp.plugin_id = pr.plugin_id
         WHERE pr.plugin_id = ?1 AND pr.version = ?2
           AND mp.visibility = 'public' AND mp.review_state = 'approved'
           AND ((pr.release_status = 'approved'
                 AND pr.security_scan_status IN ('passed', 'running'))
                OR pr.release_status = 'revoked')
           AND pr.deployment_url <> ''",
        &plugin_id,
        &version
    )?
    .first::<MarketplaceReleaseMetadataRow>(None)
    .await?;
    let Some(row) = row else {
        return error_response(
            404,
            "marketplace_release_not_found",
            "The approved plugin release does not exist.",
        );
    };
    if row.release_status == "revoked" {
        let revoked_at = row.revoked_at.and_then(exact_nonnegative_i64);
        let reason = row
            .revocation_reason
            .as_deref()
            .unwrap_or("publisher_request");
        return error_response(
            410,
            "release_revoked",
            &format!("Release {plugin_id}@{version} was revoked at {revoked_at:?}: {reason}."),
        );
    }
    if row.release_status != "approved" {
        return error_response(
            404,
            "marketplace_release_not_found",
            "The approved plugin release does not exist.",
        );
    }
    let mut platforms =
        serde_json::from_str::<Vec<String>>(&row.platforms_json).unwrap_or_default();
    let source = serde_json::from_str::<Value>(&row.source_json).unwrap_or(Value::Null);
    let stored_release_manifest =
        serde_json::from_str::<Value>(&row.release_manifest_json).unwrap_or(Value::Null);
    let (release_manifest, install) = enrich_github_release(
        &row.plugin_id,
        &row.version,
        &source,
        stored_release_manifest,
    );
    let release_manifest_sha256 = canonical_json_sha256(&release_manifest)
        .unwrap_or_else(|_| row.release_manifest_sha256.clone());
    if install.is_some()
        && release_supports_chrome_extension(&release_manifest)
        && !platforms
            .iter()
            .any(|platform| platform == CHROME_EXTENSION_PLATFORM)
    {
        platforms.push(CHROME_EXTENSION_PLATFORM.to_string());
    }
    let Some(package_size) = exact_nonnegative_i64(row.package_size) else {
        return error_response(
            503,
            "marketplace_package_size_invalid",
            "The approved release has an invalid package size.",
        );
    };
    let Some(published_at) = exact_nonnegative_i64(row.published_at) else {
        return error_response(
            503,
            "marketplace_published_at_invalid",
            "The approved release has an invalid published timestamp.",
        );
    };
    Response::from_json(&json!({
        "pluginId": row.plugin_id,
        "version": row.version,
        "packageSha256": row.package_sha256,
        "packageSize": package_size,
        "deploymentUrl": row.deployment_url,
        "publishedAt": published_at,
        "platforms": platforms,
        "source": source,
        "releaseManifest": release_manifest,
        "install": install,
        "releaseManifestSha256": release_manifest_sha256,
        "releaseStatus": row.release_status,
        "security": {
            "scanStatus": row.security_scan_status,
            "scannedAt": row.security_scanned_at.and_then(exact_nonnegative_i64),
            "nextScanAt": row.security_next_scan_at.and_then(exact_nonnegative_i64),
            "signature": serde_json::from_str::<Value>(&row.security_signature_json).unwrap_or(Value::Null),
        },
    }))
}

pub(super) async fn marketplace_plugin_download(
    _request: Request,
    context: RouteContext<()>,
) -> Result<Response> {
    let plugin_id = route_identifier(&context, "plugin_id")?;
    let version = route_version(&context)?;
    let database = context.env.d1(DATABASE_BINDING)?;
    let release = worker::query!(
        &database,
        "SELECT pr.deployment_url, pr.package_key, pr.package_sha256, pr.package_size,
                pr.release_status, pr.revoked_at, pr.revocation_reason
         FROM plugin_releases pr
         JOIN marketplace_plugins mp ON mp.plugin_id = pr.plugin_id
         WHERE pr.plugin_id = ?1 AND pr.version = ?2
           AND mp.visibility = 'public' AND mp.review_state = 'approved'
           AND ((pr.release_status = 'approved'
                 AND pr.security_scan_status IN ('passed', 'running'))
                OR pr.release_status = 'revoked')
           AND pr.deployment_url <> ''",
        &plugin_id,
        &version
    )?
    .first::<MarketplaceReleaseDownloadRow>(None)
    .await?;
    let Some(release) = release else {
        return error_response(
            404,
            "marketplace_release_not_found",
            "The approved plugin release does not exist.",
        );
    };
    if release.release_status == "revoked" {
        let revoked_at = release.revoked_at.and_then(exact_nonnegative_i64);
        let reason = release
            .revocation_reason
            .as_deref()
            .unwrap_or("publisher_request");
        return error_response(
            410,
            "release_revoked",
            &format!("Release {plugin_id}@{version} was revoked at {revoked_at:?}: {reason}."),
        );
    }
    if release.release_status != "approved" {
        return error_response(
            404,
            "marketplace_release_not_found",
            "The approved plugin release does not exist.",
        );
    }

    if !is_public_https_url(&release.deployment_url) {
        return error_response(
            503,
            "marketplace_deployment_url_invalid",
            "The approved release does not point to a valid Cloudflare Pages/Worker site.",
        );
    }
    let package_size = match exact_nonnegative_i64(release.package_size)
        .and_then(|size| usize::try_from(size).ok())
    {
        Some(size) if size > 0 && size <= 50 * 1024 * 1024 => size,
        _ => {
            return error_response(
                503,
                "marketplace_package_size_invalid",
                "The approved release has an invalid package size.",
            );
        }
    };
    // The marketplace is a metadata/control plane, not a binary CDN. Current
    // package bytes stay on the publisher's immutable GitHub origin. Older
    // rows may retain an externally served URL in `package_key`, but current
    // public releases are fail-closed unless that URL is GitHub-hosted. Clients
    // MUST continue validating the catalogued size and SHA-256 after following
    // this redirect.
    let package_url = Url::parse(&release.package_key).map_err(|_| {
        worker::Error::RustError("marketplace release package URL is invalid".into())
    })?;
    if !is_github_artifact_url(package_url.as_str()) {
        return error_response(
            503,
            "marketplace_package_url_invalid",
            "The approved release does not point to a GitHub immutable artifact.",
        );
    }
    let mut response = Response::redirect_with_status(package_url, 307)?;
    response
        .headers_mut()
        .set("X-Mahayana-Package-Sha256", &release.package_sha256)?;
    response
        .headers_mut()
        .set("X-Mahayana-Package-Size", &package_size.to_string())?;
    response
        .headers_mut()
        .set("Cache-Control", "public, max-age=300")?;
    Ok(response)
}

pub(super) async fn marketplace_release_revoke(
    mut request: Request,
    context: RouteContext<()>,
) -> Result<Response> {
    let account = match authenticated_account(&request, &context.env) {
        Ok(account) => account,
        Err(_) => {
            return error_response(
                401,
                "unauthorized",
                "A valid Mahayana account token is required to revoke marketplace releases.",
            );
        }
    };
    if !account.is_test_account
        && !account
            .scopes
            .iter()
            .any(|scope| scope == "marketplace.publish")
    {
        return error_response(
            403,
            "marketplace_revoke_forbidden",
            "The account token does not permit marketplace release revocation.",
        );
    }

    let plugin_id = route_identifier(&context, "plugin_id")?;
    let version = route_version(&context)?;
    let database = context.env.d1(DATABASE_BINDING)?;
    let owner = worker::query!(
        &database,
        "SELECT publisher_user_id FROM marketplace_plugins WHERE plugin_id = ?1",
        &plugin_id
    )?
    .first::<MarketplacePluginOwnerRow>(None)
    .await?;
    let Some(owner) = owner else {
        return error_response(
            404,
            "marketplace_plugin_not_found",
            "The marketplace plugin does not exist.",
        );
    };
    if owner.publisher_user_id != account.user_id {
        return error_response(
            403,
            "marketplace_plugin_owner_mismatch",
            "The authenticated publisher does not own this plugin ID.",
        );
    }

    let release = worker::query!(
        &database,
        "SELECT release_status, revoked_at, revocation_reason
         FROM plugin_releases WHERE plugin_id = ?1 AND version = ?2",
        &plugin_id,
        &version
    )?
    .first::<MarketplaceReleaseStatusRow>(None)
    .await?;
    let Some(release) = release else {
        return error_response(
            404,
            "marketplace_release_not_found",
            "The marketplace release does not exist.",
        );
    };
    if release.release_status == "revoked" {
        return Response::from_json(&json!({
            "revoked": true,
            "pluginId": plugin_id,
            "version": version,
            "releaseStatus": release.release_status,
            "revokedAt": release.revoked_at.and_then(exact_nonnegative_i64),
            "reason": release.revocation_reason,
        }));
    }

    let body = request.json::<Value>().await.unwrap_or_else(|_| json!({}));
    let reason = body
        .get("reason")
        .and_then(Value::as_str)
        .unwrap_or("publisher_request")
        .trim()
        .to_string();
    if reason.is_empty() || reason.len() > 256 || reason.chars().any(char::is_control) {
        return error_response(
            400,
            "invalid_revocation_reason",
            "Revocation reason must contain 1 to 256 printable characters.",
        );
    }

    let now = now_seconds();
    database
        .batch(vec![
            worker::query!(
                &database,
                "UPDATE plugin_releases
                 SET release_status = 'revoked', revoked_at = ?1, revocation_reason = ?2
                 WHERE plugin_id = ?3 AND version = ?4",
                now,
                &reason,
                &plugin_id,
                &version
            )?,
            worker::query!(
                &database,
                "UPDATE marketplace_plugins
                 SET latest_version = (
                     SELECT version FROM plugin_releases
                     WHERE plugin_id = ?2 AND release_status = 'approved'
                       AND security_scan_status = 'passed'
                     ORDER BY published_at DESC LIMIT 1
                 ),
                 visibility = CASE WHEN EXISTS (
                     SELECT 1 FROM plugin_releases
                     WHERE plugin_id = ?2 AND release_status = 'approved'
                       AND security_scan_status = 'passed'
                 ) THEN 'public' ELSE 'unlisted' END,
                 review_state = CASE WHEN EXISTS (
                     SELECT 1 FROM plugin_releases
                     WHERE plugin_id = ?2 AND release_status = 'approved'
                       AND security_scan_status = 'passed'
                 ) THEN 'approved' ELSE 'rejected' END,
                 updated_at = ?1
                 WHERE plugin_id = ?2 AND latest_version = ?3",
                now,
                &plugin_id,
                &version
            )?,
        ])
        .await?;

    Response::from_json(&json!({
        "revoked": true,
        "pluginId": plugin_id,
        "version": version,
        "releaseStatus": "revoked",
        "revokedAt": now,
        "reason": reason,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn github_release() -> (Value, Value) {
        let source = json!({
            "provider": "fabushi-official",
            "repository": "https://github.com/bhrumom/fabushi",
            "commit": "7b02d8d00e0646e9bf4e90a129cbf203fcff015d"
        });
        let release = json!({
            "schemaVersion": 1,
            "protocol": "mahayana.external-release.v1",
            "pluginId": "global-dharma",
            "version": "1.0.0",
            "permissions": ["network"],
            "artifacts": [{
                "id": "global-dharma-universal-ui",
                "runtime": "local-web",
                "platforms": ["desktop", "web"],
                "source": {
                    "type": "https",
                    "url": "https://raw.githubusercontent.com/bhrumom/fabushi/7b02d8d00e0646e9bf4e90a129cbf203fcff015d/marketplace/packages/global-dharma/1.0.0/app.tar.gz"
                },
                "sha256": "43de877dc87b5dff306164eb143baad545ef40bea2247f28cbe21616829478be",
                "size": 1827,
                "format": "tar-gz",
                "entry": "index.html"
            }]
        });
        (source, release)
    }

    #[test]
    fn enriches_legacy_github_rows_with_shared_install_contract() {
        let (source, release) = github_release();
        let (enriched, install) = enrich_github_release("global-dharma", "1.0.0", &source, release);
        let install = install.expect("GitHub release should be installable");
        assert_eq!(install["protocol"], MARKETPLACE_INSTALL_PROTOCOL);
        assert_eq!(install["strategy"], "github-immutable");
        assert_eq!(install["source"]["sourceRef"], source["commit"]);
        assert_eq!(
            enriched["install"]["source"]["repository"],
            "https://github.com/bhrumom/fabushi"
        );
        assert!(
            enriched["artifacts"][0]["platforms"]
                .as_array()
                .is_some_and(|platforms| platforms
                    .iter()
                    .any(|platform| platform == CHROME_EXTENSION_PLATFORM))
        );
    }

    #[test]
    fn rejects_non_github_artifacts_from_the_unified_install_contract() {
        let (source, mut release) = github_release();
        release["artifacts"][0]["source"]["url"] =
            Value::String("https://example.com/plugin.tar.gz".into());
        let (_, install) = enrich_github_release("global-dharma", "1.0.0", &source, release);
        assert!(install.is_none());
    }

    #[test]
    fn exposes_the_pinned_chatgpt_userscript_as_a_chrome_only_projection() {
        let projection = chatgpt_userscript_projection();
        assert_eq!(projection["pluginId"], CHATGPT_USERSCRIPT_PLUGIN_ID);
        assert_eq!(projection["latestVersion"], CHATGPT_USERSCRIPT_VERSION);
        assert_eq!(projection["platforms"], json!([CHROME_EXTENSION_PLATFORM]));
        assert_eq!(
            projection["install"]["source"]["sourceRef"],
            CHATGPT_USERSCRIPT_COMMIT
        );
        assert_eq!(
            projection["install"]["artifacts"][0]["sha256"],
            CHATGPT_USERSCRIPT_SHA256
        );
        assert_eq!(
            projection["install"]["artifacts"][0]["size"],
            CHATGPT_USERSCRIPT_SIZE
        );
        assert_eq!(projection["releaseManifest"]["runtimeForm"], "userscript");
        assert_eq!(
            projection["releaseManifest"]["surfaces"][0]["platforms"],
            json!([CHROME_EXTENSION_PLATFORM])
        );
        assert_eq!(
            projection["releaseManifest"]["install"]["protocol"],
            MARKETPLACE_INSTALL_PROTOCOL
        );
        assert!(release_supports_chrome_extension(
            &projection["releaseManifest"]
        ));
        assert!(
            github_install_contract(
                CHATGPT_USERSCRIPT_PLUGIN_ID,
                CHATGPT_USERSCRIPT_VERSION,
                &projection["source"],
                &projection["releaseManifest"],
            )
            .is_some()
        );
        assert_eq!(
            projection["releaseManifestSha256"].as_str().map(str::len),
            Some(64)
        );
    }
}
