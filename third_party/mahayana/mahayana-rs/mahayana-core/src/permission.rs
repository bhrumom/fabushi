//! Durable Mahayana permission ledger.
//!
//! This implements session approvals and persistent never-allow decisions for
//! shell, web, MCP, computer, and future capability classes without relying on
//! a provider's permission database.

use crate::capability::kernel::PermissionDecision;
use crate::capability::kernel::PermissionDisposition;
use crate::capability::kernel::PermissionKey;
use crate::capability::kernel::PermissionMode;
use crate::capability::kernel::PermissionRequest;
use crate::capability::kernel::RiskClass;
use serde::Deserialize;
use serde::Serialize;
use std::collections::BTreeMap;
use std::collections::HashSet;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PermissionDomain {
    Shell,
    Filesystem,
    Git,
    Web,
    Mcp,
    Computer,
    Plugin,
    Native,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PermissionRule {
    pub domain: PermissionDomain,
    pub key: PermissionKey,
    pub disposition: StoredDisposition,
    pub created_at_ms: i64,
    pub reason: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum StoredDisposition {
    Allow,
    Deny,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DurablePermissionState {
    pub rules: Vec<PermissionRule>,
}

#[derive(Debug, Clone, Default)]
pub struct PermissionLedger {
    durable: BTreeMap<String, PermissionRule>,
    session_allows: HashSet<String>,
    session_denials: HashSet<String>,
}

impl PermissionLedger {
    pub fn from_state(state: DurablePermissionState) -> Result<Self, PermissionLedgerError> {
        let mut ledger = Self::default();
        for rule in state.rules {
            let identity = rule_identity(rule.domain, &rule.key);
            if ledger.durable.insert(identity.clone(), rule).is_some() {
                return Err(PermissionLedgerError::DuplicateRule(identity));
            }
        }
        Ok(ledger)
    }

    pub fn durable_state(&self) -> DurablePermissionState {
        DurablePermissionState {
            rules: self.durable.values().cloned().collect(),
        }
    }

    pub fn evaluate(
        &self,
        domain: PermissionDomain,
        mode: PermissionMode,
        request: &PermissionRequest,
    ) -> PermissionDisposition {
        let identity = rule_identity(domain, &request.key);
        if let Some(rule) = self.durable.get(&identity) {
            return match rule.disposition {
                StoredDisposition::Allow => PermissionDisposition::Allow,
                StoredDisposition::Deny => PermissionDisposition::Deny,
            };
        }
        if self.session_denials.contains(&identity) {
            return PermissionDisposition::Deny;
        }
        if self.session_allows.contains(&identity) {
            return PermissionDisposition::Allow;
        }
        default_disposition(mode, request.risk)
    }

    pub fn resolve(
        &mut self,
        domain: PermissionDomain,
        request: &PermissionRequest,
        decision: PermissionDecision,
        remember_permanently: bool,
        created_at_ms: i64,
        reason: Option<String>,
    ) {
        let identity = rule_identity(domain, &request.key);
        match decision {
            PermissionDecision::AllowOnce | PermissionDecision::DenyOnce => {}
            PermissionDecision::AllowSession => {
                self.session_denials.remove(&identity);
                self.session_allows.insert(identity.clone());
                if remember_permanently {
                    self.durable.insert(
                        identity,
                        PermissionRule {
                            domain,
                            key: request.key.clone(),
                            disposition: StoredDisposition::Allow,
                            created_at_ms,
                            reason,
                        },
                    );
                }
            }
            PermissionDecision::DenyAlways => {
                self.session_allows.remove(&identity);
                self.session_denials.insert(identity.clone());
                self.durable.insert(
                    identity,
                    PermissionRule {
                        domain,
                        key: request.key.clone(),
                        disposition: StoredDisposition::Deny,
                        created_at_ms,
                        reason,
                    },
                );
            }
        }
    }

    pub fn forget(
        &mut self,
        domain: PermissionDomain,
        key: &PermissionKey,
    ) -> Option<PermissionRule> {
        let identity = rule_identity(domain, key);
        self.session_allows.remove(&identity);
        self.session_denials.remove(&identity);
        self.durable.remove(&identity)
    }

    pub fn clear_session(&mut self) {
        self.session_allows.clear();
        self.session_denials.clear();
    }
}

fn rule_identity(domain: PermissionDomain, key: &PermissionKey) -> String {
    format!("{domain:?}:{}:{}", key.capability, key.target)
}

fn default_disposition(mode: PermissionMode, risk: RiskClass) -> PermissionDisposition {
    match risk {
        RiskClass::ReadOnly => PermissionDisposition::Allow,
        RiskClass::WorkspaceMutation => match mode {
            PermissionMode::ReadOnly => PermissionDisposition::Deny,
            PermissionMode::Workspace | PermissionMode::Elevated => PermissionDisposition::Allow,
        },
        RiskClass::ExternalSideEffect | RiskClass::Privileged => PermissionDisposition::Ask,
    }
}

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum PermissionLedgerError {
    #[error("duplicate durable permission rule: {0}")]
    DuplicateRule(String),
}

#[cfg(test)]
mod tests {
    use super::*;

    fn external() -> PermissionRequest {
        PermissionRequest {
            key: PermissionKey::new("web.fetch", "example.test").expect("key"),
            risk: RiskClass::ExternalSideEffect,
        }
    }

    #[test]
    fn never_allow_survives_serialization_and_new_session() {
        let request = external();
        let mut ledger = PermissionLedger::default();
        ledger.resolve(
            PermissionDomain::Web,
            &request,
            PermissionDecision::DenyAlways,
            true,
            1,
            Some("user selected never allow".into()),
        );
        let encoded = serde_json::to_string(&ledger.durable_state()).expect("encode");
        let state: DurablePermissionState = serde_json::from_str(&encoded).expect("decode");
        let restored = PermissionLedger::from_state(state).expect("restore");
        assert_eq!(
            restored.evaluate(PermissionDomain::Web, PermissionMode::Elevated, &request),
            PermissionDisposition::Deny
        );
    }

    #[test]
    fn session_allow_does_not_become_durable_unless_requested() {
        let request = external();
        let mut ledger = PermissionLedger::default();
        ledger.resolve(
            PermissionDomain::Mcp,
            &request,
            PermissionDecision::AllowSession,
            false,
            1,
            None,
        );
        assert_eq!(
            ledger.evaluate(PermissionDomain::Mcp, PermissionMode::ReadOnly, &request),
            PermissionDisposition::Allow
        );
        assert!(ledger.durable_state().rules.is_empty());
        ledger.clear_session();
        assert_eq!(
            ledger.evaluate(PermissionDomain::Mcp, PermissionMode::ReadOnly, &request),
            PermissionDisposition::Ask
        );
    }

    #[test]
    fn permanent_deny_overrides_elevated_mode() {
        let request = PermissionRequest {
            key: PermissionKey::new("computer.click", "desktop").expect("key"),
            risk: RiskClass::Privileged,
        };
        let mut ledger = PermissionLedger::default();
        ledger.resolve(
            PermissionDomain::Computer,
            &request,
            PermissionDecision::DenyAlways,
            true,
            1,
            None,
        );
        assert_eq!(
            ledger.evaluate(
                PermissionDomain::Computer,
                PermissionMode::Elevated,
                &request
            ),
            PermissionDisposition::Deny
        );
    }
}
