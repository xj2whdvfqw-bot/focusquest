import SwiftUI
import UIKit

/// Jedno misto pro zvukove efekty a haptiku v cele appce.
/// Kazdy zvuk patri do jedne skupiny s vlastnim prepinacem v Nastaveni:
///  - Tap sounds: klepnuti na tlacitka a ovladaci prvky (FQPressStyle, ShopButtonStyle, prepinace),
///  - Battle sounds: utok, zasah, vitezstvi, utek bosse, konec prestavky,
///  - Reward sounds: mince, XP, level up, serie v plamenech,
///  - Alarm sound: pipani pri zvednuti telefonu (hraje AudioAtmosphereService),
///  - Haptics: vsechny vibrace (tlacitka, vysledky, alarm v bitve).
/// Predvolby sem posila AppDIContainer pri kazde zmene (`configure`).
@MainActor
final class FQFeedback {
    static let shared = FQFeedback()

    enum Category { case tap, battle, reward, alarm }

    enum Sound: CaseIterable {
        case tap, attack, hit, victory, escape, coin, xp, levelUp, alarm

        var category: Category {
            switch self {
            case .tap: .tap
            case .attack, .hit, .victory, .escape: .battle
            case .coin, .xp, .levelUp: .reward
            case .alarm: .alarm
            }
        }

        fileprivate var effect: EffectSounds.Effect {
            switch self {
            case .tap: .click
            case .attack: .attack
            case .hit: .hit
            case .victory: .victory
            case .escape: .escape
            case .coin: .coin
            case .xp: .xp
            case .levelUp: .jingle
            case .alarm: .beep
            }
        }
    }

    enum Haptic { case selection, light, medium, heavy, success, warning, error }

    private var preferences = AppPreferences()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {}

    func configure(with preferences: AppPreferences) {
        self.preferences = preferences
    }

    func isEnabled(_ category: Category) -> Bool {
        switch category {
        case .tap: preferences.isSFXEnabled
        case .battle: preferences.isBattleSoundEnabled
        case .reward: preferences.isAchievementSoundEnabled
        case .alarm: preferences.isAlarmSoundEnabled
        }
    }

    /// Prehraje zvuk, kdyz je jeho skupina zapnuta (hlasitost podle "Effects volume").
    func play(_ sound: Sound) {
        guard isEnabled(sound.category) else { return }
        EffectSounds.shared.play(sound.effect, volume: Float(preferences.effectsVolume))
    }

    /// Vibrace, kdyz je zapnuta Haptics.
    func haptic(_ kind: Haptic) {
        guard preferences.isHapticsEnabled else { return }
        switch kind {
        case .selection: selectionGenerator.selectionChanged()
        case .light: lightGenerator.impactOccurred(intensity: 0.6)
        case .medium: mediumGenerator.impactOccurred()
        case .heavy: heavyGenerator.impactOccurred()
        case .success: notificationGenerator.notificationOccurred(.success)
        case .warning: notificationGenerator.notificationOccurred(.warning)
        case .error: notificationGenerator.notificationOccurred(.error)
        }
    }

    /// Ukazka hlasitosti (posuvnik Effects volume): zazni i se zrovna vypnutou skupinou.
    func preview(_ sound: Sound) {
        EffectSounds.shared.play(sound.effect, volume: Float(preferences.effectsVolume))
    }

    /// Klepnuti na tlacitko nebo ovladaci prvek: tichy klik a jemna vibrace.
    func tap() {
        play(.tap)
        haptic(.selection)
    }
}

extension View {
    /// Vibrace pres FQFeedback (respektuje prepinac Haptics), kdyz se `trigger` zmeni a plati `condition`.
    func fqHaptic<T: Equatable>(_ kind: FQFeedback.Haptic, trigger: T, when condition: @escaping (T, T) -> Bool = { _, _ in true }) -> some View {
        onChange(of: trigger) { old, new in
            if condition(old, new) { FQFeedback.shared.haptic(kind) }
        }
    }

    /// Zvuk pres FQFeedback (respektuje prepinac sve skupiny), kdyz se `trigger` zmeni a plati `condition`.
    func fqSound<T: Equatable>(_ sound: FQFeedback.Sound, trigger: T, when condition: @escaping (T, T) -> Bool = { _, _ in true }) -> some View {
        onChange(of: trigger) { old, new in
            if condition(old, new) { FQFeedback.shared.play(sound) }
        }
    }
}
