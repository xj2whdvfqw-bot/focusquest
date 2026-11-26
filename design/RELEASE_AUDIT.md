# Audit před vydáním na App Store

Stav k 26. 11. 2026, větev `phase3-duolingo`, poslední zelený build #91 (145 unit testů prošlo, Release se kompiluje).
Audit nic neopravuje, jen popisuje stav. Podklady: `CLAUDE.md`, `design/DECISIONS.md`, `design/progress.html`,
`design/DEVELOPER_ACCOUNT_TODO.md`, `CREDITS.md`, celý kód v `FocusQuest/`, `Shared/`, `FocusQuestWidgets/`, `Support/`,
`project.yml`, CI (`.github/workflows/ios.yml`, `scripts/`), web v `docs/` a log CI buildu #91.

Pracovní název v celém dokumentu je **FocusQuest**. Finální název se teprve vybere, texty pro App Store Connect
proto používají `[APP NAME]`.

---

## 1. Shrnutí

**Verdikt: s výhradami.** Aplikace je funkčně hotová, stabilní a technicky v dobrém stavu. Do App Review ale zatím odeslat nejde.
Brání tomu hlavně věci mimo kód: placený účet, nový název, e-mail pro podporu a signing v CI.
V kódu jsou čtyři menší blokery (privacy manifest widgetu, Contact bez adresy, widget bez dat, zastaralý web podpory).

Co je v pořádku:
- Debug funkce (Win now, Unlock all worlds, +1000 coins, Change class (free), Debug widget, testovací notifikace) jsou v UI
  za `#if DEBUG`. CI kompiluje i Release.
- Žádná síť, žádné SDK, analytika, reklamy ani účty. Štítek „Data Not Collected“ odpovídá kódu.
- Privacy manifest appky existuje, `ITSAppUsesNonExemptEncryption = NO` je správně (CryptoKit jen pro integritu bitvy).
- Ikona 1024 × 1024 je RGB bez alfa kanálu.
- Force unwrapy jsou jen tři (konstantní URL v `LegalLinks`, `hosting.view!`) a jsou bezpečné.
- Data se dekódují tolerantně (`decodeIfPresent`) a nečitelná data se zálohují. Migrace starších verzí pokrývá zhruba 20 testů.
- Práce s datem jde přes `Calendar` (žádné `86400`), notifikace se plánují v místním čase.

**Odhad zbývající práce:**
- Kód: 6 balíčků (R1–R6, kapitola 6), zhruba 6–9 pracovních session. Z toho jsou 2–3 session nutné (R1, R2, R4 a část R3).
- Mimo kód: schválení Developer účtu (obvykle 1–2 dny), výběr názvu a loga, e-mail, texty a screenshoty v App Store Connect.
- Review a TestFlight: počítej s 1–2 týdny kalendářního času.

---

## 2. BLOKERY

Co by vedlo k odmítnutí při nahrání nebo v App Review, nebo k právnímu problému.

### B1. Název „FocusQuest“ je obsazený (2.3.7, 5.2.1)
- **Kde:** všude, viz inventář v kapitole 7.
- **Proč:** v App Store existuje víc aplikací s tímto názvem, mj. „Focus Quest: Study buddy“ (Shikudo) se stejným konceptem.
  - App Store Connect nedovolí stejný název.
  - Podobný název u stejného konceptu je riziko kvůli ochranné známce a zamítnutí jako matoucí (5.2.1, 4.1).
  - Bundle ID `com.focusquest.app` je globálně unikátní. Může ho mít registrovaný někdo jiný a navíc odkazuje na cizí značku.
- **Jak opravit:** vybrat nový název, ověřit ho (App Store, ochranné známky EUIPO a USPTO, doména) a založit záznam
  v App Store Connect, který název zarezervuje. Pak přejmenovat jedním balíčkem R3 **před** vytvořením App ID a App Group.

### B2. Widget Extension nemá privacy manifest (ITMS-91053)
- **Kde:** `FocusQuestWidgets/`, nemá žádný `PrivacyInfo.xcprivacy`. Widget kompiluje `Shared/WidgetSnapshot.swift`,
  který čte `UserDefaults.standard` i `UserDefaults(suiteName:)`.
- **Proč:** od května 2024 App Store Connect odmítne nahrání, když bundle používá Required Reason API bez deklarace.
  Kontroluje se každý bundle zvlášť, tedy i `.appex`.
- **Jak opravit:**
  - Přidat `FocusQuestWidgets/PrivacyInfo.xcprivacy`: UserDefaults s důvodem `CA92.1`, tracking `false`, sběr dat prázdný.
  - Po zapnutí App Group přidat v obou manifestech důvod `1C8F.1` (přístup ke sdíleným UserDefaults v App Group).
  - Do `scripts/ci-build-ipa.sh` přidat kontrolu `PlugIns/FocusQuestWidgets.appex/PrivacyInfo.xcprivacy`.

### B3. „Contact the developer“ nemá adresu (2.1, 1.5)
- **Kde:** `FocusQuest/Views/Settings/SettingsView.swift:245–251` (`contactDeveloper()`) skládá `mailto:` jen s předmětem.
- **Proč:**
  - Reviewer otevře Mail s prázdným příjemcem, což působí jako nefunkční tlačítko.
  - Bez nainstalované appky Mail `openURL` tiše nic neudělá.
  - Guideline 1.5 chce snadný kontakt na vývojáře v appce i na Support URL.
- **Jak opravit:**
  - Doplnit samostatnou adresu podpory (ne osobní e-mail, viz kapitola 5).
  - Když Mail chybí (`openURL` vrátí `false`), ukázat list s adresou a tlačítkem „Copy address“.
  - Adresu nikdy necommitovat, dokud je repo veřejné s historií (viz B6). Stačí ji vložit až do čistého repa.

### B4. Web podpory nemá kontakt a popisuje starou verzi (1.5, 2.3.1)
- **Kde:** `docs/support.html`.
- **Proč:**
  - Jediný kontakt je „open an issue on GitHub“. Vyžaduje účet na GitHubu a vede do veřejného repa se starou historií.
    Apple chce, aby Support URL obsahovala snadný kontakt.
  - Text je v rozporu s appkou:
    - ř. 23 „The first slip in a battle is forgiven. After the second…“: od E1 platí jediný odpočet bez odpuštění,
    - ř. 32 „Settings › Sounds & notifications“: dnes je to podstránka „Notifications“,
    - chybí Streak freeze, Extra pause, Class Potion, widget, Focus Filter a Siri.
- **Jak opravit:** přepsat FAQ podle DECISIONS.md, přidat e-mail a odkaz na Privacy. Viz R2.

### B5. Widget bez App Group ukazuje jen „Open FocusQuest“ (2.1, 4.2)
- **Kde:** `Shared/WidgetSnapshot.swift` (`sharedDefaults`), `Shared/FocusWidgetViews.swift:153`.
- **Proč:** bez entitlementu App Group widget nikdy neukáže data. Reviewer, který si widget přidá, uvidí jen výzvu.
  To se hodnotí jako nedokončená funkce.
- **Jak opravit:** s placeným účtem zapnout App Group podle `DEVELOPER_ACCOUNT_TODO.md` §1 (balíček R4).
  Pokud by to nestihlo verzi 1.0, widget z `FocusQuestWidgetsBundle` pro 1.0 vyřadit (Live Activity zůstane).

### B6. Veřejné repo s parodiemi v historii (právní riziko, mimo App Review)
- **Kde:** veřejné repo `xj2whdvfqw-bot/focusquest`. Staré commity obsahují tři odstraněné parodické světy
  (klíče `heroes`, `villains`, `fairyTale`, `sewerDojo`, `brainrot` v `BossWorld.legacyWorldKeys` jen připomínají,
  co tam bylo).
