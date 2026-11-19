import Foundation

protocol FocusValidationServiceProtocol: Sendable {
    func startSession(bossID: String, mode: SessionMode, targetMinutes: Int) async throws -> StartSessionResponse
    func sendHeartbeat(sessionID: String, monotonicElapsedSeconds: TimeInterval, motionIntegrityToken: String, attestationAssertion: Data?, clientNonce: String, requestSignature: String?) async throws -> HeartbeatResponse
    func reportViolation(sessionID: String, reason: String, monotonicElapsedSeconds: TimeInterval) async throws
    func completeSession(sessionID: String) async throws -> CompleteSessionResponse
}

struct RemoteFocusValidationService: FocusValidationServiceProtocol {
    let api: APIClient
    let attestation: any AppAttestServiceProtocol
    let signer: any CryptoSignerProtocol

    func startSession(bossID: String, mode: SessionMode, targetMinutes: Int) async throws -> StartSessionResponse {
        let request = StartSessionRequest(bossID: bossID, mode: mode, targetMinutes: Boss.clampedMinutes(targetMinutes), clientNonce: signer.makeNonce(byteCount: 24), clientUptime: ProcessInfo.processInfo.systemUptime)
        let response = try await api.post("v1/sessions/start", body: request, as: StartSessionResponse.self)
        if await attestation.isSupported(), let keyID = try await attestation.prepareKey(), let assertion = try await attestation.attest(keyID: keyID, challenge: Data(response.sessionNonce.utf8)) {
            let registration = AttestationRegistrationRequest(sessionID: response.sessionID, keyID: keyID, attestation: assertion)
            let _: EmptyAcknowledgement = try await api.post("v1/attestation", body: registration, as: EmptyAcknowledgement.self)
        }
        return response
    }

    func sendHeartbeat(sessionID: String, monotonicElapsedSeconds: TimeInterval, motionIntegrityToken: String, attestationAssertion: Data?, clientNonce: String, requestSignature: String?) async throws -> HeartbeatResponse {
        let request = HeartbeatRequest(sessionID: sessionID, monotonicElapsedSeconds: monotonicElapsedSeconds, motionIntegrityToken: motionIntegrityToken, clientNonce: clientNonce)
        let keyID = try await attestation.prepareKey()
        let assertion: Data?
        if let keyID { assertion = try await attestation.assertion(keyID: keyID, payload: JSONEncoder.focusQuest.encode(request)) ?? attestationAssertion }
        else { assertion = attestationAssertion }
        let signed = SignedRequest(payload: try JSONEncoder.focusQuest.encode(request), nonce: request.clientNonce, hmacSHA256: nil, appAttestAssertion: assertion)
        _ = requestSignature
        return try await api.post("v1/sessions/heartbeat", body: signed, as: HeartbeatResponse.self)
    }

    /// Boss utekl (ustup, zvednuty telefon, dosla pauza): bitva uz nic neprinese.
    /// Jinak se nic nebere: XP, serie ani mince z drivejsich bitev zustavaji.
    func reportViolation(sessionID: String, reason: String, monotonicElapsedSeconds: TimeInterval) async throws {
        let request = ViolationRequest(sessionID: sessionID, reason: reason, monotonicElapsedSeconds: monotonicElapsedSeconds)
        let _: EmptyAcknowledgement = try await api.post("v1/sessions/violation", body: request, as: EmptyAcknowledgement.self)
    }

    func completeSession(sessionID: String) async throws -> CompleteSessionResponse {
        try await api.post("v1/sessions/complete", body: SessionIDRequest(sessionID: sessionID), as: CompleteSessionResponse.self)
    }
}

