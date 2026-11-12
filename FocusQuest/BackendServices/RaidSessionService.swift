import Foundation

struct RaidMember: Identifiable, Codable, Sendable {
    let id: String
    var displayName: String
    var isFocusing: Bool
}

protocol RaidSessionServiceProtocol: Sendable {
    func partyMembers() async -> [RaidMember]
    func events() async -> AsyncStream<PartyComboBrokenEvent>
    func broadcastComboBroken(memberName: String) async
}

actor RaidSessionService: RaidSessionServiceProtocol {
    private var members: [RaidMember] = []
    private var continuations: [UUID: AsyncStream<PartyComboBrokenEvent>.Continuation] = [:]

    func setMembers(_ members: [RaidMember]) { self.members = Array(members.prefix(4)) }
    func partyMembers() async -> [RaidMember] { members }

    func events() async -> AsyncStream<PartyComboBrokenEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in Task { await self?.removeContinuation(id) } }
        }
    }

    func broadcastComboBroken(memberName: String) async {
        let event = PartyComboBrokenEvent(eventID: UUID(), memberName: memberName, occurredAt: Date())
        for continuation in continuations.values { continuation.yield(event) }
    }

    private func removeContinuation(_ id: UUID) { continuations[id] = nil }
}