# Finální go / no-go audit před odesláním do App Review

Stav k 28. 11. 2026, větev `phase3-duolingo`, HEAD `1a2668e`. Kód je shodný s commitem `a745f30`, na kterém proběhl
poslední zelený CI build #91 (run `45840050242`). Od něj se změnily jen soubory v `design/`.
Audit nic neopravuje. Navazuje na `design/RELEASE_AUDIT.md` (26. 11.) a ověřuje, co se od té doby změnilo.

Guidelines jsem ověřil 28. 11. 2026 přímo na developer.apple.com/app-store/review/guidelines (znění 1.5, 2.3.7, 2.5.4,
3.1.1, 4.5.4, 5.1.1(i), 5.2.5 a 5.6.1 sedí s tím, z čeho tu vycházím).

---

## 1. VERDIKT

# NO-GO: 11 blokerů

- **7 blokerů v kódu a konfiguraci:** přejmenování na Slaymo vůbec nezačalo, widget nemá privacy manifest,
  „Contact the developer“ nemá adresu, web podpory a Privacy Policy jsou zastaralé a pod starým názvem,
  CI neumí podepsaný archiv, widget bez App Group ukazuje jen výzvu.
- **4 blokery mimo kód:** Developer účet, záznam v App Store Connect (rezervace názvu), web slaymo.app s funkčním
  e-mailem support@slaymo.app, screenshoty a metadata.
- Od auditu 26. 11. se **nedokončil žádný z balíčků R1–R6** (od té doby žádný commit v kódu).

Co je v pořádku: žádná síť, SDK, reklamy, analytika, účty ani nákupy. Debug UI je za `#if DEBUG`. Ikona je správná.
145 testů prochází, Release se kompiluje. Nikde nejsou zdravotní tvrzení, placeholdery ani zmínky o jiných platformách.
Apple emoji v UI nejsou.

Realistická cesta ke GO: R1 → R2 → R3 (Slaymo) → R4 (po schválení účtu) → R6 → TestFlight → odeslání.
To je zhruba 5–8 pracovních session a 1–2 týdny kalendářního času.

---

## 2. Výsledky automatických kontrol

### 2.1 Build a testy
| Kontrola | Výsledek | Důkaz |
|---|---|---|
| Release build | ✅ kompiluje (jen `COMPILE_ONLY`, bez podpisu a archivu) | CI #91, krok `CONFIG=Release COMPILE_ONLY=1 bash scripts/ci-build-ipa.sh` |
| Unit testy | ✅ **145 testů, 0 selhání** (168,9 s) | CI #91: „Executed 145 tests, with 0 failures“ |
| Varování kompilátoru | ⚠️ **4 unikátní** (každé 3× v logu: Debug, Release, testy) | viz níže |
| Varování CI | ⚠️ `actions/upload-artifact@v4` běží na Node 20 (vynuceně na 24) | log CI #91 |
| Podepsaný archiv / upload | ❌ neexistuje | `.github/workflows/` obsahuje jen `ios.yml`, bez `archive` a `-exportArchive` |

Lokálně build spustit nejde (Windows, bez Macu), výsledky jsou z CI. Varování:
- `FocusQuest/Views/Shop/ShopStallArt.swift`: `StallPedestal.heightInPixels` a `pad` (main actor-isolated v nonisolated kontextu),
- `FocusQuest/Views/Arena/BattleStage.swift`: `BattleStage.finaleSeconds` (totéž),
- `FocusQuest/Hardware/CallMonitoringService.swift:56`: nevyužitý výsledek `MainActor.assumeIsolated`.

### 2.2 Grep v repu (`FocusQuest/`, `Shared/`, `FocusQuestWidgets/`, `Support/`, `docs/`, `project.yml`)
| Hledaný výraz | Výskyty | Hodnocení |
|---|---|---|
| `FocusQuest` / `Focus Quest` | **168** ve 39 souborech (kód 105, `project.yml` 21, Info.plist 5, web 20, privacy manifest 1, …) | ❌ blokér B1 |
| `Slaymo` | **0** | ❌ přejmenování nezačalo |
| `TODO` | 3, jen komentáře s názvem souboru `DEVELOPER_ACCOUNT_TODO.md` | ✅ |
| `FIXME`, `lorem`, `coming soon` | 0 | ✅ |
| `placeholder` | 1: `FocusStatusWidget.swift:13` je povinná metoda WidgetKitu `placeholder(in:)` | ✅ |
| `beta` | 0 | ✅ |
| `test` v uživatelských textech | `Boss.swift:184` „…the night before the test.“ (hláška bosse, v pořádku); `BattleNotificationService.swift:185–187` a `SettingsView.swift:668–672` „Test notifications“ (jen Debug UI, ale funkce v Release binárce, D1) | ⚠️ D1 |
| `Android`, `Google Play` | 0 | ✅ |
| `http://` | 0 (kromě DTD hlaviček plistů, ty jsou standard) | ✅ |
| `print(`, `NSLog`, `os_log` | 0 | ✅ |
| `Logger(` | 1: `BattleNotificationService.swift:39`, subsystem `"FocusQuest"`; loguje jen chyby notifikací (ř. 58, 65, 79) | ✅ (subsystem změnit v R3) |
| `ADHD`, `clinic`, `therap`, `anxiety` | 0 | ✅ 1.4.1 |
| `Buy coins`, `purchase`, `StoreKit` | 0 | ✅ 3.1.1 |
| `URLSession`, `import Network` | 0 | ✅ |
| Cizí značky | `AppBlockerManager.swift:26–30`: Instagram, Facebook, LinkedIn, TikTok, YouTube vč. barev značek (mrtvý kód); `StatsShare.swift:69` jen v komentáři | ⚠️ D1 |

### 2.3 Emoji (5.2.5: „Apps … may not include Apple emoji“)
Sken rozsahů U+1F000–1FAFF, U+2300–27BF, U+2B00–2BFF a U+FE0F:
- `FocusQuest/Views/Stats/HabitsCard.swift:152`: `"❄︎ streak freeze"`. Znak U+2744 s U+FE0E (textová prezentace),
  takže se vykreslí písmem, ne jako Apple Color Emoji. **Formálně PASS**, ale doporučuji nahradit SF Symbolem `snowflake`
  (R1), ať o tom reviewer nemusí přemýšlet.
