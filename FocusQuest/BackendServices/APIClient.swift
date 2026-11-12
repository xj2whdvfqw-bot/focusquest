import Foundation
import CryptoKit
import Security

enum APIClientError: Error { case invalidURL, insecureTransport, badStatus(Int), retryLimit }

actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let pinningDelegate: CertificatePinningDelegate?
    private let keychain: (any KeychainServiceProtocol)?
    private let maximumAttempts = 3

    init(baseURL: URL, pinnedCertificateSHA256: Set<String> = [], keychain: (any KeychainServiceProtocol)? = nil, session: URLSession? = nil) {
        self.baseURL = baseURL
        self.keychain = keychain
        if let session {
            self.session = session
            self.pinningDelegate = nil
        } else {
            let delegate = CertificatePinningDelegate(pins: pinnedCertificateSHA256)
            self.pinningDelegate = delegate
            self.session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        }
    }

    func get<Response: Decodable & Sendable>(_ path: String, as type: Response.Type) async throws -> Response {
        try await send(path, method: "GET", body: Optional<Data>.none, as: type)
    }

    func post<Request: Encodable & Sendable, Response: Decodable & Sendable>(_ path: String, body: Request, as type: Response.Type) async throws -> Response {
        let payload = try JSONEncoder.focusQuest.encode(body)
        return try await send(path, method: "POST", body: payload, as: type)
    }

    func delete(_ path: String) async throws {
        let _: EmptyResponse = try await send(path, method: "DELETE", body: Optional<Data>.none, as: EmptyResponse.self)
    }

    private func send<Response: Decodable & Sendable>(_ path: String, method: String, body: Data?, as type: Response.Type) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else { throw APIClientError.invalidURL }
        guard url.scheme == "https" || url.host == "localhost" else { throw APIClientError.insecureTransport }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let keychain, let tokenData = try? await keychain.load(for: "auth-token"), let token = String(data: tokenData, encoding: .utf8) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        for attempt in 0..<maximumAttempts {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw APIClientError.badStatus(-1) }
                if (200..<300).contains(http.statusCode) {
                    if Response.self == EmptyResponse.self { return try JSONDecoder.focusQuest.decode(Response.self, from: Data("{}".utf8)) }
                    return try JSONDecoder.focusQuest.decode(Response.self, from: data)
                }
                if http.statusCode < 500 || attempt == maximumAttempts - 1 { throw APIClientError.badStatus(http.statusCode) }
            } catch let error as APIClientError {
                throw error
            } catch {
                if attempt == maximumAttempts - 1 { throw error }
            }
            try await Task.sleep(for: .milliseconds(250 * (1 << attempt)))
        }
        throw APIClientError.retryLimit
    }
}

private struct EmptyResponse: Decodable, Sendable { }

private final class CertificatePinningDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let pins: Set<String>
    init(pins: Set<String>) { self.pins = pins }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        guard !pins.isEmpty else { completionHandler(.performDefaultHandling, nil); return }
        guard SecTrustEvaluateWithError(trust, nil), let certificate = SecTrustGetCertificateAtIndex(trust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let digest = SHA256.hash(data: SecCertificateCopyData(certificate) as Data).map { String(format: "%02x", $0) }.joined()
        if pins.contains(digest) { completionHandler(.useCredential, URLCredential(trust: trust)) }
        else { completionHandler(.cancelAuthenticationChallenge, nil) }
    }
}

extension JSONEncoder {
    static var focusQuest: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var focusQuest: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}