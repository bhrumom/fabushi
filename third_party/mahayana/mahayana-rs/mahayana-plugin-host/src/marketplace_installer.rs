use codex_core_plugins::plugin_bundle_archive::unpack_plugin_bundle_tar_gz;
use serde_json::Value;
use serde_json::json;
use sha2::Digest;
use sha2::Sha256;
use std::fs;
use std::path::Path;
use std::path::PathBuf;
use std::time::SystemTime;
use std::time::UNIX_EPOCH;

use crate::LocalPlugin;

const MAX_UNPACKED_BYTES: u64 = 100 * 1024 * 1024;
const RECEIPT_NAME: &str = "marketplace-install.json";

/// Installs a marketplace archive into the actual Codex plugin directory used
/// by embedded mobile/desktop runtimes. The caller must supply the server-
/// authoritative release identity; this function re-verifies the downloaded
/// archive and plugin manifest before making the install visible atomically.
pub fn install_marketplace_bundle_to_codex_home(
    codex_home: &Path,
    plugin_id: &str,
    version: &str,
    package_sha256: &str,
    package_size: u64,
    archive: &[u8],
    source: &Value,
) -> Result<Value, String> {
    let plugin_id = safe_plugin_id(plugin_id)?;
    let version = safe_version(version)?;
    let expected_sha256 = safe_sha256(package_sha256)?;
    if package_size == 0 || package_size > 50 * 1024 * 1024 {
        return Err("marketplace package size is outside the supported range".into());
    }
    if archive.len() as u64 != package_size {
        return Err("downloaded marketplace archive size does not match release metadata".into());
    }
    let actual_sha256 = format!("{:x}", Sha256::digest(archive));
    if !actual_sha256.eq_ignore_ascii_case(expected_sha256) {
        return Err(
            "downloaded marketplace archive SHA-256 does not match release metadata".into(),
        );
    }

    let plugins_root = codex_home.join("plugins");
    let destination = plugins_root.join(plugin_id);
    if destination.exists() {
        let inspected = marketplace_install_inspect(codex_home, plugin_id)?;
        let same_identity = inspected.get("installed").and_then(Value::as_bool) == Some(true)
            && inspected.get("pluginId").and_then(Value::as_str) == Some(plugin_id)
            && inspected.get("version").and_then(Value::as_str) == Some(version)
            && inspected
                .get("packageSha256")
                .and_then(Value::as_str)
                .is_some_and(|value| value.eq_ignore_ascii_case(expected_sha256));
        if !same_identity {
            return Err(format!(
                "plugin {plugin_id} is already installed with a different or unverifiable release; use the explicit update flow"
            ));
        }
        return Ok(json!({
            "installed": true,
            "alreadyInstalled": true,
            "pluginId": plugin_id,
            "version": version,
            "packageSha256": actual_sha256,
            "packageSize": package_size,
            "source": source,
            "pluginRoot": destination,
            "receipt": inspected.get("receipt"),
        }));
    }

    fs::create_dir_all(&plugins_root).map_err(|error| error.to_string())?;
    let staging = plugins_root.join(format!(".install-{plugin_id}-{}", uuid::Uuid::new_v4()));
    let result = (|| {
        unpack_plugin_bundle_tar_gz(archive, &staging, MAX_UNPACKED_BYTES)
            .map_err(|error| error.to_string())?;
        let plugin = LocalPlugin::load(&staging).map_err(|error| error.to_string())?;
        if plugin.codex.name != plugin_id {
            return Err(format!(
                "marketplace archive plugin id {} does not match authoritative id {plugin_id}",
                plugin.codex.name
            ));
        }
        if plugin.codex.version.as_deref() != Some(version) {
            return Err(format!(
                "marketplace archive version {} does not match authoritative version {version}",
                plugin.codex.version.as_deref().unwrap_or("<missing>")
            ));
        }
        validate_mobile_runtime(&staging)?;

        let receipt = json!({
            "schemaVersion": 1,
            "protocol": "mahayana.marketplace.install-receipt.v1",
            "pluginId": plugin_id,
            "version": version,
            "packageSha256": actual_sha256,
            "packageSize": package_size,
            "source": source,
            "installedAtMs": now_millis(),
        });
        let receipt_dir = staging.join(".mahayana");
        fs::create_dir_all(&receipt_dir).map_err(|error| error.to_string())?;
        fs::write(
            receipt_dir.join(RECEIPT_NAME),
            serde_json::to_vec_pretty(&receipt).map_err(|error| error.to_string())?,
        )
        .map_err(|error| error.to_string())?;
        fs::rename(&staging, &destination).map_err(|error| error.to_string())?;
        Ok(json!({
            "installed": true,
            "alreadyInstalled": false,
            "pluginId": plugin_id,
            "version": version,
            "packageSha256": actual_sha256,
            "packageSize": package_size,
            "source": source,
            "pluginRoot": destination,
            "receipt": receipt,
        }))
    })();

    if result.is_err() && staging.exists() {
        let _ = fs::remove_dir_all(&staging);
    }
    result
}