- **Proč:** cizí chráněné postavy ve veřejně stažitelném zdrojáku stejné aplikace. Riziko je malé, ale zbytečné.
  Support web navíc odkazuje přímo na toto repo.
- **Jak opravit:** před vydáním založit nové čisté repo bez historie (jen poslední stav), přesunout tam GitHub Pages a CI
  a staré repo archivovat jako soukromé nebo smazat. Jde to bez přepisování historie. Nevratné kroky jen na výslovný pokyn.

### B7. Chybí podepsaný Release archiv a nahrání do App Store Connect
- **Kde:** `.github/workflows/ios.yml` umí jen nepodepsanou Debug IPA a kompilaci Release, bez `archive` a `-exportArchive`.
- **Proč:** bez placeného účtu a signingu v CI nejde nahrát build ani do TestFlightu. To je zatím nejtvrdší bloker.
- **Jak opravit:** balíček R4.
  - Samostatný workflow `release.yml` (ruční spuštění):
    - převod hudby `afconvert`,
    - `xcodegen`,
    - `xcodebuild archive -configuration Release -allowProvisioningUpdates` s App Store Connect API klíčem z GitHub Secrets,
    - `-exportArchive` (method `app-store-connect`, destination `upload`).
  - Build number z `github.run_number` už funguje.

---

## 3. DŮLEŽITÉ

Opravit před vydáním: kvalita, pády, UX a věci, které reviewer snadno najde.

### D1. Zbytky debug kódu v Release binárce
UI je čisté, ale v Release se dál kompiluje:
- `FocusQuest/Views/Profile/ClassChangeSheet.swift:36, 97, 105`: případ `Mode.debugFree` s texty „Debug: changes the class for free…“.
- `FocusQuest/Hardware/BattleNotificationService.swift:177–210`: `scheduleTestNotifications()` a `pendingSummary()`.
- `FocusQuest/BackendServices/ProfileSyncService.swift:13, 62`: `setLevel` (jen pro Debug) a `PlayerStats.setLevel` / `grantBonusXP`.
- `FocusQuest/Models/Domain/AppPreferences.swift:311`: `debugUnlockAllWorlds` se v Release dekóduje a ignoruje. To je OK,
  ale pole by se nemělo ani ukládat.
- `FocusQuest/Hardware/AppBlockerManager.swift`: mrtvý kód s maketou blokování a názvy a barvami značek
  Instagram, Facebook, LinkedIn, TikTok, YouTube. UI ho už nepoužívá, `AppDIContainer` ho jen vytváří.

**Proč:** nejde o přímé zamítnutí, ale stringy „Debug: …“ a cizí značky v binárce jsou zbytečné riziko (2.3.1, 5.2.1).
**Jak opravit:** obalit `#if DEBUG`, `AppBlockerManager` smazat i s klíčem `focusquest.blocked-apps` (při resetu se maže).
Do CI přidat kontrolu, že Release binárka neobsahuje stringy `Win now`, `Unlock all worlds`, `Debug:`.

### D2. Hudba na pozadí s nulovou hlasitostí (2.5.4)
- **Kde:** `FocusQuest/Audio/AudioAtmosphereService.swift:41–43` (`targetVolume`) a posuvník `SettingsView.swift:446–449`
  (rozsah `0...1`).
- **Proč:** `UIBackgroundModes = audio` je obhajitelný jen tehdy, když opravdu hraje zvuk. Při hlasitosti 0 % přehrávač běží
  potichu, appka zůstane na pozadí a hlídá senzor. To Apple považuje za zneužití režimu pozadí.
- **Jak opravit:**
  - Při `ambientVolume < 0.01` přehrávač zastavit stejně jako při vypnuté hudbě (nebo dát posuvníku minimum 5 %).
  - Do poznámek pro review napsat, proč je audio na pozadí potřeba (viz kapitola 8).

### D3. CallKit a čínský App Store
- **Kde:** `FocusQuest/Hardware/CallMonitoringService.swift` (`CXCallObserver`).
- **Proč:** Apple u aplikací, které linkují CallKit, opakovaně vyžaduje vyřazení z pevninské Číny (regulace MIIT).
  Týká se to i aplikací, které jen sledují hovory.
- **Jak opravit:** v App Store Connect › Pricing and Availability vyřadit **China mainland**. Kód se nemění.

### D4. Privacy Policy je neúplná
- **Kde:** `docs/privacy.html`.
- **Proč:** v sekci Notifications chybí „Streak in danger“. Chybí Siri a Zkratky, Focus Filter, Live Activity, widget
  (snímek dat v App Group) a sdílecí obrázky (volitelné jméno). Kontakt odkazuje jen na Support, kde e-mail také není.
  Po zapnutí iCloudu bude potřeba sekce o iCloud Key-Value Storage (data jdou přes Apple, ne k vývojáři;
  štítek zůstává „Not Collected“).
- **Jak opravit:** doplnit sekce, uvést e-mail a jméno správce (podle účtu: fyzická osoba), nové datum účinnosti. Balíček R2.

### D5. Chybějící přiznání licencí v appce a v CREDITS.md
- **Kde:** `CREDITS.md`, Nastavení (žádná obrazovka Acknowledgements).
- **Proč:**
  - CREDITS.md tvrdí „Autora přesto uvádíme tady i v Nastavení appky“, ale v appce o HoliznaCC0 nic není.
  - V CREDITS.md chybí čtyři soubory z Pixabay: `tap-click.mp3`, `reward-chime.mp3`, `fireplace-piano.mp3`
    a `study-flow.mp3`. Jsou jen v DECISIONS.md.
  - SIL OFL 1.1 (Pixelify Sans) vyžaduje, aby každá kopie fontu měla copyright a text licence. Splní to metadata TTF,
    ale jistější je přiložit `OFL.txt` nebo licenci ukázat v appce.
- **Jak opravit:**
  - Doplnit CREDITS.md (Pixabay tabulka s původními názvy souborů a autory).
  - Přidat Nastavení › About › „Acknowledgements“: hudba (HoliznaCC0, Pixabay autoři), font (OFL 1.1 s plným textem).
  - Uložit důkazy licencí (snímky stránek nebo odkazy na web.archive.org), viz kapitola 5.

### D6. Release se nikdy netestoval na skutečném iPhonu
- **Kde:** Sideloadly dostává Debug IPA (`CONFIG=Debug`). Release jen kompiluje CI.
- **Proč:**
  - Release má optimalizace (`-O`) a jiné chování časování, Swift Concurrency i SwiftUI animací.
  - Bez debug karty se nedá rychle projít hra, takže chyby v Release tocích (odemykání světů, ceny) nikdo neviděl.
- **Jak opravit:**
  - TestFlight (interní testeři) projít s Release buildem podle checklistu v kapitole 8.
  - Do té doby volitelně přidat v CI i nepodepsanou Release IPA pro Sideloadly.

### D7. Varování překladače (Swift 6)
CI build #91 hlásí 4 unikátní varování:
- `FocusQuest/Views/Shop/ShopStallArt.swift`: `StallPedestal.heightInPixels` a `pad` (main actor-isolated v nonisolated kontextu),
- `FocusQuest/Views/Arena/BattleStage.swift`: `BattleStage.finaleSeconds` (totéž),
- `FocusQuest/Hardware/CallMonitoringService.swift:56`: nevyužitý výsledek `MainActor.assumeIsolated`.

**Proč:** v budoucím Xcode se z nich stanou chyby. Teď jsou neškodná (delegát hovorů běží na `.main`, takže `assumeIsolated` je bezpečné).
**Jak opravit:** konstanty označit `nonisolated static let`, výsledek `_ =`.
V CI je ještě varování Node 20 u `actions/upload-artifact@v4`: zvednout na verzi, která běží na Node 24.

