import CryptoKit
import Foundation
import Security

protocol CryptoSignerProtocol: Sendable {
    func sign(_ payload: Data, key: Data, nonce: String) -> String
    func verify(_ signature: String, payload: Data, key: Data, nonce: String) -> Bool
    func makeNonce(byteCount: Int) -> String
}

struct CryptoSigner: CryptoSignerProtocol {
    func sign(_ payload: Data, key: Data, nonce: String) -> String {
        let key = SymmetricKey(data: key)
        let message = Data(nonce.utf8) + payload
        let signature = HMAC<SHA256>.authenticationCode(for: message, using: key)
        return Data(signature).map { String(format: "%02x", $0) }.joined()
    }

    func verify(_ signature: String, payload: Data, key: Data, nonce: String) -> Bool {
        let expected = Array(sign(payload, key: key, nonce: nonce).utf8)
        let supplied = Array(signature.utf8)
        guard expected.count == supplied.count else { return false }
        return zip(expected, supplied).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }

    func makeNonce(byteCount: Int = 32) -> String {
        let count = max(16, min(byteCount, 64))
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else { return UUID().uuidString }
        return Data(bytes).base64EncodedString()
    }
}