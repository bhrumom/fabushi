//! Fabushi Pay core.
//!
//! This crate intentionally contains no Apple, Google, Stripe, bank, card or
//! blockchain SDK. It owns the deterministic accounting and payment state
//! machine. Platform/provider adapters submit verified external outcomes.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, HashMap, HashSet};
use thiserror::Error;
use uuid::Uuid;

pub const CREDITS_CURRENCY: &str = "FBC";

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct Currency(pub String);

impl Currency {
    pub fn credits() -> Self {
        Self(CREDITS_CURRENCY.into())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Money {
    pub currency: Currency,
    pub amount: i64,
}

impl Money {
    pub fn positive(currency: Currency, amount: i64) -> Result<Self, PayError> {
        if amount <= 0 {
            return Err(PayError::InvalidAmount(amount));
        }
        Ok(Self { currency, amount })
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum AccountKind {
    UserCredits,
    DeveloperPendingRevenue,
    DeveloperAvailableRevenue,
    PlatformRevenue,
    ProviderClearing,
    RefundReserve,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct LedgerAccount {
    pub account_id: String,
    pub owner_id: String,
    pub kind: AccountKind,
    pub currency: Currency,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct LedgerLine {
    pub account_id: String,
    pub currency: Currency,
    /// Signed minor-unit amount. Every currency must sum to exactly zero.
    pub amount: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct LedgerEntry {
    pub entry_id: String,
    pub reference_type: String,
    pub reference_id: String,
    pub created_at_ms: i64,
    pub lines: Vec<LedgerLine>,
}

impl LedgerEntry {
    pub fn validate(&self) -> Result<(), PayError> {
        if self.lines.len() < 2 {
            return Err(PayError::NotEnoughLedgerLines);
        }
        let mut totals = BTreeMap::<&Currency, i128>::new();
        for line in &self.lines {
            if line.amount == 0 {
                return Err(PayError::ZeroLedgerLine);
            }
            *totals.entry(&line.currency).or_default() += i128::from(line.amount);
        }
        if let Some((currency, amount)) = totals.into_iter().find(|(_, total)| *total != 0) {
            return Err(PayError::UnbalancedLedger {
                currency: currency.0.clone(),
                amount,
            });
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ProductKind {
    DigitalConsumable,
    DigitalDurable,
    Subscription,
    Physical,
    Service,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PaymentRail {
    Credits,
    AppleInAppPurchase,
    GooglePlayBilling,
    WebProvider,
    MerchantProvider,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PaymentStatus {
    Created,
    RequiresAction,
    Processing,
    Succeeded,
    Failed,
    Cancelled,
    PartiallyRefunded,
    Refunded,
}

impl PaymentStatus {
    fn terminal(self) -> bool {
        matches!(
            self,
            Self::Succeeded | Self::Failed | Self::Cancelled | Self::PartiallyRefunded | Self::Refunded
        )
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CreatePaymentIntent {
    pub idempotency_key: String,
    pub user_id: String,
    pub mini_app_id: String,
    pub developer_id: String,
    pub sku: String,
    pub product_kind: ProductKind,
    pub rail: PaymentRail,
    pub amount: Money,
    pub platform_fee_bps: u16,
    pub created_at_ms: i64,
}

impl CreatePaymentIntent {
    pub fn validate(&self) -> Result<(), PayError> {
        if self.idempotency_key.trim().is_empty()
            || self.user_id.trim().is_empty()
            || self.mini_app_id.trim().is_empty()
            || self.developer_id.trim().is_empty()
            || self.sku.trim().is_empty()
        {
            return Err(PayError::MissingStableId);
        }
        if self.amount.amount <= 0 {
            return Err(PayError::InvalidAmount(self.amount.amount));
        }
        if self.platform_fee_bps > 10_000 {
            return Err(PayError::InvalidFeeBps(self.platform_fee_bps));
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct PaymentIntent {
    pub payment_id: String,
    pub idempotency_key: String,
    pub user_id: String,
    pub mini_app_id: String,
    pub developer_id: String,
    pub sku: String,
    pub product_kind: ProductKind,
    pub rail: PaymentRail,
    pub amount: Money,
    pub platform_fee_bps: u16,
    pub status: PaymentStatus,
    pub provider_reference: Option<String>,
    pub refunded_amount: i64,
    pub created_at_ms: i64,
    pub updated_at_ms: i64,
}

impl PaymentIntent {
    pub fn platform_fee(&self) -> i64 {
        let gross = i128::from(self.amount.amount);
        let fee = gross * i128::from(self.platform_fee_bps) / 10_000;
        i64::try_from(fee).unwrap_or(i64::MAX)
    }

    pub fn developer_net(&self) -> i64 {
        self.amount.amount.saturating_sub(self.platform_fee())
    }

    pub fn refundable_amount(&self) -> i64 {
        self.amount.amount.saturating_sub(self.refunded_amount)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ProviderOutcome {
    pub provider_reference: String,
    pub occurred_at_ms: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct RefundRequest {
    pub idempotency_key: String,
    pub payment_id: String,
    pub amount: i64,
    pub occurred_at_ms: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct SettlementRelease {
    pub idempotency_key: String,
    pub payment_id: String,
    pub occurred_at_ms: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PaymentMutation {
    pub payment: PaymentIntent,
    pub ledger_entry: Option<LedgerEntry>,
}

#[derive(Default)]
pub struct PayEngine {
    payments: HashMap<String, PaymentIntent>,
    payment_by_idempotency: HashMap<String, String>,
    mutation_keys: HashSet<String>,
}

impl PayEngine {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn get(&self, payment_id: &str) -> Option<&PaymentIntent> {
        self.payments.get(payment_id)
    }

    pub fn create_payment(&mut self, request: CreatePaymentIntent) -> Result<PaymentIntent, PayError> {
        request.validate()?;
        if let Some(payment_id) = self.payment_by_idempotency.get(&request.idempotency_key) {
            return self
                .payments
                .get(payment_id)
                .cloned()
                .ok_or_else(|| PayError::CorruptIdempotencyIndex(request.idempotency_key));
        }

        let payment = PaymentIntent {
            payment_id: Uuid::new_v4().to_string(),
            idempotency_key: request.idempotency_key.clone(),
            user_id: request.user_id,
            mini_app_id: request.mini_app_id,
            developer_id: request.developer_id,
            sku: request.sku,
            product_kind: request.product_kind,
            rail: request.rail,
            amount: request.amount,
            platform_fee_bps: request.platform_fee_bps,
            status: PaymentStatus::Created,
            provider_reference: None,
            refunded_amount: 0,
            created_at_ms: request.created_at_ms,
            updated_at_ms: request.created_at_ms,
        };
        self.payment_by_idempotency
            .insert(request.idempotency_key, payment.payment_id.clone());
        self.payments.insert(payment.payment_id.clone(), payment.clone());
        Ok(payment)
    }

    pub fn mark_requires_action(
        &mut self,
        payment_id: &str,
        now_ms: i64,
    ) -> Result<PaymentIntent, PayError> {
        self.transition(payment_id, PaymentStatus::RequiresAction, now_ms)
    }

    pub fn mark_processing(&mut self, payment_id: &str, now_ms: i64) -> Result<PaymentIntent, PayError> {
        self.transition(payment_id, PaymentStatus::Processing, now_ms)
    }

    pub fn fail(&mut self, payment_id: &str, now_ms: i64) -> Result<PaymentIntent, PayError> {
        self.transition(payment_id, PaymentStatus::Failed, now_ms)
    }

    pub fn cancel(&mut self, payment_id: &str, now_ms: i64) -> Result<PaymentIntent, PayError> {
        self.transition(payment_id, PaymentStatus::Cancelled, now_ms)
    }

    pub fn succeed(
        &mut self,
        payment_id: &str,
        outcome: ProviderOutcome,
    ) -> Result<PaymentMutation, PayError> {
        let payment = self
            .payments
            .get(payment_id)
            .cloned()
            .ok_or_else(|| PayError::PaymentNotFound(payment_id.into()))?;

        if payment.status == PaymentStatus::Succeeded
            || payment.status == PaymentStatus::PartiallyRefunded
            || payment.status == PaymentStatus::Refunded
        {
            if payment.provider_reference.as_deref() == Some(&outcome.provider_reference) {
                return Ok(PaymentMutation {
                    payment,
                    ledger_entry: None,
                });
            }
            return Err(PayError::ProviderReferenceConflict);
        }
        if payment.status.terminal() {
            return Err(PayError::InvalidTransition {
                from: payment.status,
                to: PaymentStatus::Succeeded,
            });
        }

        let fee = payment.platform_fee();
        let net = payment.developer_net();
        let mut updated = payment.clone();
        updated.status = PaymentStatus::Succeeded;
        updated.provider_reference = Some(outcome.provider_reference);
        updated.updated_at_ms = outcome.occurred_at_ms;

        let entry = LedgerEntry {
            entry_id: Uuid::new_v4().to_string(),
            reference_type: "payment".into(),
            reference_id: payment.payment_id.clone(),
            created_at_ms: outcome.occurred_at_ms,
            lines: vec![
                LedgerLine {
                    account_id: format!("provider-clearing:{}", payment.amount.currency.0),
                    currency: payment.amount.currency.clone(),
                    amount: -payment.amount.amount,
                },
                LedgerLine {
                    account_id: format!("developer-pending:{}", payment.developer_id),
                    currency: payment.amount.currency.clone(),
                    amount: net,
                },
                LedgerLine {
                    account_id: "platform-revenue".into(),
                    currency: payment.amount.currency.clone(),
                    amount: fee,
                },
            ],
        };
        entry.validate()?;
        self.payments.insert(payment.payment_id.clone(), updated.clone());
        Ok(PaymentMutation {
            payment: updated,
            ledger_entry: Some(entry),
        })
    }

    pub fn refund(&mut self, request: RefundRequest) -> Result<PaymentMutation, PayError> {
        if request.idempotency_key.trim().is_empty() {
            return Err(PayError::MissingStableId);
        }
        if self.mutation_keys.contains(&request.idempotency_key) {
            let payment = self
                .payments
                .get(&request.payment_id)
                .cloned()
                .ok_or_else(|| PayError::PaymentNotFound(request.payment_id.clone()))?;
            return Ok(PaymentMutation {
                payment,
                ledger_entry: None,
            });
        }
        if request.amount <= 0 {
            return Err(PayError::InvalidAmount(request.amount));
        }

        let payment = self
            .payments
            .get(&request.payment_id)
            .cloned()
            .ok_or_else(|| PayError::PaymentNotFound(request.payment_id.clone()))?;
        if !matches!(
            payment.status,
            PaymentStatus::Succeeded | PaymentStatus::PartiallyRefunded
        ) {
            return Err(PayError::RefundNotAllowed(payment.status));
        }
        if request.amount > payment.refundable_amount() {
            return Err(PayError::RefundExceedsPayment {
                requested: request.amount,
                remaining: payment.refundable_amount(),
            });
        }

        let fee_refund = i64::try_from(
            i128::from(request.amount) * i128::from(payment.platform_fee_bps) / 10_000,
        )
        .unwrap_or(i64::MAX);
        let developer_refund = request.amount.saturating_sub(fee_refund);
        let new_refunded = payment.refunded_amount.saturating_add(request.amount);

        let mut updated = payment.clone();
        updated.refunded_amount = new_refunded;
        updated.status = if new_refunded == payment.amount.amount {
            PaymentStatus::Refunded
        } else {
            PaymentStatus::PartiallyRefunded
        };
        updated.updated_at_ms = request.occurred_at_ms;

        let entry = LedgerEntry {
            entry_id: Uuid::new_v4().to_string(),
            reference_type: "refund".into(),
            reference_id: payment.payment_id.clone(),
            created_at_ms: request.occurred_at_ms,
            lines: vec![
                LedgerLine {
                    account_id: format!("developer-pending:{}", payment.developer_id),
                    currency: payment.amount.currency.clone(),
                    amount: -developer_refund,
                },
                LedgerLine {
                    account_id: "platform-revenue".into(),
                    currency: payment.amount.currency.clone(),
                    amount: -fee_refund,
                },
                LedgerLine {
                    account_id: format!("provider-clearing:{}", payment.amount.currency.0),
                    currency: payment.amount.currency.clone(),
                    amount: request.amount,
                },
            ],
        };
        entry.validate()?;
        self.payments.insert(payment.payment_id.clone(), updated.clone());
        self.mutation_keys.insert(request.idempotency_key);
        Ok(PaymentMutation {
            payment: updated,
            ledger_entry: Some(entry),
        })
    }

    pub fn release_settlement(
        &mut self,
        request: SettlementRelease,
    ) -> Result<LedgerEntry, PayError> {
        if request.idempotency_key.trim().is_empty() {
            return Err(PayError::MissingStableId);
        }
        if !self.mutation_keys.insert(request.idempotency_key.clone()) {
            return Err(PayError::DuplicateMutation(request.idempotency_key));
        }
        let payment = self
            .payments
            .get(&request.payment_id)
            .cloned()
            .ok_or_else(|| PayError::PaymentNotFound(request.payment_id.clone()))?;
        if !matches!(payment.status, PaymentStatus::Succeeded | PaymentStatus::PartiallyRefunded) {
            return Err(PayError::SettlementNotAllowed(payment.status));
        }

        let gross_net = payment.developer_net();
        let refunded_net = i64::try_from(
            i128::from(payment.refunded_amount)
                * i128::from(10_000_u16.saturating_sub(payment.platform_fee_bps))
                / 10_000,
        )
        .unwrap_or(i64::MAX);
        let releasable = gross_net.saturating_sub(refunded_net);
        if releasable <= 0 {
            return Err(PayError::NothingToSettle);
        }

        let entry = LedgerEntry {
            entry_id: Uuid::new_v4().to_string(),
            reference_type: "settlement-release".into(),
            reference_id: payment.payment_id,
            created_at_ms: request.occurred_at_ms,
            lines: vec![
                LedgerLine {
                    account_id: format!("developer-pending:{}", payment.developer_id),
                    currency: payment.amount.currency.clone(),
                    amount: -releasable,
                },
                LedgerLine {
                    account_id: format!("developer-available:{}", payment.developer_id),
                    currency: payment.amount.currency,
                    amount: releasable,
                },
            ],
        };
        entry.validate()?;
        Ok(entry)
    }

    fn transition(
        &mut self,
        payment_id: &str,
        next: PaymentStatus,
        now_ms: i64,
    ) -> Result<PaymentIntent, PayError> {
        let payment = self
            .payments
            .get_mut(payment_id)
            .ok_or_else(|| PayError::PaymentNotFound(payment_id.into()))?;
        let allowed = matches!(
            (payment.status, next),
            (PaymentStatus::Created, PaymentStatus::RequiresAction)
                | (PaymentStatus::Created, PaymentStatus::Processing)
                | (PaymentStatus::Created, PaymentStatus::Failed)
                | (PaymentStatus::Created, PaymentStatus::Cancelled)
                | (PaymentStatus::RequiresAction, PaymentStatus::Processing)
                | (PaymentStatus::RequiresAction, PaymentStatus::Failed)
                | (PaymentStatus::RequiresAction, PaymentStatus::Cancelled)
                | (PaymentStatus::Processing, PaymentStatus::Failed)
        );
        if !allowed {
            return Err(PayError::InvalidTransition {
                from: payment.status,
                to: next,
            });
        }
        payment.status = next;
        payment.updated_at_ms = now_ms;
        Ok(payment.clone())
    }
}

#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum PayError {
    #[error("payment amount must be positive, got {0}")]
    InvalidAmount(i64),
    #[error("payment or idempotency identifiers must not be empty")]
    MissingStableId,
    #[error("platform fee basis points must be <= 10000, got {0}")]
    InvalidFeeBps(u16),
    #[error("ledger entries require at least two lines")]
    NotEnoughLedgerLines,
    #[error("ledger lines must not have zero amount")]
    ZeroLedgerLine,
    #[error("ledger entry is unbalanced for {currency}: {amount}")]
    UnbalancedLedger { currency: String, amount: i128 },
    #[error("payment not found: {0}")]
    PaymentNotFound(String),
    #[error("invalid payment transition from {from:?} to {to:?}")]
    InvalidTransition {
        from: PaymentStatus,
        to: PaymentStatus,
    },
    #[error("provider reference conflicts with an already successful payment")]
    ProviderReferenceConflict,
    #[error("refund is not allowed while payment is {0:?}")]
    RefundNotAllowed(PaymentStatus),
    #[error("refund {requested} exceeds remaining refundable amount {remaining}")]
    RefundExceedsPayment { requested: i64, remaining: i64 },
    #[error("settlement release is not allowed while payment is {0:?}")]
    SettlementNotAllowed(PaymentStatus),
    #[error("payment has no developer revenue left to settle")]
    NothingToSettle,
    #[error("duplicate mutation idempotency key: {0}")]
    DuplicateMutation(String),
    #[error("corrupt payment idempotency index: {0}")]
    CorruptIdempotencyIndex(String),
}

#[cfg(test)]
mod tests {
    use super::*;

    fn request(key: &str) -> CreatePaymentIntent {
        CreatePaymentIntent {
            idempotency_key: key.into(),
            user_id: "user-1".into(),
            mini_app_id: "miniapp-1".into(),
            developer_id: "dev-1".into(),
            sku: "pro.month".into(),
            product_kind: ProductKind::Subscription,
            rail: PaymentRail::Credits,
            amount: Money {
                currency: Currency::credits(),
                amount: 1_000,
            },
            platform_fee_bps: 1_500,
            created_at_ms: 10,
        }
    }

    #[test]
    fn creation_is_idempotent() {
        let mut engine = PayEngine::new();
        let first = engine.create_payment(request("same")).unwrap();
        let second = engine.create_payment(request("same")).unwrap();
        assert_eq!(first.payment_id, second.payment_id);
    }

    #[test]
    fn success_posts_balanced_pending_revenue() {
        let mut engine = PayEngine::new();
        let payment = engine.create_payment(request("one")).unwrap();
        let mutation = engine
            .succeed(
                &payment.payment_id,
                ProviderOutcome {
                    provider_reference: "provider-1".into(),
                    occurred_at_ms: 20,
                },
            )
            .unwrap();
        assert_eq!(mutation.payment.status, PaymentStatus::Succeeded);
        assert_eq!(mutation.payment.platform_fee(), 150);
        assert_eq!(mutation.payment.developer_net(), 850);
        mutation.ledger_entry.unwrap().validate().unwrap();
    }

    #[test]
    fn provider_success_replay_does_not_double_post() {
        let mut engine = PayEngine::new();
        let payment = engine.create_payment(request("one")).unwrap();
        let outcome = ProviderOutcome {
            provider_reference: "provider-1".into(),
            occurred_at_ms: 20,
        };
        assert!(engine.succeed(&payment.payment_id, outcome.clone()).unwrap().ledger_entry.is_some());
        assert!(engine.succeed(&payment.payment_id, outcome).unwrap().ledger_entry.is_none());
    }

    #[test]
    fn refund_cannot_exceed_remaining_amount() {
        let mut engine = PayEngine::new();
        let payment = engine.create_payment(request("one")).unwrap();
        engine
            .succeed(
                &payment.payment_id,
                ProviderOutcome {
                    provider_reference: "provider-1".into(),
                    occurred_at_ms: 20,
                },
            )
            .unwrap();
        let error = engine
            .refund(RefundRequest {
                idempotency_key: "refund-1".into(),
                payment_id: payment.payment_id,
                amount: 1_001,
                occurred_at_ms: 30,
            })
            .unwrap_err();
        assert_eq!(
            error,
            PayError::RefundExceedsPayment {
                requested: 1_001,
                remaining: 1_000,
            }
        );
    }

    #[test]
    fn settlement_moves_pending_to_available() {
        let mut engine = PayEngine::new();
        let payment = engine.create_payment(request("one")).unwrap();
        engine
            .succeed(
                &payment.payment_id,
                ProviderOutcome {
                    provider_reference: "provider-1".into(),
                    occurred_at_ms: 20,
                },
            )
            .unwrap();
        let entry = engine
            .release_settlement(SettlementRelease {
                idempotency_key: "release-1".into(),
                payment_id: payment.payment_id,
                occurred_at_ms: 100,
            })
            .unwrap();
        entry.validate().unwrap();
        assert_eq!(entry.lines[0].amount, -850);
        assert_eq!(entry.lines[1].amount, 850);
    }
}
