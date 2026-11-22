# FocusQuest: rozhodnutí a kontext pro další session

Doplňuje `design/CHANGES.md` (zadání sekcí 0–15) a `design/progress.html` (stav, buildy, co otestovat).
Tady je to, co v nich není: rozhodnutí, která padla během práce, otevřené body a známé pasti.

Stav k 22. 11. 2026: větev `phase3-duolingo`, poslední zelený build #62; dříve #61 (D1: opravy z testu po C1); E1 (opravy z testu po D1) prošel jako build #62. Všechny sekce z CHANGES.md
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
- **Styl systémového Nastavení iOS 26** (od D1): `NavigationStack` + `List(.insetGrouped)`, velký nadpis vlevo, sekce s nadpisem
  a footer textem, řádky s ikonou v barevném zaobleném čtverečku (`SettingsRow`, `SettingsIcon`), šedá hodnota vpravo
  a šipka u podstránek (Sounds & haptics, Music, Notifications). Nativní `Toggle` se systémovou zelenou. **Systémová modrá v appce není** (od E1): tint Nastavení je bílý (chevron zpět, fajfky,
  posuvníky), zelené zůstávají jen přepínače (`settingsToggleTint`).
  Liquid Glass lišta a měkký scroll edge efekt nahoře i dole (`scrollEdgeEffectStyle(.soft)` na iOS 26, jinak standard).
  Zpět chevronem i tahem od levého okraje dává `NavigationStack` (vlastní gesto zpět je pryč). Zavření tahem dolů jako dřív.
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

### Světy, bossové a mapa (od testu #56)
- **Tři parodické světy jsou úplně pryč** (bossové, sprity, texty, ID, testy i `design/`). Všechny postavy jsou vlastní.
  Staré commity je ještě obsahují (viz Otevřené body).
- **7 světů v pořadí mapy** (zdola nahoru), délka bitvy 10 + 5 × pořadí minut, obtížnost Novice → Mythic po dvou bossech:

  | Svět | Bossové (od nejslabšího) |
  |---|---|
  | Farm | Snooze Bunny, Procrasti-Hen, Baa-ck in Five, Moo-ve It Later, Couch Hog, Hee-Haw Hold-On, Neigh-ver Mind |
  | Whisperwood (lesní skřítci) | Puffcap, Lazy Sprig, Petal Pause, Mossy Snoozer, Acorn Afterwhile, Twiggy Tomorrow, Old Oakdrowse |
  | Coral Deep (podmořský svět) | Driftwell the Seahorse, Clownin' Around, Jelly Later, Spiky Maybe, Octo-Tasker, Snack-Break Shark, The Kraken of Later |
  | Dojo | Kara-Tea Break, Master Someday, Monk Mañana, Rope-a-Dope Ray, Tap-Out Tyler, Ju-Don't, Ken-Doze, Muay Thai-red, Sumo More Snacks |
  | Snoozeville High (střední škola) | Theo Theorem, Raven Rainclouds, Pep Rally Penny, Brody Bulk, Dribble Dex, Hail Mary Max, Principal Postpone |
  | History Hall | Nap-oleon, Cleo Queen of De-Nile, Veni Vidi Scrolli, Will Do It Tomorrow, Leonardo da Wi-Fi, Amadeus Pause, Isaac Inertia, Karel IV-get It, Komenský's Homework |
  | Orbit | Retro Mercury, Meme Venus, Day-Off Earth, Binge Mars, Jupi-Later, Ring-Ring Saturn, Tilted Uranus, Sea-Ya Neptune |

  - Každý boss má jednu hlášku o prokrastinaci (`Boss.quip`, ukazuje ji karta bosse na mapě).
  - Sprity nových světů jsou v `Shared/OriginalWorldBossSprites.swift` (barvy `M` mech a `H` tmavá hnědá přidány do palety).
- **Odemykání:** ve světě jde bojovat s poraženými bossy (znovu) a s bossem na řadě, další jsou zamčení.
  Další svět se odemkne až po porážce finálního bosse předchozího (`AppPreferences.isUnlocked/canFight/currentBoss`).
  Arena („Continue your path“), NEXT BOSS v přestávce i „Keep going“ po rozcvičce ukazují aktuálního bosse mapy.
- **Migrace uložených dat** (appka nesmí spadnout):
  - postup ve třech odstraněných světech přejde podle pořadí na Coral Deep, Whisperwood a Snoozeville High (strop 7, platí vyšší hodnota),
  - staré klíče Dojo a Farm se převedou na `dojo` a `farm` (`BossWorld.legacyWorldKeys`),
  - svět, kde hráč už má postup, je odemčený vždy; při prvním spuštění se uloží `revealedWorlds`, aby se nad nimi nepřehrávala mlha,
  - boss, který už neexistuje: ve statistikách „Retired boss“ (minuty, XP a předměty zůstanou, řádky Bestiáře se sloučí), naposledy vybraný se nahradí aktuálním bossem mapy.
