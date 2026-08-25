use crate::domain::{is_currency, is_identifier};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct AppleCatalogProduct {
    pub payment_id: String,
    pub mini_app_name: String,
    pub mini_app_sku: String,
    pub partner_name: String,
    pub partner_id: String,
    pub display_name: String,
    pub description: String,
    pub product_kind: String,
    pub currency: String,
    pub amount_minor: i64,
    pub tax_code: String,
    pub generic_product_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct AppleRequestInput {
    pub storefront: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct AppleAdvancedCommerceEnvelope {
    pub generic_product_id: String,
    pub request_reference_id: String,
    pub request_json: serde_json::Value,
}

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum AppleRequestError {
    #[error("invalid Apple storefront")]
    InvalidStorefront,
    #[error("invalid Apple catalog product")]
    InvalidProduct,
    #[error("Apple price conversion overflow")]
    PriceOverflow,
}

pub fn mini_app_partner_sku(product: &AppleCatalogProduct) -> Result<String, AppleRequestError> {
    if !is_identifier(&product.mini_app_sku)
        || product.partner_name.trim().is_empty()
        || product.partner_name.contains('|')
        || !is_identifier(&product.partner_id)
    {
        return Err(AppleRequestError::InvalidProduct);
    }
    let sku = format!(
        "{}|{}|{}",
        product.mini_app_sku,
        product.partner_name.trim(),
        product.partner_id
    );
    if sku.len() > 128 {
        return Err(AppleRequestError::InvalidProduct);
    }
    Ok(sku)
}

pub fn minor_units_to_milliunits(currency: &str, amount: i64) -> Result<i64, AppleRequestError> {
    if !is_currency(currency) || amount <= 0 {
        return Err(AppleRequestError::InvalidProduct);
    }
    let exponent = match currency {
        "BHD" | "IQD" | "JOD" | "KWD" | "LYD" | "OMR" | "TND" => 3,
        "BIF" | "CLP" | "DJF" | "GNF" | "ISK" | "JPY" | "KMF" | "KRW" | "PYG" | "RWF" | "UGX"
        | "UYI" | "VND" | "VUV" | "XAF" | "XOF" | "XPF" => 0,
        _ => 2,
    };
    let power = 3_u32.saturating_sub(exponent);
    amount
        .checked_mul(10_i64.pow(power))
        .ok_or(AppleRequestError::PriceOverflow)
}

pub fn build_advanced_commerce_request(
    product: &AppleCatalogProduct,
    input: &AppleRequestInput,
    request_reference_id: &str,
) -> Result<AppleAdvancedCommerceEnvelope, AppleRequestError> {
    if input.storefront.len() != 3 || !input.storefront.bytes().all(|b| b.is_ascii_uppercase()) {
        return Err(AppleRequestError::InvalidStorefront);
    }
    if !is_identifier(&product.payment_id)
        || product.display_name.trim().is_empty()
        || product.display_name.chars().count() > 30
        || product.description.chars().count() > 45
        || product.tax_code.trim().is_empty()
        || product.generic_product_id.trim().is_empty()
    {
        return Err(AppleRequestError::InvalidProduct);
    }
    let sku = mini_app_partner_sku(product)?;
    let price = minor_units_to_milliunits(&product.currency, product.amount_minor)?;
    let request_info = serde_json::json!({
        "requestReferenceId": request_reference_id,
        "appAccountToken": product.payment_id,
    });
    let request_json = if product.product_kind == "subscription" {
        serde_json::json!({
            "operation": "CREATE_SUBSCRIPTION",
            "version": "1",
            "requestInfo": request_info,
            "currency": product.currency,
            "taxCode": product.tax_code,
            "descriptors": {
                "displayName": product.mini_app_name,
                "description": product.description,
            },
            "period": "P1M",
            "storefront": input.storefront,
            "items": [{
                "SKU": sku,
                "displayName": product.display_name,
                "description": product.description,
                "price": price,
            }]
        })
    } else {
        serde_json::json!({
            "operation": "CREATE_ONE_TIME_CHARGE",
            "version": "1",
            "requestInfo": request_info,
            "currency": product.currency,
            "taxCode": product.tax_code,
            "storefront": input.storefront,
            "item": {
                "SKU": sku,
                "displayName": product.display_name,
                "description": product.description,
                "price": price,
            }
        })
    };
    Ok(AppleAdvancedCommerceEnvelope {
        generic_product_id: product.generic_product_id.clone(),
        request_reference_id: request_reference_id.to_string(),
        request_json,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn product(kind: &str) -> AppleCatalogProduct {
        AppleCatalogProduct {
            payment_id: "0f6bdf74-06ad-4b90-823f-3f66ce9e88a1".into(),
            mini_app_name: "Global Dharma".into(),
            mini_app_sku: "prayer-wheel.monthly".into(),
            partner_name: "Fabushi".into(),
            partner_id: "official.fabushi".into(),
            display_name: "Prayer Wheel Monthly".into(),
            description: "30 day access".into(),
            product_kind: kind.into(),
            currency: "CNY".into(),
            amount_minor: 3000,
            tax_code: "C003-00-1".into(),
            generic_product_id: "com.ombhrum.fabushi.miniapp.subscription".into(),
        }
    }

    #[test]
    fn builds_apple_subscription_from_server_authoritative_fiat_price() {
        let value = build_advanced_commerce_request(
            &product("subscription"),
            &AppleRequestInput {
                storefront: "CHN".into(),
            },
            "62cc8233-3030-4014-8e9e-e5f957fe11df",
        )
        .unwrap();
        assert_eq!(value.request_json["operation"], "CREATE_SUBSCRIPTION");
        assert_eq!(value.request_json["currency"], "CNY");
        assert_eq!(value.request_json["items"][0]["price"], 30000);
        assert_eq!(
            value.request_json["items"][0]["SKU"],
            "prayer-wheel.monthly|Fabushi|official.fabushi"
        );
    }

    #[test]
    fn converts_zero_decimal_currency_to_milliunits() {
        assert_eq!(minor_units_to_milliunits("JPY", 700).unwrap(), 700000);
    }
}
