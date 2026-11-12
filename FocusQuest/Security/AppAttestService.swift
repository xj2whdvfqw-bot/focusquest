import DeviceCheck
import Foundation
import CryptoKit

protocol AppAttestServiceProtocol: Sendable {
    func isSupported() async -> Bool
    func generateKey() async throws -> String?
    func prepareKey() async throws -> String?
    func attest(keyID: String, challenge: Data) async throws -> Data?
    func assertion(keyID: String, payload: Data) async throws -> Data?
}

actor AppAttestService: AppAttestServiceProtocol {
    private let keychain: any KeychainServiceProtocol

    init(keychain: any KeychainServiceProtocol) { self.keychain = keychain }

    func isSupported() async -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        DCAppAttestService.shared.isSupported
        #endif
    }

    func generateKey() async throws -> String? {
        #if targetEnvironment(simulator)
        return nil
        #else
        guard DCAppAttestService.shared.isSupported else { return nil }
        return try await DCAppAttestService.shared.generateKey()
        #endif
    }

    func prepareKey() async throws -> String? {
        #if targetEnvironment(simulator)
        return nil
        #else
        if let stored = try await keychain.load(for: "app-attest-key-id"), let keyID = String(data: stored, encoding: .utf8) { return keyID }
        guard let keyID = try await generateKey() else { return nil }
        try await keychain.save(Data(keyID.utf8), for: "app-attest-key-id")
        return keyID
        #endif
    }

    func attest(keyID: String, challenge: Data) async throws -> Data? {
        #if targetEnvironment(simulator)
        return nil
        #else
        guard DCAppAttestService.shared.isSupported else { return nil }
        return try await DCAppAttestService.shared.attestKey(keyID, clientDataHash: Data(SHA256.hash(data: challenge)))
        #endif
    }

    func assertion(keyID: String, payload: Data) async throws -> Data? {
        #if targetEnvironment(simulator)
        return nil
        #else
        guard DCAppAttestService.shared.isSupported else { return nil }
        return try await DCAppAttestService.shared.generateAssertion(keyID, clientDataHash: Data(SHA256.hash(data: payload)))
        #endif
    }
}