- `✓` a `×` jen v komentářích (`PlayerStats.swift:210`, `PathTabView.swift:998, 1073`, `SubjectManagerView.swift:181`).
- Web `docs/` bez emoji.

### 2.4 Kód za `#if DEBUG`
Bloky jsou v 9 souborech (`SettingsView.swift:122–124, 592–737`, `BattleView.swift`, `ArenaViewModel.swift`,
`PathTabView.swift`, `MainTabView.swift`, `ProfileViewModel.swift`, `ProfileSyncService.swift`, `AppPreferences.swift:248–250`,
`BattleStage.swift`).

| Debug funkce | V UI Release? | V binárce Release? |
|---|---|---|
| Debug karta v Nastavení (mince, level, světy) | ne | ne |
| Win now | ne | ne |
| Unlock all worlds | ne (`isUnlocked` ho v Release ignoruje) | pole `debugUnlockAllWorlds` se dál ukládá a dekóduje (`AppPreferences.swift:191, 202, 311`) |
| Change class (free) | ne | **ano**: `ClassChangeSheet.swift:36, 97, 105` (`Mode.debugFree`, texty „Debug: …“) |
| Test notifications | ne | **ano**: `BattleNotificationService.swift:182–210` |
| `setLevel`, `grantBonusXP` | ne | **ano**: `ProfileSyncService.swift:13, 57, 62`, `PlayerStats.swift:196, 202` |
| Debug widget | ne | ne (je v debug sekci Nastavení) |
| `AppBlockerManager` (cizí značky) | ne | **ano**: vytváří ho `AppDIContainer.swift:16, 40` |

### 2.5 Info.plist a entitlements
| Klíč | App (`Support/FocusQuest-Info.plist` + `Development.xcconfig`) | Widget (`Support/FocusQuestWidgets-Info.plist`) |
|---|---|---|
| Verze / build | `1.0.0` / `CURRENT_PROJECT_VERSION` z `github.run_number` (fallback `3` v `project.yml:16`) | stejné |
| Minimální iOS | 17.0 | 17.0 |
| Zařízení | iPhone (`TARGETED_DEVICE_FAMILY = 1`) | iPhone |
| Orientace | jen na výšku | – |
| `ITSAppUsesNonExemptEncryption` | `false` ✅ | – (nepotřebuje) |
| `UIBackgroundModes` | `audio` ⚠️ (D2) | – |
| Purpose strings | `NSMotionUsageDescription` „FocusQuest checks…“ (název změnit, R3) | – |
| `NSSupportsLiveActivities` | `true` ✅ | – |
| URL schéma | `focusquest://` (změnit v R3) | – |
| Display name | `FocusQuest` (xcconfig ř. 10) | `FocusQuest` (ř. 8) |
| Launch screen | `UILaunchScreen_Generation = YES` bez barvy (D7) | – |
| Entitlements | **žádné** `.entitlements` (App Group chybí, B7) | žádné |

Intents nejsou samostatný target. App Intents a Focus Filter jsou v hlavní appce, Live Activity ve widget extension.

### 2.6 Privacy manifesty
| Bundle | Soubor | Stav |
|---|---|---|
| App | `FocusQuest/Resources/PrivacyInfo.xcprivacy` | ✅ `NSPrivacyTracking = false`, prázdné domény i `NSPrivacyCollectedDataTypes`, UserDefaults `CA92.1`, SystemBootTime `35F9.1` (`ProcessInfo.systemUptime`) |
| Widget extension | **chybí** | ❌ B2. `Shared/WidgetSnapshot.swift:34–60` čte `UserDefaults.standard` i `UserDefaults(suiteName:)` |

Ostatní Required Reason API (časová razítka souborů, místo na disku, aktivní klávesnice) se v kódu nepoužívají ✅.
Po zapnutí App Group přidat do obou manifestů důvod `1C8F.1`.

### 2.7 Ikona a launch screen
- `AppIcon-1024.png`: 1024 × 1024, PNG typ barvy 2 (RGB **bez alfa kanálu**) ✅, jediná `universal` velikost (Xcode generuje ostatní) ✅.
- Motiv je dočasný (Warm-up Wisp). Finální ikona Slaymo a varianty dark a tinted chybí (R3).
- Launch screen je generovaná bez barvy, takže při startu bílý nebo černý záblesk (D7).

---

## 3. Tabulka Guideline → stav