### D8. Minimální iOS 17 se netestuje
- **Kde:** `project.yml` (`deploymentTarget iOS 17.0`), CI testuje jen na iPhonu 17 a SE se simulátorem iOS 26.
- **Proč:** kód má větve `#available(iOS 26)` a speciální řešení pro iOS 17 (`fqContainer`, nadpis Settings, `containerShape`).
  Na iOS 17 a 18 je nikdo nespustil. Pád nebo rozbitý layout na starším iOS najde reviewer jen náhodou, uživatelé určitě.
- **Jak opravit (rozhodnutí):** doporučuji **zvednout minimum na iOS 18.0**. iOS 17 má v roce 2026 malý podíl
  a ubude jedna sada větví. Když chceš iOS 17 držet, přidat do CI unit testy a screenshoty na simulátoru iOS 17.x
  (runtime je potřeba doinstalovat přes `xcodebuild -downloadPlatform iOS -buildVersion 17.5`).

### D9. Launch screen bliká
- **Kde:** `FocusQuest/Config/Development.xcconfig` (`INFOPLIST_KEY_UILaunchScreen_Generation = YES` bez barvy).
- **Proč:** prázdná systémová launch screen je bílá nebo černá podle režimu, appka je tmavá. Vznikne záblesk při startu.
  Odmítnutí to není, ale vypadá to nedotaženě.
- **Jak opravit:** přidat do asset catalogu barvu `LaunchBackground` (tmavá z `FQColor`) a nastavit
  `UILaunchScreen` › `UIColorName`, volitelně `UIImageName` s logem.

### D10. Odolnost uložených dat
- **Kde:** `FocusQuest/Utilities/AppStateStore.swift`, `FocusQuest/BackendServices/ProfileSyncService.swift:96–116`.
- **Proč:**
  - `formatVersion = 1` se zapisuje, ale nikde nečte. Migrace stojí jen na tolerantních dekodérech, což je v pořádku.
  - Když ale selže dekódování **povinného** pole profilu, appka vytvoří nového hrdinu. Původní data jsou sice
    v `.unreadable-backup`, ale hráč je nemá jak obnovit.
- **Jak opravit:**
  - Přidat „golden“ test: zamražený JSON dnešní verze (profil, statistiky, nastavení) v `FocusQuestTests/Fixtures`
    a test, že se načte. Každá budoucí změna modelu tak musí zůstat zpětně kompatibilní.
  - Při startu zkusit zálohu znovu dekódovat (po aktualizaci appky může jít) a případně ji obnovit.

### D11. Poznámky pro reviewera a rychlá bitva
**Proč:** reviewer nemusí pochopit, že bitva běží jen s telefonem displejem dolů. Nebude čekat 10 minut a na stojanu
uvidí jen „Lay the phone…“. Hrozí zamítnutí 2.1 „nepodařilo se ověřit funkčnost“.
**Jak opravit:** v App Review Information napsat přesný postup (text v kapitole 8). Rozcvička Warm-up Wisp trvá 5 minut
a „Start without sensor“ se objeví po 8 s. Kód se nemění.

### D12. Dynamic Type jen částečně
- **Kde:** 88 výskytů `.font(.system(size: N…))` v `FocusQuest/` a `Shared/` (pevná velikost, nereaguje na nastavení písma).
- **Proč:** DECISIONS.md uvádí Dynamic Type jako hotové, ale pevné velikosti nerostou. Reviewer to nehodnotí.
  Accessibility Nutrition Label „Larger Text“ ale v tomto stavu tvrdit nejde.
- **Jak opravit:** u textů (ne u pixelových spritů) použít `.font(.system(.body…))` nebo `@ScaledMetric`.
  Ověřit na SE s největším písmem. Balíček R5.

---

## 4. DOPORUČENÉ

Dobré mít, ale vydání to nezastaví.

1. **Text „Vibecoded with artificial intelligence“** (`SettingsView.swift:211`).
   - Žádné pravidlo App Review to nezakazuje a Apple nevyžaduje ani nezakazuje přiznání AI.
   - Riziko zamítnutí je malé. Slangové „vibecoded“ ale může u reviewera i uživatelů vzbudit dojem rychlokvašky
     (spam, 4.3) a v recenzích se to dá použít proti appce.
   - Doporučuji přeformulovat („Made with help from AI“) nebo přesunout do Acknowledgements. Rozhodnutí je na tobě.
2. **Barvy ikon v Nastavení:** `.blue` (Contact the developer, Tap sounds, iCloud), `.indigo`, `.pink`, v Debug `.teal`.
   Napodobují systémové Nastavení, ale design system říká „žádná systémová modrá a tyrkysová“. Sjednotit na barvy z `FQColor`.
3. **Časová pásma a cestování:** dny se počítají v aktuálním pásmu (`PlayerStats.dayKey`). Po letu přes pásma se bitva může
   přesunout do sousedního dne, takže se série jednou zvýší dvakrát nebo zdánlivě přeruší.
   - Je to přijatelné, ale chybí na to testy.
   - Doplnit testy přechodu na letní a zimní čas (Europe/Prague 29. 3. a 25. 10.), zóny s půlnočním DST (America/Santiago)
     a změny zóny pro `currentStreak`, `HabitGrid.make`, `WeeklyQuests.make` a `StreakFreeze.daysToFreeze`.
4. **Týden začíná vždy v pondělí** (`HabitGrid.weekStart`). Pro americké uživatele nezvyk. Zvážit `calendar.firstWeekday`
   s ohledem na uložené `weekKey` (vyzvednuté truhly).
5. **Rate this app:** Apple ID aplikace vznikne už při založení záznamu v App Store Connect, ale odkaz funguje až po vydání.
   Doporučuji ho vrátit ve verzi 1.0.1. Ve verzi 1.0 by reviewer viděl „aplikace není dostupná“.
6. **Kontrast terciárního textu** (bílá 50 % na tmavém skle) u malých písem nemusí splnit 4,5 : 1. Zkontrolovat v Accessibility
   Inspectoru (na Macu) nebo nástrojem nad screenshoty z CI.
7. **Baterie:** `TimelineView` bitvy je úsporná (2 snímky/s mezi útoky). Na pozadí se nekreslí nic.
   - Ověřit, že částice `StreakFire` a dýchání spritů neběží na skrytých záložkách.
   - Test: hodinová bitva se zamčeným telefonem a s hudbou, pak Nastavení iPhonu › Baterie (podíl aplikace).
8. **`NSMotionUsageDescription`:** `CMDeviceMotion` oprávnění nevyžaduje, takže text iOS neukáže. Neškodí.
   Zpřesnit na „…is lying face-down on the desk…“, aby odpovídal realitě.
9. **iPad a Mac:** appka je jen pro iPhone (`TARGETED_DEVICE_FAMILY = 1`). Na iPadu poběží v kompatibilním okně;
   reviewer ji tam občas spustí, takže jednou otestovat v simulátoru iPadu (CI screenshot).
   V App Store Connect **vypnout dostupnost na Macu s Apple Silicon** („Designed for iPhone“): Mac nemá senzor polohy.
10. **Dlouhodobý cíl po dobytí všech světů:** 52 bossů je asi 24 hodin soustředění. Pak zbývají jen vlastní bitvy a Shop.
    Do 1.0 to nevadí, je to námět na 1.1 (nové světy, Game Center).
11. **Ochranné známky v textech** (nízké riziko, jen posouzení):
    - Historické osobnosti (Napoleon, Kleopatra, Caesar, Shakespeare, Leonardo, Mozart, Newton, Karel IV., Komenský) jsou volné.
    - Excalibur, Kraken a vikingská helma jsou mýty a obecné pojmy, takže v pořádku.
    - „Leonardo da Wi-Fi“ používá ochrannou známku Wi-Fi Alliance jako slovní hříčku. Riziko je zanedbatelné;
      kdo chce mít klid, přejmenuje bosse.
