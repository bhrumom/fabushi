//! Unified Mahayana extension plane.
//!
//! MCP servers, skills, plugins, hooks, mini apps, and native capabilities are
//! described through one product-owned contract. Provider adapters translate
//! their own manifests into these descriptors; product surfaces never need to
//! branch on Codex/Grok-specific extension types.

use crate::BuildProfile;
use crate::capability::kernel::BackendCapabilities;
use crate::capability::kernel::PermissionMode;
use serde::Deserialize;
use serde::Serialize;
use std::collections::BTreeMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ExtensionKind {
    McpServer,
    Skill,
    Plugin,
    Hook,
    MiniApp,
    NativeCapability,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ExtensionSource {
    BuiltIn,
    User,
    Marketplace,
    Project,
    Managed,
    CompatibilityAdapter,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ExtensionTrust {
    Trusted,
    Prompt,
    Untrusted,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ExtensionExecution {
    InProcess,
    SandboxedProcess,
    Mcp,
    Wasm,
    WebView,
    HostNative,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExtensionRequirements {
    pub backend: BackendCapabilities,
    pub permissions: Vec<String>,
    pub supported_profiles: Vec<BuildProfile>,
    pub minimum_permission_mode: PermissionMode,
}

impl Default for ExtensionRequirements {
    fn default() -> Self {
        Self {
            backend: BackendCapabilities::default(),
            permissions: Vec::new(),
            supported_profiles: vec![
                BuildProfile::DesktopFull,
                BuildProfile::MobileEmbedded,
                BuildProfile::WebWasm,
            ],
            minimum_permission_mode: PermissionMode::ReadOnly,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExtensionDescriptor {
    pub id: String,
    pub name: String,
    pub version: String,
    pub kind: ExtensionKind,
    pub source: ExtensionSource,
    pub trust: ExtensionTrust,
    pub execution: ExtensionExecution,
    pub requirements: ExtensionRequirements,
    pub provenance: Option<ExtensionProvenance>,
}

impl ExtensionDescriptor {
    pub fn validate(&self) -> Result<(), ExtensionError> {
        if self.id.trim().is_empty() {
            return Err(ExtensionError::EmptyId);
        }
        if self.name.trim().is_empty() {
            return Err(ExtensionError::EmptyName);
        }
        if self.version.trim().is_empty() {
            return Err(ExtensionError::EmptyVersion);
        }
        if self.requirements.supported_profiles.is_empty() {
            return Err(ExtensionError::NoSupportedProfiles(self.id.clone()));
        }
        Ok(())
    }

    pub fn supports_profile(&self, profile: BuildProfile) -> bool {
        self.requirements.supported_profiles.contains(&profile)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExtensionProvenance {
    pub repository: Option<String>,
    pub revision: Option<String>,
    pub license: Option<String>,
    pub notice: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ExtensionStatus {
    Disabled,
    Ready,
    PermissionRequired,
    BackendUnavailable,
    UnsupportedPlatform,
    BlockedByTrust,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExtensionResolution {
    pub id: String,
    pub status: ExtensionStatus,
    pub reason: Option<String>,
}

#[derive(Default)]
pub struct ExtensionRegistry {
    descriptors: BTreeMap<String, ExtensionDescriptor>,
}

impl ExtensionRegistry {
    pub fn register(&mut self, descriptor: ExtensionDescriptor) -> Result<(), ExtensionError> {
        descriptor.validate()?;
        if self.descriptors.contains_key(&descriptor.id) {
            return Err(ExtensionError::DuplicateId(descriptor.id));
        }
        self.descriptors.insert(descriptor.id.clone(), descriptor);
        Ok(())
    }

    pub fn get(&self, id: &str) -> Option<&ExtensionDescriptor> {
        self.descriptors.get(id)
    }

    pub fn list(&self) -> Vec<&ExtensionDescriptor> {
        self.descriptors.values().collect()
    }

    pub fn resolve(
        &self,
        id: &str,
        profile: BuildProfile,
        permission_mode: PermissionMode,
        available_backend: BackendCapabilities,
    ) -> Result<ExtensionResolution, ExtensionError> {
        let descriptor = self
            .descriptors
            .get(id)
            .ok_or_else(|| ExtensionError::UnknownId(id.to_string()))?;

        if !descriptor.supports_profile(profile) {
            return Ok(ExtensionResolution {
                id: descriptor.id.clone(),
                status: ExtensionStatus::UnsupportedPlatform,
                reason: Some("extension is unavailable on this build profile".to_string()),
            });
        }
        if descriptor.trust == ExtensionTrust::Untrusted {
            return Ok(ExtensionResolution {
                id: descriptor.id.clone(),
                status: ExtensionStatus::BlockedByTrust,
                reason: Some("extension is not trusted".to_string()),
            });
        }
        if !backend_supports(available_backend, descriptor.requirements.backend) {
            return Ok(ExtensionResolution {
                id: descriptor.id.clone(),
                status: ExtensionStatus::BackendUnavailable,
                reason: Some("active backend lacks required capabilities".to_string()),
            });
        }
        if permission_rank(permission_mode)
            < permission_rank(descriptor.requirements.minimum_permission_mode)
            || (descriptor.trust == ExtensionTrust::Prompt
                && !descriptor.requirements.permissions.is_empty())
        {
            return Ok(ExtensionResolution {
                id: descriptor.id.clone(),
                status: ExtensionStatus::PermissionRequired,
                reason: Some("extension requires additional permission".to_string()),
            });
        }
        Ok(ExtensionResolution {
            id: descriptor.id.clone(),
            status: ExtensionStatus::Ready,
            reason: None,
        })
    }
}

fn backend_supports(available: BackendCapabilities, required: BackendCapabilities) -> bool {
    (!required.realtime || available.realtime)
        && (!required.tools || available.tools)
        && (!required.web || available.web)
        && (!required.mcp || available.mcp)
        && (!required.sandbox || available.sandbox)
        && (!required.subagents || available.subagents)
        && (!required.checkpoints || available.checkpoints)
        && (!required.headless || available.headless)
        && (!required.hooks || available.hooks)
        && (!required.skills || available.skills)
}

fn permission_rank(mode: PermissionMode) -> u8 {
    match mode {
        PermissionMode::ReadOnly => 0,
        PermissionMode::Workspace => 1,
        PermissionMode::Elevated => 2,
    }
}

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum ExtensionError {
    #[error("extension id must not be empty")]
    EmptyId,
    #[error("extension name must not be empty")]
    EmptyName,
    #[error("extension version must not be empty")]
    EmptyVersion,
    #[error("extension must support at least one build profile: {0}")]
    NoSupportedProfiles(String),
    #[error("extension is already registered: {0}")]
    DuplicateId(String),
    #[error("extension was not found: {0}")]
    UnknownId(String),
}

#[cfg(test)]
mod tests {
    use super::*;

    fn extension(kind: ExtensionKind) -> ExtensionDescriptor {
        ExtensionDescriptor {
            id: format!("test.{kind:?}"),
            name: format!("{kind:?}"),
            version: "1".into(),
            kind,
            source: ExtensionSource::BuiltIn,
            trust: ExtensionTrust::Trusted,
            execution: ExtensionExecution::InProcess,
            requirements: ExtensionRequirements::default(),
            provenance: None,
        }
    }

    #[test]
    fn every_extension_kind_uses_the_same_registry_contract() {
        let mut registry = ExtensionRegistry::default();
        for kind in [
            ExtensionKind::McpServer,
            ExtensionKind::Skill,
            ExtensionKind::Plugin,
            ExtensionKind::Hook,
            ExtensionKind::MiniApp,
            ExtensionKind::NativeCapability,
        ] {
            registry.register(extension(kind)).expect("register");
        }
        assert_eq!(registry.list().len(), 6);
        for descriptor in registry.list() {
            assert_eq!(
                registry
                    .resolve(
                        &descriptor.id,
                        BuildProfile::DesktopFull,
                        PermissionMode::ReadOnly,
                        BackendCapabilities::default(),
                    )
                    .expect("resolve")
                    .status,
                ExtensionStatus::Ready
            );
        }
    }

    #[test]
    fn backend_and_permission_requirements_fail_closed() {
        let mut descriptor = extension(ExtensionKind::McpServer);
        descriptor.id = "test.mcp".into();
        descriptor.trust = ExtensionTrust::Prompt;
        descriptor.requirements.backend.mcp = true;
        descriptor.requirements.permissions = vec!["network.external".into()];
        descriptor.requirements.minimum_permission_mode = PermissionMode::Workspace;
        let mut registry = ExtensionRegistry::default();
        registry.register(descriptor).expect("register");

        let unavailable = registry
            .resolve(
                "test.mcp",
                BuildProfile::DesktopFull,
                PermissionMode::Elevated,
                BackendCapabilities::default(),
            )
            .expect("resolve");
        assert_eq!(unavailable.status, ExtensionStatus::BackendUnavailable);

        let permission = registry
            .resolve(
                "test.mcp",
                BuildProfile::DesktopFull,
                PermissionMode::ReadOnly,
                BackendCapabilities {
                    mcp: true,
                    ..BackendCapabilities::default()
                },
            )
            .expect("resolve");
        assert_eq!(permission.status, ExtensionStatus::PermissionRequired);
    }
}