| Guideline | Stav | Důkaz | Oprava |
|---|---|---|---|
| **1.1** Urážlivý obsah | PASS | `Boss.swift:140–235`: hlášky o odkládání. Typy (nerd, emo, gymbro) jsou laskavé, necílí na chráněné skupiny | doporučení: přejmenovat „Monk Mañana“ (`dojo-monk`), protože spojuje španělské „mañana“ s leností (etnický stereotyp) |
| **1.4.1** Zdravotní tvrzení | PASS | grep ADHD, clinic, therap, anxiety = 0; texty v appce i návrhy metadat jsou bez zdravotních slibů | v metadatech nepoužívat ADHD, „clinically“, „treat“ |
| **1.5** Kontakt na vývojáře | **FAIL** | `SettingsView.swift:245–251` skládá `mailto:` jen s předmětem; `docs/support.html:17` vede jen na GitHub issues | B3, B4 |
| **1.6** Bezpečnost dat | PASS | data jen v UserDefaults, žádná síť | – |
| **2.1** Kompletnost | **FAIL** | widget bez dat (B7), Contact (B3); placeholdery 0 | B3, B7, Notes for Review |
| 2.1 Odměny (loot box) | PASS | truhly mají pevnou odměnu podle obtížnosti, easter eggy pevné mince (`PathTabView.swift:217`); `randomElement` jen u textů hlášek (`ArenaView.swift:505`) a částic ohně | – |
| **2.3.1** Skryté funkce | PASS (s výhradou) | easter eggy jsou kosmetické s malou odměnou mincí; debug funkce v UI nejsou | D1 (odstranit debug kód z binárky) |
| **2.3.3** Screenshoty | RUČNĚ OVĚŘIT | neexistují | R6 |
| **2.3.7** Název | **FAIL** | display name `FocusQuest` (obsazený název); „Slaymo“ má 6 znaků ✅ | B1 / R3 |
| **2.3.8** Metadata 4+ | PASS | návrhy v kap. 6 | – |
| **2.3.10** Jiné platformy | PASS | grep Android, Google Play = 0 | – |
| **2.3.6** Věkové hodnocení | RUČNĚ OVĚŘIT | návrh odpovědí v kap. 6.8 | vyplnit v ASC |
| **2.4.1** iPad | RUČNĚ OVĚŘIT | `TARGETED_DEVICE_FAMILY = 1`, na iPadu poběží v kompatibilním okně na výšku | jednou vyfotit v CI na simulátoru iPadu (R6) |
| **2.4.2** Baterie | RUČNĚ OVĚŘIT | `TimelineView` 2 snímky/s mimo útok, na pozadí stojí (`BattleStage.swift:99`); senzor 10 Hz jen během bitvy (`MotionMonitoringService.swift:84`) | hodinový test se zamčeným telefonem (kap. 7) |
| **2.5.1** Veřejná API | PASS | žádné privátní API ani `dlopen` | – |
| **2.5.2** Stahování kódu | PASS | žádná síť | – |
| **2.5.4** Background modes | **FAIL (riziko)** | `UIBackgroundModes = audio`; přehrávač běží i při `ambientVolume = 0` (`AudioAtmosphereService.swift:41–43`, posuvník `0...1` v `SettingsView.swift:449`). Během hudby běží appka na pozadí a čte senzor | D2 + text do Notes |
| **2.5.9** Systémové chování | PASS | detekce „displejem dolů“ jen čte `CMMotionManager`, nic systémového nemění | – |
| **2.5.11** App Intents | PASS | Start battle, Show streak, Pause battle (`FocusQuestIntents.swift:38–78`) odpovídají funkcím | popisy přejmenovat (R3) |
| **2.5.16** Widget, Live Activity | **FAIL** (widget) / PASS (Live Activity) | widget bez App Group ukazuje „Open FocusQuest“ (`Shared/FocusWidgetViews.swift:153`) | B7 |
| **3.1.1** IAP | PASS | grep StoreKit, purchase, Buy coins = 0; mince jen za minuty soustředění | – |
| **3.2.2 / 5.6.1** Hodnocení | PASS / N/A | žádný prompt na hodnocení; „Rate this app“ je skryté (`SettingsView.swift:86–87`) | vrátit v 1.0.1 přes `requestReview` / odkaz `?action=write-review` |
| **4.1** Copycat | **FAIL** (do R3) | název FocusQuest koliduje s „Focus Quest: Study buddy“; ikona i grafika jsou vlastní; Excalibur (`Equipment.swift:150`) je obecný mýtus ✅ | B1; Slaymo prověřit (kap. 7) |
| **4.2** Minimální funkčnost | PASS | bitvy, mapa 7 světů, Shop, statistiky, Live Activity, Shortcuts | – |
| **4.5.4** Notifikace | PASS | jen lokální; žádost až po první výhře; appka funguje i bez nich; žádný marketing | – |
| HIG: Dynamic Type | ⚠️ | 95× `.font(.system(size:))` | R5; v Accessibility Nutrition Labels netvrdit „Larger Text“ |
| HIG: VoiceOver | ⚠️ | 86 `accessibilityLabel`, ruční průchod chybí | TestFlight checklist |
| HIG: Reduce Motion | PASS | 19 souborů reaguje na `accessibilityReduceMotion` | – |
| HIG: Dark Mode | PASS | appka je celá tmavá | – |
| HIG: SE i Pro Max | PASS | CI screenshoty na SE a iPhone 17 | – |
| **5.1.1(i)** Privacy Policy | **FAIL** | `docs/privacy.html`: jméno FocusQuest, adresa na `xj2whdvfqw-bot.github.io`, bez e-mailu a jména správce; chybí Streak in danger, widget/App Group, Siri, Focus Filter, Live Activity, sdílecí obrázky. Uchování a smazání popsané je ✅ | B5 |
| **5.1.1(ii)** Purpose strings | PASS (po R3) | `NSMotionUsageDescription` pravdivý; notifikace a CallKit observer string nepotřebují | název v textu (R3) |
| **5.1.1(v)** Mazání účtu | N/A | žádné účty, nikde se nevytváří | – |
| **5.1.2** Sdílení dat | PASS | žádné třetí strany ani AI; ATT není potřeba | – |
| **5.1.4** Děti | PASS | ne Kids kategorie; v metadatech nepsat „for kids“ | – |
| **5.2.1** Duševní vlastnictví | ⚠️ | licence hudby OK (CC0, Pixabay), ale obrazovka Acknowledgements v appce chybí a CREDITS.md tvrdí opak (ř. 7); chybí 4 soubory z Pixabay | D4 |
| **5.2.5** Apple emoji, podpora od Apple | PASS | jen `❄︎` s textovou prezentací (`HabitsCard.swift:152`); nic nenaznačuje podporu od Apple | doporučení: SF Symbol `snowflake` |
| **5.3** Hazard | PASS | žádné náhodné odměny za mince, žádná výměna za reálnou hodnotu | – |
| ITMS-91053 manifesty | **FAIL** | widget bez `PrivacyInfo.xcprivacy` | B2 |
| Export compliance | PASS | `ITSAppUsesNonExemptEncryption = false`; CryptoKit jen pro integritu bitvy (výjimka) | – |

---

## 4. BLOKERY, DŮLEŽITÉ, DOPORUČENÉ

### 4.1 BLOKERY

**B1. Přejmenování na Slaymo není hotové (2.3.7, 4.1, 5.2.1)** → balíček **R3**
- 168 výskytů názvu, bundle ID `com.focusquest.app`, `.widgets`, `.tests` (`project.yml:7, 34, 47, 68`),
  App Group `group.com.focusquest.app` (`Shared/WidgetSnapshot.swift:12`), URL schéma `focusquest`,
  widget `kind = "FocusQuestStatus"`, Focus Filter `title "FocusQuest"` (`FocusFilter.swift:35, 46`).
