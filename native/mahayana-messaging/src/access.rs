use crate::actor::ActorId;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use thiserror::Error;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum AccessScope {
    Messaging,
    Calls,
    BlobsRead,
    BlobsWrite,
    Payments,
    MiniApps,
    Administration,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AccessGrant {
    pub id: String,
    pub actor_id: ActorId,
    pub device_id: String,
    pub scopes: BTreeSet<AccessScope>,
    pub issued_at_ms: i64,
    pub expires_at_ms: Option<i64>,
    pub revoked_at_ms: Option<i64>,
}

impl AccessGrant {
    pub fn active_at(&self, now_ms: i64) -> bool {
        self.revoked_at_ms.is_none()
            && self
                .expires_at_ms
                .is_none_or(|expires_at_ms| expires_at_ms > now_ms)
    }

    pub fn allows(&self, scope: AccessScope) -> bool {
        self.scopes.contains(&scope) || self.scopes.contains(&AccessScope::Administration)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AuthorizedAccess {
    pub grant_id: String,
    pub actor_id: ActorId,
    pub device_id: String,
    pub scopes: BTreeSet<AccessScope>,
}

#[derive(Debug, Clone)]
struct SecretGrant {
    secret: Vec<u8>,
    grant: AccessGrant,
}

#[derive(Debug, Clone, Default)]
pub struct AccessTokenRegistry {
    grants: Vec<SecretGrant>,
}

impl AccessTokenRegistry {
    pub fn issue(
        &mut self,
        secret: impl AsRef<[u8]>,
        grant: AccessGrant,
    ) -> Result<(), AccessError> {
        let secret = secret.as_ref();
        validate_secret(secret)?;
        if grant.id.trim().is_empty()
            || grant.device_id.trim().is_empty()
            || !grant.actor_id.is_valid()
        {
            return Err(AccessError::InvalidGrant);
        }
        if grant.scopes.is_empty() {
            return Err(AccessError::EmptyScopes);
        }
        if self.grants.iter().any(|existing| {
            existing.grant.id == grant.id || constant_time_eq(&existing.secret, secret)
        }) {
            return Err(AccessError::DuplicateGrant);
        }
        self.grants.push(SecretGrant {
            secret: secret.to_vec(),
            grant,
        });
        Ok(())
    }

    pub fn authorize(
        &self,
        secret: impl AsRef<[u8]>,
        actor_id: &ActorId,
        device_id: &str,
        scope: AccessScope,
        now_ms: i64,
    ) -> Result<AuthorizedAccess, AccessError> {
        let secret = secret.as_ref();
        validate_secret(secret)?;
        let matching = self
            .grants
            .iter()
            .find(|entry| constant_time_eq(&entry.secret, secret))
            .ok_or(AccessError::Unauthorized)?;
        if &matching.grant.actor_id != actor_id || matching.grant.device_id != device_id {
            return Err(AccessError::IdentityMismatch);
        }
        if !matching.grant.active_at(now_ms) {
            return Err(AccessError::ExpiredOrRevoked);
        }
        if !matching.grant.allows(scope) {
            return Err(AccessError::ScopeDenied(scope));
        }
        Ok(AuthorizedAccess {
            grant_id: matching.grant.id.clone(),
            actor_id: matching.grant.actor_id.clone(),
            device_id: matching.grant.device_id.clone(),
            scopes: matching.grant.scopes.clone(),
        })
    }

    pub fn revoke(&mut self, grant_id: &str, now_ms: i64) -> Result<(), AccessError> {
        let entry = self
            .grants
            .iter_mut()
            .find(|entry| entry.grant.id == grant_id)
            .ok_or_else(|| AccessError::GrantNotFound(grant_id.to_string()))?;
        entry.grant.revoked_at_ms = Some(now_ms);
        zeroize_bytes(&mut entry.secret);
        Ok(())
    }

    pub fn rotate(
        &mut self,
        grant_id: &str,
        old_secret: impl AsRef<[u8]>,
        new_secret: impl AsRef<[u8]>,
    ) -> Result<(), AccessError> {
        validate_secret(new_secret.as_ref())?;
        if self
            .grants
            .iter()
            .any(|entry| constant_time_eq(&entry.secret, new_secret.as_ref()))
        {
            return Err(AccessError::DuplicateGrant);
        }
        let entry = self
            .grants
            .iter_mut()
            .find(|entry| entry.grant.id == grant_id)
            .ok_or_else(|| AccessError::GrantNotFound(grant_id.to_string()))?;
        if !constant_time_eq(&entry.secret, old_secret.as_ref()) {
            return Err(AccessError::Unauthorized);
        }
        zeroize_bytes(&mut entry.secret);
        entry.secret = new_secret.as_ref().to_vec();
        Ok(())
    }

    pub fn grant(&self, grant_id: &str) -> Option<&AccessGrant> {
        self.grants
            .iter()
            .find(|entry| entry.grant.id == grant_id)
            .map(|entry| &entry.grant)
    }
}

impl Drop for AccessTokenRegistry {
    fn drop(&mut self) {
        for entry in &mut self.grants {
            zeroize_bytes(&mut entry.secret);
        }
    }
}

fn validate_secret(secret: &[u8]) -> Result<(), AccessError> {
    if secret.len() < 32 {
        return Err(AccessError::WeakSecret);
    }
    Ok(())
}

fn constant_time_eq(left: &[u8], right: &[u8]) -> bool {
    if left.len() != right.len() {
        return false;
    }
    let mut difference = 0u8;
    for (left, right) in left.iter().zip(right) {
        difference |= left ^ right;
    }
    difference == 0
}

fn zeroize_bytes(bytes: &mut [u8]) {
    for byte in bytes {
        unsafe {
            std::ptr::write_volatile(byte, 0);
        }
    }
    std::sync::atomic::compiler_fence(std::sync::atomic::Ordering::SeqCst);
}

#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum AccessError {
    #[error("messaging access secret must contain at least 32 bytes")]
    WeakSecret,
    #[error("messaging access grant is invalid")]
    InvalidGrant,
    #[error("messaging access grant has no scopes")]
    EmptyScopes,
    #[error("messaging access grant or secret already exists")]
    DuplicateGrant,
    #[error("messaging access token is unauthorized")]
    Unauthorized,
    #[error("messaging access token actor or device does not match request context")]
    IdentityMismatch,
    #[error("messaging access token is expired or revoked")]
    ExpiredOrRevoked,
    #[error("messaging access token is missing required scope {0:?}")]
    ScopeDenied(AccessScope),
    #[error("messaging access grant {0} was not found")]
    GrantNotFound(String),
}

#[cfg(test)]
mod tests {
    use super::*;

    fn secret(fill: u8) -> Vec<u8> {
        vec![fill; 32]
    }

    #[test]
    fn token_is_bound_to_actor_device_scope_and_revocation() {
        let actor_id = ActorId::new("human:1");
        let mut registry = AccessTokenRegistry::default();
        registry
            .issue(
                secret(7),
                AccessGrant {
                    id: "grant:1".into(),
                    actor_id: actor_id.clone(),
                    device_id: "desktop:1".into(),
                    scopes: BTreeSet::from([AccessScope::Messaging, AccessScope::Calls]),
                    issued_at_ms: 1,
                    expires_at_ms: Some(100),
                    revoked_at_ms: None,
                },
            )
            .unwrap();

        assert!(registry
            .authorize(secret(7), &actor_id, "desktop:1", AccessScope::Messaging, 2,)
            .is_ok());
        assert!(matches!(
            registry.authorize(
                secret(7),
                &ActorId::new("human:other"),
                "desktop:1",
                AccessScope::Messaging,
                2,
            ),
            Err(AccessError::IdentityMismatch)
        ));
        assert!(matches!(
            registry.authorize(secret(7), &actor_id, "desktop:1", AccessScope::Payments, 2,),
            Err(AccessError::ScopeDenied(AccessScope::Payments))
        ));
        registry.revoke("grant:1", 3).unwrap();
        assert!(matches!(
            registry.authorize(secret(7), &actor_id, "desktop:1", AccessScope::Messaging, 4,),
            Err(AccessError::Unauthorized | AccessError::ExpiredOrRevoked)
        ));
    }
}