12. **Accessibility Nutrition Labels** (nové v App Store Connect): nic netvrdit, dokud nejsou ověřené všechny hlavní úkoly.
    Reálně jde zatím tvrdit nejvýš „Reduced Motion“ (19 souborů reaguje na Reduce Motion) a „Dark Interface“.
    VoiceOver ani Larger Text zatím ne (viz D12).
13. **CloudSync a reset:** před zapnutím iCloudu rozhodnout, zda Reset maže i `fq.state` v KVS (viz DEVELOPER_ACCOUNT_TODO.md §2.7).
    Pro 1.0 doporučuji **iCloud nezapínat**: méně rizika a sekce v Nastavení je skrytá.

---

## Podrobné nálezy podle oblastí

### A – App Store Review Guidelines

| Guideline | Stav | Poznámka |
|---|---|---|
| 2.1 Kompletnost | ⚠️ | B3 (Contact), B5 (widget), D11 (poznámky pro review). Placeholdery, „coming soon“ ani prázdné obrazovky v kódu nejsou (grep na `soon`, `TODO`, `placeholder`, `lorem`). |
| 2.3 Metadata | ⚠️ | Screenshoty musí ukazovat skutečnou appku. Popis nesmí slibovat blokování aplikací (maketa pryč, D1) ani zdravotní účinky („ADHD“, 1.4.1). |
| 2.5.4 Pozadí | ⚠️ | D2. |
| 4.0 Design | ✅ | Vlastní ucelený design system, iPhone SE až Pro Max ve screenshotech CI. |
| 4.1 Copycats / 5.2.1 | ❌ | B1 (název). Grafika a kód jsou vlastní. |
| 4.2 Minimum functionality | ✅ | Bohatá appka (bitvy, mapa, Shop, statistiky, widget, Live Activity, Zkratky). |
| 4.3 Spam | ✅ | Žánr je přeplněný (Forest, Focus Quest, Habitica). Vlastní obsah ale stačí; vyhnout se podobnému názvu a ikoně. |
| 5.1.1 Data | ✅ | Žádné účty, notifikace se žádají až po první výhře. |
| 5.1.2 | ✅ | Žádné sdílení dat s třetími stranami ani AI službami. |
| 3.1 Platby | ✅ | Žádné nákupy, mince jen za soustředění, truhly mají pevnou odměnu (nejsou to loot boxy). |

**Debug v Release (ověřeno):** `DebugSettingsSections` (`SettingsView.swift:122, 592–737`), Win now (`BattleView.swift:143–146,
237–255`, `ArenaViewModel.debugWinNow` 806–836), mapa (`PathTabView.swift:180–193, 792`), launch argumenty `-initialTab`
(`MainTabView.swift:13–17`), ukázkový postup (`ArenaViewModel.swift:134–140, 227–238`), `isUnlocked`
(`AppPreferences.swift:248–250`) a debug metody profilu (`ProfileViewModel.swift:109–135`). Vše je za `#if DEBUG`.
Zbytky v D1.

**Odkazy v Nastavení** (`FocusQuest/ViewModels/SettingsViewModel.swift:5–9`):

| Odkaz | Kam vede | Stav |
|---|---|---|
| Privacy Policy | `…github.io/focusquest/privacy.html` | funguje, obsah neúplný (D4), adresa se změní s repem (B6, R3) |
| Terms of Use | Apple standard EULA | v pořádku (v App Store Connect nechat „Standard EULA“) |
| Support | `…github.io/focusquest/support.html` | funguje, chybí kontakt a texty jsou zastaralé (B4) |
| Contact the developer | `mailto:` bez adresy | ❌ B3 |
| Rate this app | skryté | v pořádku pro 1.0 (doporučené 5) |

Účet GitHubu `xj2whdvfqw-bot` v adresách působí jako bot. Lepší je vlastní doména (zhruba 10 €/rok, GitHub Pages ji umí)
nebo aspoň Pages pod novým čistým repem s názvem appky.

### B – Privacy a oprávnění

**Privacy manifest appky** (`FocusQuest/Resources/PrivacyInfo.xcprivacy`):
- `NSPrivacyTracking = false`, žádné domény ani sběr dat. ✅
- UserDefaults `CA92.1` ✅.
- SystemBootTime `35F9.1` (`ProcessInfo.systemUptime` v `StudySession.swift:17`) ✅.
  `clock_gettime_nsec_np(CLOCK_MONOTONIC)` v `MonotonicClock.swift` není na seznamu Required Reason API, deklarace stačí.
- Časová razítka souborů, místo na disku ani klávesnice se nepoužívají ✅.
- Chybí: důvod `1C8F.1` pro App Group (po zapnutí, B2) a manifest widgetu (B2).

**Info.plist:**

| Klíč | Hodnota | Hodnocení |
|---|---|---|
| `NSMotionUsageDescription` | „…lying flat on the desk during a focus battle.“ | pravdivý, iOS ho neukáže (doporučené 8) |
| Notifikace | bez usage stringu (není potřeba) | žádost až po první výhře ✅ |
| `UIBackgroundModes` | `audio` | obhajitelné, pokud hraje zvuk (D2), vysvětlit v poznámkách |
| `NSSupportsLiveActivities` | `true` | Live Activity nepotřebuje režim pozadí ani push ✅ |
| `ITSAppUsesNonExemptEncryption` | `false` | správně ✅ |
| `CFBundleURLTypes` | `focusquest://` | při přejmenování zvážit (kapitola 7) |
| CallKit | bez oprávnění | `CXCallObserver` nevidí čísla ✅, ale viz D3 (Čína) |

Siri, App Intents a Focus Filter nepotřebují usage string ani entitlement ✅.

**Síť:** v kódu není `URLSession`, `Network`, `AdSupport` ani `AppTrackingTransparency`. Jediné odchozí akce jsou
`openURL` na odkazy z Nastavení a `mailto:`. ✅

**Návrh vyplnění App Privacy v App Store Connect:**
- „Do you or your third-party partners collect data from this app?“ → **No, we do not collect data from this app.**
- Výsledek: **Data Not Collected**.
- Platí i po zapnutí iCloud KVS (data jdou do iCloudu uživatele, vývojář k nim nemá přístup)
  a pro e-maily na podporu (nejde o sběr přes appku).
- Tracking: **No**.

### C – Technika a stabilita

**Možné pády:**
- Force unwrapy: 3 výskyty, všechny bezpečné (`SettingsViewModel.swift:6–8` konstantní URL, `ZoomableMapView.swift:93`).
- Indexy: `BossWorld.allCases[0].bosses[0]` (`ArenaViewModel.swift:149, 276, 282, 341`, `AppDIContainer.swift:118`)
  stojí na statických datech. Test `testEveryBossHasAFullSpriteAndAPlaceOnAPath` hlídá, že nejsou prázdná.
  `HabitGrid.recentWeeks` má ohraničené rozsahy ✅.
- Dělení: `PathTabView.swift:909` hlídá prázdný seznam, `MapLayout.swift:63` a `bandHeight` mají `max(1, …)` ✅.
- Assety: hudba (`.mp3`), font a ikonu kontroluje CI. **`.m4a` (Fireplace piano, Study flow) CI nekontroluje.**
  Když převod selže, skladba potichu nehraje. Přidat kontrolu do `ci-build-ipa.sh` (R1).
