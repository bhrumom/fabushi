import CryptoKit
import Foundation
import Security

/// Persistent iOS node identity used in addition to Fabushi account OAuth.
///
/// Physical devices prefer a non-exportable Secure Enclave P-256 key. The
/// Simulator and devices without Secure Enclave support fall back to a P-256
/// SecKey stored as this-device-only Keychain material. Neither representation
/// is included in device discovery or MCP results.
struct FabushiMeshNodeIdentity {
    static let protocolVersion = "fabushi.device-mesh.v1"

    enum IdentityError: LocalizedError {
        case keyCreation(String)
        case publicKeyUnavailable
        case invalidPublicKey
        case signing(String)
        case invalidCanonicalJSON

        var errorDescription: String? {
            switch self {
            case .keyCreation(let detail): "device_mesh_key_creation_failed: \(detail)"
            case .publicKeyUnavailable: "device_mesh_public_key_unavailable"
            case .invalidPublicKey: "device_mesh_public_key_invalid"
            case .signing(let detail): "device_mesh_signature_failed: \(detail)"
            case .invalidCanonicalJSON: "device_mesh_canonical_json_invalid"
            }
        }
    }

    let privateKey: SecKey
    let publicJWK: [String: String]
    let fingerprint: String

    static func loadOrCreate() throws -> FabushiMeshNodeIdentity {
        let privateKey = try existingPrivateKey() ?? createPrivateKey()
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw IdentityError.publicKeyUnavailable
        }
        var copyError: Unmanaged<CFError>?
        guard let representation = SecKeyCopyExternalRepresentation(publicKey, &copyError) as Data? else {
            throw IdentityError.keyCreation(copyError?.takeRetainedValue().localizedDescription ?? "public export failed")
        }
        guard representation.count == 65, representation.first == 0x04 else {
            throw IdentityError.invalidPublicKey
        }
        let x = representation.subdata(in: 1..<33).base64URLString
        let y = representation.subdata(in: 33..<65).base64URLString
        let jwk = ["kty": "EC", "crv": "P-256", "x": x, "y": y]
        let fingerprint = SHA256.hash(data: Data(canonicalJWK(jwk).utf8)).base64URLString.prefix(32)
        return FabushiMeshNodeIdentity(
            privateKey: privateKey,
            publicJWK: jwk,
            fingerprint: String(fingerprint)
        )
    }

    func sign(_ message: Data) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            message as CFData,
            &error
        ) as Data? else {
            throw IdentityError.signing(error?.takeRetainedValue().localizedDescription ?? "unknown")
        }
        return signature
    }

    func registrationPayload(
        deviceId: String,
        generation: String,
        toolSchemaVersion: String,
        nonce: String
    ) -> Data {
        Data([
            Self.protocolVersion,
            deviceId,
            generation,
            toolSchemaVersion,
            nonce,
            Self.canonicalJWK(publicJWK),
        ].joined(separator: "\n").utf8)
    }

    static func canonicalJSONData(_ value: Any) throws -> Data {
        guard JSONSerialization.isValidJSONObject(value) else {
            throw IdentityError.invalidCanonicalJSON
        }
        return try JSONSerialization.data(
            withJSONObject: value,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }

    static func schemaVersion(_ value: Any) throws -> String {
        let data = try canonicalJSONData(value)
        return SHA256.hash(data: data).hexString
    }

    static func canonicalJWK(_ jwk: [String: String]) -> String {
        "\(jwk["kty"] ?? ""):\(jwk["crv"] ?? ""):\(jwk["x"] ?? ""):\(jwk["y"] ?? "")"
    }

    private static let keyTag = Data("com.ombhrum.fabushi.device-mesh.v1".utf8)

    private static func existingPrivateKey() throws -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let item else {
            throw IdentityError.keyCreation(SecCopyErrorMessageString(status, nil) as String? ?? "Keychain status \(status)")
        }
        return (item as! SecKey)
    }

    private static func createPrivateKey() throws -> SecKey {
        #if targetEnvironment(simulator)
        return try createPrivateKey(useSecureEnclave: false)
        #else
        do {
            return try createPrivateKey(useSecureEnclave: true)
        } catch {
            // Older devices and managed environments may not expose Secure
            // Enclave signing. The fallback remains Keychain protected and is
            // bound to this device backup domain.
            return try createPrivateKey(useSecureEnclave: false)
        }
        #endif
    }

    private static func createPrivateKey(useSecureEnclave: Bool) throws -> SecKey {
        var privateAttributes: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        // Explicitly disable synchronizable storage. A mesh node identity must
        // never migrate through iCloud Keychain to another physical device.
        privateAttributes[kSecAttrSynchronizable as String] = false

        var attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: privateAttributes,
        ]
        if useSecureEnclave {
            attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        }

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            // Another process/scene can race first creation. Prefer the winner.
            if let existing = try existingPrivateKey() { return existing }
            throw IdentityError.keyCreation(error?.takeRetainedValue().localizedDescription ?? "unknown")
        }
        return key
    }
}

private extension Data {
    var base64URLString: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension SHA256.Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

    var base64URLString: String {
        Data(self).base64URLString
    }
}
