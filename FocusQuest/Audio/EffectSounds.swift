import AVFoundation
import Foundation

/// Kratke efekty: klepnuti, zasah, vitezstvi, utek bosse, mince, XP, level up a pipnuti alarmu.
/// Klepnuti (tap-click.mp3) a mince s XP (reward-chime.mp3) jsou nahravky z Pixabay (Pixabay Content License,
/// viz design/DECISIONS.md); ostatni 8-bit tony se generuji primo v appce (ctverec, pila, sinus s obalkou).
/// Co a kdy hraje, rozhoduje FQFeedback (podle prepinacu v Nastaveni).
@MainActor
final class EffectSounds {
    static let shared = EffectSounds()

    enum Effect: CaseIterable {
        /// Ctverec 520 Hz, 0,06 s (klepnuti na tlacitko).
        case click
        /// Pila 220 Hz klesajici k 50 Hz, 0,55 s (financi uder, nastvany boss).
        case hit
        /// Fanfara C5 E5 G5 a dlouhe C6 (vitezstvi).
        case victory
        /// Ctverec klesajici 600 -> 150 Hz, 0,45 s (boss utekl).
        case escape
        /// Dve kratka pipnuti B5 a E6 (mince).
        case coin
        /// Rychle arpeggio C5 E5 G5 C6 (XP).
        case xp
        /// Ctverce C5 E5 G5 C6 po 0,09 s (level up, serie v plamenech).
        case jingle
        /// Sinus 660 Hz, 0,14 s (pipnuti alarmu pri zvednuti telefonu).
        case beep

        /// Nahravka v bundlu misto syntezy (nil = generovany ton).
        var fileName: String? {
            switch self {
            case .click: "tap-click"
            case .coin, .xp: "reward-chime"
            default: nil
            }
        }

        /// O1/H2: vychozi zesileni efektu proti posuvniku "Effects volume". Nahravka odmeny
        /// (reward-chime.mp3, lolo_s-start) je vyrazne hlasitejsi nez ostatni efekty, proto hraje na 37 %
        /// (asi −8,6 dB). Ostatni efekty se nemeni.
        var gain: Float {
            switch self {
            case .coin, .xp: Self.rewardGain
            default: 1
            }
        }

        static let rewardGain: Float = 0.37
    }

    private var cache: [Effect: Data] = [:]
    /// Vic prehravacu naraz, aby se rychle klepnuti navzajem neusekla.
    private var players: [AVAudioPlayer] = []

    private init() {}

    /// Prehraje efekt hlasitosti 0...1. Mimo bitvu bezi zvuk pres kategorii .ambient:
    /// respektuje tichy rezim a neprerusi hudbu z jinych appek. Behem bitvy (kategorie .playback
    /// s mixWithOthers pro hudbu) se kategorie nemeni.
    func play(_ effect: Effect, volume: Float) {
        guard volume > 0 else { return }
        prepareAmbientSessionIfNeeded()
        let data = cache[effect] ?? Self.recording(effect) ?? Self.render(effect)
        cache[effect] = data
        players.removeAll { !$0.isPlaying }
        guard players.count < 6, let player = try? AVAudioPlayer(data: data) else { return }
        player.volume = max(0, min(1, volume * effect.gain))
        player.play()
        players.append(player)
    }

    private func prepareAmbientSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        guard session.category != .playback else { return }
        if session.category != .ambient {
            try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        }
        try? session.setActive(true)
    }

    /// Nahravka efektu z bundlu; kdyz chybi, pouzije se generovany ton.
    private static func recording(_ effect: Effect) -> Data? {
        guard let name = effect.fileName, let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return nil }
        return try? Data(contentsOf: url)
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
        case .victory:
            buffer = silence(0.02 + 3 * 0.11 + 0.7)
            for (index, midi) in [72, 76, 79, 84].enumerated() {
                let last = index == 3
                add(&buffer, at: 0.02 + Double(index) * 0.11, duration: last ? 0.65 : 0.22, gain: 0.13, attack: 0.005, wave: .square) { _ in note(midi) }
            }
        case .escape:
            buffer = silence(0.5)
            add(&buffer, at: 0.005, duration: 0.45, gain: 0.14, attack: 0.004, wave: .square) { t in 600 * pow(0.25, min(1, t / 0.4)) }
        case .coin:
            buffer = silence(0.32)
            add(&buffer, at: 0.005, duration: 0.08, gain: 0.12, attack: 0.002, wave: .square) { _ in note(83) }
            add(&buffer, at: 0.075, duration: 0.22, gain: 0.12, attack: 0.002, wave: .square) { _ in note(88) }
        case .xp:
            buffer = silence(0.02 + 3 * 0.05 + 0.2)
            for (index, midi) in [72, 76, 79, 84].enumerated() {
                add(&buffer, at: 0.02 + Double(index) * 0.05, duration: 0.14, gain: 0.1, attack: 0.003, wave: .square) { _ in note(midi) }
            }
        case .jingle:
            buffer = silence(0.02 + 3 * 0.09 + 0.36)
            for (index, midi) in [72, 76, 79, 84].enumerated() {
                add(&buffer, at: 0.02 + Double(index) * 0.09, duration: 0.3, gain: 0.14, attack: 0.005, wave: .square) { _ in note(midi) }
            }
        case .beep:
            buffer = silence(0.18)
            add(&buffer, at: 0.0, duration: 0.14, gain: 0.4, attack: 0.004, wave: .sine) { _ in 660 }
        }
        let samples = buffer.map { Int16(max(-1, min(1, $0)) * Double(Int16.max)) }
        return wav(samples: samples)
    }

    /// Frekvence noty podle MIDI cisla (69 = A4 = 440 Hz).
    private static func note(_ midi: Int) -> Double { 440 * pow(2, Double(midi - 69) / 12) }

    private enum Wave { case square, saw, sine }

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
            case .sine: sin(2 * .pi * phase)
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
