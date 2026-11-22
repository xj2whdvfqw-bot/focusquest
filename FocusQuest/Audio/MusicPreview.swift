import AVFoundation
import Foundation
import Observation

/// Ukazka hudby v Nastaveni › Music: 8 s se zesilenim na zacatku a zeslabenim na konci.
/// Hraje vzdy jen jedna ukazka (spusteni jine zastavi predchozi). Hlasitost je stejna jako hudba v bitve
/// (`ambientVolume`) a meni se hned s posuvnikem. Stranka pri odchodu vola `stop()`.
@Observable
@MainActor
final class MusicPreview {
    static let shared = MusicPreview()

    /// Prave hrajici ukazka (nil = ticho).
    private(set) var playing: BattleSound?

    static let length: TimeInterval = 8
    static let fade: TimeInterval = 1.2

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var volume: Float = 0.55

    private init() {}

    /// Play/stop u stopy: znovu klepnuti na hrajici stopu ji zastavi.
    func toggle(_ sound: BattleSound, preferences: AppPreferences) {
        if playing == sound { stop(); return }
        play(sound, preferences: preferences)
    }

    func play(_ sound: BattleSound, preferences: AppPreferences) {
        stop(fadeOut: false)
        guard let soundscape = sound.soundscape, let next = Self.makePlayer(soundscape, preferences: preferences) else { return }
        volume = Float(preferences.ambientVolume)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        next.volume = 0
        next.prepareToPlay()
        next.play()
        next.setVolume(volume, fadeDuration: Self.fade)
        player = next
        playing = sound
        task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.length - Self.fade))
            guard let self, !Task.isCancelled, self.player === next else { return }
            next.setVolume(0, fadeDuration: Self.fade)
            try? await Task.sleep(for: .seconds(Self.fade))
            guard !Task.isCancelled, self.player === next else { return }
            self.finish()
        }
    }

    /// Posuvnik hlasitosti hudby: hrajici ukazka se hned ztisi nebo zesili.
    func setVolume(_ value: Double) {
        volume = Float(min(1, max(0, value)))
        player?.setVolume(volume, fadeDuration: 0.1)
    }

    /// Zastavi ukazku (kratke zeslabeni, aby to neluplo).
    func stop(fadeOut: Bool = true) {
        task?.cancel()
        task = nil
        guard let current = player else { playing = nil; return }
        player = nil
        playing = nil
        if fadeOut {
            current.setVolume(0, fadeDuration: 0.25)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                current.stop()
            }
        } else {
            current.stop()
        }
        restoreAmbientSession()
    }

    private func finish() {
        player?.stop()
        player = nil
        playing = nil
        task = nil
        restoreAmbientSession()
    }

    /// Mimo bitvu plati kategorie .ambient (tichy rezim, hudba jinych appek hraje dal).
    private func restoreAmbientSession() {
        let session = AVAudioSession.sharedInstance()
        guard session.category == .playback else { return }
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    }

    private static func makePlayer(_ soundscape: Soundscape, preferences: AppPreferences) -> AVAudioPlayer? {
        switch soundscape {
        case .lofi:
            guard let url = Bundle.main.url(forResource: preferences.selectedTrack.resourceName, withExtension: "mp3") else { return nil }
            return try? AVAudioPlayer(contentsOf: url)
        case .fireplacePiano, .studyFlow:
            guard let resource = soundscape.loopResource, let url = AudioAtmosphereService.loopURL(resource) else { return nil }
            return try? AVAudioPlayer(contentsOf: url)
        case .whiteNoise, .brownNoise:
            let samples = soundscape == .brownNoise ? NoiseSynth.brownNoise() : NoiseSynth.whiteNoise()
            let player = try? AVAudioPlayer(data: AudioAtmosphereService.wav(samples: samples, sampleRate: NoiseSynth.sampleRate))
            player?.numberOfLoops = -1
            return player
        }
    }
}