pub fn marketplace_install_inspect(codex_home: &Path, plugin_id: &str) -> Result<Value, String> {
    let plugin_id = safe_plugin_id(plugin_id)?;
    let destination = codex_home.join("plugins").join(plugin_id);
    if !destination.is_dir() {
        return Ok(json!({
            "installed": false,
            "pluginId": plugin_id,
        }));
    }
    let receipt = marketplace_install_receipt(codex_home, plugin_id)?.ok_or_else(|| {
        format!("plugin {plugin_id} is present without a verified marketplace receipt")
    })?;
    let plugin = LocalPlugin::load(&destination).map_err(|error| error.to_string())?;
    let manifest_version = plugin
        .codex
        .version
        .as_deref()
        .ok_or_else(|| format!("installed plugin {plugin_id} has no manifest version"))?;
    if plugin.codex.name != plugin_id
        || receipt.get("version").and_then(Value::as_str) != Some(manifest_version)
    {
        return Err(format!(
            "installed plugin manifest and marketplace receipt disagree for {plugin_id}"
        ));
    }
    Ok(json!({
        "installed": true,
        "pluginId": plugin_id,
        "version": manifest_version,
        "packageSha256": receipt.get("packageSha256"),
        "packageSize": receipt.get("packageSize"),
        "source": receipt.get("source"),
        "pluginRoot": destination,
        "receipt": receipt,
    }))
}

pub fn marketplace_install_receipt(
    codex_home: &Path,
    plugin_id: &str,
) -> Result<Option<Value>, String> {
    let plugin_id = safe_plugin_id(plugin_id)?;
    let path = receipt_path(codex_home, plugin_id);
    if !path.is_file() {
        return Ok(None);
    }
    let value =
        serde_json::from_slice::<Value>(&fs::read(&path).map_err(|error| error.to_string())?)
            .map_err(|error| format!("invalid marketplace receipt {}: {error}", path.display()))?;
    if value.get("protocol").and_then(Value::as_str)
        != Some("mahayana.marketplace.install-receipt.v1")
        || value.get("pluginId").and_then(Value::as_str) != Some(plugin_id)
    {
        return Err(format!(
            "marketplace receipt identity is invalid at {}",
            path.display()
        ));
    }
    Ok(Some(value))
}

fn validate_mobile_runtime(plugin_root: &Path) -> Result<(), String> {
    let manifest_path = plugin_root.join(".codex-plugin/plugin.json");
    let manifest: Value = serde_json::from_slice(
        &fs::read(&manifest_path)
            .map_err(|error| format!("failed to read {}: {error}", manifest_path.display()))?,
    )
    .map_err(|error| format!("invalid {}: {error}", manifest_path.display()))?;
    let runtime_variants = manifest
        .get("runtimeVariants")
        .and_then(Value::as_array)
        .ok_or_else(|| "marketplace plugin requires runtimeVariants".to_string())?;

    let mcp_path = plugin_root.join(".mcp.json");
    let mcp: Value = serde_json::from_slice(
        &fs::read(&mcp_path)
            .map_err(|error| format!("failed to read {}: {error}", mcp_path.display()))?,
    )
    .map_err(|error| format!("invalid {}: {error}", mcp_path.display()))?;
    let servers = mcp
        .get("mcpServers")
        .and_then(Value::as_object)
        .ok_or_else(|| ".mcp.json requires mcpServers".to_string())?;
    if servers.is_empty() {
        return Err(".mcp.json requires at least one server".into());
    }

    for (name, server) in servers {
        if let Some(endpoint) = server.get("url").and_then(Value::as_str) {
            let endpoint = url::Url::parse(endpoint)
                .map_err(|error| format!("MCP server {name} URL is invalid: {error}"))?;
            if endpoint.scheme() != "https" || endpoint.host_str().is_none() {
                return Err(format!("MCP server {name} must use an absolute HTTPS URL"));
            }
            if !endpoint.username().is_empty() || endpoint.password().is_some() {
                return Err(format!("MCP server {name} URL must not embed credentials"));
            }
        } else if server.get("command").is_none() {
            return Err(format!("MCP server {name} requires url or command"));
        }
    }

    let mut mobile_servers = runtime_variants
        .iter()
        .filter(|variant| {
            variant
                .get("platforms")
                .and_then(Value::as_array)
                .is_some_and(|platforms| {
                    platforms
                        .iter()
                        .any(|value| value.as_str() == Some("mobile"))
                })
        })
        .filter_map(|variant| variant.get("server").and_then(Value::as_str))
        .collect::<Vec<_>>();
    mobile_servers.sort_unstable();
    mobile_servers.dedup();
    if mobile_servers.is_empty() {
        return Err("marketplace plugin has no mobile runtime variant".into());
    }
    for server_name in &mobile_servers {
        if !servers.contains_key(*server_name) {
            return Err(format!(
                "mobile runtime references missing MCP server {server_name}"
            ));
        }
    }
    Ok(())
}

