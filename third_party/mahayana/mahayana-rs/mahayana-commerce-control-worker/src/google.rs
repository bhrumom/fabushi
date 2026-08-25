use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct GoogleCatalogProduct {
    pub package_name: String,
    pub product_id: String,
    pub display_name: String,
    pub description: String,
    pub product_kind: String,
    pub currency: String,
    pub amount_minor: i64,
    pub region_code: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct GoogleSyncRequest {
    pub method: String,
    pub url: String,
    pub body: serde_json::Value,
}

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum GoogleCatalogError {
    #[error("invalid Google Play product")]
    InvalidProduct,
    #[error("unsupported currency exponent")]
    UnsupportedCurrency,
}

pub fn build_google_sync_request(product: &GoogleCatalogProduct) -> Result<GoogleSyncRequest, GoogleCatalogError> {
    if product.package_name.trim().is_empty()
        || product.product_id.trim().is_empty()
        || product.display_name.trim().is_empty()
        || product.amount_minor <= 0
        || product.region_code.len() != 2
        || product.currency.len() != 3
    {
        return Err(GoogleCatalogError::InvalidProduct);
    }
    if product.product_kind == "subscription" {
        return Ok(GoogleSyncRequest {
            method: "POST".into(),
            url: format!(
                "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{}/subscriptions?productId={}",
                product.package_name, product.product_id
            ),
            body: serde_json::json!({
                "packageName": product.package_name,
                "productId": product.product_id,
                "listings": [{
                    "languageCode": "en-US",
                    "title": product.display_name,
                    "benefits": [product.description],
                }],
                "basePlans": [{
                    "basePlanId": "monthly",
                    "autoRenewingBasePlanType": { "billingPeriodDuration": "P1M" },
                    "regionalConfigs": [{
                        "regionCode": product.region_code,
                        "price": money(&product.currency, product.amount_minor)?,
                    }]
                }]
            }),
        });
    }

    Ok(GoogleSyncRequest {
        method: "PATCH".into(),
        url: format!(
            "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{}/onetimeproducts/{}?updateMask=listings,purchaseOptions",
            product.package_name, product.product_id
        ),
        body: serde_json::json!({
            "packageName": product.package_name,
            "productId": product.product_id,
            "listings": [{
                "languageCode": "en-US",
                "title": product.display_name,
                "description": product.description,
            }],
            "purchaseOptions": [{
                "purchaseOptionId": "buy",
                "buyOption": {},
                "regionalPricingAndAvailabilityConfigs": [{
                    "regionCode": product.region_code,
                    "price": money(&product.currency, product.amount_minor)?,
                    "availability": "AVAILABLE"
                }]
            }]
        }),
    })
}

fn money(currency: &str, amount_minor: i64) -> Result<serde_json::Value, GoogleCatalogError> {
    let exponent = match currency {
        "BHD" | "IQD" | "JOD" | "KWD" | "LYD" | "OMR" | "TND" => 3_u32,
        "BIF" | "CLP" | "DJF" | "GNF" | "ISK" | "JPY" | "KMF" | "KRW" | "PYG" | "RWF" | "UGX" | "UYI" | "VND" | "VUV" | "XAF" | "XOF" | "XPF" => 0_u32,
        _ => 2_u32,
    };
    let divisor = 10_i64.pow(exponent);
    let units = amount_minor / divisor;
    let remainder = amount_minor % divisor;
    let nanos = if exponent == 0 { 0 } else { (remainder * 1_000_000_000_i64 / divisor) as i32 };
    Ok(serde_json::json!({
        "currencyCode": currency,
        "units": units.to_string(),
        "nanos": nanos,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn builds_current_one_time_product_patch_without_manual_play_console_sku_work() {
        let req = build_google_sync_request(&GoogleCatalogProduct {
            package_name: "com.ombhrum.fabushi".into(),
            product_id: "global_dharma.prayer_wheel_lifetime".into(),
            display_name: "Prayer Wheel Lifetime".into(),
            description: "Permanent access".into(),
            product_kind: "digital_durable".into(),
            currency: "CNY".into(),
            amount_minor: 108000,
            region_code: "CN".into(),
        }).unwrap();
        assert_eq!(req.method, "PATCH");
        assert_eq!(req.body["purchaseOptions"][0]["regionalPricingAndAvailabilityConfigs"][0]["price"]["units"], "1080");
    }

    #[test]
    fn builds_subscription_catalog_payload() {
        let req = build_google_sync_request(&GoogleCatalogProduct {
            package_name: "com.ombhrum.fabushi".into(),
            product_id: "global_dharma.prayer_wheel_monthly".into(),
            display_name: "Prayer Wheel Monthly".into(),
            description: "30 day access".into(),
            product_kind: "subscription".into(),
            currency: "CNY".into(),
            amount_minor: 3000,
            region_code: "CN".into(),
        }).unwrap();
        assert_eq!(req.method, "POST");
        assert_eq!(req.body["basePlans"][0]["autoRenewingBasePlanType"]["billingPeriodDuration"], "P1M");
    }
}
