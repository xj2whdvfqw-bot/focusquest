import AVFoundation
import Foundation

@MainActor
protocol AudioAtmosphereServiceProtocol: AnyObject {
    /// Volano, kdyz lo-fi playlist sam prejde na dalsi skladbu.
    var onTrackAdvanced: ((AmbientTrack) -> Void)? { get set }
    func apply(preferences: AppPreferences)
    func beginFocus(preferences: AppPreferences)
    func enterWarning(preferences: AppPreferences, secondsRemaining: Int)
    func countdownTick(preferences: AppPreferences, secondsRemaining: Int)
    func recover(preferences: AppPreferences)
    func stop()
    /// Konec prestavky ("Break's over"): kratka dvoutonova melodie.
    func breakOver(preferences: AppPreferences)
}

extension AudioAtmosphereServiceProtocol {
    func breakOver(preferences: AppPreferences) { }
}

/// Prehrava zvuk behem soustredeni (lo-fi playlist, bily nebo hnedy sum) a 8-bit tony varovneho odpoctu.
/// Lo-fi jsou skutecne nahravky z bundlu; sumy se generuji v appce a hraji ve smycce.
@MainActor
final class AudioAtmosphereService: NSObject, AudioAtmosphereServiceProtocol, AVAudioPlayerDelegate {
    var onTrackAdvanced: ((AmbientTrack) -> Void)?
    private var ambientPlayer: AVAudioPlayer?
    private var warningPlayer: AVAudioPlayer?
    private var currentTrack: AmbientTrack?
    private var preferences = AppPreferences()
    private var isWarning = false
    private var isSessionActive = false
    private var interruptionObserver: (any NSObjectProtocol)?
    private var noiseCache: [Soundscape: Data] = [:]
    /// Dlouhe skladby (Fireplace piano, Study flow) hraji ve smycce: konec se prolne do noveho zacatku.
    private var loopTask: Task<Void, Never>?
    /// Dohravajici konec skladby behem prolnuti.
    private var fadingPlayer: AVAudioPlayer?
    private static let loopCrossfade: TimeInterval = 6

    /// Behem varovani se hudba ztlumi, aby vynikl odpocet.
    private var targetVolume: Float {
        preferences.isMusicEnabled ? Float(preferences.ambientVolume * (isWarning ? 0.2 : 1)) : 0
    }

    func apply(preferences: AppPreferences) {
        let previous = self.preferences
        self.preferences = preferences
        guard isSessionActive else { return }
        guard preferences.isMusicEnabled else { stopAmbient(); return }
        let sourceChanged = previous.soundscape != preferences.soundscape || previous.isMusicEnabled != preferences.isMusicEnabled
            || (preferences.soundscape == .lofi && currentTrack != preferences.selectedTrack)
        if ambientPlayer == nil || sourceChanged {
            startAmbient()
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
            startAmbient()
        }
    }

    func enterWarning(preferences: AppPreferences, secondsRemaining: Int) {
        self.preferences = preferences
        isWarning = true
        ambientPlayer?.setVolume(targetVolume, fadeDuration: 0.15)
        countdownTick(preferences: preferences, secondsRemaining: secondsRemaining)
    }

    /// Pipnuti odpoctu pri zvednuti telefonu. S vypnutym Alarm sound telefon jen vibruje.
    func countdownTick(preferences: AppPreferences, secondsRemaining: Int) {
        guard preferences.isAlarmSoundEnabled else { return }
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
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        // Mimo bitvu hraji jen efekty: kategorie .ambient respektuje tichy rezim
        // a neprerusi hudbu z jinych appek (.playback plati jen pro hudbu bitvy).
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    }

    // MARK: - Hudba a sumy

    private func startAmbient() {
        // Vzdy hraje jen jedna stopa: vsechno ostatni se zastavi pred spustenim dalsi.
        stopAllAudio()
        do {
            guard let player = try makeAmbientPlayer() else { return }
            // .playback + rezim "audio" v Info.plist = zvuk hraje i se zamcenou obrazovkou.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            player.delegate = self
            player.volume = 0
            player.prepareToPlay()
            player.play()
            player.setVolume(targetVolume, fadeDuration: 1.5)
            ambientPlayer = player
            if let resource = preferences.soundscape.loopResource { startLoopWatch(resource: resource) }
        } catch {
            ambientPlayer = nil
            currentTrack = nil
        }
    }

    private func makeAmbientPlayer() throws -> AVAudioPlayer? {
        switch preferences.soundscape {
        case .lofi:
            let track = preferences.selectedTrack
            guard let url = Bundle.main.url(forResource: track.resourceName, withExtension: "mp3") else { return nil }
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            currentTrack = track
            return player
        case .fireplacePiano, .studyFlow:
            guard let resource = preferences.soundscape.loopResource, let url = Self.loopURL(resource) else { return nil }
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            currentTrack = nil
            return player
        case .whiteNoise, .brownNoise:
            let player = try AVAudioPlayer(data: noiseData(for: preferences.soundscape))
            player.numberOfLoops = -1
            currentTrack = nil
            return player
        }
    }