- Bundle ID, App Group, `kind` widgetu, URL schéma a názvy typů App Intents jsou po vydání napevno. Musí se změnit **před** App ID.

**B2. Widget extension bez privacy manifestu (odmítnutí při nahrání, ITMS-91053)** → **R1**
- `FocusQuestWidgets/` nemá `PrivacyInfo.xcprivacy`, přitom čte UserDefaults (`Shared/WidgetSnapshot.swift:34–60`).

**B3. „Contact the developer“ bez adresy (1.5, 2.1)** → **R2**
- `SettingsView.swift:245–251`: `mailto:` bez příjemce. Bez appky Mail tlačítko tiše nic neudělá.
- Oprava: `mailto:support@slaymo.app`, a když `openURL` vrátí `false`, ukázat list s adresou a „Copy address“.

**B4. Support URL bez kontaktu, se zastaralým obsahem a pod starou adresou (1.5, 2.3.1)** → **R2 + R3**
- `docs/support.html:17`: kontakt jen přes GitHub issues. Ř. 23 popisuje odpuštění prvního zvednutí, které už neplatí.
- `LegalLinks.support` (`SettingsViewModel.swift:7`) míří na `xj2whdvfqw-bot.github.io/focusquest/`.
- Oprava: nový `https://slaymo.app/support` s e-mailem support@slaymo.app a FAQ podle DECISIONS.md.

**B5. Privacy Policy pod starým názvem, bez správce a kontaktu (5.1.1(i), GDPR čl. 13)** → **R2 + R3**
- `docs/privacy.html`: chybí jméno správce (fyzická osoba), e-mail, sekce Streak in danger, widget (App Group), Siri a Zkratky,
  Focus Filter, Live Activity a sdílecí obrázky.
- Oprava: `https://slaymo.app/privacy` s novým datem účinnosti, stejná URL v appce i v App Store Connect.

**B6. Chybí podepsaný Release archiv a nahrání (bez toho není TestFlight ani review)** → **R4**
- `ios.yml` umí jen nepodepsanou Debug IPA a `COMPILE_ONLY` Release.
- Oprava: `release.yml` s `xcodebuild archive` + `-exportArchive` (`app-store-connect`, `upload`) a API klíčem v Secrets.

**B7. Widget bez App Group ukazuje jen výzvu (2.1, 2.5.16)** → **R4**
- Bez entitlementu widget nikdy neukáže data (`Shared/FocusWidgetViews.swift:153`).
- Oprava: App Group `group.app.slaymo` (nebo podle nového bundle ID) v obou targetech. Pokud to nestihne 1.0,
  widget z `FocusQuestWidgetsBundle` dočasně vyřadit (Live Activity zůstane) a vynechat ho z popisu.

**Mimo kód (M1–M4):** viz kapitola 8. Bez nich nejde nic nahrát:
M1 Developer Program, M2 záznam Slaymo v App Store Connect, M3 web slaymo.app a funkční support@slaymo.app,
M4 screenshoty 6,9" a vyplněná metadata.

### 4.2 DŮLEŽITÉ

**D1. Debug zbytky a mrtvý kód v Release binárce (2.3.1, 5.2.1)** → R1
- `ClassChangeSheet.swift:36, 97, 105`, `BattleNotificationService.swift:182–210`, `ProfileSyncService.swift:13, 57, 62`,
  `PlayerStats.swift:196, 202`, ukládání `debugUnlockAllWorlds` (`AppPreferences.swift:191, 202, 311`).
- `AppBlockerManager.swift` s pěti cizími značkami a barvami (`AppDIContainer.swift:16, 40`). Smazat.
- Do CI přidat `strings` kontrolu Release binárky na `Debug:`, `Win now`, `Unlock all worlds`, `Instagram`, `TikTok`.

**D2. Hudba na pozadí (2.5.4)** → R1 + Notes
- Výchozí stav: hudba zapnutá, hlasitost 55 % (`AppPreferences.swift:157, 173`). To je obhajitelné.
- Problém: při posuvníku na 0 % přehrávač běží dál potichu a appka zůstane na pozadí a čte senzor. Přesně tohle Apple
  zamítá („silent audio to stay alive“).
- Oprava: při `ambientVolume < 0.01` přehrávač zastavit (nebo posuvník od 5 %); stejně tak při `Soundscape.off`.
- Ověřit a do Notes popsat, co se děje **bez hudby**: appka se po zamčení uspí, senzor stojí, čas bitvy se dopočítá
  z monotónních hodin a Live Activity odpočítává sama. Bitva musí fungovat i bez hudby, jinak Apple usoudí, že audio slouží
  jen k udržení appky naživu.

**D3. CallKit a pevninská Čína** → App Store Connect
- `CallMonitoringService.swift:1, 15` (`CXCallObserver`). V Pricing and Availability vyřadit **China mainland**.

**D4. Licence a Acknowledgements (5.2.1)** → R2
- V appce chybí obrazovka Acknowledgements, přitom `CREDITS.md:7` tvrdí „…i v Nastavení appky“.
- V CREDITS.md chybí Pixabay: `tap-click.mp3` (denielcz), `reward-chime.mp3` (lolo_s), `fireplace-piano.mp3` (juliush),
  `study-flow.mp3` (luceris). Jsou jen v DECISIONS.md a v komentáři `EffectSounds.swift:5`.
- Pixelify Sans (OFL 1.1): plný text licence v appce nebo `OFL.txt` v bundlu.

**D5. Release build se nikdy netestoval na iPhonu** → TestFlight (kap. 7)

**D6. iOS 17 se netestuje** → R5. Doporučení: zvednout minimum na iOS 18.0, nebo přidat CI na simulátoru iOS 17.5.

**D7. Launch screen bliká** → R1. Barva `LaunchBackground` + `UILaunchScreen › UIColorName`.