- Čas a datum: všechno přes `Calendar.current`, bez pevných 86 400 s.
  - `currentStreak` má pojistku 3 650 kroků.
  - Live Activity počítá z `Date` (UTC), takže změna pásma ani letní čas bitvu nerozbijí.
  - `clockIsTampered` porovnává monotónní a nástěnné hodiny. Letní čas `Date` nemění, falešný poplach nehrozí.
  - Chybí testy (doporučené 3).

**Režimy pozadí:** jen `audio`, potřebné pro hudbu se zamčeným telefonem (D2). Live Activities režim pozadí nepotřebují,
push není zapnutý a není potřeba.

**Výkon a baterie:** `TimelineView` bitvy dělá 30 snímků/s jen během útoku, jinak 2 snímky/s, a na pozadí stojí.
`PixelArtAvatarView` se na pozadí a s Reduce Motion zastaví. Audio session je `.playback` + `mixWithOthers` jen během bitvy,
jinak `.ambient` ✅. Zbývá ověření z doporučeného bodu 7.

**Persistence:** UserDefaults, asi 250 B na bitvu (3 bitvy denně po 3 roky ≈ 800 kB, pro UserDefaults v pořádku).
Tolerantní dekodéry, záloha nečitelných dat a testy migrací ✅. Zbývá D10.

**Warnings a API:** D7. Deprecated API v logu nejsou.

**Minimální iOS a zařízení:** iPhone, na výšku, iOS 17 (doporučuji iOS 18, viz D8). iPad ani Mac nepodporovat:
celý koncept stojí na telefonu displejem dolů a layout je laděný pro iPhone.

**Testy:** 145 testů v 12 souborech. Dobře pokrývají:
- postup, ekonomiku a migrace (`ProgressionModelTests`, 68),
- anti-cheat a stavy bitvy (17),
- sloty výbavy, Shop, tutoriál a sdílecí karty.

Kriticky chybí:
1. Zlatý soubor s JSON dnešní verze (D10).
2. Datum: letní čas, změna pásma a půlnoc pro sérii, Habits, týdenní úkoly a freeze (doporučené 3).
3. Plánování notifikací („Streak in danger“ ve 20:00, ne po půlnoci, zrušení po bitvě, Focus Filter mute). Přes protokol
   nad `UNUserNotificationCenter`.
4. Deep link `focusquest://fight` a App Intents (příkaz během bitvy a tutoriálu se ignoruje).
5. `CloudSync.merge` má jen 3 testy. Před zapnutím iCloudu přidat konflikty (dvě zařízení, reset).
6. Žádný UI test celé cesty onboarding → bitva → výhra v Release konfiguraci (stačí jeden smoke test v CI).

### D – Funkčnost a UX