- **Mapa (záložka Path)**:
  - `UIScrollView` v `ZoomableMapView` (posun, setrvačnost, pinch-zoom 0,5–1,6×, nikdy celá mapa najednou), obsah je SwiftUI v `UIHostingController`,
  - mapa 2400 × 3600 bodů; terén včetně cesty, dekorací a staveb je pixelová bitmapa 600 × 900 px (1 px = 4 body, asi 2 MB) generovaná v kódu
    na pozadí (`MapTerrain`), zobrazená bez vyhlazování; nejdřív se ukáže hrubý náhled (1 px = 16 bodů), plná mapa se uloží
    do Caches (`map-terrain-v2.rgba`, při změně vzhledu zvýšit verzi) a další otevření je okamžité;
    nad ní vrstvy: mlha, zastávky a hrdina (stejné vrstvy jako Shop a Hero Profile); názvy světů jsou nad mapou v souřadnicích obrazovky,
  - mapa respektuje hlavičku a tab bar: `contentInset` scroll view = výška hlavičky nahoře a safe area s rezervou tab baru dole,
    takže se dá odrolovat tak, aby nic nebylo pod lištou, a kamera centruje do středu viditelné části;
    cesta začíná výš (`MapLayout.bottomMargin` = 420), aby šli první bossové posunout do středu,
  - názvy světů (`WorldLabelsOverlay`) se vodorovně drží v obrazovce (nikdy nejsou useknuté) a schovají se pod hlavičkou i nad tab barem,
  - mlha zamčených světů je jen jemný tmavý závoj přes svět a u prvního zamčeného světa měkký pás mraků přes hranici
    (160 bodů nahoru, 96 dolů, vyhlazený obrázek, ne pixelové dlaždice); dřív zakrývala celý svět,
  - horní tlačítka mapy mají neinteraktivní sklo a mapa je `UIViewControllerRepresentable` s hosting controllerem jako potomkem:
    interaktivní Liquid Glass nad UIKit mapou pohlcoval klepnutí a zůstával rozsvícený (test po C1),
  - cesta se v každém světě jednou přehoupne z jedné strany na druhou, zastávky jsou rovnoměrně po její délce (`MapLayout`),
  - zastávky: poražený má vlajku, aktuální pulzuje a stojí u něj hrdina, zamčený je šedý se zámkem,
  - kamera po otevření mapy najede z oddálení na aktuálního bosse; tlačítko s terčíkem vrátí kameru zpět,
  - klepnutí na zastávku otevře skleněnou kartu (hláška, délka „⏱ 15 min“ i u zamčeného bosse, Fight nebo důvod zámku); zavře se klepnutím do mapy nebo tahem dolů,
  - mlha nad nově odemčeným světem se jednou rozplyne a zapamatuje se,
  - přístupnost: zastávky mají VoiceOver popisky („Jelly Later, Coral Deep, boss 3 of 7, 20 min, current boss“),
    tlačítko seznamu otevře list se světy a bossy (stav, délka bitvy); výběr bosse list zavře a otevře Fight sheet.

### Bitva
- **Hovor během bitvy** (`CXCallObserver`, stav `callPaused`):
  - bitva se automaticky pozastaví, bez časového limitu a nepočítá se do pauz bitvy,
  - zvednutí telefonu se během hovoru netrestá,
  - po hovoru se ukáže „Call ended – continue the battle?“ a bitva pokračuje, až telefon zase leží displejem dolů,
  - bez senzoru („Start without sensor“) je tam tlačítko „Continue battle“.

  Omezení: když je aplikace během hovoru uspaná (bitva bez zvuku a zamčený telefon), hovor se zjistí
  až po návratu do aplikace.
- **Kontrola integrity (jailbreak, debugger) je úplně odstraněná.** Zůstala jen kontrola posunu hodin v bitvě
  (`AntiCheatRules.clockIsTampered`).
- Zabití aplikace během bitvy: bitva se ztratí. Při dalším spuštění se zruší notifikace „Victory!“ a ukončí Live Activity.
- **Pauzy** (od D1): **2 pauzy za bitvu** (`ArenaViewModel.pausesPerBattle`), každá nejdéle 2 minuty. Tlačítko ukazuje
  „Pauses 2/2“, po vyčerpání zůstane vidět, ale je neaktivní. Hovor se do pauz nepočítá.
