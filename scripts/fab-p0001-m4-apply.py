# Retrigger after the branch-local workflow is present.
from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    target = Path(path)
    text = target.read_text()
    if new in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one patch anchor, found {count}")
    target.write_text(text.replace(old, new, 1))


replace_once(
    "native/mahayana-messaging/src/engine.rs",
    '''    #[error("message is protected from forwarding")]
    ProtectedContent,
    #[error("secret conversations must contain exactly two participants")]
''',
    '''    #[error("message is protected from forwarding")]
    ProtectedContent,
    #[error("actor {actor_id:?} is not a participant of conversation {conversation_id:?}")]
    SenderNotParticipant {
        conversation_id: ConversationId,
        actor_id: ActorId,
    },
    #[error("conversation {0:?} does not allow sending messages")]
    MessageSendPermissionDenied(ConversationId),
    #[error("conversation {0:?} does not allow sending media")]
    MediaSendPermissionDenied(ConversationId),
    #[error("conversation {0:?} does not allow sending polls")]
    PollSendPermissionDenied(ConversationId),
    #[error("secret conversations must contain exactly two participants")]
''',
)

replace_once(
    "native/mahayana-messaging/src/engine.rs",
    '''fn wallet_account_id(actor_id: &ActorId) -> WalletAccountId {
''',
    '''fn message_content_uses_media(content: &MessageContent) -> bool {
    matches!(
        content,
        MessageContent::Photo { .. }
            | MessageContent::Video { .. }
            | MessageContent::Animation { .. }
            | MessageContent::Audio { .. }
            | MessageContent::Voice { .. }
            | MessageContent::VideoNote { .. }
            | MessageContent::Document { .. }
            | MessageContent::Sticker { .. }
    )
}

fn wallet_account_id(actor_id: &ActorId) -> WalletAccountId {
''',
)

replace_once(
    "native/mahayana-messaging/src/engine.rs",
    '''                let conversation = self.require_conversation(&conversation_id)?;
                self.require_actor(&sender_id)?;
                let is_secret_conversation = matches!(
''',
    '''                let conversation = self.require_conversation(&conversation_id)?;
                self.require_actor(&sender_id)?;
                let sender_is_participant = conversation
                    .participants
                    .iter()
                    .any(|participant| participant.actor_id == sender_id)
                    || conversation.owner_id.as_ref() == Some(&sender_id);
                if !sender_is_participant {
                    return Err(EngineError::SenderNotParticipant {
                        conversation_id: conversation_id.clone(),
                        actor_id: sender_id.clone(),
                    });
                }
                if !conversation.permissions.can_send_messages {
                    return Err(EngineError::MessageSendPermissionDenied(
                        conversation_id.clone(),
                    ));
                }
                if message_content_uses_media(&content) && !conversation.permissions.can_send_media {
                    return Err(EngineError::MediaSendPermissionDenied(
                        conversation_id.clone(),
                    ));
                }
                if matches!(&content, MessageContent::Poll { .. })
                    && !conversation.permissions.can_send_polls
                {
                    return Err(EngineError::PollSendPermissionDenied(
                        conversation_id.clone(),
                    ));
                }
                let is_secret_conversation = matches!(
''',
)

replace_once(
    "native/mahayana-messaging/src/blob_store.rs",
    '''use serde::{Deserialize, Serialize};
use std::fs::{self, File, OpenOptions};
''',
    '''use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fs::{self, File, OpenOptions};
''',
)

replace_once(
    "native/mahayana-messaging/src/blob_store.rs",
    '''        let final_path = self.blob_path(id);
        fs::rename(&part_path, &final_path)?;
''',
    '''        if let Some(expected_hash) = metadata.content_hash.as_deref() {
            let expected = normalize_sha256(expected_hash)?;
            let actual = sha256_file(&part_path)?;
            if actual != expected {
                return Err(BlobStoreError::IntegrityMismatch { expected, actual });
            }
        }
        let final_path = self.blob_path(id);
        fs::rename(&part_path, &final_path)?;
''',
)

replace_once(
    "native/mahayana-messaging/src/blob_store.rs",
    '''fn validate_metadata(metadata: &BlobMetadata) -> Result<(), BlobStoreError> {
''',
    '''fn normalize_sha256(value: &str) -> Result<String, BlobStoreError> {
    let trimmed = value.trim();
    let raw = trimmed.strip_prefix("sha256:").unwrap_or(trimmed);
    let normalized = raw.to_ascii_lowercase();
    if normalized.len() != 64 || !normalized.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err(BlobStoreError::InvalidContentHash(value.to_string()));
    }
    Ok(normalized)
}

fn sha256_file(path: &Path) -> Result<String, BlobStoreError> {
    let mut file = File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = [0u8; 64 * 1024];
    loop {
        let read = file.read(&mut buffer)?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
    }
    Ok(format!("{:x}", hasher.finalize()))
}

fn validate_metadata(metadata: &BlobMetadata) -> Result<(), BlobStoreError> {
''',
)

replace_once(
    "native/mahayana-messaging/src/blob_store.rs",
    '''    #[error("blob range length {0} is invalid")]
    InvalidRangeLength(u64),
''',
    '''    #[error("blob content hash is not a valid SHA-256 value: {0}")]
    InvalidContentHash(String),
    #[error("blob integrity mismatch: expected {expected}, found {actual}")]
    IntegrityMismatch { expected: String, actual: String },
    #[error("blob range length {0} is invalid")]
    InvalidRangeLength(u64),
''',
)
