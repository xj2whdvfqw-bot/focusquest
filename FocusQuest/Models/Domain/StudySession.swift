import Foundation

enum SessionMode: String, Codable, Sendable { case solo, raid }
enum StudySessionStatus: String, Codable, Sendable { case awaitingPlacement, focusing, warning, penalized, completed, abandoned }

struct StudySession: Identifiable, Codable, Sendable {
    let id: UUID
    let serverSessionID: String
    let bossID: String
    let mode: SessionMode
    let monotonicStartUptime: TimeInterval
    let wallClockStart: Date
    var comboMultiplier: Int
    var status: StudySessionStatus
    var verifiedSeconds: Int

    init(id: UUID = UUID(), serverSessionID: String, bossID: String, mode: SessionMode, monotonicStartUptime: TimeInterval = ProcessInfo.processInfo.systemUptime, wallClockStart: Date = Date(), comboMultiplier: Int = 1, status: StudySessionStatus = .awaitingPlacement, verifiedSeconds: Int = 0) {
        self.id = id
        self.serverSessionID = serverSessionID
        self.bossID = bossID
        self.mode = mode
        self.monotonicStartUptime = monotonicStartUptime
        self.wallClockStart = wallClockStart
        self.comboMultiplier = comboMultiplier
        self.status = status
        self.verifiedSeconds = verifiedSeconds
    }
}