import AVFoundation
import Foundation

@MainActor
protocol AudioAtmosphereServiceProtocol: AnyObject {
    func apply(preferences: AppPreferences)
    func beginFocus(preferences: AppPreferences)
    func enterWarning(preferences: AppPreferences, secondsRemaining: Int)
    func countdownTick(preferences: AppPreferences, secondsRemaining: Int)
    func recover(preferences: AppPreferences)
    func stop()
}

@MainActor
final class AudioAtmosphereService: AudioAtmosphereServiceProtocol {
    private var ambientPlayer: AVAudioPlayer?
    private var warningPlayer: AVAudioPlayer?
    private var preferences = AppPreferences()
    private var isWarning = false

    func apply(preferences: AppPreferences) {
        self.preferences = preferences
        ambientPlayer?.volume = preferences.isMusicEnabled ? Float(preferences.ambientVolume * (isWarning ? 0.2 : 1)) : 0
    }

    func beginFocus(preferences: AppPreferences) {
        self.preferences = preferences
        isWarning = false
        guard preferences.isMusicEnabled else { ambientPlayer?.stop(); return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let samples = Self.ambientWave(track: preferences.selectedTrack)
            ambientPlayer = try AVAudioPlayer(data: samples)
            ambientPlayer?.numberOfLoops = -1
            ambientPlayer?.volume = Float(preferences.ambientVolume)
            ambientPlayer?.prepareToPlay()
            ambientPlayer?.play()
        } catch { ambientPlayer = nil }
    }

    func enterWarning(preferences: AppPreferences, secondsRemaining: Int) {
        self.preferences = preferences
        isWarning = true
        ambientPlayer?.setVolume(preferences.isMusicEnabled ? Float(preferences.ambientVolume * 0.2) : 0, fadeDuration: 0.15)
        countdownTick(preferences: preferences, secondsRemaining: secondsRemaining)
    }

    func countdownTick(preferences: AppPreferences, secondsRemaining: Int) {
        guard preferences.isSFXEnabled else { return }
        let frequency = 660 + (5 - max(0, min(5, secondsRemaining))) * 95
        playTone(frequency: Double(frequency), duration: 0.14, volume: 0.55)
    }

    func recover(preferences: AppPreferences) {
        self.preferences = preferences
        isWarning = false
        warningPlayer?.stop()
        ambientPlayer?.setVolume(preferences.isMusicEnabled ? Float(preferences.ambientVolume) : 0, fadeDuration: 0.25)
    }

    func stop() {
        ambientPlayer?.stop()
        warningPlayer?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func playTone(frequency: Double, duration: Double, volume: Float) {
        guard let data = Self.toneWave(frequency: frequency, duration: duration) else { return }
        do {
            warningPlayer?.stop()
            warningPlayer = try AVAudioPlayer(data: data)
            warningPlayer?.volume = volume
            warningPlayer?.play()
        } catch { warningPlayer = nil }
    }

    private static func ambientWave(track: AmbientTrack) -> Data {
        let sampleRate = 8_000
        let sampleCount = sampleRate * 4
        var samples = [Int16](repeating: 0, count: sampleCount)
        var seed: UInt32 = track == .midnightRain ? 19 : (track == .vinylLibrary ? 47 : 83)
        for index in samples.indices {
            seed = 1_664_525 &* seed &+ 1_013_904_223
            let noise = Double(Int32(bitPattern: seed) >> 16) / 32768
            let tone = sin(Double(index) * 2 * .pi * (track == .campfireCrackle ? 82 : 54) / Double(sampleRate)) * 0.07
            samples[index] = Int16(max(-1, min(1, noise * 0.035 + tone)) * Double(Int16.max))
        }
        return wav(samples: samples, sampleRate: sampleRate)
    }

    private static func toneWave(frequency: Double, duration: Double) -> Data? {
        let rate = 16_000
        let count = Int(Double(rate) * duration)
        let samples = (0..<count).map { index -> Int16 in
            let envelope = 1 - Double(index) / Double(max(1, count))
            let value = sin(Double(index) * 2 * .pi * frequency / Double(rate)) * envelope * 0.45
            return Int16(value * Double(Int16.max))
        }
        return wav(samples: samples, sampleRate: rate)
    }

    private static func wav(samples: [Int16], sampleRate: Int) -> Data {
        let bytes = samples.withUnsafeBytes { Data($0) }
        var data = Data("RIFF".utf8)
        data.appendLE(UInt32(36 + bytes.count))
        data.append(Data("WAVEfmt ".utf8))
        data.appendLE(UInt32(16)); data.appendLE(UInt16(1)); data.appendLE(UInt16(1))
        data.appendLE(UInt32(sampleRate)); data.appendLE(UInt32(sampleRate * 2)); data.appendLE(UInt16(2)); data.appendLE(UInt16(16))
        data.append(Data("data".utf8)); data.appendLE(UInt32(bytes.count)); data.append(bytes)
        return data
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}