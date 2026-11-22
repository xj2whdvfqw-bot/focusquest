# FocusQuest: rozhodnutí a kontext pro další session

Doplňuje `design/CHANGES.md` (zadání sekcí 0–15) a `design/progress.html` (stav, buildy, co otestovat).
Tady je to, co v nich není: rozhodnutí, která padla během práce, otevřené body a známé pasti.

Stav k 22. 11. 2026: větev `phase3-duolingo`, opravy po testu #55 (A1–A6) hotové, build viz progress.html. Všechny sekce z CHANGES.md
a všechny opravy z auditu jsou hotové.

## 1. Rozhodnutí

### Účty a server
- **Účty a celý serverový kód jsou odstraněné.** Pryč je přihlášení přes Apple, smazání účtu, `APIClient`,
  App Attest, Keychain, Supabase a klíče `API_BASE_URL`, `SUPABASE_ANON_KEY` a `PINNED_CERTIFICATE_SHA256`.
- Profil, statistiky, předměty i nastavení jsou jen v telefonu (UserDefaults: `LocalProfileSyncService`,
  `PreferencesStore`). Bitvy ověřuje `SimulatedSecureBackendService` přímo v telefonu.
- Důsledek: žádné pravidlo o smazání účtu (5.1.1(v)) a štítek App Privacy = „Data Not Collected“.
- Server znovu nezavádět bez nového rozhodnutí. Přinesl by povinné Sign in with Apple, smazání účtu, GDPR a jiný štítek.

### Settings
- **Reset progress** je v sekci „Your data“ s potvrzovacím dialogem. Smaže:
  - hrdinu, level, mince, statistiky, předměty a nastavení,
  - zálohy nečitelných dat (`.unreadable-backup`),
  - výběr appek a naplánované notifikace.

  Pak se znovu ukáže onboarding.
- **Rate this app je skryté**, dokud nebude App Store ID. Pak se vrátí jako přímý odkaz
  `https://apps.apple.com/app/id<ID>?action=write-review`, protože `requestReview()` často nic neukáže.
- **Contact the developer** otevírá Mail jen s předmětem. Adresa zatím chybí (viz Otevřené body).
- Privacy Policy, Terms of Use a Support v patičce otevírají web:
  - Privacy a Support jsou na GitHub Pages,
  - Terms = standardní Apple EULA.

### Bitva
- **Hovor během bitvy** (`CXCallObserver`, stav `callPaused`):
  - bitva se automaticky pozastaví, bez časového limitu a mimo jedinou pauzu „Pause once“,
  - zvednutí telefonu se během hovoru netrestá,
  - po hovoru se ukáže „Call ended – continue the battle?“ a bitva pokračuje, až telefon zase leží displejem dolů,
  - bez senzoru („Start without sensor“) je tam tlačítko „Continue battle“.

  Omezení: když je aplikace během hovoru uspaná (bitva bez zvuku a zamčený telefon), hovor se zjistí
  až po návratu do aplikace.
- **Kontrola integrity (jailbreak, debugger) je úplně odstraněná.** Zůstala jen kontrola posunu hodin v bitvě
  (`AntiCheatRules.clockIsTampered`).
- Zabití aplikace během bitvy: bitva se ztratí. Při dalším spuštění se zruší notifikace „Victory!“ a ukončí Live Activity.

### Vzhled
- **Koncentrické rohy:** vnitřní poloměr = vnější − odsazení.
  - Všechny poloměry jsou v `Shared/FQRadius.swift`: kontejnery, `Inset` a odvozené vnitřní poloměry.
    Sdílí je aplikace i Live Activity.
  - iOS 26+: `FQRadius.shape(_:)` vrací `ConcentricRectangle(corners: .concentric(minimum: .fixed(r)), isUniform: true)`
    a kontejnery volají `.fqContainer(radius:)`, což je `containerShape` jen na iOS 26.
  - iOS 17–25: stejný poloměr z `FQRadius.concentric`.
  - Live Activity a Dynamic Island používají `ContainerRelativeShape`.
  - Pixel-art bubliny, toasty a sprity mají schválně schodovité rohy, nesahat na ně.
  - Čipy zůstávají kapslemi.
