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

/// Prehrava lo-fi hudbu behem soustredeni a 8-bit tony varovneho odpoctu.
/// Hudba jsou skutecne nahravky z bundlu; hraje se jako playlist od vybrane skladby.
@MainActor
final class AudioAtmosphereService: NSObject, AudioAtmosphereServiceProtocol, AVAudioPlayerDelegate {
    private var ambientPlayer: AVAudioPlayer?
    private var warningPlayer: AVAudioPlayer?
    private var currentTrack: AmbientTrack?
    private var preferences = AppPreferences()
    private var isWarning = false
    private var isSessionActive = false
    private var interruptionObserver: (any NSObjectProtocol)?

    /// Behem varovani se hudba ztlumi, aby vynikl odpocet.
    private var targetVolume: Float {
        preferences.isMusicEnabled ? Float(preferences.ambientVolume * (isWarning ? 0.2 : 1)) : 0
    }

    func apply(preferences: AppPreferences) {
        let previousTrack = self.preferences.selectedTrack
        self.preferences = preferences
        guard isSessionActive else { return }
        guard preferences.isMusicEnabled else { stopAmbient(); return }
        if ambientPlayer == nil || previousTrack != preferences.selectedTrack {
            startAmbient(track: preferences.selectedTrack)
        } else {
            ambientPlayer?.volume = targetVolume
        }
    }

    func beginFocus(preferences: AppPreferences) {
        self.preferences = preferences
        isWarning = false
        isSessionActive = true
        observeInterruptionsIfNeeded()
        guard preferences.isMusicEnabled else { stopAmbient(); return }
        if let player = ambientPlayer {
            // Navrat z varovani: hudba pokracuje tam, kde byla, jen se vrati hlasitost.
            if !player.isPlaying { player.play() }
            player.setVolume(targetVolume, fadeDuration: 0.25)
        } else {
            startAmbient(track: preferences.selectedTrack)
        }
    }

    func enterWarning(preferences: AppPreferences, secondsRemaining: Int) {
        self.preferences = preferences
        isWarning = true
        ambientPlayer?.setVolume(targetVolume, fadeDuration: 0.15)
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
        ambientPlayer?.setVolume(targetVolume, fadeDuration: 0.25)
    }

    func stop() {
        isSessionActive = false
        isWarning = false
        stopAmbient()
        warningPlayer?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Hudba

    private func startAmbient(track: AmbientTrack) {
        stopAmbient()
        guard let url = Bundle.main.url(forResource: track.resourceName, withExtension: "mp3") else { return }
        do {
            // .playback + rezim "audio" v Info.plist = hudba hraje i se zamcenou obrazovkou.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.numberOfLoops = 0
            player.volume = 0
            player.prepareToPlay()
            player.play()
            player.setVolume(targetVolume, fadeDuration: 1.5)
            ambientPlayer = player
            currentTrack = track
        } catch {
            ambientPlayer = nil
        }
    }

    private func stopAmbient() {
        ambientPlayer?.stop()
        ambientPlayer = nil
        currentTrack = nil
    }

    private func playNextTrack() {
        guard isSessionActive, preferences.isMusicEnabled, let finished = currentTrack else { return }
        startAmbient(track: finished.next)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.playNextTrack() }
    }

    /// Po hovoru nebo Siri system prehravani pozastavi; po skonceni preruseni ho obnovime.
    private func observeInterruptionsIfNeeded() {
        guard interruptionObserver == nil else { return }
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard rawType == AVAudioSession.InterruptionType.ended.rawValue else { return }
            Task { @MainActor [weak self] in self?.resumeAfterInterruption() }
        }
    }

    private func resumeAfterInterruption() {
        guard isSessionActive, preferences.isMusicEnabled, let player = ambientPlayer, !player.isPlaying else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
    }

    // MARK: - Tony odpoctu

    private func playTone(frequency: Double, duration: Double, volume: Float) {
        guard let data = Self.toneWave(frequency: frequency, duration: duration) else { return }
        do {
            warningPlayer?.stop()
            warningPlayer = try AVAudioPlayer(data: data)
            warningPlayer?.volume = volume
            warningPlayer?.play()
        } catch { warningPlayer = nil }
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