- **Zvednutý telefon: jediný odpočet, bez „slip one time“** (od E1). Dřív: první propadlý odpočet v bitvě se odpustil
  (obrazovka „Slip forgiven“ na 2,2 s), odpočet běžel znovu a teprve druhý propadlý znamenal útěk bosse (`hasUsedSlipGrace`,
  `slipForgivenSeconds`). Teď odpočet (10 s, `AntiCheatRules.warningSeconds`) proběhne jen jednou: kdo telefon do konce
  nepoloží, tomu boss uteče (`EscapeReason.phoneStayedUp`). Položení telefonu během odpočtu bitvu obnoví jako dřív.
  Stav `warningCountdown` už nemá parametr `forgiven`; text v onboardingu je „10 seconds to put it back, or the boss escapes.“
- **Konec bitvy bez mezistavu** (od E1): karta bitvy mimo bitvu nemá žádné tlačítko (dřív „Begin Battle“, které problikávalo
  během K.O. scény, po Retreat a při zavírání). Místo drží neviditelný zástupce, aby scéna neposkočila. Odchod z výsledku
  (`leave(to:)` v `BattleView`) kartu schová hned (`isLeaving`). Každá nová bitva má čerstvou scénu (`battleSerial` + `.id`),
  takže se před startem neukáže „K.O.!“ ani ležící boss z minulé bitvy.
- **Přestávka**: „Next boss“ spustí dalšího bosse, „Same again“ otevře Fight sheet, „Change boss“ vede na Path,
  **„Done for today“ vede domů na Arenu** (`AfterBattle.home`).
- Ovládání v kartě bitvy: Pauses a Retreat vycentrované. Debug „Win now“ je malá kapsle v levém dolním rohu obrazovky.
- **Červená obrazovka zvednutého telefonu** má dole vedlejší tlačítko „Retreat“ (obrys, bez výplně) s potvrzením přímo
  u tlačítka (`confirmationDialog`, v iOS 26 vyrůstá z tlačítka). Potvrzení = boss uteče jako při běžném ústupu.
- **Live Activity počítá čas a HP sama** (od D1): appka na pozadí neběží, takže `ContentState` nese začátek a konec bitvy
  (`focusStartedAt`, `focusEndsAt`) a widget kreslí odpočet `Text(timerInterval:)` s popiskem „left“ a HP bar
  `ProgressView(timerInterval:countsDown:)`, který ubývá i se zamčeným telefonem. Při pauze, hovoru a zvednutí telefonu
  hodiny stojí (`frozenRemainingSeconds`). `staleDate` = konec bitvy: když appka spí, widget po konci ukáže
  „Time’s up! Open FocusQuest to claim your win“. Konec bitvy aktivitu ukončí s výsledkem (`outcome`: Victory / escaped),
  který zůstane 15 minut na zamčené obrazovce; zrušení bitvy nebo chyba ji ukončí hned.