- **Zavírání oken tahem dolů bez křížků.** Týká se Fight sheetu, Your subjects, editoru vzhledu a Settings
  (od testu #53 bez Done). Pomocný kód je v `Views/DesignSystem/SheetDismissal.swift`.
  - Úchyt nahoře zůstává.
  - VoiceOver zavírá gestem escape (dva prsty Z) nebo akcí „Close“ na nadpisu okna.
  - Tah okno nezavře:
    - v bitvě a v onboardingu (celoobrazovkové okno),
    - během potvrzení smazání předmětu (okno se vrátí a potvrzení se zruší),
    - během Reset progress.
  - Rozepsaný nový předmět: tah se zeptá „Discard the new subject?“. Pokus o zavření se zachytí přes UIKit
    (`presentationControllerDidAttemptToDismiss` přes přeposílajícího delegáta), protože SwiftUI na iOS 17 tuhle událost nemá.
- **Výsledková okna jsou skleněná** (`ResultDialog` v `Views/DesignSystem/Motion.swift`): útěk bosse, vítězství,
  Battle stopped a Call ended.
  - Jemné ztmavení scény 28 % a skleněná karta (`glassCard`, ultraThin materiál), panel přestávky má stejné ztmavení.
  - Pod výsledkem se karta bitvy schová, aby neprosvítala (dřív bylo vidět „Begin Battle“).
  - Karta se objeví pružinou (0,92 → 1), s Reduce Motion jen prolnutím.
- **Shop nemá velké pixelové nadpisy** („Gear up“, „Change the scenery“ jsou pryč). Hlavička je kompaktní:
  malý štítek „Shop“, mince, ozubené kolo, záložky Gear/Backgrounds a u Gear menší náhled hrdiny.
- **Připnutá hlavička (`pinnedTopHeader`)**: přechod do průhledna (24 pt) je součástí odsazení obsahu,
  takže na začátku nic nepodjíždí pod hlavičku. Dřív přesahoval 60 pt a zakrýval nadpis první sekce.
- **Settings nemají tlačítko Done**, zavírá se jen tahem dolů (VoiceOver gestem escape).
- **Skeletony místo spinnerů**: pro načítání obsahu se používá skeleton ve tvaru obsahu (redacted + jemný lesk),
  ne `ProgressView`. Teď se v appce nic nenačítá (všechna data jsou v telefonu), takže žádný skeleton zatím není.
  Jediné kolečko je u Reset progress a to značí probíhající akci, ne načítání.
- **Paleta bez tyrkysové** (od testu #55, vše v `Shared/FQColor.swift`):
  - `accent` je bílý (text na něm `onAccent` téměř černý #0D0B1C), Live Activity `liveAccent` bílá,
  - šedé odstíny pro vedlejší prvky, zapnutý přepínač má šedou stopu `toggleOn` (bílá kulička na bílé by zmizela),
  - žlutá jen pro hlavní CTA, červená (`danger`) pro ústup a mazání, mince zlaté (`coin`, komponenta `CoinLabel`),
  - další barvy nepřidávat.
  - Kontrast WCAG AA (spočítaný pro tmavé i světlé scény): sklo na světlých pozadích `cardOnBright` .78 (dřív .64),
    terciární text bílá 62 % (dřív 50 %), `danger` rgb(255,120,135) (dřív 255,84,102). Bílá na skle ≥ 7:1, vedlejší 78 % ≥ 4,5:1.
- **Animace** (`FQMotion`, `FQPressStyle`, `TabSwitchEntrance` v `Motion.swift`):
  - krátké, 0,2–0,35 s,
  - stisk tlačítek 0,97, podtržítko Gear/Backgrounds klouže, vybraný předmět v Shopu se zvedne na 1,02,
  - Reduce Motion: bez zmenšení, posunu, squashe a pružiny, jen prolnutí.
- **Tab bar a přechody záložek** (od testu #55):
  - bublina výběru je jeden tvar pod ikonami: zmáčkne se (0,8 × 0,86), přeletí pružinou s malým překmitem a roztáhne se (1,12 → 1), asi 0,35 s,
  - obsah nové záložky vyjede ve směru pořadí záložek (48 pt) a prolne se, krajina stojí,
  - vodorovný swipe po obrazovce přepíná na sousední záložku (obsah jde s prstem, na krajích jen kousek; přepne po ~70 pt nebo švihu),
  - swipe nesmí přebít vnitřní gesta: musí být výrazně vodorovný (|dx| > 1,8 × |dy|) a posuvník si ho zamkne (`TabSwipeLock`).
    Systémový TabView se stránkováním se nepoužil, protože nepouští pozadí obrazovek pod stavový řádek.
  - každá změna záložky jde přes `switchTab(to:)` (směr a spuštění přechodu ve stejném překreslení).
- **Zvuky a haptika: jeden centrální `FQFeedback`** (`Audio/FQFeedback.swift`), samostatné přepínače v Settings › Sounds:
  - Tap sounds (klik na tlačítka a ovládací prvky), Haptics (všechny vibrace včetně alarmu), Battle sounds (útok, zásah,
    vítězství, útěk bosse, konec přestávky), Reward sounds (mince, XP, level up, série v plamenech), Alarm sound, hlasitost efektů,
  - u každého zapnutého přepínače se rozbalí karta „Try it“ s ukázkou,
  - tlačítka dostávají klik a vibraci přes společný styl (`FQPressStyle` / `TapFeedback`, i `ShopButtonStyle`, dlaždice Path,
    skleněná tlačítka a přepínače), nové tlačítko má proto používat `.buttonStyle(.fqPress)`, ne `.plain`,
  - zvuky jsou syntetické tóny generované v kódu (`EffectSounds`), žádné soubory, tedy žádná licence,
  - efekty mimo bitvu hrají přes audio session `.ambient`: respektují přepínač ticha a nepřeruší hudbu z jiných appek;
    hudba bitvy zůstává `.playback` s `mixWithOthers` a po bitvě se session vrací na `.ambient`,
  - v uložených datech zůstávají klíče `isSFXEnabled` (= Tap sounds) a `isAchievementSoundEnabled` (= Reward sounds);
    nový `isBattleSoundEnabled` převezme hodnotu starého společného přepínače.
- **Notifikace jsou jen lokální** (`UNUserNotificationCenter`), žádný push/APNs: appka je sideloadovaná s bezplatným Apple ID
  a entitlement `aps-environment` nemá. Typy (`BattleNotificationService`, actor):

  | Typ | Identifikátor | Kdy | Text |
  |---|---|---|---|
  | Victory! | `focusquest.battle.victory` | na konec odpočtu bitvy (plánuje se při startu a po návratu z pauzy či zvednutí; ruší se pauzou, zvednutím, ústupem, útěkem bosse a po zabití appky) | „{boss} is defeated. Open FocusQuest to collect your XP and coins.“ |
  | Break is over | `focusquest.break.over` | 5 min po Collect Loot (ruší se odchodem z přestávky) | „Fresh head. Time for the next boss.“ |
  | Daily reminder | `focusquest.reminder.0…7` | 17:00 místního času na 7 dní dopředu, když je zapnutý; dnes ne, pokud už se bojovalo | „Your boss is waiting“ / „No battle yet today. Put your phone down for a few minutes.“ |

  - každé plánování se nejdřív zeptá na povolení (jen když se iOS ještě neptal), chyby jdou do logu (`Logger`, kategorie notifications),
  - Settings ukazují skutečný stav (Allowed, Not allowed yet + Allow, Banners off nebo Off + Open Settings),
  - Debug: „Test notifications“ naplánuje každý typ za 5, 7 a 9 s, „Show pending“ vypíše naplánované s časem.
- **Onboarding** má 4 stránky (pravidla, předměty, hrdina, povolení) ve stránkovaném pageru se swipem a tečkami;
  krok hrdiny používá `FQChip` a `HeroLookEditor` jako záložka Hero. Doporučení 5min bitvy na konci je pryč.
- **Návrat v Settings tahem od levého okraje**: podstránka Sounds & notifications nemá NavigationStack, proto vlastní gesto
  (začátek do 32 pt od okraje, stránka jde s prstem, zpět po ~100 pt nebo švihu). Tlačítko ‹ Settings zůstává.
- Home: volné místo nad a pod bossem v poměru 1 : 2, boss je blíž středu a nad Fight je vzduch.
- Dynamic Type:
  - texty s pevnou velikostí používají `fqFont(size:weight:design:)` a rostou nejvýš 1,5×,
  - aplikace má strop `accessibility2`,
  - ikony, časovače a pixelové bubliny mají velikost pevnou.
- Na nízkých displejích (iPhone SE, výška pod 620 bodů) má Arena kompaktní rozložení, aby Fight nebyl pod lištou.
- Aplikace je jen pro iPhone (`TARGETED_DEVICE_FAMILY = 1`).
- Dočasná ikona je Warm-up Wisp na tmavém pozadí (`FocusQuest/Resources/Assets.xcassets`).

### Repo, CI a hosting
- **Repo `xj2whdvfqw-bot/focusquest` zůstává veřejné až do vydání.** Proto nikdy necommitovat tajné údaje
  ani osobní údaje (e-mail atd.).
- **GitHub Pro je ze studentského balíčku.**
- **GitHub Pages** (Privacy, Support) se publikují z větve `phase3-duolingo`, složka `docs/`:
  - https://xj2whdvfqw-bot.github.io/focusquest/privacy.html
  - https://xj2whdvfqw-bot.github.io/focusquest/support.html
- **Buildy se spouští až po 2–3 bodech**, ne po každém. Commit a push ale po každém bodu.
  Příkaz: `gh workflow run ios.yml --ref phase3-duolingo -R xj2whdvfqw-bot/focusquest`.
- CI dělá tyto kroky:
  - Debug IPA pro Sideloadly,
  - kompilaci Release verze,
  - unit testy,
  - screenshoty: iPhone 17 a druhý průchod na iPhonu SE (3. gen.).
- Číslo buildu se bere z `github.run_number`.

## 2. Audit před App Storem

### Hotové
- PrivacyInfo.xcprivacy (UserDefaults `CA92.1`, systemUptime `35F9.1`). CI kontroluje, že je v aplikaci.
- `ITSAppUsesNonExemptEncryption = NO`.
- Dočasná ikona. CI kontroluje `CFBundleIconName` a `Assets.car`.
- Privacy Policy a Support na GitHub Pages; Terms = Apple EULA.
- Účty pryč, Reset progress.
- Jen iPhone.
- Notifikace:
  - po zabití aplikace se zruší „Victory!“ a ukončí Live Activity,
  - přepínače v onboardingu i Settings ukazují skutečný stav a při odmítnutí nabídnou Nastavení iPhonu.
- Přepínač Motion sensor v onboardingu nahradil informativní řádek, protože senzor oprávnění nepotřebuje.
- CI kompiluje i Release verzi.
- VoiceOver na liště záložek („Tab 1 of 5“).
- Záloha dat, která se nepodaří načíst.
- Dynamic Type.
- iPhone SE ve screenshotech a oprava Areny na SE.
- Rate this app skryté, pauza při hovoru, kontrola integrity odstraněná.

### Zbývá (viz Otevřené body)
- placený Apple Developer účet,
- e-mail pro Contact,
- vrácení Rate this app,
- finální ikona,
- autorská práva postav a hudby.

### Podklady pro App Store Connect
- App Privacy: Data Not Collected, Tracking: No.
- Šifrování: exempt (jen CryptoKit pro kontrolu integrity bitvy, žádné HTTPS).
- Věkové hodnocení: Cartoon or Fantasy Violence = Infrequent/Mild, vše ostatní None/No → 9+.
  Pokud boj s bossy nebrat jako násilí, None → 4+.
  - Bez UGC (předměty zůstávají v telefonu), bez chatu, reklam, nákupů v aplikaci a loot boxů.

## 3. Otevřené body
- **E-mail pro Contact the developer.** Samostatná adresa pro podporu. Doplnit i na stránku Support.
- **Placený Apple Developer Program** (99 USD/rok). Bez něj nejde odeslat build ani TestFlight.
  Podepisování pak přes GitHub Actions (App Store Connect API klíč v Secrets).
- **Náhrada parodií postav**: světy Hero Heights, Villain Vault a Swamp Kingdom (bossové volně inspirovaní
  známými postavami). **Ověřit licence hudby**: `calm-currents.mp3`, `peaceful-drift.mp3`, `tokyo-sunset.mp3`
  (viz `CREDITS.md`).
- **Finální ikona** (navrhne autor aplikace). Nahradit `AppIcon-1024.png`, případně doplnit tmavou a tónovanou variantu.
- **Vrátit Rate this app**, až bude App Store ID.

## 4. Nápady na později
- Záloha a synchronizace přes iCloud (bez vlastního serveru, štítek App Privacy zůstane bez sběru dat).
- Widgety na plochu (série, dnešní minuty, další boss).
- Siri a Zkratky (App Intents: „Start a 25 min battle“).
- Kartička vítězství ke sdílení (základ je v `BattleReceiptRenderer`).
- Game Center (žebříčky a achievementy).
- Čeština (lokalizace; texty jsou teď anglicky).
- Haptika: bohatší vzorce (Core Haptics) pro zásah bosse, vítězství a varování.

## 5. Známé pasti
- **LF/CRLF varování** při commitu (`LF will be replaced by CRLF`) jsou neškodná, `.gitattributes` to řeší.
- **Backslashe:** Bash, `node -e` a `sed` na Windows ztrácí `\`. Pro `\(…)`, `\.keyPath` a `@Environment(\.x)` použít nástroj Edit.
- **Flaky testy:**
  - `ArenaAntiCheatTests` (hlášení porušení se čeká až 1 s),
  - test hlasitosti šumu (očekává `brownPeak × Int16.max`, ne pevné číslo).
- **Billing:**
  - soukromé repo spotřebuje minuty GitHub Actions rychle, protože macOS buildy se počítají 10×; i proto je repo veřejné,
  - **build, který spadne za pár sekund bez jediného kroku = blokace kvůli billingu**, ne chyba kódu.
- **Výpadky GitHubu:** krok „Nahrání IPA“ může spadnout na timeoutu služby artefaktů (build #48). Stačí spustit znovu.
- **Pomalé screenshoty:**
  - Intel runner `macos-26-intel` je pomalý: hlavní screenshoty trvají kolem 10 minut a SE simulátor startuje několik minut,
  - limit kroku je 28 min a start SE se po 8 min vzdá,
  - screenshoty build nikdy neshodí.
- **GitHub Pages po sloučení do main:** v repu přepnout Settings › Pages na větev `main` (složka `/docs`). Adresy zůstanou stejné.
- **Debug a Release:**
  - CI staví pro Sideloadly konfiguraci Debug, takže v IPA je karta Debug v Settings,
  - v Release je za `#if DEBUG` skrytá.
- **`containerShape` na iOS 17:**
  - iOS 26 přetížení se nesmí volat mimo `#available(iOS 26.0, *)`, proto `fqContainer` vrací na starších iOS jen `self`,
  - `AnyShape` neumí `strokeBorder`, použít `stroke` + `padding(lineWidth / 2)`.