fn receipt_path(codex_home: &Path, plugin_id: &str) -> PathBuf {
    codex_home
        .join("plugins")
        .join(plugin_id)
        .join(".mahayana")
        .join(RECEIPT_NAME)
}

fn safe_plugin_id(value: &str) -> Result<&str, String> {
    let value = value.trim();
    if value.is_empty()
        || value == "."
        || value == ".."
        || !value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-'))
    {
        return Err("marketplace plugin id is invalid".into());
    }
    Ok(value)
}

fn safe_version(value: &str) -> Result<&str, String> {
    let value = value.trim();
    if value.is_empty()
        || value.len() > 128
        || !value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-' | b'+'))
    {
        return Err("marketplace plugin version is invalid".into());
    }
    Ok(value)
}

fn safe_sha256(value: &str) -> Result<&str, String> {
    let value = value.trim();
    if value.len() == 64 && value.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        Ok(value)
    } else {
        Err("marketplace package SHA-256 is invalid".into())
    }
}

fn now_millis() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_unsafe_plugin_ids() {
        assert!(safe_plugin_id("global-dharma").is_ok());
        assert!(safe_plugin_id("official.global-dharma").is_ok());
        assert!(safe_plugin_id("../global-dharma").is_err());
        assert!(safe_plugin_id("global/dharma").is_err());
    }

    #[test]
    fn mobile_runtime_requires_https_mcp_variant() {
        let root = std::env::temp_dir().join(format!(
            "mahayana-mobile-runtime-validation-{}",
            uuid::Uuid::new_v4()
        ));
        fs::create_dir_all(root.join(".codex-plugin")).unwrap();
        fs::write(
            root.join(".codex-plugin/plugin.json"),
            serde_json::to_vec(&json!({
                "name": "global-dharma",
                "version": "1.0.0",
                "runtimeVariants": [
                    {"id":"account-http","server":"global-dharma","platforms":["mobile"]}
                ]
            }))
            .unwrap(),
        )
        .unwrap();
        fs::write(
            root.join(".mcp.json"),
            serde_json::to_vec(&json!({
                "mcpServers": {
                    "global-dharma": {"url":"https://example.invalid/mcp"}
                }
            }))
            .unwrap(),
        )
        .unwrap();
        assert!(validate_mobile_runtime(&root).is_ok());
        fs::write(
            root.join(".mcp.json"),
            serde_json::to_vec(&json!({
                "mcpServers": {
                    "global-dharma": {"url":"http://example.invalid/mcp"}
                }
            }))
            .unwrap(),
        )
        .unwrap();
        assert!(validate_mobile_runtime(&root).is_err());
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn install_rejects_bad_digest_before_unpacking() {
        let root = std::env::temp_dir().join(format!(
            "mahayana-marketplace-installer-{}",
            uuid::Uuid::new_v4()
        ));
        let result = install_marketplace_bundle_to_codex_home(
            &root,
            "global-dharma",
            "1.0.0",
            &"0".repeat(64),
            3,
            b"bad",
            &json!({"provider": "test"}),
        );
        assert!(result.is_err());
        assert!(!root.join("plugins/global-dharma").exists());
        let _ = fs::remove_dir_all(root);
    }
}