- **Hrdina v bitvě (C1, `BattleStage`)**: v hlavičce karty bitvy stojí vlevo hrdina z profilu, vpravo boss.
  - Hrdina se skládá ze stejných vrstev jako v Shopu a profilu (`AvatarSprite.layers`), jen rozdělených na tělo a zbraň
    (`AvatarSprite.battleLayers`), aby se zbraň dala natočit a sklopit.
  - Druh útoku (`HeroAttack`) určuje nasazená zbraň, jinak povolání:

    | Zbraň / povolání | Útok |
    |---|---|
    | Wooden Sword, Excalibur | švih mečem, oblouk přes bosse |
    | Magic Staff, Mage | zářící koule se stopou, záblesk |
    | Archer | pixelový šíp |
    | Rogue | dvě rychlá bodnutí dýkou |
    | Warrior bez meče | výpad se štítem |

  - Rytmus: útok každých 5 s času bitvy (`BattleStage.attackInterval`). Boss zabliká, otřese se a vyskočí číslo poškození
    (~10 HP za sekundu bitvy, každý 7. útok kritický ×2). Číslo je jen efekt, pruh zdraví dál ubývá podle odpočtu.
  - Výhra: finální úder, boss se skácí a zmizí, „K.O.!“ a hrdina vyskočí. Okno výhry (a fanfára) přijde až po 1,8 s.
    Útěk bosse (ústup, zvednutý telefon, došlá pauza): hrdina sklopí zbraň, boss se otočí a odběhne, pak okno „escaped“.
    Když bitva skončí na pozadí nebo je zapnuté Reduce Motion, okno výsledku přijde hned.
  - Zvuky přes Battle sounds: **běžný útok je bez zvuku** (zvuk poškození je od E1 úplně odstraněný: efekt `attack`,
    jeho syntéza, volání při zásahu i při startu bitvy a ukázka v Nastavení; byl to generovaný tón, soubor neexistoval),
    finální úder = zásah (`hit`). Haptika (přepínač Haptics):
    finální úder = silný ťuk, výhra = úspěch, útěk = varování. **Běžné útoky záměrně nevibrují:** telefon leží displejem
    dolů na stole a vibrace každých 5 s by rušila soustředění.
  - Baterie: scéna se počítá z hodin v jednom `TimelineView`, žádné opakované animace. Během útoku 30 snímků/s,
    mezi útoky 2 snímky/s (hrdina přešlápne o pixel), na pozadí a se zamčeným telefonem stojí.
    Dýchání pixelových spritů (`PixelArtAvatarView`, ~3 snímky/s) se nově zastaví na pozadí a s Reduce Motion v celé appce.
  - Reduce Motion: statická scéna bez útoků a čísel, mění se jen pruh zdraví.
  - CI screenshot `battle-hit` (jen Debug) ukazuje scénu zastavenou uprostřed kritického zásahu.

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
- **Jednotné karty podle Shop › Backgrounds** (od E1): sdílený modifier `fqCard(selected:)` v `GlassSurfaces.swift`.
  Rozmazané sklo `.ultraThinMaterial`, na světlých pozadích tmavá vrstva rgba(13,11,28,.40), jinak bílá 6 %, okraj bílá 10 % 1 pt,
  rohy `FQRadius.smallCard`, bez stínu. Používá ho Shop (Gear, náhled, Backgrounds), Hero Profile, Stats, Habits, onboarding
  a seznam světů. Skleněné `glassCard` zůstává jen pro plovoucí prvky (karta bosse nad mapou, dialogy, panel přestávky, kapsle).
- **Výběr = bílý rámeček**: nasazený předmět v Gear i používané pozadí mají jen bílý okraj karty 2 pt, žádnou fajfku
  (u pozadí zůstal text „In use“ místo tlačítka).
- **Výchozí pozadí nových hráčů je Daybreak** (od E1, `UserProfile.fresh`, i po Reset progress). Stávající profily bez
  uloženého pozadí dál mají World scenes.
- **Stats › Habits je kalendář** (od E1): řádek = týden (Po–Ne zleva doprava), nejstarší týden nahoře, dnešek na konci;
  dny jdou chronologicky jako text. Dřív byl týden sloupec a při čtení po řádcích dny přeskakovaly.
- **Daily focus target v Hero Profile**: splněná část kruhu má barvu pásku zvolené třídy (`AvatarSprite.classAccent`, stejný
  token jako pásek hrdiny: Warrior červená, Mage fialová, Archer zelená, Rogue modrá), nesplněná tlumeně šedá. Dřív byl
  kruh v bílém `accent`, takže nebylo vidět, kolik je splněno.
- **Pulz aktuálního bosse na mapě** počítá `TimelineView` z hodin (`MapStopPulse`), ne `repeatForever` z `onAppear`, který se
  při překreslení nebo recyklaci hostingu v UIKit mapě zastavil. Je jemnější (2 pt, zvětšení jen o 18 %) a nesahá k hrdinovi.
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
  - **swipe mezi záložkami je úplně pryč** (od D1): přepíná se jen klepnutím v liště; swipe se pletl s mapou, posuvníky
    a tlačítky. `TabSwipeLock` je odstraněný.
  - každá změna záložky jde přes `switchTab(to:)` (směr a spuštění přechodu ve stejném překreslení).