**D8. 4 varování kompilátoru + Node 20 v CI** → R1. `nonisolated static let`, `_ = MainActor.assumeIsolated`, `upload-artifact@v5` nebo novější.

**D9. Staré veřejné repo s parodiemi v historii (právní riziko mimo review)** → mimo kód
- Před vydáním založit nové **soukromé** repo bez historie (jen aktuální stav po R3). Staré archivovat nebo smazat
  (nevratný krok, jen na tvůj pokyn). Pozor: soukromé repo spotřebovává minuty Actions (macOS 10×), viz kap. 8.

**D10. Notes for Review jsou nutné** (jinak riziko 2.1 „nepodařilo se ověřit“). Text v kap. 6.9.

**D11. Dostupnost na Macu s Apple Silicon a Vision Pro** → App Store Connect. Vypnout („Designed for iPhone“): Mac nemá
senzor polohy a jádro appky by tam nefungovalo.

**D12. Dynamic Type a VoiceOver nejsou ověřené** → R5. V Accessibility Nutrition Labels zatím tvrdit nejvýš
„Dark Interface“ a „Reduced Motion“.

### 4.3 DOPORUČENÉ
1. `❄︎` → SF Symbol `snowflake` (`HabitsCard.swift:152`).
2. Přejmenovat bosse „Monk Mañana“ (etnický stereotyp). Volitelně „Leonardo da Wi-Fi“ (Wi-Fi je ochranná známka, riziko zanedbatelné).
3. „Vibecoded with artificial intelligence“ (`SettingsView.swift:211`) přeformulovat na „Made with help from AI“
   nebo přesunout do Acknowledgements.
4. Logger subsystem sjednotit s bundle ID (`BattleNotificationService.swift:39`).
5. `NSMotionUsageDescription` zpřesnit na „…lying face-down on the desk…“.
6. Varianty ikony dark a tinted (iOS 18+).
7. Rate this app vrátit v 1.0.1 přes `requestReview()` nebo odkaz `apps.apple.com/app/id…?action=write-review`.
8. Golden JSON test, testy letního času a časových pásem, testy plánování notifikací (R5).
9. Barvy ikon v Nastavení (`.blue`, `.indigo`, `.pink`) sjednotit s `FQColor`.
10. Zvážit, jestli „Streak in danger“ má být výchozí zapnutá (`AppPreferences.swift:172`). Pravidla to nezakazují
    (lokální, po souhlasu), ale uživatelsky je šetrnější opt-in.

---

## 5. Stav balíčků R1–R6

| Balíček | Stav | Co zbývá |
|---|---|---|
| **R1 Release hygiena** | ❌ zbývá vše | manifest widgetu + CI kontrola (B2), debug zbytky a `AppBlockerManager` (D1), hudba při 0 % (D2), varování (D8), kontrola `.m4a` v CI, launch screen (D7), `❄︎` → SF Symbol |
| **R2 Web, právo, kontakt** | ❌ zbývá vše | Support (B4), Privacy (B5), Contact s adresou a „Copy address“ (B3), Acknowledgements + CREDITS.md (D4), AI credit |
| **R3 Přejmenování na Slaymo** | ❌ nezačalo (0× „Slaymo“) | `AppBrand.name`, display name, bundle ID, App Group, URL schéma `slaymo://`, widget kind, Focus Filter, intenty, ikona, web na slaymo.app, CI skripty |
| **R4 Podepisování a TestFlight** | ❌ čeká na účet | `release.yml`, entitlements App Group, `1C8F.1`, offset build number v novém repu, widget s daty (B6, B7) |
| **R5 Stabilita a testy** | ❌ zbývá vše | golden JSON, testy data a notifikací, minimum iOS 18 (D6), Dynamic Type (D12), smoke UI test |
| **R6 Podklady pro App Store** | ❌ zbývá vše | screenshoty 6,9" z CI, finální texty (kap. 6), iPad screenshot pro kontrolu |

---

## 6. Texty pro App Store Connect (anglicky)

### 6.1 Name (30 znaků)
> Slaymo

Volitelně s doplňkem, pokud bude „Slaymo“ samo obsazené: „Slaymo: Focus Boss Battles“ (26).

### 6.2 Subtitle (30 znaků)
> Focus timer with boss battles

(29 znaků. Alternativy: „Put your phone down. Slay.“ (26), „Study timer meets pixel RPG“ (27).)

### 6.3 Keywords (100 znaků, bez názvu a kategorie)
> pomodoro,study,timer,focus,rpg,pixel,habit,streak,homework,concentration,gamified,student,boss,quest

(100 znaků, tedy přesně na limitu. Bez „ADHD“, bez názvů cizích aplikací.)

### 6.4 Promotional Text (170 znaků)
> Put your phone face-down and fight procrastination. Every focused minute hits the boss. Earn coins, gear up your pixel hero and conquer seven worlds.

### 6.5 Description
> Slaymo turns focus time into pixel-art boss battles.
>
> Pick what you're working on, choose a boss and lay your iPhone face-down on the desk. While the phone stays down, your hero keeps attacking. Stay focused until the timer runs out and the boss is knocked out. Pick the phone up and you have 10 seconds to put it back before the boss escapes.
>
> HOW IT WORKS
> • Battles from 5 minutes up to 4 hours, with a free pause in every battle
> • Calls pause the battle automatically
> • Music for focus: lo-fi, fireplace piano, study flow, white or brown noise
> • A Live Activity shows the battle on your Lock Screen and in the Dynamic Island
>
> A WORLD TO CONQUER
> • Seven worlds full of procrastinating bosses, from Snooze Bunny on the farm to the planets of Orbit
> • Each boss is a little longer than the last, so your focus grows step by step
> • Hidden surprises on the map
>
> YOUR HERO, YOUR STYLE
> • Choose Warrior, Mage, Archer or Rogue
> • Earn coins for every focused minute and spend them on weapons, gear and backgrounds
> • Supplies like Extra pause and Streak freeze help when life gets in the way
>
> SEE YOUR PROGRESS
> • Streaks, a habits grid and weekly quests with reward chests
> • Battle log with notes on what you got done
> • Share cards for your week or your streak
>
> WORKS THE WAY YOU DO
> • Home Screen widget with your streak and next boss
> • Siri, Shortcuts and the Action button
> • Focus filter: suggest a battle and mute reminders while a Focus is on
>
> PRIVATE BY DESIGN
> No account, no ads, no tracking, no purchases. Everything stays on your iPhone.

