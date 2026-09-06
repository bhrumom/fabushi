import XCTest
@testable import Fabushi

final class GlobalDharmaCommerceTests: XCTestCase {
    func testCanonicalLifetimeOfferAcceptsOnlyServerCNY1080DurableContract() throws {
        let offer = try XCTUnwrap(GlobalDharmaCommerceModel.parseLifetimeOffer([
            "productId": "prod.global-dharma.local-prayer-wheel.lifetime",
            "sku": "local-prayer-wheel.lifetime",
            "productKind": "digital_durable",
            "currency": "CNY",
            "amount": 108_000,
            "activeRails": ["apple_in_app_purchase", "web_provider"],
        ]))

        XCTAssertTrue(offer.matchesCanonicalLifetime)
        XCTAssertTrue(offer.appleStoreAvailable)
    }

    func testLifetimeOfferFailsClosedOnClientTamperedPriceOrSku() throws {
        let wrongAmount = try XCTUnwrap(GlobalDharmaCommerceModel.parseLifetimeOffer([
            "productId": "prod.global-dharma.local-prayer-wheel.lifetime",
            "sku": "local-prayer-wheel.lifetime",
            "productKind": "digital_durable",
            "currency": "CNY",
            "amount": 107_999,
            "activeRails": ["apple_in_app_purchase"],
        ]))
        let wrongSku = try XCTUnwrap(GlobalDharmaCommerceModel.parseLifetimeOffer([
            "productId": "prod.global-dharma.local-prayer-wheel.lifetime",
            "sku": "local-prayer-wheel.monthly",
            "productKind": "digital_durable",
            "currency": "CNY",
            "amount": 108_000,
            "activeRails": ["apple_in_app_purchase"],
        ]))

        XCTAssertFalse(wrongAmount.matchesCanonicalLifetime)
        XCTAssertFalse(wrongSku.matchesCanonicalLifetime)
    }

    func testPendingAppleProviderKeepsStoreKitPurchaseDisabled() throws {
        let offer = try XCTUnwrap(GlobalDharmaCommerceModel.parseLifetimeOffer([
            "productId": "prod.global-dharma.local-prayer-wheel.lifetime",
            "sku": "local-prayer-wheel.lifetime",
            "productKind": "digital_durable",
            "currency": "CNY",
            "amount": 108_000,
            "activeRails": ["web_provider"],
        ]))

        XCTAssertTrue(offer.matchesCanonicalLifetime)
        XCTAssertFalse(offer.appleStoreAvailable)
    }

    func testAdvancedCommerceRequestDataUsesAppleSignatureInfoEnvelope() throws {
        let data = try FabushiPayStoreKit.advancedCommerceRequestData(compactJWS: "header.payload.signature")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let signatureInfo = try XCTUnwrap(object["signatureInfo"] as? [String: String])

        XCTAssertEqual(signatureInfo, ["token": "header.payload.signature"])
        XCTAssertEqual(object.count, 1)
    }

    func testAdvancedCommerceRequestDataRejectsEmptyJWS() {
        XCTAssertThrowsError(try FabushiPayStoreKit.advancedCommerceRequestData(compactJWS: ""))
    }
}