actor SimulatedSecureBackendService: FocusValidationServiceProtocol {
    private struct ActiveSession {
        let id: String
        var boss: Boss
        let startedAt: TimeInterval
        var lastAuthorizedAt: TimeInterval
        var verifiedSeconds = 0
        var violated = false
    }

    private let signingKey: Data
    private let signer = CryptoSigner()
    private var sessions: [String: ActiveSession] = [:]
    private let bosses = Dictionary(uniqueKeysWithValues: Boss.allBosses.map { ($0.id, $0) })
    private var stats = PlayerStats.initial

    init(signingKey: Data? = nil) { self.signingKey = signingKey ?? Data(CryptoSigner().makeNonce(byteCount: 48).utf8) }

    func startSession(bossID: String, mode: SessionMode, targetMinutes: Int) async throws -> StartSessionResponse {
        guard let template = bosses[bossID] else { throw SimulationError.unknownBoss }
        let now = MonotonicClock.now
        let id = UUID().uuidString
        // Kazda bitva ma vlastniho bosse s HP, ktere si hrac zvolil (1 HP = 1 minuta).
        sessions[id] = ActiveSession(id: id, boss: template.withHP(minutes: targetMinutes), startedAt: now, lastAuthorizedAt: now)
        _ = mode
        return StartSessionResponse(sessionID: id, sessionNonce: signer.makeNonce(), serverTimestamp: Date())
    }

    func sendHeartbeat(sessionID: String, monotonicElapsedSeconds: TimeInterval, motionIntegrityToken: String, attestationAssertion: Data?, clientNonce: String, requestSignature: String?) async throws -> HeartbeatResponse {
        guard var session = sessions[sessionID], !session.violated else { throw SimulationError.invalidSession }
        guard monotonicElapsedSeconds >= 0, monotonicElapsedSeconds.isFinite else { throw SimulationError.invalidClock }
        let heartbeat = HeartbeatRequest(sessionID: sessionID, monotonicElapsedSeconds: monotonicElapsedSeconds, motionIntegrityToken: motionIntegrityToken, clientNonce: clientNonce)
        let payload = try JSONEncoder.focusQuest.encode(heartbeat)
        guard let requestSignature, signer.verify(requestSignature, payload: payload, key: signingKey, nonce: clientNonce) else { throw SimulationError.invalidSignature }
        let elapsed = MonotonicClock.now - session.startedAt
        // Klient nesmi hlasit vic casu, nez opravdu ubehlo. Mene hlasit smi: pauzy pri zvednuti telefonu se do soustredeni nepocitaji.
        guard monotonicElapsedSeconds <= elapsed + 2 else { throw SimulationError.invalidClock }
        let available = Int((monotonicElapsedSeconds - (session.lastAuthorizedAt - session.startedAt)) / 60)
        let damage = max(0, available)
        if damage > 0 {
            session.lastAuthorizedAt += TimeInterval(damage * 60)
            session.verifiedSeconds += damage * 60
            session.boss.applyDamage(damage)
        }
        sessions[sessionID] = session
        _ = motionIntegrityToken
        _ = attestationAssertion
        return HeartbeatResponse(authorizedDamage: damage, authoritativeBossHP: session.boss.currentHP, serverTimestamp: Date())
    }

    /// Boss utekl (ustup, zvednuty telefon, dosla pauza): bitva uz nic neprinese.
    /// Jinak se nic nebere: XP, serie ani mince z drivejsich bitev zustavaji.
    func reportViolation(sessionID: String, reason: String, monotonicElapsedSeconds: TimeInterval) async throws {
        guard var session = sessions[sessionID] else { throw SimulationError.invalidSession }
        session.violated = true
        sessions[sessionID] = session
        _ = reason
        _ = monotonicElapsedSeconds
    }

    func completeSession(sessionID: String) async throws -> CompleteSessionResponse {
        // Bitva, ze ktere boss utekl, se uz nepripise (zadne XP ani mince).
        guard let session = sessions.removeValue(forKey: sessionID), !session.violated else { throw SimulationError.invalidSession }
        let boss = session.boss
        stats.battles += 1
        if boss.isDefeated { stats.wins += 1 }
        stats.totalHPDealt += session.verifiedSeconds / 60
        let xpEarned = RewardRules.xp(verifiedMinutes: session.verifiedSeconds / 60)
        stats.totalXP += xpEarned
        stats.level = max(1, stats.totalXP / 1000 + 1)
        return CompleteSessionResponse(stats: stats, boss: boss, xpEarned: xpEarned)
    }

    enum SimulationError: Error { case unknownBoss, invalidSession, invalidClock, invalidSignature }
}

struct SessionIDRequest: Codable, Sendable { let sessionID: String }
struct EmptyAcknowledgement: Codable, Sendable { }
private struct AttestationRegistrationRequest: Codable, Sendable { let sessionID: String; let keyID: String; let attestation: Data }