(Řádek o widgetu vynechat, pokud se widget pro 1.0 vyřadí, viz B7. Coins nemají reálnou hodnotu a nedají se koupit.)

### 6.6 What's New (verze 1.0)
> First release. Lay your phone down, beat the boss, build your streak.

### 6.7 URL a ostatní pole
- Support URL: `https://slaymo.app/support`
- Privacy Policy URL: `https://slaymo.app/privacy`
- Marketing URL: `https://slaymo.app` (volitelné)
- Copyright: `2026 [tvé celé jméno]`
- Kategorie: primární **Productivity**, sekundární **Education** (nebo žádná). Ne Games jako primární.
- Cena: **Free**, bez In-App Purchases.
- EULA: Apple Standard EULA.

### 6.8 Věkové hodnocení (dotazník od 2025: stupně 4+, 9+, 13+, 16+, 18+)
| Otázka | Odpověď |
|---|---|
| Parental Controls | No |
| Age Assurance | No |
| Unrestricted Web Access | No |
| User-Generated Content | No |
| Messaging and Chat | No |
| Advertising | No |
| Cartoon or Fantasy Violence | **Infrequent / Mild** (pixeloví bossové jsou „K.O.“, bez krve) |
| Realistic Violence | None |
| Prolonged Graphic or Sadistic Realistic Violence | None |
| Guns or Other Weapons | None (kreslené meče, hole a luky jsou fantasy vybavení; pokud se otázka ptá i na fantasy zbraně, Infrequent) |
| Profanity or Crude Humor | None |
| Mature or Suggestive Themes | None |
| Horror / Fear Themes | None |
| Alcohol, Tobacco or Drug Use or References | None |
| Sexual Content or Nudity | None |
| Medical or Treatment Information | None |
| Health or Wellness Topics | No |
| Simulated Gambling | None |
| Contests | None |
| Loot Boxes | No (truhly mají pevné odměny a nedají se koupit) |
| Made for Kids | No |

Očekávaný výsledek: **9+** (kvůli mírnému kreslenému násilí). Je to bezpečnější varianta než 4+.

### 6.9 App Review Information › Notes
> No account or login is needed. The app is free, has no in-app purchases, no ads, no analytics and makes no network requests. All data stays on the device.
>
> HOW TO TEST THE CORE LOOP (about 6 minutes)
> 1. Finish or skip the short onboarding.
> 2. Tap Fight, pick any focus area and the "Warm-up Wisp" battle (5 minutes).
> 3. Lay the iPhone face-down on a flat surface. The battle starts when the phone lies still, and the boss loses hearts over time. You may lock the screen.
> 4. Lift the phone: a 10-second countdown appears. Put it back down to continue. If you keep it up, the boss escapes and the battle earns nothing (your streak and coins are never lost).
> 5. After 5 minutes the boss is knocked out and you get XP and coins. If the app is in the background, a "Victory!" notification and the Live Activity on the Lock Screen show the result.
> If you test on a stand or cannot move the device, a "Start without sensor" button appears after about 8 seconds.
>
> BACKGROUND AUDIO
> During a battle the app plays focus music or noise chosen by the user (lo-fi, fireplace piano, study flow, white or brown noise). Users lay the phone face-down and often lock it, so the audio must keep playing in the background. Audio stops when the battle ends, when music is turned off in Settings, or when the volume is set to zero. Battles work the same with music off: the remaining time is computed from the clock and the Live Activity counts down on its own.
>
> PHONE CALLS
> CallKit's CXCallObserver is used only to pause the battle while a phone or FaceTime call is active. No call data or numbers are read or stored.
>
> OTHER FEATURES
> • Live Activity: shows the remaining battle time and the boss's health on the Lock Screen and in the Dynamic Island.
> • Home Screen widget: shows the current streak, the next boss and today's focus minutes. Tapping it opens the battle setup.
> • Focus Filter (Settings › Focus › add filter "Slaymo"): can suggest a battle on Home and mute the app's reminders while a Focus is on.
> • Siri and Shortcuts: "Start a battle in Slaymo", "Show my streak in Slaymo", "Pause my battle in Slaymo".
> • Coins are earned only by focusing and have no real-world value. They cannot be bought.

**Demo video:** doporučuji přiložit (do Notes odkaz na neveřejné video, 30–60 s). Mechanika „telefon displejem dolů“
se na stojanu nebo v simulátoru ověřit nedá a video výrazně snižuje riziko zamítnutí 2.1. Natočit: start bitvy, položení,
zamčení, zvednutí s odpočtem, položení zpět, výhra a Live Activity.

### 6.10 App Privacy (štítek)
- „Do you or your third-party partners collect data from this app?“ → **No, we do not collect data from this app.**
- Výsledek: **Data Not Collected**. Tracking: **No**.
- Odpovídá kódu: žádná síť, žádná SDK. E-maily na podporu nejsou sběr přes appku.

---

## 7. Checklist: co musíš udělat ty ručně

### App Store Connect
- [ ] Apple Developer Program jako **individual** (jméno prodejce bude tvé celé jméno).
- [ ] Prověřit „Slaymo“: App Store (iPhone i iPad), EUIPO a USPTO (třídy 9 a 41), doména slaymo.app je tvoje.
- [ ] My Apps › New App: název Slaymo (tím se rezervuje), English (U.S.), bundle ID z R3, SKU např. `slaymo-001`.
- [ ] **EU DSA:** prohlásit se za **non-trader**. Bezplatná appka fyzické osoby bez příjmů a bez obchodního záměru.
      Dopady: v EU se nezobrazí adresa ani telefon, jen jméno. Kdybys později zavedl placení nebo reklamu, musíš
      status změnit na trader a zveřejnit kontaktní údaje. Bez vyplnění se appka v EU nezobrazí.
