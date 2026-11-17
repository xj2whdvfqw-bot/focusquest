import AVFoundation
import Foundation

/// Kratke 8-bit efekty mimo bitvu (Arena): klepnuti, zasah, vitezna znelka.
/// Tony se generuji v appce stejne jako v prototypu (design/focusquest.html, objekt Sfx).
@MainActor
final class EffectSounds {
    static let shared = EffectSounds()

    enum Effect: CaseIterable {
        /// Ctverec 520 Hz, 0,06 s.
        case click
        /// Pila 220 Hz klesajici k 50 Hz, 0,55 s.
        case hit
        /// Ctverce C5 E5 G5 C6 po 0,09 s.
        case jingle
    }

    private var cache: [Effect: Data] = [:]
    /// Vic prehravacu naraz, aby se rychle klepnuti navzajem neusekla.
    private var players: [AVAudioPlayer] = []

    private init() {}

    func play(_ effect: Effect, enabled: Bool) {
        guard enabled else { return }
        let data = cache[effect] ?? Self.render(effect)
        cache[effect] = data
        players.removeAll { !$0.isPlaying }
        guard players.count < 6, let player = try? AVAudioPlayer(data: data) else { return }
        player.volume = 0.9
        player.play()
        players.append(player)
    }

    // MARK: - Synteza

    private static let sampleRate = 22_050

    private static func render(_ effect: Effect) -> Data {
        var buffer: [Double]
        switch effect {
        case .click:
            buffer = silence(0.12)
            add(&buffer, at: 0.005, duration: 0.06, gain: 0.12, attack: 0.002, wave: .square) { _ in 520 }
        case .hit:
            buffer = silence(0.62)
            add(&buffer, at: 0.01, duration: 0.55, gain: 0.3, attack: 0.004, wave: .saw) { t in
                // Exponencialni pad 220 -> 50 Hz za 0,5 s, pak drzi.
                220 * pow(50.0 / 220.0, min(1, t / 0.5))
            }
        case .jingle:
            buffer = silence(0.02 + 3 * 0.09 + 0.36)
            for (index, midi) in [72, 76, 79, 84].enumerated() {
                let frequency = 440 * pow(2, Double(midi - 69) / 12)
                add(&buffer, at: 0.02 + Double(index) * 0.09, duration: 0.3, gain: 0.14, attack: 0.005, wave: .square) { _ in frequency }
            }
        }
        let samples = buffer.map { Int16(max(-1, min(1, $0)) * Double(Int16.max)) }
        return wav(samples: samples)
    }

    private enum Wave { case square, saw }

    private static func silence(_ seconds: Double) -> [Double] {
        Array(repeating: 0, count: Int(Double(sampleRate) * seconds))
    }

    /// Prida ton s nabehem `attack` a exponencialnim dozvukem (jako gain ramp v Web Audio).
    private static func add(_ buffer: inout [Double], at start: Double, duration: Double, gain: Double, attack: Double, wave: Wave, frequency: (Double) -> Double) {
        let rate = Double(sampleRate)
        let first = Int(start * rate)
        let count = Int(duration * rate)
        var phase = 0.0
        for index in 0..<count {
            let sample = first + index
            guard sample < buffer.count else { break }
            let t = Double(index) / rate
            phase += frequency(t) / rate
            phase -= phase.rounded(.down)
            let raw: Double = switch wave {
            case .square: phase < 0.5 ? 1 : -1
            case .saw: phase * 2 - 1
            }
            // Linearne 0 -> gain za `attack`, pak exponencialne ke 0,0001 na konci tonu.
            let envelope = t < attack ? t / attack : pow(0.0001 / gain, (t - attack) / max(0.001, duration - attack))
            buffer[sample] += raw * gain * envelope
        }
    }

    private static func wav(samples: [Int16]) -> Data {
        let bytes = samples.withUnsafeBytes { Data($0) }
        var data = Data("RIFF".utf8)
        data.appendLittleEndian(UInt32(36 + bytes.count))
        data.append(Data("WAVEfmt ".utf8))
        data.appendLittleEndian(UInt32(16)); data.appendLittleEndian(UInt16(1)); data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt32(sampleRate)); data.appendLittleEndian(UInt32(sampleRate * 2))
        data.appendLittleEndian(UInt16(2)); data.appendLittleEndian(UInt16(16))
        data.append(Data("data".utf8)); data.appendLittleEndian(UInt32(bytes.count)); data.append(bytes)
        return data
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