- **Zvuky a haptika: jeden centrální `FQFeedback`** (`Audio/FQFeedback.swift`), samostatné přepínače v Settings › Sounds & haptics:
  - Tap sounds (klik na tlačítka a ovládací prvky), Haptics (všechny vibrace včetně alarmu), Battle sounds (finální úder,
    vítězství, útěk bosse, konec přestávky), Reward sounds (mince, XP, level up, série v plamenech), Alarm sound, hlasitost efektů,
  - u každého zapnutého přepínače se rozbalí karta „Try it“ s ukázkou,
  - tlačítka dostávají klik a vibraci přes společný styl (`FQPressStyle` / `TapFeedback`, i `ShopButtonStyle`, dlaždice Path,
    skleněná tlačítka a přepínače), nové tlačítko má proto používat `.buttonStyle(.fqPress)`, ne `.plain`,
  - **Battle sounds jsou výchozí vypnuté** (od D1), u nových i stávajících uživatelů: uložená hodnota platí jen s `isBattleSoundUserSet`
    (hráč přepínač sám přepnul); karta „Try it“ se při OFF schová a při ON rozbalí jako u ostatních,
  - **síla haptiky** Light / Medium / Strong (segmented control pod přepínačem Haptics, `hapticStrength`) platí pro celou appku
    (`FQFeedback` i `HapticEngineService`, násobek 0,5 / 0,8 / 1); „Try it“ přehraje zvolenou sílu,
  - tap = nahrávka `tap-click.mp3`, mince a XP = `reward-chime.mp3` (viz Zvuky a licence níž); ostatní efekty jsou syntetické tóny (`EffectSounds`),
  - efekty mimo bitvu hrají přes audio session `.ambient`: respektují přepínač ticha a nepřeruší hudbu z jiných appek;
    hudba bitvy zůstává `.playback` s `mixWithOthers` a po bitvě se session vrací na `.ambient`,
  - v uložených datech zůstávají klíče `isSFXEnabled` (= Tap sounds) a `isAchievementSoundEnabled` (= Reward sounds);
    `isBattleSoundEnabled` platí jen s `isBattleSoundUserSet`.
- **Zvuky a licence** (od D1): nahrávky z Pixabay pod **Pixabay Content License** (komerční použití v appce povoleno,
  bez uvedení autora, nesmí se prodávat samostatně jako zvuky ani hudba). Zdroj pixabay.com:
  | Soubor v appce | Původní soubor (Pixabay) | Použití |
  |---|---|---|
  | `tap-click.mp3` | `denielcz-immersivecontrol-button-click-sound-463065` | Tap sounds |
  | `reward-chime.mp3` | `lolo_s-start-474092` | mince a XP |
  | `fireplace-piano.m4a` | `juliush-crackling-fireplace-and-soft-piano-music-10454` | hudba „Fireplace piano“ |
  | `study-flow.m4a` | `luceris-study-music-602504` | hudba „Study flow“ |

  Písničky jsou v repu jako `audio-src/*.mp3` (mimo target); CI je na macOS převede `afconvert` do AAC 128 kb/s (`.m4a`)
  a ty jdou do appky (krok „Prevod hudby do AAC“, artefakt `hudba-m4a`). Když `.m4a` v repu je, převod se přeskočí.
  Lo-fi playlist (Calm Currents, Tokyo Sunset, Peaceful Drift) zůstává od HoliznaCC0 pod CC0.
- **Hudba bitvy**: Off, Lo-fi, Fireplace piano, Study flow, Brown noise, White noise (Settings › Music i Fight sheet).
  Pořadí je všude pevné, výběr jen zvýrazní. Čip má vždy šířku tučného popisku, takže se vybraný nerozšíří a v `ChipFlow`
  se nic nezalomí jinam (dřív to vypadalo, že se pořadí mění).
  Settings › Music (od E1): u každé stopy play/stop s **ukázkou 8 s** (zesílení a zeslabení 1,2 s, `MusicPreview`); jiná ukázka
  zastaví předchozí, odchod ze stránky zastaví vše. Pod seznamem **posuvník hlasitosti hudby** (`ambientVolume`, ukládá se,
  platí pro hudbu v bitvě i ukázku). Fajfka vybrané stopy je bílá.
  Fireplace piano a Study flow hrají ve smyčce; 6 s před koncem se skladba spustí znovu potichu a obě se prolnou, takže není slyšet střih.
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
- licence hudby a vyčištění git historie (staré commity s parodiemi).

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
- **Ověřit licence hudby**: `calm-currents.mp3`, `peaceful-drift.mp3`, `tokyo-sunset.mp3` (viz `CREDITS.md`).
- **Před vydáním vyčistit git historii.** Tři odstraněné parodické světy jsou v kódu i v `design/` pryč, ale ve
  starých commitech veřejného repa zůstávají. Před vydáním založit nové čisté repo (nebo přepsat historii
  a force-push; nevratné, jen na výslovný pokyn).
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
  - v Release je za `#if DEBUG` skrytá,
  - Debug obsahuje „Unlock all worlds“ / „Lock them back“ (`debugUnlockAllWorlds`, v Release se ignoruje)
    a v běžící bitvě malé tlačítko „Win now“ vlevo dole (`debugWinNow`): bitva hned skončí výhrou včetně odměn a posunu cesty.
- **`containerShape` na iOS 17:**
  - iOS 26 přetížení se nesmí volat mimo `#available(iOS 26.0, *)`, proto `fqContainer` vrací na starších iOS jen `self`,
  - `AnyShape` neumí `strokeBorder`, použít `stroke` + `padding(lineWidth / 2)`.