- [ ] Pricing: Free. Availability: všechny země **kromě China mainland** (D3).
- [ ] Vypnout dostupnost na Macu s Apple Silicon a na Apple Vision Pro (D11).
- [ ] Kategorie, věkové hodnocení (6.8), App Privacy (6.10), texty (6.1–6.7), Notes (6.9), kontakt pro review (tvůj telefon a e-mail, Apple je nezveřejní).
- [ ] Accessibility Nutrition Labels: nejvýš Dark Interface a Reduced Motion (nic, co není ověřené).
- [ ] Export compliance: nic nevyplňovat, `ITSAppUsesNonExemptEncryption = NO` ho vyřeší.

### Screenshoty
- [ ] **iPhone 6,9" povinné:** 1320 × 2868 (nebo 1290 × 2796), na výšku, 1–10 kusů, bez alfa kanálu. Menší velikosti se dopočítají.
- [ ] iPad screenshoty **nejsou potřeba** (appka je jen pro iPhone).
- [ ] Doporučené záběry: 1) bitva s hrdinou a bossem, 2) mapa světů, 3) výběr bitvy, 4) Shop, 5) Stats se sérií,
      6) Live Activity na zamčené obrazovce, 7) výhra. Jen skutečná appka (2.3.3), bez debug karty a bez slibů, které appka neplní.

### TestFlight
1. Po R4 spustit `release.yml`, build se do 10–30 minut objeví v App Store Connect › TestFlight.
2. Internal Testing: skupina s tebou, bez Beta App Review. Instalace přes aplikaci TestFlight.
3. Testovat **na fyzickém iPhonu** na nejnižším podporovaném iOS (18.0 po D6, jinak 17.x) i na nejnovějším iOS 26.x.
4. Checklist Release buildu:
   - [ ] čistá instalace, onboarding, tutoriál (Skip, Replay),
   - [ ] Warm-up 5 min do výhry se zamčeným telefonem; notifikace Victory, Live Activity, Dynamic Island,
   - [ ] zvednutí s odpočtem a položení, zvednutí do útěku bosse, pauza zdarma, Extra pause, Retreat,
   - [ ] **bitva s vypnutou hudbou** se zamčeným telefonem (D2), hudba na 0 % (appka nesmí zůstat na pozadí),
   - [ ] příchozí hovor během bitvy, zabití appky během bitvy,
   - [ ] odemčení dalšího světa, easter egg, týdenní truhla, Streak freeze přes noc,
   - [ ] Shop: Gear, Backgrounds, Supplies, sloty, Class Potion,
   - [ ] notifikace: povolení po první výhře, odmítnutí, Daily reminder, Streak in danger, Break is over,
   - [ ] widget s daty (App Group), Siri a Zkratky, Action button, Focus Filter,
   - [ ] Nastavení: Privacy, Terms, Support, Contact otevřou funkční cíl; **v Release není Debug karta, Win now ani Change class (free)**,
   - [ ] Reset progress,
   - [ ] iPhone SE a Pro Max, největší písmo, VoiceOver na hlavních obrazovkách, Reduce Motion,
   - [ ] změna časového pásma, bitva přes půlnoc,
   - [ ] update build N → N+1 přes TestFlight, data zůstanou,
   - [ ] hodinová bitva s hudbou a zamčeným telefonem, pak Nastavení › Baterie.
5. Pak App Store › verze 1.0 › vybrat build › Add for Review › Submit.

---

## 8. Co chybí ode mě mimo kód