Celou appku nešlo v tomto kroku spustit (bez Macu). Hodnocení vychází z kódu, DECISIONS.md, poznámek v progress.html
a screenshotů CI. Obrazovky a toky jsou podle progress.html hotové a testované na iPhonu do T1 (#91).
Ruční průchod Release buildem je v checklistu TestFlightu (kapitola 8).

| Oblast | Stav | Nález |
|---|---|---|
| Onboarding, tutoriál | ✅ | 14 kroků, Skip, Replay v Nastavení. Povolení se tu nežádá (dobře). |
| Home / Arena | ✅ | Ověřit na iOS 17/18 (D8). |
| Bitva | ✅ | Start, pauzy (1 zdarma + extra), hovor, zvednutí s odpočtem, Retreat, K.O. a výhra. Reviewerovi vysvětlit (D11). |
| Break | ✅ | Next boss / Same again / Change boss / Done for today. |
| Path, světy, easter eggy | ✅ | Odemykání jen po finálním bossovi, debug odemčení jen v Debug. |
| Shop | ✅ | Gear, Backgrounds, Supplies, sloty, třídy, Class Potion. |
| Stats a sdílení | ✅ | Bez osobních dat, jméno jen volitelně. |
| Hero | ✅ | Třída se zámkem, odkaz do Shopu. |
| Settings | ⚠️ | B3, D5, doporučené 1 a 2. |
| Notifikace | ✅ | Testy plánování chybí. |
| Widget | ❌ | B5. |
| Live Activity | ✅ | Odpočet běží i se spící appkou, stav „Time’s up“. |
| App Intents / Shortcuts | ✅ | Fráze obsahují `.applicationName`, po přejmenování se upraví samy. |
| Focus Filter | ✅ | Název filtru je napevno „FocusQuest“ (kapitola 7). |

**Texty a angličtina:** v kódu ani v appce jsem nenašel překlepy ani placeholdery. Zastaralé texty jsou na webu podpory (B4).

**Accessibility:** 86 `accessibilityLabel` a 95 `accessibilityHidden` (dekorace), VoiceOver na tab baru, srdíčkách,
pauzách i Shopu. Reduce Motion řeší 19 souborů. Slabá místa: D12 (pevné velikosti písma) a doporučené 6 (kontrast).

**Ekonomika hry (3 mince a 12 XP za minutu):**

| Položka | Cena | Odpovídá minutám soustředění |
|---|---|---|
| Extra pause | 40 | 13 min |
| Streak freeze | 150 | 50 min |
| Class Potion | 500 | 2 h 47 min |
| Gear (bez zbraní cizích tříd) | 60–600 | 20 min – 3 h 20 min |
| Backgrounds | 800–1 500 | 4 h 27 min – 8 h 20 min |

- Příjem: všech 52 bossů ≈ 1 460 min ≈ 4 380 mincí, easter eggy 450, týdenní truhly 3 × 40–100 týdně.
- Výdaje: všechno pro jednu třídu ≈ 2 700 (gear) + 7 800 (pozadí) ≈ 10 500 mincí ≈ 58 h soustředění.
- Hráč s 30 min denně (90 mincí + asi 30 z truhel) koupí všechno zhruba za 3 měsíce. Přiměřené tempo bez grindu.
- Zásoby jsou dost levné, aby se používaly, a limity (5 pauz, 2 freeze, 1 lektvar) brání zneužití.
- **Hodnocení: vybalancované.** Jediné riziko je prázdno po dobytí světů (doporučené 10).

### E – Práva a obsah

| Asset | Licence | Doložitelnost | Co udělat |
|---|---|---|---|
| `calm-currents.mp3`, `tokyo-sunset.mp3`, `peaceful-drift.mp3` (HoliznaCC0) | CC0 1.0 | CREDITS.md: ověřeno 12. 11. 2026 na Free Music Archive | Uložit snímky stránek skladeb s licencí a odkaz z web.archive.org do soukromé složky. CC0 nevyžaduje uvedení, ale credit je slušnost (D5). |
| `fireplace-piano.mp3` (juliush), `study-flow.mp3` (luceris) | Pixabay Content License | jen tabulka v DECISIONS.md | Doplnit do CREDITS.md. Uložit stránky s ID souborů. Licence dovoluje použití v appce, zakazuje prodej samostatně. Uvedení není povinné. |
| `tap-click.mp3` (denielcz), `reward-chime.mp3` (lolo_s) | Pixabay Content License | jen DECISIONS.md | Totéž. |
| Syntetické zvuky (šumy, 8-bit tóny) | vlastní | kód | – |
| Pixelify Sans Medium | SIL OFL 1.1 | CREDITS.md | Přiložit `OFL.txt` nebo licenci ukázat v appce (D5). |
| Sprity bossů, hrdinů, předmětů a pozadí | vlastní (pixel art v kódu) | kód | – |
| SF Symbols | Apple licence | – | Jen v UI, ne v logu (pravidla Apple). |
| Ikona (Warm-up Wisp, dočasná) | vlastní | – | Finální ikona (R3). |

- **Chráněné postavy a značky:** v aktuální verzi žádné. Výjimka jsou mrtvé názvy značek v `AppBlockerManager` (D1)
  a stará historie repa (B6). Posouzení jmen v doporučeném bodě 11.
- **Pixabay obecně:** obsah se nahrává bez ověření autorství. Kdyby se ukázalo, že uploader nebyl autor, nese riziko i uživatel
  obsahu. Pro 6 souborů je riziko malé, záznam o stažení (datum a stránka) je ale dobrá pojistka.

**Věkové hodnocení: návrh odpovědí do dotazníku App Store Connect**

| Otázka | Odpověď |
|---|---|
| Parental Controls, Age Assurance | No |
| Unrestricted Web Access | No (otevírá jen vlastní odkazy v Safari) |
| User-Generated Content | No (poznámky k bitvám zůstávají v telefonu) |
| Messaging and Chat | No |
| Advertising | No |
| Cartoon or Fantasy Violence | **Infrequent/Mild** (pixeloví bossové „K.O.“) |
| Realistic Violence, Prolonged Graphic Violence | None |
| Guns or Other Weapons (pokud se otázka objeví) | Infrequent/Mild (kreslené meče a luky) |
| Profanity or Crude Humor | None |
| Mature or Suggestive Themes | None |
| Horror/Fear Themes | None |
| Alcohol, Tobacco or Drug Use | None |
| Sexual Content or Nudity | None |
| Medical or Treatment Information | None |
| Health or Wellness Topics | No |
| Simulated Gambling | None |
| Contests | None |
| Loot Boxes | No (truhly mají pevnou odměnu podle obtížnosti) |
| Made for Kids | **No** (kategorie Kids má přísnější pravidla a nic nepřináší) |

Výsledek: **9+**. Kdo „K.O.“ pixelového bosse nebere jako násilí, odpoví None a dostane 4+. Bezpečnější je 9+.

### F – Příprava na vydání

- **Verze:** `MARKETING_VERSION 1.0.0` a `CURRENT_PROJECT_VERSION` v CI z `github.run_number` (stále roste) ✅.
  Pozor: po přechodu do nového čistého repa (B6) začne `run_number` od 1. Buď ručně nastavit offset
  (`BUILD_NUMBER = run_number + 1000`), nebo build number brát z času.
- **Ikona:** jen 1024 × 1024 `universal`, Xcode 14+ z ní generuje všechny velikosti ✅. Bez alfa kanálu ✅. Chybí tmavá
  a tónovaná varianta (iOS 18+) a finální motiv. Icon Composer (`.icon`, Liquid Glass) je jen pro macOS, takže zůstat
  u PNG variant v asset catalogu (`appearances: luminosity dark / tinted`).
- **Launch screen:** D9.
- **Developer účet:** pořadí kroků v kapitole 5.
- **Texty pro App Store Connect:** kapitola 8.

---

## 5. Co musíš udělat ty mimo kód

Seřazeno podle pořadí.

1. **Vybrat nový název a nechat navrhnout logo.**
   - Ověřit volnost: App Store (iPhone i iPad), EUIPO a USPTO (třída 9 a 41), doména `.app` nebo `.com`, uživatelské jméno na GitHubu.
   - Název do 30 znaků. Ideálně bez slova „Focus“ na začátku: hodně obsazené a „focus“ může být v klíčových slovech.
2. **Zaregistrovat Apple Developer Program** (99 USD/rok) jako fyzická osoba.
   - Pozor: jméno prodejce na App Store bude tvoje celé jméno.
   - Organizace by potřebovala IČO a D-U-N-S číslo, pro jednu bezplatnou appku se nevyplatí.
3. **Samostatný e-mail pro podporu**, např. `[nazev].app@…` nebo adresa na vlastní doméně. Nedávat osobní adresu.
4. **EU Digital Services Act:** v App Store Connect se musíš prohlásit za „trader“ nebo „non-trader“.
   - Bezplatná appka bez příjmů od fyzické osoby = typicky **non-trader**.
   - Trader by musel zveřejnit adresu a telefon.
   - Bez vyplnění se appka v EU nezobrazí.
5. **V developer.apple.com** (až po výběru názvu, protože ID se po vydání nedají změnit):
   - App ID appky a widgetu s novým bundle ID,
   - App Group `group.<nové bundle ID>`,
   - App Store Connect API klíč (role App Manager) → GitHub Secrets (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`),
   - Team ID do `project.yml` (`DEVELOPMENT_TEAM`).
6. **Pořadí z DEVELOPER_ACCOUNT_TODO.md:**
   1. §0 společné kroky (App ID, tým, API klíč): **nutné**,
   2. §1 App Group pro widget: **nutné** (B5),
   3. §2 iCloud KVS: **odložit na 1.1** (doporučené 13),
   4. push: **nezapínat** (není potřeba),
   5. Rate this app: v 1.0.1.
7. **Nové čisté repo** (B6) a v něm GitHub Pages. Volitelně vlastní doména pro Privacy a Support.
   Staré repo pak archivovat a skrýt.
8. **App Store Connect › New App:**
   - název (tím se zarezervuje), primární jazyk English (U.S.), nové bundle ID, SKU (třeba `app-001`),
   - kategorie, věkové hodnocení, App Privacy, Pricing: Free, Availability bez China mainland (D3),
   - vypnout „Make this app available on Mac“ (doporučené 9),
   - EULA: Standard, copyright `2026 [tvé jméno]`.
9. **Důkazy licencí** (D5): snímky stránek skladeb a zvuků s licencí a datem stažení do soukromé složky, ne do veřejného repa.
10. **Screenshoty:** viz kapitola 8 (vybrat 5–8 nejlepších záběrů).
11. **TestFlight:** pozvat interní testery (až 100 lidí z týmu App Store Connect, bez review) a projít checklist z kapitoly 8.

---

## 6. Návrh pořadí práce

| Balíček | Obsah | Velikost | Model | Závisí na |
|---|---|---|---|---|
| **R1 Release hygiena** | D1 (zbytky debugu do `#if DEBUG`, smazat `AppBlockerManager`), B2 (manifest widgetu + kontrola v CI), D2 (zastavit hudbu při 0 %), D7 (warningy, Node 24 akce), kontrola `.m4a` a stringů debugu v Release v CI, D9 (launch screen) | S (1 session) | **Medium** | nic, jde hned |
| **R2 Web, právo, kontakt** | B4 (nová Support stránka s FAQ podle DECISIONS.md), D4 (Privacy Policy), D5 (CREDITS.md + obrazovka Acknowledgements s OFL), B3 (Contact s adresou a záložním listem „Copy address“), doporučené 1 (přeformulovat credit AI) | M (1–2 session) | **Medium** | e-mail od tebe (adresa až do čistého repa) |
| **R3 Přejmenování** | Konstanta `AppBrand` v `Shared/`, všechny viditelné texty, display name, bundle ID, App Group ID, URL schéma, widget kind, nová ikona (+ tmavá a tónovaná), docs, CI skripty, dokumentace. Podle kapitoly 7. | M–L (1–2 session) | **High** | název a logo od tebe; **před** R4 |
| **R4 Podepisování a TestFlight** | `release.yml` (archive + export + upload přes API klíč), entitlements App Group pro obě cíle, důvod `1C8F.1` v obou manifestech, build number v novém repu, B5 ověřit na zařízení | M (1–2 session + čekání na Apple) | **High** | placený účet, R3 |
| **R5 Stabilita a testy** | D10 (golden JSON test, obnova ze zálohy), testy data a času (doporučené 3), testy plánování notifikací a deep linku, D8 (minimum iOS 18, nebo CI na iOS 17), smoke UI test Release toku, D12 (Dynamic Type u textů) | M–L (2 session) | **High** | nic, může běžet souběžně s R2 |
| **R6 Podklady pro App Store** | Skript screenshotů 6,9" (1320 × 2868) z CI simulátoru iPhone 17 Pro Max s ukázkovými daty (Debug launch argumenty už jsou), doladit texty z kapitoly 8 s novým názvem, poznámky pro review | S–M (1 session) | **Medium** | R3 |
| *Po vydání (1.0.1/1.1)* | Rate this app s App Store ID, iCloud sync, doporučené 2, 4, 6, 10 | – | Medium/High | vydání |

Doporučené pořadí: **R1 → R2 → R5** (hned, bez účtu), pak **R3** (po výběru názvu), **R4** (po schválení účtu),
**R6**, TestFlight, odeslání do review.

---

## 7. Inventář názvu pro přejmenování

Nic se zatím nepřejmenovává. Cílem je, aby šlo všechno změnit jedním balíčkem R3.

### 7.1 Postup, aby se nic neztratilo
1. **Uložená data appky se nepřejmenovávají.** Klíče UserDefaults (`focusquest.local-profile`, `focusquest.local-stats`,
   `focusquest.sensory-preferences`, `focusquest.onboarding.done`, `focusquest.tutorial.step`, `focusquest.blocked-apps`,
   `fq.*`) nejsou vidět. Jejich přejmenování by vyžadovalo migraci a nic nepřináší. **Nechat beze změny.**
2. **Interní identifikátory notifikací** (`focusquest.battle.victory`, `focusquest.break.over`, `focusquest.reminder.N`,
   `focusquest.streak.N`) také nechat. Nejsou vidět a změna by osiřela naplánované notifikace testerů.
3. **Swift typy** (`FocusQuestApp`, `FocusQuestBackdrop`, `FocusQuestTab`, `FocusQuestWidgetsBundle`, …) a název targetu
   a modulu `FocusQuest` je možné nechat. Uživatel je nevidí, `CFBundleDisplayName` se nastavuje zvlášť. Přejmenování
   targetu by zasáhlo `project.yml`, skripty CI, `@testable import FocusQuest` ve 12 testech a název `.xcodeproj`.
   Doporučení: **nechat**, nebo přejmenovat až úplně nakonec samostatným commitem.
4. **Co je po vydání napevno, a proto se musí změnit před 1.0:**
   - bundle ID appky, widgetu a testů,
   - App Group ID,
   - identifikátor iCloud KVS (odvozený z bundle ID),
   - `kind` widgetu (změna po vydání smaže widgety z ploch),
   - URL schéma (může ho používat Zkratky uživatelů),
   - **názvy typů App Intents** (`StartBattleIntent`, `ShowStreakIntent`, `PauseBattleIntent`, `FocusQuestFocusFilter`):
     uživatelské zkratky a nastavené Focus filtry se na ně odkazují. Když se mají měnit, tak teď.
5. **Testeři se Sideloadly:** nové bundle ID = nová appka vedle staré, data se nepřenesou. Před vydáním jde o testovací data,
   takže to nevadí. Kdo o data stojí, může dočasně nechat obě appky.
6. **Viditelné texty sjednotit** do jedné konstanty `AppBrand.name` v `Shared/` (sdílí ji appka i widget). Pak stačí změnit
   jedno místo plus Info.plist a weby.

### 7.2 Místa s názvem

**Identifikátory a konfigurace**

| Soubor | Co |
|---|---|
| `project.yml` | `name: FocusQuest`, `bundleIdPrefix: com.focusquest`, `com.focusquest.app`, `.widgets`, `.tests`, názvy targetů a schématu |
| `FocusQuest/Config/Development.xcconfig` | `PRODUCT_BUNDLE_IDENTIFIER = com.focusquest.app`, `INFOPLIST_KEY_CFBundleDisplayName = FocusQuest` |
| `Support/FocusQuest-Info.plist` | `NSMotionUsageDescription` („FocusQuest checks…“), `CFBundleURLName com.focusquest.app`, `CFBundleURLSchemes focusquest` |
| `Support/FocusQuestWidgets-Info.plist` | `CFBundleDisplayName FocusQuest` |
| `Shared/WidgetSnapshot.swift:12` | `appGroupID = "group.com.focusquest.app"` |
| `FocusQuest/Intents/FocusQuestIntents.swift:26` | `scheme = "focusquest"` |
| `FocusQuestWidgets/FocusStatusWidget.swift:35, 54` | `kind = "FocusQuestStatus"`, `widgetURL("focusquest://fight")` |
| `FocusQuest/Hardware/BattleNotificationService.swift:39` | `Logger(subsystem: "FocusQuest")` (nevidí se, sjednotit s bundle ID) |
| `FocusQuest/ViewModels/SettingsViewModel.swift:6–7` | URL Privacy a Support (`xj2whdvfqw-bot.github.io/focusquest/…`) |
| Budoucí `Support/*.entitlements` | App Group a iCloud (`DEVELOPER_ACCOUNT_TODO.md`) |

**Viditelné texty v appce**

| Soubor | Text |
|---|---|
| `FocusQuest/Views/Onboarding/OnboardingView.swift:122` | „FocusQuest turns focus time into battles…“ |
| `FocusQuest/Views/Settings/SettingsView.swift:79, 182, 198, 249, 547, 710, 902, 906, 946–948, 955, 960` | Help footer, iCloud footer, „FocusQuest version“, předmět e-mailu, notifikace vypnuté, Debug widget, návod Focus, fráze Siri, Action button |
| `FocusQuest/Hardware/BattleNotificationService.swift:104` | „Open FocusQuest to collect your XP and coins.“ |
| `FocusQuest/Intents/FocusFilter.swift:35, 36, 46` | název filtru „FocusQuest“, popis, `DisplayRepresentation` |
| `FocusQuest/Intents/FocusQuestIntents.swift:39, 59` | popisy intentů (fráze používají `.applicationName` ✅) |
| `FocusQuest/Views/Stats/StatsShare.swift:362, 441` | značka na sdílecím obrázku, „My FocusQuest progress“ |
| `FocusQuest/Views/Components/BattleReceiptRenderer.swift:37, 78` | „FocusQuest battle record“, „FocusQuest battle victory“ |
| `Shared/FocusWidgetViews.swift:153` | „Open FocusQuest“ (widget) |
| `FocusQuestWidgets/FocusStatusWidget.swift:41` | `configurationDisplayName("FocusQuest")` |
| `FocusQuestWidgets/FocusBattleLiveActivity.swift:169, 176` | „Open FocusQuest to collect your loot“, „Time’s up! Open FocusQuest…“ |

**Assety**

| Soubor | Co |
|---|---|
| `FocusQuest/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | ikona (+ nové varianty dark a tinted) |
| `docs/icon.png` | ikona na webu |

**Web, dokumentace a CI**

| Soubor | Výskytů |
|---|---|
| `docs/index.html`, `docs/privacy.html`, `docs/support.html` | 3 + 11 + 6, plus titulky stránek a odkaz na GitHub |
| `CREDITS.md`, `NAVOD.md`, `CLAUDE.md` | 4, 11, 1 |
| `design/DECISIONS.md`, `design/DEVELOPER_ACCOUNT_TODO.md`, `design/CHANGES.md`, `design/progress.html`, `design/focusquest.html` | 18, 20, 3, 10, 7 (historické dokumenty, stačí poznámka nahoře) |
| `.github/workflows/ios.yml`, `scripts/ci-build-ipa.sh`, `scripts/ci-test.sh`, `scripts/ci-screenshot.sh`, `tools/stahni-ipa.ps1` | 5, 7, 2, 4, 4: `FocusQuest.xcodeproj`, schéma, `FocusQuest.app`, název artefaktu `FocusQuest-ipa`, repo |
| `FocusQuestTests/*.swift` | `@testable import FocusQuest` (jen při přejmenování modulu) |

Počty jsou z `git grep -ci "focus ?quest"`. Kompletní seznam pro kontrolu po přejmenování:
`git grep -niE "focus ?quest|focusquest"`. Po R3 by měl vrátit jen interní klíče z bodů 7.1.1–3.

---

## 8. Podklady pro App Store Connect a TestFlight

### 8.1 Povinné rozměry a pole
- **Screenshoty iPhone 6,9"**: 1320 × 2868 (nebo 1290 × 2796) na výšku, 1–10 kusů, PNG/JPEG bez alfa kanálu.
  Když jsou 6,9", menší velikosti se dopočítají a nejsou povinné. iPad se nedělá (appka je jen pro iPhone).
- **App preview video** (volitelné): 15–30 s, 886 × 1920.
- **Limity:**
  - Name 30 znaků, Subtitle 30, Promotional Text 170 (jde měnit bez nové verze),
  - Description 4 000, Keywords 100 znaků (čárky bez mezer, neopakovat název ani kategorii),
  - Support URL a Privacy Policy URL povinné, Marketing URL volitelná.
- **Kategorie:** primární **Productivity**, sekundární **Education**. Do Games ne: soutěž s hrami a jiné žebříčky.
- **Návrh screenshotů** (CI je umí vyfotit z Debug launch argumentů s ukázkovými daty):
  1. bitva s hrdinou a bossem, titulek „Put your phone down. Beat the boss.“,
  2. mapa světů, „Seven worlds of procrastinators“,
  3. Fight setup, „Pick a focus and a boss“,
  4. Shop stánek, „Earn coins. Gear up your hero.“,
  5. Stats s Habits a sérií, „Build a streak that sticks“,
  6. Live Activity na zamčené obrazovce, „Your battle on the Lock Screen“,
  7. výhra, „Every minute counts“.

### 8.2 Texty (angličtina)

**Subtitle** (29 znaků):
> Focus timer with boss battles

Alternativy: „Beat bosses by staying focused“ (30), „Study timer meets pixel RPG“ (27).

**Promotional Text** (do 170 znaků):
> Put your phone face-down and fight procrastination. Every focused minute hits the boss. Earn coins, gear up your pixel hero and conquer seven worlds.

**Keywords** (94 znaků; když název obsahuje „focus“, slovo vynechat a doplnit jiné):
> pomodoro,study,timer,focus,rpg,pixel,habit,streak,homework,concentration,gamified,student,boss

**Description:**
> [APP NAME] turns focus time into pixel-art boss battles.
>
> Pick what you're working on, choose a boss and lay your iPhone face-down on the desk. While the phone stays down, your hero keeps attacking. Stay focused until the timer runs out and the boss is knocked out. Pick the phone up and you have 10 seconds to put it back before the boss escapes.
>
> HOW IT WORKS
> • Battles from 5 minutes up to 4 hours, with one free pause per battle
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
> • Siri, Shortcuts and the Action button: "Start a battle in [APP NAME]"
> • Focus filter: suggest a battle and mute reminders while a Focus is on
>
> PRIVATE BY DESIGN
> No account, no ads, no tracking. Everything stays on your iPhone.

(Ve verzi 1.0 vynechat řádek o widgetu, kdyby se widget kvůli B5 vyřadil. Nic nesliboval o blokování aplikací ani o zdraví.)

**Support URL:** `https://[doména nebo nové pages]/support.html`
**Privacy Policy URL:** `https://[doména nebo nové pages]/privacy.html`
**Marketing URL:** `https://[doména nebo nové pages]/` (volitelné)
**Copyright:** `2026 [tvé jméno]`

**App Review Information › Notes:**
> No account or login is needed.
>
> How to test a battle: tap Fight, choose any focus area and the "Warm-up Wisp" quick battle (5 minutes), then lay the iPhone face-down on a flat surface. The battle starts when the phone lies still and the boss loses hearts over time. Lifting the phone starts a 10-second countdown; put it back down to continue. If you test on a stand or without moving the device, a "Start without sensor" button appears after about 8 seconds.
>
> Background audio: during a battle the app plays focus music or noise (lo-fi, piano, white/brown noise) that keeps playing while the screen is locked, because users put the phone face-down. Audio stops when the battle ends or when music is turned off.
>
> Phone calls: CallKit's CXCallObserver is used only to pause the battle while a call is active. No call data is read or stored.
>
> All data stays on the device. The app makes no network requests.

### 8.3 TestFlight: postup
1. R4 nahraje build (`release.yml`). Za 10–30 minut se objeví v App Store Connect › TestFlight.
2. Export compliance se nevyplňuje, `ITSAppUsesNonExemptEncryption = NO` to vyřeší automaticky.
3. **Internal testing:** skupina s tebou (a s dalšími z týmu), bez review Apple. Instalace přes aplikaci TestFlight.
   Sideloadly verzi předtím smazat, kvůli nové appce s jiným bundle ID to ale nutné není.
4. **External testing** (volitelné, až 10 000 lidí přes veřejný odkaz) potřebuje Beta App Review (zpravidla do 1–2 dnů).
5. Po projití checklistu: App Store › verze 1.0 › vybrat build › Submit for Review.

### 8.4 Co otestovat v TestFlightu (Release build)
- **Čistá instalace:** onboarding, tutoriál všech 14 kroků, Skip, Replay tutorial.
- **Bitva:**
  - Warm-up 5 min až do výhry (telefon dolů, zamknout, nechat zamčený),
  - notifikace „Victory!“, Live Activity a Dynamic Island,
  - zvednutí s odpočtem a položení, zvednutí až do útěku bosse,
  - pauza zdarma a Extra pause, Retreat s potvrzením,
  - hovor během bitvy (zavolat si z jiného telefonu), zabití appky během bitvy (Live Activity zmizí).
- **Hudba:** všech 6 zvuků, posuvník na 0 % (po opravě D2 nesmí appka zůstat na pozadí), zamčený telefon, AirPods.
- **Postup:**
  - poražení finálního bosse odemkne svět (v Release bez debug odkazu, takže ověřit aspoň první svět),
  - mince odpovídají minutám, easter egg, týdenní úkol a truhla, Streak freeze přes noc (vynechat den).
- **Shop:** nákup ve všech třech záložkách, sloty, Class Potion (koupě, zrušení, potvrzení).
- **Notifikace:** žádost po první výhře, odmítnutí a pak nabídka Nastavení iPhonu, Daily reminder, „Streak in danger“ ve 20:00, Break is over.
- **Widget** (malý i střední) se skutečnými daty po App Group, obnova po bitvě, tónovaná a tmavá plocha, klepnutí otevře Fight sheet.
- **Siri a Zkratky:** „Start a battle in [APP NAME]“, Show streak, Pause battle, Action button. Focus Filter zapnout a vypnout.
- **Nastavení:**
  - každý odkaz (Privacy, Terms, Support, Contact) otevře funkční cíl,
  - v Release **není** karta Debug, „Win now“ ani „Change class (free)“,
  - Reset progress.
- **Zařízení a přístupnost:**
  - iPhone SE (3. gen.) a Pro Max, největší Dynamic Type, VoiceOver na hlavních obrazovkách, Reduce Motion,
  - nejstarší podporovaný iOS (D8), iPad v kompatibilním režimu (aspoň v simulátoru, viz doporučené 9).
- **Datum:** změna časového pásma v Nastavení iPhonu (série a Habits se nerozbijí), bitva přes půlnoc.
- **Update:** nainstalovat build N, odehrát bitvy, nainstalovat build N+1 přes TestFlight. Data musí zůstat.
- **Baterie:** hodinová bitva se zamčeným telefonem a hudbou, pak spotřeba v Nastavení › Baterie.