    /// Smycka sumu se vyrobi pri prvnim pouziti a pak se drzi v pameti.
    private func noiseData(for soundscape: Soundscape) -> Data {
        if let cached = noiseCache[soundscape] { return cached }
        let samples = soundscape == .brownNoise ? NoiseSynth.brownNoise() : NoiseSynth.whiteNoise()
        let data = Self.wav(samples: samples, sampleRate: NoiseSynth.sampleRate)
        noiseCache[soundscape] = data
        return data
    }

    /// Zastavi hudbu, sum i tony odpoctu.
    private func stopAllAudio() {
        stopAmbient()
        warningPlayer?.stop()
        warningPlayer = nil
    }

    private func stopAmbient() {
        loopTask?.cancel()
        loopTask = nil
        fadingPlayer?.stop()
        fadingPlayer = nil
        ambientPlayer?.stop()
        ambientPlayer = nil
        currentTrack = nil
    }

    /// Skladba v bundlu: .m4a (AAC z CI), pro jistotu i puvodni .mp3.
    static func loopURL(_ resource: String) -> URL? {
        Bundle.main.url(forResource: resource, withExtension: "m4a") ?? Bundle.main.url(forResource: resource, withExtension: "mp3")
    }

    /// Hlida konec dlouhe skladby. Kdyz zbyva `loopCrossfade` sekund, spusti tutez skladbu od zacatku
    /// potichu a obe prolne (nova nahoru, stara dolu), takze smycka nema slysitelny strih.
    /// Kontrola jednou za sekundu; behem pauzy nebo varovani se nic nepocita navic.
    private func startLoopWatch(resource: String) {
        loopTask?.cancel()
        loopTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                guard !Task.isCancelled, let player = self.ambientPlayer, player.isPlaying else { continue }
                guard player.duration > Self.loopCrossfade * 3, player.duration - player.currentTime <= Self.loopCrossfade else { continue }
                self.crossfadeLoop(from: player, resource: resource)
            }
        }
    }

    private func crossfadeLoop(from old: AVAudioPlayer, resource: String) {
        guard let url = Self.loopURL(resource), let next = try? AVAudioPlayer(contentsOf: url) else { return }
        next.numberOfLoops = 0
        next.volume = 0
        next.prepareToPlay()
        next.play()
        next.setVolume(targetVolume, fadeDuration: Self.loopCrossfade)
        old.setVolume(0, fadeDuration: Self.loopCrossfade)
        fadingPlayer?.stop()
        fadingPlayer = old
        ambientPlayer = next
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.loopCrossfade + 0.5))
            guard let self, self.fadingPlayer === old else { return }
            old.stop()
            self.fadingPlayer = nil
        }
    }

    private func playNextTrack() {
        guard isSessionActive, preferences.isMusicEnabled, preferences.soundscape == .lofi, let finished = currentTrack else { return }
        preferences.selectedTrack = finished.next
        startAmbient()
        onTrackAdvanced?(finished.next)
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

    func breakOver(preferences: AppPreferences) {
        guard preferences.isBattleSoundEnabled else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        playTone(frequency: 784, duration: 0.16, volume: 0.5)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            self?.playTone(frequency: 1_175, duration: 0.28, volume: 0.5)
        }
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

    static func wav(samples: [Int16], sampleRate: Int) -> Data {
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

/// Generator sumu. Vraci kratkou smycku vzorku (16 bit, mono), kterou jde prehravat dokola bez lupnuti.
enum NoiseSynth {
    static let sampleRate = 32_000
    static let loopSeconds = 8
    /// Hlasitost sumu je asi o 65 % nizsi nez driv (prototyp: brown gain 0,17, white 0,04).
    static let whiteGain = 0.07
    static let brownPeak = 0.19

    /// Bily sum: kazdy vzorek je nahodny, zadna frekvence neprevlada.
    static func whiteNoise(seed: UInt64 = 0x9E37_79B9_7F4A_7C15) -> [Int16] {
        var generator = Generator(state: seed)
        return (0..<sampleRate * loopSeconds).map { _ in Int16(generator.nextUnit() * Self.whiteGain * Double(Int16.max)) }
    }

    /// Hnedy sum: bily sum protazeny integratorem, takze prevladaji hluboke tony (zni jako vodopad).
    static func brownNoise(seed: UInt64 = 0xD1B5_4A32_D192_ED03) -> [Int16] {
        var generator = Generator(state: seed)
        let count = sampleRate * loopSeconds
        var values = [Double](repeating: 0, count: count)
        var last = 0.0
        for index in 0..<count {
            last = (last + 0.02 * generator.nextUnit()) / 1.02
            values[index] = last
        }
        // Konec smycky musi navazat na zacatek, jinak by pri kazdem opakovani luplo.
        let drift = values[count - 1] - values[0]
        var peak = 0.0
        for index in 0..<count {
            values[index] -= drift * Double(index) / Double(count - 1)
            peak = max(peak, abs(values[index]))
        }
        let gain = peak > 0 ? Self.brownPeak / peak : 0
        return values.map { Int16($0 * gain * Double(Int16.max)) }
    }

    /// Maly rychly generator nahodnych cisel (xorshift64*); systemovy je na stovky tisic vzorku zbytecne pomaly.
    private struct Generator {
        var state: UInt64

        /// Nahodne cislo v rozsahu -1...1.
        mutating func nextUnit() -> Double {
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            let value = (state &* 2_685_821_657_736_338_717) >> 11
            return Double(value) / Double(UInt64(1) << 53) * 2 - 1
        }
    }
}
