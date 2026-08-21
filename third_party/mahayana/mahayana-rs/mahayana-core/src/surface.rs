//! Cross-surface Mahayana runtime capability contract.
//!
//! CLI/TUI, headless CI, Electron desktop, native mobile, Web, and IDE clients
//! negotiate the same product features rather than binding directly to a
//! provider-specific app-server protocol.

use crate::BuildProfile;
use crate::capability::kernel::BackendCapabilities;
use serde::Deserialize;
use serde::Serialize;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SurfaceKind {
    Cli,
    Tui,
    Headless,
    ElectronDesktop,
    NativeMobile,
    Web,
    Ide,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SurfaceFeatures {
    pub streaming: bool,
    pub approvals: bool,
    pub activities: bool,
    pub rich_resources: bool,
    pub computer_control: bool,
    pub notifications: bool,
    pub background_tasks: bool,
    pub realtime_audio: bool,
}

impl SurfaceFeatures {
    pub fn for_surface(surface: SurfaceKind) -> Self {
        match surface {
            SurfaceKind::Cli => Self {
                streaming: true,
                approvals: true,
                activities: true,
                notifications: true,
                ..Self::default()
            },
            SurfaceKind::Tui => Self {
                streaming: true,
                approvals: true,
                activities: true,
                rich_resources: true,
                notifications: true,
                background_tasks: true,
                ..Self::default()
            },
            SurfaceKind::Headless => Self {
                streaming: true,
                activities: true,
                background_tasks: true,
                ..Self::default()
            },
            SurfaceKind::ElectronDesktop => Self {
                streaming: true,
                approvals: true,
                activities: true,
                rich_resources: true,
                computer_control: true,
                notifications: true,
                background_tasks: true,
                realtime_audio: true,
            },
            SurfaceKind::NativeMobile => Self {
                streaming: true,
                approvals: true,
                activities: true,
                rich_resources: true,
                notifications: true,
                background_tasks: true,
                realtime_audio: true,
                computer_control: false,
            },
            SurfaceKind::Web => Self {
                streaming: true,
                approvals: true,
                activities: true,
                rich_resources: true,
                notifications: true,
                ..Self::default()
            },
            SurfaceKind::Ide => Self {
                streaming: true,
                approvals: true,
                activities: true,
                rich_resources: true,
                background_tasks: true,
                ..Self::default()
            },
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SurfaceHandshake {
    pub protocol_version: u32,
    pub surface: SurfaceKind,
    pub build_profile: BuildProfile,
    pub requested_surface_features: SurfaceFeatures,
    pub required_backend: BackendCapabilities,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RuntimeHandshake {
    pub protocol_version: u32,
    pub accepted: bool,
    pub surface_features: SurfaceFeatures,
    pub backend_capabilities: BackendCapabilities,
    pub missing: Vec<String>,
}

pub fn negotiate(
    request: &SurfaceHandshake,
    available_surface: SurfaceFeatures,
    available_backend: BackendCapabilities,
) -> RuntimeHandshake {
    let mut missing = Vec::new();
    check_feature(
        request.requested_surface_features.streaming,
        available_surface.streaming,
        "surface.streaming",
        &mut missing,
    );
    check_feature(
        request.requested_surface_features.approvals,
        available_surface.approvals,
        "surface.approvals",
        &mut missing,
    );
    check_feature(
        request.requested_surface_features.activities,
        available_surface.activities,
        "surface.activities",
        &mut missing,
    );
    check_feature(
        request.requested_surface_features.rich_resources,
        available_surface.rich_resources,
        "surface.richResources",
        &mut missing,
    );
    check_feature(
        request.requested_surface_features.computer_control,
        available_surface.computer_control,
        "surface.computerControl",
        &mut missing,
    );
    check_feature(
        request.requested_surface_features.notifications,
        available_surface.notifications,
        "surface.notifications",
        &mut missing,
    );
    check_feature(
        request.requested_surface_features.background_tasks,
        available_surface.background_tasks,
        "surface.backgroundTasks",
        &mut missing,
    );
    check_feature(
        request.requested_surface_features.realtime_audio,
        available_surface.realtime_audio,
        "surface.realtimeAudio",
        &mut missing,
    );
    check_backend(request.required_backend, available_backend, &mut missing);

    RuntimeHandshake {
        protocol_version: request.protocol_version,
        accepted: missing.is_empty(),
        surface_features: available_surface,
        backend_capabilities: available_backend,
        missing,
    }
}

fn check_backend(
    required: BackendCapabilities,
    available: BackendCapabilities,
    missing: &mut Vec<String>,
) {
    for (name, required, available) in [
        ("backend.realtime", required.realtime, available.realtime),
        ("backend.tools", required.tools, available.tools),
        ("backend.web", required.web, available.web),
        ("backend.mcp", required.mcp, available.mcp),
        ("backend.sandbox", required.sandbox, available.sandbox),
        ("backend.subagents", required.subagents, available.subagents),
        (
            "backend.checkpoints",
            required.checkpoints,
            available.checkpoints,
        ),
        ("backend.headless", required.headless, available.headless),
        ("backend.hooks", required.hooks, available.hooks),
        ("backend.skills", required.skills, available.skills),
    ] {
        check_feature(required, available, name, missing);
    }
}

fn check_feature(required: bool, available: bool, name: &str, missing: &mut Vec<String>) {
    if required && !available {
        missing.push(name.to_string());
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_product_surfaces_share_one_handshake_shape() {
        for surface in [
            SurfaceKind::Cli,
            SurfaceKind::Tui,
            SurfaceKind::Headless,
            SurfaceKind::ElectronDesktop,
            SurfaceKind::NativeMobile,
            SurfaceKind::Web,
            SurfaceKind::Ide,
        ] {
            let request = SurfaceHandshake {
                protocol_version: 1,
                surface,
                build_profile: BuildProfile::DesktopFull,
                requested_surface_features: SurfaceFeatures {
                    streaming: true,
                    ..SurfaceFeatures::default()
                },
                required_backend: BackendCapabilities::default(),
            };
            let response = negotiate(
                &request,
                SurfaceFeatures::for_surface(surface),
                BackendCapabilities::default(),
            );
            assert!(response.accepted, "surface {surface:?} must stream");
        }
    }

    #[test]
    fn negotiation_reports_missing_provider_features_without_vendor_names() {
        let request = SurfaceHandshake {
            protocol_version: 1,
            surface: SurfaceKind::Headless,
            build_profile: BuildProfile::DesktopFull,
            requested_surface_features: SurfaceFeatures {
                streaming: true,
                ..SurfaceFeatures::default()
            },
            required_backend: BackendCapabilities {
                tools: true,
                sandbox: true,
                headless: true,
                ..BackendCapabilities::default()
            },
        };
        let response = negotiate(
            &request,
            SurfaceFeatures::for_surface(SurfaceKind::Headless),
            BackendCapabilities {
                tools: true,
                sandbox: true,
                ..BackendCapabilities::default()
            },
        );
        assert!(!response.accepted);
        assert_eq!(response.missing, vec!["backend.headless"]);
    }
}