| # | Co | Proč | Kdy |
|---|---|---|---|
| 1 | Apple Developer Program (99 USD/rok, individual) | bez něj nejde App ID, signing ani upload | hned, schválení 1–2 dny |
| 2 | Rezervace názvu Slaymo v App Store Connect | 2.3.7, nikdo jiný ho pak nezabere | hned po účtu |
| 3 | App ID appky a widgetu, App Group | po R3 (bundle ID se po vydání nedá změnit) | po R3 |
| 4 | App Store Connect API klíč (App Manager) → GitHub Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`; Team ID | R4 | po účtu |
| 5 | Web slaymo.app: `/privacy`, `/support`, `/terms` (nebo odkaz na Apple EULA), HTTPS | povinné URL v ASC | před R2 nasazením |
| 6 | Funkční schránka support@slaymo.app (přeposílání na tvou poštu) | 1.5; reviewer ji může vyzkoušet | před odesláním |
| 7 | Finální ikona Slaymo (1024 × 1024, bez průhlednosti a zaoblení), volitelně dark a tinted | R3 | před R3 |
| 8 | Screenshoty a demo video phone-down | 2.3.3, D10 | po R6 |
| 9 | Nové čisté **soukromé** repo bez historie s parodiemi | D9 | před R3 nebo spolu s ním |
| 10 | Důkazy licencí (snímky stránek FMA a Pixabay s datem) v soukromé složce | 5.2.1 | kdykoli |

Pozor u bodu 9: v soukromém repu se minuty GitHub Actions počítají (macOS runner 10× rychleji, bezplatný účet
má 2 000 minut měsíčně, tedy zhruba 200 minut macOS, jeden build trvá kolem 39 minut). Možnosti:
- web slaymo.app hostovat zvlášť (GitHub Pages z malého veřejného repa jen s webem, nebo Cloudflare Pages),
- buildy v soukromém repu omezit na release a občasné kontroly, nebo přejít na placený plán GitHub.

---

## 9. Prompty na opravy

Doporučení modelu: **Sonnet 5.5** na mechanické balíčky, **Opus 5.5** na balíčky, kde jde o signing, přejmenování
identifikátorů nebo logiku dat. Každý prompt začíná stejně: „Načti CLAUDE.md, design/DECISIONS.md, design/progress.html
a design/RELEASE_AUDIT_FINAL.md.“

### R1 Release hygiena (Sonnet 5.5, effort medium, 1 session)
> Načti CLAUDE.md, design/DECISIONS.md, design/progress.html a design/RELEASE_AUDIT_FINAL.md. Proveď balíček R1 podle kap. 4 a 5:
> 1. Přidej `FocusQuestWidgets/PrivacyInfo.xcprivacy` (UserDefaults `CA92.1`, tracking false, prázdné domény a sběr dat) a do `scripts/ci-build-ipa.sh` kontrolu, že je v `PlugIns/*.appex`.
> 2. `Mode.debugFree` v `ClassChangeSheet`, `scheduleTestNotifications`, `pendingSummary`, `setLevel` a `grantBonusXP` obal `#if DEBUG`; `debugUnlockAllWorlds` ukládej jen v Debug. Smaž `AppBlockerManager` i z `AppDIContainer` (klíč `focusquest.blocked-apps` dál mazat při resetu).
> 3. Do CI přidej `strings` kontrolu Release binárky: nesmí obsahovat `Debug:`, `Win now`, `Unlock all worlds`, `Instagram`, `TikTok`.
> 4. `AudioAtmosphereService`: při hlasitosti pod 0,01 nebo `Soundscape.off` přehrávač zastav a audio session deaktivuj. Přidej unit test.
> 5. Oprav 4 varování (`nonisolated static let`, `_ = MainActor.assumeIsolated`) a zvedni `actions/upload-artifact` na verzi s Node 24.
> 6. Launch screen: barva `LaunchBackground` v asset catalogu a `UILaunchScreen › UIColorName`.
> 7. Kontrola převedených `.m4a` v CI. `❄︎` v `HabitsCard.swift:152` nahraď SF Symbolem `snowflake`.
> Commit, push, CI build, výsledky do progress.html.

### R2 Web, právo, kontakt (Sonnet 5.5, effort medium, 1–2 session)
> Načti … Proveď balíček R2:
> 1. `contactDeveloper()`: `mailto:support@slaymo.app` s předmětem; když `openURL` selže, list s adresou a tlačítkem „Copy address“.
> 2. Nastavení › About › Acknowledgements: hudba (HoliznaCC0, CC0), Pixabay (4 soubory s autory), Pixelify Sans s plným textem OFL 1.1. Doplň tabulku Pixabay do CREDITS.md a oprav ř. 7.
> 3. Přepiš `docs/support.html` (FAQ podle DECISIONS.md: jediný odpočet bez odpuštění, Notifications, Streak freeze, Extra pause, Class Potion, widget, Focus Filter, Siri; e-mail support@slaymo.app; odkaz na Privacy).
> 4. Přepiš `docs/privacy.html`: správce [jméno], kontakt support@slaymo.app, sekce Streak in danger, widget (App Group), Siri a Zkratky, Focus Filter, Live Activity, sdílecí obrázky, nové datum účinnosti.
> 5. „Vibecoded with artificial intelligence“ → „Made with help from AI“ v Acknowledgements.
> Commit, push, CI.

### R3 Přejmenování na Slaymo (Opus 5.5, effort high, 1–2 session)
> Načti … a kap. 7 v design/RELEASE_AUDIT.md. Přejmenuj appku na Slaymo:
> 1. Konstanta `AppBrand.name` v `Shared/`, všechny viditelné texty (Onboarding, Settings, notifikace, Focus Filter, intenty, sdílecí obrázky, Live Activity, widget).
> 2. Display name appky i widgetu, `NSMotionUsageDescription`, bundle ID (`app.slaymo` / `app.slaymo.widgets` / `app.slaymo.tests` – potvrď se mnou před commitem), App Group `group.app.slaymo`, URL schéma `slaymo://`, widget `kind`, Logger subsystem.
> 3. Rozhodni názvy typů App Intents a Focus Filteru teď (po vydání napevno).
> 4. Klíče UserDefaults a identifikátory notifikací **neměň**.
> 5. LegalLinks na `https://slaymo.app/privacy` a `/support`; web v `docs/` přejmenuj.
> 6. Nová ikona z `[cesta]`, varianty dark a tinted.
> 7. CI skripty a dokumentace. Na konci `git grep -niE "focus ?quest"` smí vrátit jen interní klíče.
> Přejmenuj také „Monk Mañana“. Commit, push, CI.

### R4 Podepisování a TestFlight (Opus 5.5, effort high, 1–2 session, po účtu a R3)
> Načti … a design/DEVELOPER_ACCOUNT_TODO.md. Proveď R4:
> 1. `DEVELOPMENT_TEAM` do obou targetů, entitlements App Group pro appku i widget, důvod `1C8F.1` do obou privacy manifestů.
> 2. `.github/workflows/release.yml` (workflow_dispatch): převod hudby, `xcodegen`, `xcodebuild archive -configuration Release -allowProvisioningUpdates` s API klíčem ze Secrets, `-exportArchive` (method `app-store-connect`, destination `upload`).
> 3. Build number v novém repu: `run_number + 1000`.
> 4. Ověř, že widget ukazuje data přes App Group (Debug › Debug widget hlásí „Shared with widget“).
> Commit, push, spusť release.yml, výsledek do progress.html.

### R5 Stabilita a testy (Opus 5.5, effort high, 2 session, souběžně s R2)
> Načti … Proveď R5: golden JSON fixture dnešní verze a test načtení, obnova `.unreadable-backup` při startu, testy letního času a změny časového pásma (série, Habits, týdenní úkoly, freeze), testy plánování notifikací přes protokol nad `UNUserNotificationCenter`, test deep linku a intentů během bitvy, minimum iOS 18.0 (odstraň větve jen pro 17), Dynamic Type u textů (`@ScaledMetric` / textové styly, ne u spritů), jeden smoke UI test onboarding → bitva → výhra. Commit, push, CI.

### R6 Podklady pro App Store (Sonnet 5.5, effort medium, 1 session, po R3)
> Načti … Proveď R6: skript `scripts/ci-screenshot.sh` rozšiř o iPhone 17 Pro Max (1320 × 2868) s ukázkovými daty z Debug launch argumentů pro 7 záběrů z kap. 7 (bez debug UI) a o jeden snímek na simulátoru iPadu (kontrola kompatibilního režimu). Výstup jako artefakt CI. Texty z kap. 6 zkontroluj proti finální appce (počty znaků) a ulož do `design/APPSTORE_METADATA.md`.
