# FocusQuest: rozhodnutí a kontext pro další session

Doplňuje `design/CHANGES.md` (zadání sekcí 0–15) a `design/progress.html` (stav, buildy, co otestovat).
Tady je to, co v nich není: rozhodnutí, která padla během práce, otevřené body a známé pasti.

Stav k 24. 11. 2026: větev `phase3-duolingo`; Q1 prošla jako build #86 (J1: stánek Shopu jako sbalovací hlavička nad rolovacím obsahem, kompaktní panel věci; J2: nadpis Settings jako v systémovém Nastavení), viz progress.html. Předtím P1 (I1–I6: obchod jako pixelový kupecký stánek s cedulemi, policemi, obrazy a pultem) a O1 (H1–H3: footer a hlavička Settings, tišší odměna, třídy bez pokrývek hlavy s maskou účesu), prošly jako build #85 (#82 zrušen startem #83, #83 a #84 spadly na testech obchodu). Předtím N1 (G1: plynulé přechody tutoriálu, A na stejné obrazovce v jedné animaci, B při změně obrazovky se schováním a objevením na stabilním cíli) prošel jako build #81. Předtím M1 (tutoriál: kroky 2–4 v otevřeném Fight setupu, cíle měřené v `.global`, Hero ve dvou krocích, celkem 14) prošel jako build #80, viz progress.html. Předtím L1 (opravy E1–E5 po testu #76: Skip v safe area, plynulé přechody, Home bez scrollu, Break panel) prošel jako build #79. Předtím zelený build #76 (K1: onboarding karta, tutoriál ve vlastním okně, Shop Supplies, sdílecí karty, zvuky) a #74 (J1: Habits, widget, freeze, Focus, zkratky, úkoly, poznámky, příprava iCloud); dříve #70 (I1), #69 (H1), #67 (G1); dříve #65 (F1); E1 (opravy z testu po D1) prošel jako build #62; F1 (Habits, mapa, easter eggy) prošel jako build #65; F2 (nový onboarding a coach marks) prošel jako build #66. Všechny sekce z CHANGES.md
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
  Zpět chevronem i tahem od levého okraje dává `NavigationStack` (vlastní gesto zpět je pryč). Zavření tahem dolů jako dřív.
- **Nadpis Settings jako systémové Nastavení** (od Q1/J2): systémový velký nadpis (`.navigationBarTitleDisplayMode(.large)`)
  se v listu na iOS 26 s viditelným pozadím lišty (O1) nekreslil: nahoře velký prázdný tmavý blok a „Settings“ až po odrolování.
  Proto vlastní řešení jen na kořeni: navigační lišta je skrytá (`.toolbar(.hidden)`), velký nadpis „Settings“
  (`.largeTitle` tučně, vlevo) je hlavička první sekce hned pod grabberem a roluje s obsahem. Při rolování se během 40 bodů
  zmenší a zprůhlední a nahoře se prolne malý nadpis na středu s materiálem `.bar` a dělicí čarou
  (`SettingsCompactTitleBar`, postup z `onScrollGeometryChange`, na iOS 17 velký nadpis jen odroluje).
  **Podstránky** (Sounds & haptics, Music, Notifications, Focus, Shortcuts) mají systémovou lištu s malým nadpisem
  (`.inline`) a zpět; lišta je v klidu průhledná, po odrolování má materiál (iOS 26: tvrdý scroll edge efekt nahoře,
  měkký dole; `settingsScrollEdges`). Pozadí lišty už není vynucené (`.visible`).
- **Reset progress** je v sekci „Your data“ s potvrzovacím dialogem. Smaže:
  - hrdinu, level, mince, statistiky, předměty a nastavení,
  - zálohy nečitelných dat (`.unreadable-backup`),
  - výběr appek a naplánované notifikace.

  Pak se znovu ukáže onboarding a po něm tutoriál (od F2).
- **Rate this app je skryté**, dokud nebude App Store ID. Pak se vrátí jako přímý odkaz
  `https://apps.apple.com/app/id<ID>?action=write-review`, protože `requestReview()` často nic neukáže.
- **Contact the developer** otevírá Mail jen s předmětem. Adresa zatím chybí (viz Otevřené body).
- Privacy Policy, Terms of Use a Support v patičce otevírají web:
  - Privacy a Support jsou na GitHub Pages,
  - Terms = standardní Apple EULA.
- **Credit** (od H1): úplně dole pod verzí a odkazy nenápadný řádek „Vibecoded with artificial intelligence“ (caption2, terciární barva).
- **Podstránky přes hodnotu** (od H1): `NavigationStack(path:)` + `NavigationLink(value: SettingsPage)` + `navigationDestination`.
  Klik při otevření hraje `onChange(of: path)`, ne gesto na řádku.

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
    do Caches (`map-terrain-v3.rgba`, při změně vzhledu zvýšit verzi) a další otevření je okamžité;
    nad ní vrstvy: závoj, zastávky, hrdina, easter eggy a mraky (stejné vrstvy jako Shop a Hero Profile); názvy světů jsou nad mapou v souřadnicích obrazovky,
  - mapa respektuje hlavičku a tab bar: `contentInset` scroll view = výška hlavičky nahoře a safe area s rezervou tab baru dole,
    takže se dá odrolovat tak, aby nic nebylo pod lištou, a kamera centruje do středu viditelné části;
    cesta začíná výš (`MapLayout.bottomMargin` = 420), aby šli první bossové posunout do středu,
  - názvy světů (`WorldLabelsOverlay`) se vodorovně drží v obrazovce (nikdy nejsou useknuté) a schovají se pod hlavičkou i nad tab barem,
  - **viditelný je jen jeden zamčený svět dopředu** (od F1): první zamčený svět (`frontier` v `MapContent`) je ztmavený
    závojem (`MapTerrain.veil`, 50 % tmavá, vyhlazený okraj po organické hranici). Všechny další světy zakrývají **plné
    pixelové mraky** (`MapTerrain.clouds`, 1 px = 8 bodů, bez vyhlazování): neprůhledné, s obrysem, stínem u spodku
    a světlými skvrnami, spodní okraj z oblých chomáčků (půlkruhy 3–7 px) pod hranicí světa, ne vodorovný pruh.
    Bossové, hrdina, easter eggy ani názvy světů pod mraky se nekreslí.
    **Od H1** jsou bossové zamčeného světa jen tmavé siluety (`colorMultiply(.black)`) bez jména, nejdou otevřít a VoiceOver
    čte jen „Locked boss 3 of 7 in {svět}“. Seznam světů (prostřední tlačítko vpravo nahoře) ukazuje totéž co mapa:
    odemčené světy, jeden zamčený (název, nápověda k odemčení, řada siluet, nejde rozbalit) a pak jedinou kartu
    „??? · N more worlds to discover“ bez názvů a bossů (`HiddenWorldsCard`). Při odemčení se závoj nového světa a mraky
    nad dalším světem jednou animovaně rozplynou (zprůhlednění, rozmazání, posun nahoru) a zapamatuje se to (`revealedWorlds`),
  - **přechody mezi světy** (od F1): hranice je organická (`MapLayout.boundaryShift`: dlouhá vlna + šum, vybočení až ~140 bodů)
    a pixely na ní se náhodně promíchají, takže nikde není rovný šev přes celou šířku. Kolem Coral Deep je pobřeží
    (písek na souši, mělčina ve vodě). Cesta jde přes hranici bez přerušení. Hlavička mapy má rozmazané tmavé pozadí
    se scroll edge přechodem (`MapHeaderBackground`), pod ní neprosvítají bossové ani názvy,
  - **okraj mapy jako pixelový pergamen** (od F1, `MapLayout.parchmentDepth`): zubatý okraj z pixelů, 2 px tmavě hnědý
    a 2 px světlý lem, šikmo otrhané rohy, mimo mapu průhledno a tmavé pozadí obrazovky. Vlastní kresba v kódu,
  - horní tlačítka mapy mají neinteraktivní sklo a mapa je `UIViewControllerRepresentable` s hosting controllerem jako potomkem:
    interaktivní Liquid Glass nad UIKit mapou pohlcoval klepnutí a zůstával rozsvícený (test po C1),
  - cesta se v každém světě jednou přehoupne z jedné strany na druhou, zastávky jsou rovnoměrně po její délce (`MapLayout`),
  - zastávky: poražený má vlajku, aktuální pulzuje a stojí u něj hrdina, zamčený je šedý se zámkem,
  - kamera po otevření mapy najede z oddálení na aktuálního bosse; tlačítko s terčíkem vrátí kameru zpět,
  - klepnutí na zastávku otevře skleněnou kartu (hláška, délka „⏱ 15 min“ i u zamčeného bosse, Fight nebo důvod zámku); zavře se klepnutím do mapy nebo tahem dolů,
  - **easter eggy** (od F1, `MapEasterEgg`, `MapEasterEggs.swift`): každý jen jednou za celou hru (`UserProfile.foundEasterEggs`,
    smaže je i Reset progress), žádné tipy ani nápovědy:

    | Svět | Co udělat | Odměna |
    |---|---|---|
    | Whisperwood | 3× klepnout na rybník (kola na vodě) → vynoří se truhla → klepnout na truhlu | +150 mincí |
    | Orbit | 4× klepnout na oranžovou planetu (zachvění) → mince vyletí | +200 mincí |
    | Farm | křížek (X) vlevo dole: 3 klepnutí truhlu postupně vykopou → klepnout na truhlu | +100 mincí |

    Odměna: zvuk mincí (Reward sounds), haptika úspěchu a nahoře počítadlo mincí, které se dopočítá. Klepnutí jsou tap gesta
    v obsahu `UIScrollView` (tah je zruší, plocha roste se zoomem). Debug: „Reset easter eggs“,
  - **nalezený easter egg zůstane na mapě vidět** (od testu #66, `FoundEasterEggView`): Farm = vykopaná jáma přes křížek
    (11 × 7 buněk) s otevřenou prázdnou truhlou a hromádkou hlíny, Whisperwood = otevřená prázdná truhla na pravém břehu
    rybníka, Orbit = malá pixelová vlajka na vrcholu oranžové planety. Stav se bere z `foundEasterEggs` (žádná nová data,
    Reset easter eggs / Reset progress stopy smažou). Další klepnutí nic nedává: jen klik a vibrace (Tap sounds, Haptics)
    a malé poskočení, s Reduce Motion bez pohybu,
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
- **Pauzy** (od I1, dřív 2 za bitvu): **1 pauza zdarma za bitvu** (`freePausesPerBattle`), každá nejdéle 2 minuty.
  Hovor se do pauz nepočítá.
  - **Extra pause** v Shopu (Gear › Battle supplies) za **40 mincí** (`UserProfile.extraPausePrice`), drží se nejvýš **5**
    (`maxExtraPauses`, uloženo v profilu `extraPauses`, starší profily = 0). V jedné bitvě jde navíc použít nejvýš **1**
    (`maxExtraPausesPerBattle`), vždy až po pauze zdarma. Použití se hned odečte z profilu (`onExtraPauseUsed` → `consumeExtraPause`).
  - Cena: 3 mince za minutu → extra pauza ≈ 13 minut soustředění, levnější předměty Shopu stojí víc. Má být dostupná,
    ale ne zadarmo; limit 5 a 1 za bitvu brání tomu, aby se z bitvy stalo „pauzování“.
  - Na kartě bitvy je pod tlačítky řádek „Pause: 1 free + 2 extra“ (po použití „free used“ / „extra used“), tlačítko má popisek
    Pause / Extra pause / No pauses a nápovědu pro VoiceOver. Debug: „+3 extra pauses“.
- **Zvednutý telefon: jediný odpočet, bez „slip one time“** (od E1). Dřív: první propadlý odpočet v bitvě se odpustil
  (obrazovka „Slip forgiven“ na 2,2 s), odpočet běžel znovu a teprve druhý propadlý znamenal útěk bosse (`hasUsedSlipGrace`,
  `slipForgivenSeconds`). Teď odpočet (10 s, `AntiCheatRules.warningSeconds`) proběhne jen jednou: kdo telefon do konce
  nepoloží, tomu boss uteče (`EscapeReason.phoneStayedUp`). Položení telefonu během odpočtu bitvu obnoví jako dřív.
  Stav `warningCountdown` už nemá parametr `forgiven`; v tutoriálu (krok 4) je „Lift it and the boss escapes in 10 seconds“.
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
    | Warrior (sekera, od O1/H3) | švih sekerou (jako meč) |

    `HeroAttack.bash` (výpad se štítem) od O1/H3 nic nepoužívá; Warrior nemá štít.

  - **Srdíčka místo HP čáry** (od I1, `BossHearts`, `BossHeartsView`): pixelová srdíčka 8 × 7, počet podle obtížnosti
    (Novice 3, Adept 4, Elite 5, Mythic 6), každé má 4 čtvrtky (vlevo nahoře, vpravo nahoře, vpravo dole, vlevo dole;
    ubývá se od posledního srdíčka vpravo). Rozestup úderů = délka bitvy / počet čtvrtek (Novice 15 min = 12 čtvrtek, úder
    po 75 s), úder k padne v k × délka / čtvrtky, poslední čtvrtka je finální úder přesně na konci. Hrdina zaútočí jen při
    úderu (dřív každých 5 s), vyskočí „-¼“ (žádné kritické zásahy). Srdíčko se otřese a čtvrtka se rozpadne na 6 pixelů;
    Reduce Motion = čtvrtka jen zmizí. Kosmetické ťukání nic neubírá. **Live Activity má dál plynulý pruh podle času.**
    VoiceOver: „2 and 3 quarters of 3 hearts left“.
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
  - **Ťukání na bosse během bitvy (od testu #66, čistě kosmetické)**: klepnutí na bosse (jen fáze `fighting`) spustí útok
    `.poke` podle třídy/zbraně (stejné animace jako běžný útok: švih, kouzlo, šíp, dýka, štít), boss zabliká, otřese se
    a odletí jiskry. **Neubírá HP ani čas, žádné číslo poškození, žádný zvuk zásahu**, jen klik a vibrace (Tap sounds, Haptics).
    Nejvýš 3 klepnutí za sekundu (`BattleStage.maxPokesPerSecond`), běžný útok ani finální úder klepnutí nepřeruší.
    Reduce Motion: boss se jen otřese o 3 body (0,3 s).
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
  a seznam světů. Skleněné `glassCard` zůstává jen pro kartu bosse nad mapou a kapsle.
- **Sjednocené plovoucí karty** (od testu #66): Victory, „Call ended – continue the battle?“, útěk bosse, Battle stopped,
  panel přestávky a bublina tutoriálu (coach marks) mají `fqGlassPanel(radius:)` = `fqCard` (stejné světlejší průsvitné sklo
  jako hlavní karta bitvy a Shop › Backgrounds, okraj bílá 10 %) + měkký stín 0 12 30 černá 35 %. Dřív tmavé `glassCard`
  (rgba(13,11,28,.60)), resp. u bubliny téměř neprůhledná tmavá .90. Rohy zůstávají (`FQRadius.dialog`, `breakPanel`, `smallCard`).
  Vnitřní dlaždice (XP, Coins, Keep going, Same again, Change boss) mají sdílené `fqInnerTile(in:)`: bílá 8 % + okraj bílá 12 %,
  bez dalšího materiálu (sklo ve skle by kartu ztmavilo). Kontrast: text bílá 100 % / 78 % na tmavé variantě materiálu
  (obrazovky bitvy jsou `.dark`) nad 28% ztmavením scény, stejně jako na kartě bitvy; na světlých pozadích přidá `fqCard` tmavou vrstvu .40.
  Onboarding žádné tmavé karty neměl (používá `fqCard`).
- **Výběr = bílý rámeček**: nasazený předmět v Gear i používané pozadí mají jen bílý okraj karty 2 pt, žádnou fajfku
  (u pozadí zůstal text „In use“ místo tlačítka).
- **Výchozí pozadí nových hráčů je Daybreak** (od E1, `UserProfile.fresh`, i po Reset progress). Stávající profily bez
  uloženého pozadí dál mají World scenes.
- **Stats › Habits je pevná mřížka od prvního dne** (od J1, dřív byl dnešek přišpendlený vlevo nahoře a mřížka se každý den posouvala):
  - řádky jsou pevně M, T, W, T, F, S, S,
  - sloupce jsou týdny; sloupec 1 je týden prvního dne používání (`UserProfile.firstUseDate`; u stávajících hráčů den první bitvy).
  - Dny před prvním dnem se nekreslí, budoucí dny mají tlumený čárkovaný obrys.
  - Dnešek má bílý rámeček a každý den se posune o čtvereček dál.
  - Aspoň 15 sloupců, další týdny mřížku prodlouží; vodorovně se dá posouvat a při otevření se posune na dnešek (`todayWeek`).
  - Popisek: „Each square is one day, starting from your first day · filled by your focus time“.
  - Zamrzlý den (Streak freeze) je ledově modrý s vločkou.
  - Škála je zelená od tmavé po světlou.
  - Mini Habits ke sdílení = posledních 5 týdnů (`recentWeeks`).
- **Daily focus target v Hero Profile**: splněná část kruhu má barvu pásku zvolené třídy (`AvatarSprite.classAccent`, stejný
  token jako pásek hrdiny: Warrior červená, Mage fialová, Archer zelená, Rogue modrá), nesplněná tlumeně šedá. Dřív byl
  kruh v bílém `accent`, takže nebylo vidět, kolik je splněno.
- **Oslava série** (od testu #66): po první dokončené bitvě dne (`PlayerStats.isStreakCelebrationDue`) se po návratu na Home
  (bitva i Fight sheet zavřené, Home viditelný) plamínek rozhoří (zvětšení 1,65× a záře), číslo naskočí ze včerejší hodnoty
  (`numericText`), pilulka poskočí a z plamínku odletí pixelové jiskry (`StreakSparks`, 0,9 s); haptika úspěchu a zvuk
  level up (Reward sounds). Jednou za den: den poslední oslavy je v UserDefaults `fq.streakCelebratedDay` (smaže ho Reset progress).
  Reduce Motion: jen prolnutí čísla, bez zvětšení a jisker. VoiceOver oznámí „Streak up: N days“.
- **Pulz aktuálního bosse na mapě** počítá `TimelineView` z hodin (`MapStopPulse`), ne `repeatForever` z `onAppear`, který se
  při překreslení nebo recyklaci hostingu v UIKit mapě zastavil. Je jemnější (2 pt, zvětšení jen o 18 %) a nesahá k hrdinovi.
- **Výsledková okna jsou skleněná** (`ResultDialog` v `Views/DesignSystem/Motion.swift`): útěk bosse, vítězství,
  Battle stopped a Call ended.
  - Jemné ztmavení scény 28 % a skleněná karta (`fqGlassPanel`, od testu #66 stejné sklo jako karta bitvy), panel přestávky má stejné ztmavení.
- **Panel přestávky je sheet se dvěma výškami** (od I1, `BreakPanel` v `BattleView.swift`). **Od L1/E5** ukazuje
  kompaktní výška všechno potřebné: BREAK, odpočet, Next boss, Same again + Change boss a Done for today. Roztažená
  výška přidá jen scénu `RestingHeroScene` (hrdina spí u pixelového ohně, nad ním „z“). Obě výšky se **měří z obsahu**
  (spodek Done for today, resp. scény + okraj + spodní bezpečná zóna), takže nic není oříznuté ani s větším písmem
  nebo na SE; vybraná výška se při přeměření posune s nimi. Scéna je v kompaktní výšce průhledná (nekouká proužek).
  Mezi výškami plynulý tah systémovým madlem, `interactiveDismissDisabled`: úplně stáhnout nejde, zavírá se jen tlačítky.
  Při odchodu (Same again, Change boss, Done) se nejdřív zavře sheet a po 0,38 s celá bitva (dvě prezentace naráz
  se zasekávaly). Když už není další boss, hlavní akce je Same again.
  - **Klepnutí na spícího hrdinu** (L1/E5, jen kosmetické): protáhne se (0–0,45 s), „z“ zmizí, malý poskok (do 10 bodů),
    oheň vyšlehne s pixelovými jiskrami (0,9 s), klik (Tap sounds) a lehká vibrace (Haptics); po 3 s zase usne
    (další klepnutí čas prodlouží). Probuzení běží 30 snímků/s, spánek 8. Reduce Motion: bez pohybu, „z“ a záře
    ohně se jen prolnou. VoiceOver: tlačítko „Your hero sleeps by the fire“ s nápovědou „Wakes your hero up“.
  - Pod výsledkem se karta bitvy schová, aby neprosvítala (dřív bylo vidět „Begin Battle“).
  - Karta se objeví pružinou (0,92 → 1), s Reduce Motion jen prolnutím.
- **Třídy nemají pokrývku hlavy, účes je vždy celý vidět** (od O1/H3, `AvatarSprite.classMarks`). Helma Warriora,
  kapuce Archera a kápě Roguea jsou pryč. Třídu odliší zbraň + doplněk: Warrior sekera (pravá ruka) + kovový
  nárameník, Mage hůl s fialovým kamenem + krátký plášť, Archer luk + toulec s šípy na zádech, Rogue dýka + šátek
  přes pusu. Zbraň třídy (slot weapon) ustoupí zbrani z obchodu, doplněk zůstává.
  - **Pokrývky hlavy jsou jen z obchodu** a každá definuje masku účesu (`EquipmentItem.hairBrimRow`,
    `AvatarSprite.hairRows`): vlasy do okraje pokrývky a pod jejími pixely se schovají; Long nechá jen pramínky
    po stranách pod okrajem, Spiky a Mohawk se schovají celé, Short a Bald podle tvaru. Vlasy nikdy netrčí přes pokrývku.
  - Testy: `testClassesWearNoHeadwearAndHairIsAlwaysWhole` a `testHeadwearMasksEveryHairstyleForEveryClass`
    (4 třídy × 5 účesů × 3 pokrývky); onboarding „Create your hero“ kreslí stejné vrstvy (`HeroAvatarView`).
- **Shop je pixelový kupecký stánek** (od P1/I, `ShopView.swift` + `ShopStallArt.swift`; ruší seznam karet, podtržené
  záložky, náhled hrdiny v kartě a Preview pozadí přes celou appku). Vše je kreslené po pixelech (Canvas, mřížky znaků,
  pixel stánku 3 body) stejně jako sprity; žádné cizí assety, žlutá jen pro hlavní akci, žádná tyrkysová ani systémová modrá.
  - **Hlavička** (od Q1/J1 vlastní rozvržení místo `pinnedTopHeader`, který na iOS 26 dělal kolem hrdiny velké tmavé
    rozmazané plochy a police scrollovaly pod stánek): nahoře řádek se štítkem „Shop“, mincemi (pixelová mince + číslo)
    a ozubeným kolem, pod ním stánek: pruhovaná stříška (žlutá a krémová, obloučky), dřevěné sloupky, v okně mezi nimi
    obloha a krajina přes celé okno (`StallScene`: scéna pozadí zvětšená tak, aby okno vyplnila, horizont dole,
    12 snímků/s, s Reduce Motion stojí), hrdina velký na kamenném podstavci, pod stánkem pult (prkno), z něj visí cedule.
  - **Rozměry stánku** (`StallHeaderMetrics`): stříška + okno + pult = 35 % celé výšky displeje (SE okno 185 bodů,
    Pro Max 287). Hrdina s podstavcem zabírá asi 84 % okna (SE 140 bodů, Pro Max 210, strop 210), podstavec má
    pixel 3–6 bodů podle okna. Bez pozadí hlavičky, bez materiálu a rozmazání.
  - **Sbalování při rolování**: obsah záložky je ve vlastním `ScrollView` pod hlavičkou. Prvních N bodů rolování
    (N = 60 % okna) zužuje okno až na 40 % jeho výšky; hrdina s podstavcem se zmenšuje ke spodní hraně okna
    (`scaleEffect`), stříška a pult zůstávají. Pak cedule zůstanou přilepené nahoře a obsah mizí pod nimi
    (maska s přechodem 14 bodů; nikdy se nekreslí přes stánek). Viditelná plocha `ScrollView` začíná pod zmenšeným
    stánkem a cedulemi (`safeAreaPadding`), obsah má nahoře navíc rozsah sbalení. Přetažení nahoru stánek nezvětší.
    Stánek nemá tlačítka a `allowsHitTesting(false)`, takže tah po něm roluje obsah jako tah po policích.
  - **Cedule** (I2): Gear / Backgrounds / Supplies jako dřevěné desky na dvou řetízcích s pixelovou ikonou (meč, obraz,
    lahvička) a nápisem. Aktivní je světlejší se zlatým lemem a při výběru se zhoupne (keyframe kolem horní hrany;
    Reduce Motion bez zhoupnutí). Klik a vibrace výběru přes `FQFeedback`.
  - **Gear na policích** (I3): skupiny (Helmets & hats, Weapons, Boots, Gadgets) mají malou dřevěnou cedulku nad
    policí; věci stojí na prkně jen jako sprity (`ItemSprite`: vrstvy předmětu oříznuté na obrys, pixel 3–6 bodů),
    pod prknem visí papírová cenovka na provázku (pixelová mince + cena, vlastněné „Owned“), nasazená věc má hvězdičku
    a bílou záři, vybraná žlutou záři a zvedne se o 4 body. Klepnutí = hrdina si věc hned vyzkouší (poskok a 8 jisker,
    ne když ji už má nasazenou) a dole nad lištou vyjede kompaktní panel (sklo `fqGlassPanel`, od Q1/J1 v jednom řádku:
    vlevo název a popis na nejvýš 2 řádky, vpravo žluté „Buy · 150“ / žluté „Equip“ / vedlejší „Unequip“, bez mincí
    šedé „Need 40 more“; s velkým písmem pod sebou, tlačítko přes celou šířku). Panel je jen ve spodní bezpečné zóně
    obsahu, cedule ani stánek nepřekryje; po výběru se celá police s věcí (u Supplies pult) odroluje nad panel
    (`scrollTo` s `anchor: nil`, jen o potřebný kus). Panel zavře druhé klepnutí na věc, tah dolů nebo VoiceOver
    escape (žádný křížek); přepnutí cedule nebo odchod ze Shopu ho zavře i se zkoušením.
  - **Backgrounds jako obrazy na zadní stěně** (I4): stěna ze svislých prken, obrazy v pixelovém zlatém rámu
    (`PixelFrame`, `PaintingScene`), vodorovný karusel se snapem na střed (`scrollTargetBehavior(.viewAligned)`,
    `scrollPosition(id:)`), sousední obrazy zmenšené na 0,8 vykukují po stranách. Visačka na rámu: „Free“, cena
    nebo „Owned“; používaný obraz má hvězdičku. Vycentrovaný obraz se plynule prolne do okna stánku (živý náhled),
    celá appka ani lišta se nepřepínají (`previewBackground` Shop už nenastavuje). Pod obrazem název, popis a žluté
    „Use“ / šedé „In use“ / žluté „Buy · N“ / „Need N more“. Odchod ze Shopu nebo přepnutí cedule vrátí do okna
    používané pozadí.
  - **Supplies na pultu** (I5): dřevěný pult s přední stěnou; Extra pause = přesýpací hodiny (písek se přesýpá
    ve 4 fázích), Streak freeze = ledový krystal (třpyt), s Reduce Motion stojí. Odznak „×2“ u předmětu, na přední
    stěně pultu název a limit „2 / 5“. Popis až v panelu (stejný jako u Gear) s „Buy · 40“ / „Need N more“ /
    „Max 5 held“ (VoiceOver „You hold the maximum of 5“).
  - **Kvalita** (I6): VoiceOver u každé věci název, stav (cena, Owned, Equipped, In use, počet) a nápověda; cenovky,
    cedule a popisky mají `lineLimit(1)` + `minimumScaleFactor`, takže je velké písmo nerozbije. Test
    `ShopStallTests` vykreslí stánek ve skutečném okně na SE i Pro Max s největším písmem (Reduce Motion se v testu nastavit nedá, ověří iPhone).
- **Připnutá hlavička (`pinnedTopHeader`)**: přechod do průhledna (24 pt) je součástí odsazení obsahu,
  takže na začátku nic nepodjíždí pod hlavičku. Dřív přesahoval 60 pt a zakrýval nadpis první sekce.
- **Settings nemají tlačítko Done**, zavírá se jen tahem dolů (VoiceOver gestem escape).
- **Footer Settings na střed** (od O1/H1): „FocusQuest version …“, odkazy a credit na středu se stejnými odstupy (8 bodů).
  Privacy Policy · Terms of Use · Support jsou `.footnote` na jednom řádku a žádný se nezalomí; když se nevejdou
  (úzký iPhone, velké písmo), `ViewThatFits` je dá pod sebe, každý na střed.
- **Hlavička Settings** (O1/H1 → Q1/J2): O1 vynutil `toolbarBackground(.visible)`, aby se velký nadpis nekreslil přes obsah,
  ale na iOS 26 tím velký nadpis zmizel. Od Q1 viz „Nadpis Settings jako systémové Nastavení“ výše.
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
  - **Všechny zvuky i haptika jsou výchozí zapnuté** (od K1/D6): Battle sounds ON, Tap sounds ON, Haptics ON (i Reward a Alarm sound).
    **Ruší dřívější rozhodnutí „Battle sounds OFF by default“** (od D1). Uložená hodnota Battle sounds platí jen s `isBattleSoundUserSet`
    (hráč přepínač sám přepnul), jinak platí výchozí ON. Bez migrace (jediný uživatel). Karta „Try it“ se při OFF schová a při ON rozbalí,
  - **audit tap zvuku (od testu #66, opraveno v H1)**: kde nejde použít `FQPressStyle` (systémové řádky Listu, `NavigationLink`, `.bordered`
    tlačítka, chipy s `onTapGesture`), je `FQFeedback.shared.tap()` **přímo v akci** tlačítka, u navigace v `onChange` cesty.
    `.fqTapSound()` se `simultaneousGesture(TapGesture())` je pryč: v `List` gesto pohltilo klepnutí a řádky Nastavení
    se neotevřely (regrese buildu #67). **Na řádky Listu nikdy nedávat tap gesta.** Skleněná tlačítka (`glassButtonStyle`,
    `prominentGlassButtonStyle`) simultánní gesto mají dál, mimo List funguje;
    přepínače mají `Binding.fqTapFeedback()` (klik **před** změnou, takže cvakne i vypnutí Tap sounds / Haptics);
    výběr v `ValueMenu` a segmentový výběr síly haptiky klikají při změně; tlačítka v potvrzovacích dialozích volají
    `FQFeedback.shared.tap()` v akci. Šťouchání do bosse na Home hraje klik vždy (naštvaný boss přidá zásah z Battle sounds).
    Záměrně bez kliku: ukázky „Try it“ (hrají vlastní zvuk), posuvníky (hlasitost má vlastní ukázku), tah a zoom mapy,
    klepnutí do prázdné mapy a karty Habits (jen zrušení výběru),
  - **síla haptiky** Light / Medium / Strong (segmented control pod přepínačem Haptics, `hapticStrength`) platí pro celou appku
    (`FQFeedback` i `HapticEngineService`, násobek 0,5 / 0,8 / 1); „Try it“ přehraje zvolenou sílu,
  - tap = nahrávka `tap-click.mp3`, mince a XP = `reward-chime.mp3` (viz Zvuky a licence níž); ostatní efekty jsou syntetické tóny (`EffectSounds`),
  - **odměna hraje na 37 %** (od O1/H2, `EffectSounds.Effect.gain`, asi −8,6 dB): nahrávka `reward-chime.mp3` byla výrazně
    hlasitější než ostatní efekty; násobí se s posuvníkem Effects volume (i v ukázce v Settings), ostatní efekty 100 %,
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

  - plánování se na povolení neptá (od F1, viz kontextová žádost výš); bez povolení nic nenaplánuje, chyby jdou do logu (`Logger`, kategorie notifications),
  - Settings ukazují skutečný stav (Allowed, Not allowed yet + Allow, Banners off nebo Off + Open Settings),
  - Debug: „Test notifications“ naplánuje každý typ za 5, 7 a 9 s, „Show pending“ vypíše naplánované s časem.
- **Onboarding (od F2, `Views/Onboarding/OnboardingView.swift`)**: při prvním spuštění stránkovaný onboarding
  na pixelovém pozadí (swipe, tečky, zpět šipkou i swipem, Continue vždy nad tečkami). Volby jsou v konceptu a do profilu
  se uloží až tlačítkem Start, takže se při listování neztratí:

  | # | Stránka | Obsah |
  |---|---|---|
  | 1 | Vítej | hrdina vs. boss (pohupují se), „Focus. Your hero fights.“; Skip skočí na jméno |
  | 2 | How it works | soustředíš se → hrdina bojuje → mince, gear, světy; Skip |
  | 3 | Jméno | „What should we call you?“ → `username`, pozdrav „Hi, {jméno}“ na Home a jméno na Hero tabu |
  | 4 | Focus | „What do you want to make time for?“ chipy Work, School, Reading, Project, Exercise, Creative, Languages + vlastní, víc naráz |
  | 5 | Hrdina | třída, pleť, vlasy, barva vlasů, oblečení, boty; hrdina připnutý nahoře; karta voleb stojí pevně s čistými zaoblenými rohy (bez masky, od K1) a roluje jen její obsah, Continue je samostatně pod kartou; změna = poskočení |
  | 6 | Ready | „Ready, {jméno}?“ → Start → Home a hned tutoriál |

  - Onboarding vidí jen nový hráč (bez odehraných bitev). Hráč, který appku už používá, ho přeskočí i s tutoriálem.
  - Jméno: 1–20 znaků, písmena i s diakritikou, číslice, mezery (`UserProfile.cleanName`, totéž na Hero tabu); prázdné = „Hero“.
  - Položky „focus“ nahradí výchozí seznam nového hráče; položky s odehranými bitvami zůstanou (`applyOnboardingFocus`).
  - Řady chipů, které přetékají, mají na kraji fade (`FadingHorizontalScroll`, i v editoru na Hero tabu).
  - Notifikace se v onboardingu neřeší.
- **„Focus“ místo „study“** (od F2): appka není jen na učení. V textech je „focus“ / „what you're focusing on“
  (Fight sheet, Stats › Focus, „Your focus list“, cíl „Focus every day“). Interní typ `StudySubject` a id zůstávají kvůli uloženým datům.
  Od H1 ani Privacy a Support na webu ani komentáře neříkají „subject“ (stránka správy je „Your focus list“, tlačítko „Edit focus list“).
  Názvy bossů a skladba „Study flow“ se nemění.
- **Tutoriál jako coach marks místo TipKitu** (od F2, `Views/Onboarding/CoachMarks.swift`). TipKit je pryč (FQTips, popover tipy, Reset tips).
  - Celá obrazovka ztmavne (72 %), zvýrazněný prvek je vyříznutý zaobleným výřezem podle tvaru (kapsle/kruh, karty 20 pt,
    Start Battle rohy tlačítka + 8) se žlutou pulzující září; vedle bublina (titulek, max 2 věty, „3 of 14“, Next),
    nahoře vlevo „Skip tutorial“.
  - **Kroky 2–4 stojí v otevřeném Fight setupu** (od M1/F1; ruší L1/E1 „tutoriál nikdy neotvírá listy“). Next v kroku 1
    posune krok a zároveň otevře Fight setup s bossem na řadě (`syncTutorialFightSheet` v `MainTabView`); overlay
    mezitím zmizí a objeví se, až list dojede, rovnou na sekci Focusing (krok 2; od N1/G1, přechod typu B níže).
    Krok 3 = sekce Sound, krok 4 = tlačítko Start Battle (`CoachTarget.focusing/.sound/.start`). Next v kroku 4 list
    zavře a krok 5 („Not feeling it?“) počká, až list zmizí. Skip během kroků 2–4 list taky zavře; list, který otevřel
    hráč, tutoriál nezavírá (`tutorialOwnsFightSheet`). Obnovený krok 2–4 po pádu list při spuštění znovu otevře.
    Ve Fight setupu během tutoriálu (`coach.step != nil`): `allowsHitTesting(false)`, zavření tahem zablokované
    (`fqSheetDismissal(blocked:)`, VoiceOver escape nic neudělá), jen výška podle obsahu (bez `.large`), krok s prvkem
    mimo zorné pole list odroluje (`scrollTo(target, anchor: nil)`).
    **Minulá chyba (L1)**: overlay prvky v listu nenašel. Pravděpodobná příčina: `.environment(coach)` v `MainTabView`
    stojí pod modifikátorem `.sheet`, takže ho obsah listu nedostal (`coach` byl nil a list nic nehlásil). Teď ho
    `FightSheetView` dostává přímo v `.sheet { … .environment(coach) }`.
  - **Měření cílů v `.global`** (od M1/F1, bez anchorPreference): `.coachMark(target)` má v pozadí `GeometryReader`
    a hlásí `frame(in: .global)` do sdíleného `CoachMarkStore` (`report`: `onAppear` a každá změna včetně rolování;
    `onDisappear` = `withdraw`; nulový rámeček se nebere). `CoachMarkStore` je ten sdílený „TutorialController“ (@Observable).
    **Pojistka pro list**: není jisté, jestli `.global` v listu počítá od okna, nebo od horní hrany listu. Každý kořen
    hierarchie (`.coachRoot()`: stránka záložky, lišta, `.coachRoot(sheet: true)` ve Fight setupu) má neviditelnou UIKit
    sondu (`CoachRootProbeView`): rozdíl její polohy v okně (`convert(.zero, to: nil)`) a `.global` počátku kořene se
    přičte k rámečkům cílů pod ním (v hlavním okně 0). Kořen mimo okno (skrytá záložka) se vynechá.
  - **Spotlight čeká na dojetý list**: sonda listu po vstupu do okna čeká na konec prezentace (transition coordinator,
    pojistka 0,9 s; bez coordinatoru 0,5 s, `CoachMetrics.sheetSettle*`). Do té doby cíle listu nemají rámeček.
    `sheetOnScreen` (sonda listu je v okně) zároveň drží cíle Home a lišty, dokud se list nezavře, takže výřez nehoní
    jedoucí list. Pojistka 1 s platí dál: cíl, který do 1 s není, = bublina uprostřed bez výřezu, Next funguje vždy.
  - **Overlay je ve vlastním `UIWindow`** (od K1, `CoachOverlayWindow`, úroveň `.normal + 5`) nad hlavním oknem,
    tedy i nad listy (prezentují se v hlavním okně). Okno je vidět jen během tutoriálu a pohlcuje všechna klepnutí
    i tahy (ani list nejde stáhnout); projde jen Next a Skip.
  - **Bublina je vidět vždy, když tutoriál běží** (L1/E1): bez předchozí bubliny hned uprostřed, jinak se na prvek čeká
    nejdéle 1 s (`CoachMetrics.fallbackSeconds`, `CoachLayout.resolve`). Prvek, který se do 1 s nenajde (nebo je mimo
    obrazovku), = bublina uprostřed bez výřezu. Next funguje vždy, **kroky se nikdy nepřeskakují**, přeskočit jde jen celý
    tutoriál přes Skip. Rozvržení (výřez + bublina) počítá čistá funkce `CoachLayout.anchored/centered` v `CoachSpace`.
  - **„Skip tutorial“** (od L1/E2) je samostatná pilulka (plné tmavé pozadí, okraj, stín) **vlevo nahoře v safe area
    ve výšce ozubeného kola** (horní hrana 8 bodů pod bezpečnou zónou, řádek 44 bodů, `CoachMetrics.skipTop/skipRowHeight`),
    ve všech krocích na stejném místě. Dřív byl přes hodiny: `GeometryReader` s `.ignoresSafeArea()` hlásí bezpečnou zónu 0
    (viz Známé pasti). Nic nepřekrývá: během tutoriálu nadpis vlevo nahoře na každé záložce uhne o 52 bodů dolů
    (`coachSkipClearance()`, prostředí `coachSkipClearance`: `ScreenHeader`, hlavička Path, štítek Shop); ozubené kolo,
    mince a tlačítka vpravo zůstávají. Pás přes celou šířku (`safeAreaInset` 56 pt) je pryč. Bublina nikdy nezajede do řádku Skip.
  - **Dva typy přechodů** (od N1/G1, ruší L1/E3 „text se prolne hned a bublina dojede, až prvek stojí“; tím
    bublina na stejné obrazovce stála ~0,5 s se starým místem a novým textem a při otevření panelu výřez skočil
    na Sound). Typ určí `CoachStep.transition(to:)`: stejná záložka a stejný stav Fight setupu = A, jinak B.
    Next 5→6, 2→3, 3→4, 9→10, 10→11, 12→13, 13→14 = A; 1→2, 4→5, 6→7, 7→8, 8→9, 11→12 = B.
    - **A, stejná obrazovka**: cíle se hlásí už při zobrazení (`.coachMark`, i mimo aktivní krok), takže rámeček
      nového cíle je v `CoachMarkStore` předem. Overlay v obsluze Next (`CoachMarkOverlay.next`) hned v jednom
      `withAnimation` (pružina 0,35 s) nastaví nový text i rozvržení: bublina odjede, výřez změní pozici, velikost
      a zaoblení (`CoachDimShape.animatableData`) a text se prolne, vše současně. Obrazovka, která cíl odroluje
      (`scrollTo(target, anchor: nil)` ve stejné pružině), hlásí svou viditelnou plochu (`.coachViewport()` na
      ScrollView v `ScreenScaffold` a ve Fight setupu) a overlay jede rovnou tam, kde cíl po odrolování bude
      (`CoachLayout.scrolledIntoView`, `CoachMarkStore.settledFrame`). Kdyby odhad nesedl (konec obsahu),
      sledování výřez po dojetí doladí. Chybějící cíl = jen prolnutí textu a čekání (pojistka 1 s).
    - **B, změna obrazovky** (Fight setup se otevře/zavře, přepnutí záložky): ztmavení, výřez i bublina zmizí za 0,15 s
      (`CoachMetrics.hideDuration`), Skip zůstává a vrstva pod ním dál pohlcuje klepnutí. Po schování se neviditelně
      přepne text (bublina se přeměří) a čeká se na cíl: na své obrazovce, panel dojel (transition coordinator,
      `sheetOnScreen`) a dvě měření po sobě (50 ms) na stejném místě; po přepnutí záložky nejdřív za 0,3 s
      (`tabSwitchDuration`, příjezd obsahu). Rámeček změřený během animace se nikdy nepoužije. Pak se rozvržení
      nastaví bez animace a overlay se objeví za 0,2 s se zvětšením bubliny a záře z 0,96 (`revealDuration/Scale`).
      Cíl, který do 1 s od Next není, = bublina uprostřed, Next funguje; když se cíl objeví později, výřez k němu dojede.
      Během schování Next nejde (bublina není vidět).
    - Bublina nad prvkem drží spodní hranu, pod prvkem horní (při změně výšky nikdy nezajede do výřezu).
      Overlay dál měří rámečky průběžně (50 ms první 1,5 s, pak 150 ms), dokud krok trvá, a výřez se po dojetí
      rolování nebo záložky přesune, až prvek stojí. Reduce Motion: A = stará a nová bublina i výřez se prolnou,
      B = jen prolnutí bez zvětšení; záře nepulzuje. VoiceOver čte bublinu (modální, fokus na ni).
  - **Postup jen přes Next** (od K1): každý krok má Next, poslední Finish. Zvýrazněné prvky nejsou interaktivní.
    **Krok stojí na své záložce** (`CoachStep.screen`): kroky 1–6 Home (2–4 ve Fight setupu nad ní), Path na Path,
    Shop na Shop, Stats na Stats, Your hero, Daily focus target a Nastavení na Hero. Lišta je během tutoriálu úplně zamčená (`userSwitchTab`).
    Výřez sedí jen na správné záložce (`CoachMarkStore.screen`; ikony lišty jsou vidět všude).
    Obrazovka s rolováním (`ScreenScaffold`) odroluje prvek kroku do zorného pole (`scrollTo(target, anchor: nil)`,
    `.coachMark` dává prvku `id`), po konci tutoriálu se vrátí nahoru.
  - Tutoriál začne až po zavření onboardingu (`onDismiss`), ztmavení se prolne.
  - Krok se ukládá (`focusquest.tutorial.step`), po pádu pokračuje přesně od posledního.
  - Na Home během tutoriálu nezačne oslava série ani nabídka sdílení milníku.

  | # | Kde (spotlight) | Text |
  |---|---|---|
  | 1 | Home: Fight | boss = jedna session, Fight otevře nastavení; Next otevře Fight setup |
  | 2 | Fight setup: sekce Focusing (nadpis + chipy) | vyber, na co je session (Stats počítá čas) |
  | 3 | Fight setup: sekce Sound | hudba nebo ticho, hraje i se zamčenou obrazovkou |
  | 4 | Fight setup: Start Battle + animace telefonu | po Start telefon dolů, zvednutí = útěk za 10 s, pauza zdarma; Next panel zavře |
  | 5 | Home: odkaz „Not feeling it? Just 5 minutes“ (jen text, ne celý řádek) | |
  | 6 | Home: plamínek série | |
  | 7–9 | lišta: Path a Stats; Shop (od P1/I6) cedule stánku (`CoachTarget.shopStall`); každý na své záložce | záložku přepne tutoriál |
  | 10 | Stats: graf Habits (čtverečky = dny od prvního dne, řádky Po–Ne, dnešek s rámečkem, barva = minuty) | |
  | 11 | Stats: Win rate, Bosses beaten, Longest streak, Focus hours | |
  | 12 | Hero: karta hrdiny nahoře („Your hero“) | vzhled (štětec = úprava), level a XP |
  | 13 | Hero: karta Daily focus target (kroužek a posuvník) | kroužek se během dne plní barvou třídy, posuvník = denní cíl |
  | 14 | Hero: ozubené kolo Nastavení | Finish |

  Od M1/F2 má Hero dva kroky (dřív jeden společný „Your hero“ na kartě Daily focus target), celkem 14. Uložený krok
  od 12 výš se u rozběhnutého tutoriálu posune o jeden (neškodné). Výchozí jméno „Hero“ bez vyplněného jména je správně.
  Všude Next, poslední Finish. Testy: `CoachMarkTests` projde všech 14 kroků jen přes Next a ověří bublinu u prvku i uprostřed
  (iPhone 17 i SE, včetně prvků ve Fight setupu), každý krok ukáže ve skutečném okně (snímek `drawHierarchy`) se žlutým
  tlačítkem Next/Finish a `testGlobalFramesMapToTheWindowAndPanelTargetsWaitForThePanel` ověří převod `.global` do okna
  (i pro list počítající od své hrany), čekání na dojetý list a zmizení po jeho zavření.

  - Settings › Help › „Replay tutorial“; Debug „Reset onboarding“ (1A i 1B).
  - CI screenshoty (`-initialTab`) onboarding ani tutoriál neukazují.
- **Oprávnění k notifikacím se žádá kontextově** (od F1): až po první dokončené (vyhrané) bitvě, nikdy v onboardingu ani tutoriálu. Plánování notifikací
  se už neptá (bez povolení nic nenaplánuje); ptá se jen kontextová žádost a Debug „Test notifications“.
- **Návrat v Settings tahem od levého okraje**: podstránka Sounds & notifications nemá NavigationStack, proto vlastní gesto
  (začátek do 32 pt od okraje, stránka jde s prstem, zpět po ~100 pt nebo švihu). Tlačítko ‹ Settings zůstává.
- **Home je pevné rozvržení bez scrollu** (od L1/E4, `ScreenScaffold(fixed: true)` + `ArenaLayout` v `ArenaView.swift`).
  Dřív byla Arena ve `ScrollView`: dala se posunout a zůstala posunutá a s pásem tutoriálu byl odkaz „Not feeling it?“
  pod tab barem (spotlight kroku 5 pak zvýraznil lištu).
  - Výška obrazovky nad lištou a změřené bloky (hlavička se sérií, texty u bosse, tlačítka) určí rámeček bosse:
    nejvýš 26 % výšky, 84–220 bodů, sprite = 128/168 rámečku; s větším písmem nebo kartou Focus režimu se zmenší boss, ne tlačítka.
  - Volné místo nad a pod bossem v poměru 1 : 2; pod 640 bodů (SE) menší mezery.
  - Spodek „Not feeling it?“ je 24 bodů nad lištou (SE 12): bezpečná zóna Home končí 8 bodů pod horní hranou lišty
    (`ArenaLayout.tabBarOverlap`). Test `testHomeFitsAboveTheTabBarWithoutScrolling` (SE, 17, Pro Max, s tutoriálem i bez).
  - Ostatní taby rolují dál (Stats, Shop, Hero jsou dlouhé seznamy) se standardním odpružením: obsah, který se vejde,
    se vždy vrátí. Po konci tutoriálu se obrazovky vrátí nahoru.
- Dynamic Type:
  - texty s pevnou velikostí používají `fqFont(size:weight:design:)` a rostou nejvýš 1,5×,
  - aplikace má strop `accessibility2`,
  - ikony, časovače a pixelové bubliny mají velikost pevnou.
- Aplikace je jen pro iPhone (`TARGETED_DEVICE_FAMILY = 1`).
- Dočasná ikona je Warm-up Wisp na tmavém pozadí (`FocusQuest/Resources/Assets.xcassets`).

### Sdílení statistik (od I1)
- **Stats › Share** (ikona vedle ozubeného kola, `ScreenHeader(onShare:)`) otevře náhled `StatsShareSheet`: přepínač šablon
  **This week** (minuty za 7 dní, poražení bossové, série) a **Streak** (série, další milník nebo nejdelší série),
  přepínač „Show my name“ (výchozí vypnutý) a `ShareLink` s obrázkem.
- Obrázek `StatsShareCard` přes `ImageRenderer` (skala 3) ve dvou formátech (od K1, přepínač Story / Wide v náhledu):
  **Story 360 × 640 bodů = 1080 × 1920** (Instagram, TikTok) a **Wide 640 × 360 = 1920 × 1080** (hrdina | čísla | Habits vedle sebe).
  Obsah: hrdina, série, minuty za týden, poražení bossové, mini Habits a „FocusQuest“. ImageRenderer neumí materiály,
  proto je sklo z průhledných výplní. **Žádná osobní data** kromě volitelného jména (ne jména bossů, předmětů ani data).
  - **Bezpečný okraj 7,5 % šířky ze všech stran** (`ShareFormat.margin`: 27 pt na výšku, 48 pt na šířku). Obsah je v pevném rámu,
    záře a hvězdy jsou jen `background`. Dřív 420pt kruh v ZStacku roztáhl kartu na šířku a dlaždice se ořízly, obsah
    přetékal na výšku a nadpis se lepil na okraj. Test `ShareCardRenderTests` kartu vyrenderuje (i dlouhé jméno a velká čísla)
    a ověří, že v okraji není žádný pixel obsahu; PNG jsou přílohy výsledku testu.
  - **Mini Habits = vždy celá mřížka 5 týdnů (7 × 5)**, stejná logika jako ve Stats (`HabitGrid.recentWeeks`): poslední týdny
    po týden s dneškem; u nového hráče se doplní budoucí týdny (čárkované), dny před prvním dnem jsou prázdné.
  - **Jméno = `profile.username`** (bez výchozího „NewFocuser“). „Hero“ je tam jen tehdy, když hráč v onboardingu jméno nevyplnil.
- **Milníky série 7, 30 a 100 dní:** po denní oslavě série na Home se jednou nabídne sdílení se šablonou Streak.
  Nabídnuté milníky jsou v UserDefaults `fq.offeredStreakMilestones`.

### Série a Streak freeze (od J1)
- **Série se počítá z historie dnů** (`PlayerStats.currentStreak(frozenDayKeys:)`), ne z uloženého počítadla `streakDays`
  (to zůstává jen kvůli starším datům a iCloudu).
  - Počet po sobě jdoucích dnů s bitvou, končí dneškem nebo včerejškem.
  - Zamrzlé dny řadu nepřeruší, ale do počtu se nepočítají.
- **Streak freeze** v Shopu › Supplies za **150 mincí**, v zásobě nejvýš **2** (`StreakFreeze`).
  - Při spuštění a návratu do appky (`applyStreakFreezes`) se vynechané dny od poslední bitvy zmrazí, když na ně zásoba stačí.
  - Když nestačí, nespotřebuje se nic a série spadne.
  - Dnešek se nezmrazí nikdy.
  - Zamrzlé dny jsou v `UserProfile.frozenDays`.
  - Na Home je u série vločka, když freeze v posledních 7 dnech zachránil den. Debug: „+1 streak freeze“.
- **Streak in danger** (notifikace `focusquest.streak.0/1`):
  - ve 20:00, když série platí a ten den ještě nebyla bitva,
  - plánuje se na dnes a zítra, po každé bitvě a návratu do appky se přepočítá,
  - přepínač v Notifications (výchozí zapnutý), ztlumí ho i Focus Filter.

### Týdenní úkoly (od J1)
- Každé pondělí 3 úkoly (`WeeklyQuests.make`), generované lokálně.
  - **Obtížnost** z průměru posledních 4 týdnů před pondělím, počítají se jen týdny od první bitvy; během týdne se nemění:
    - minuty: průměr × 1,15 zaokrouhleno na 15, 60–600,
    - dny: průměr + 1, 3–7,
    - bossové: průměr + 1, 2–12,
    - třetí úkol se střídá podle týdne: bossové / různé focus oblasti / jedna dlouhá bitva 20 nebo 30 min.
  - **Odměna:** truhla 40–100 mincí podle obtížnosti, vyzvedne se ve Stats tlačítkem Open.
  - **Oslava:** truhla poskočí, vyletí „+N“, zvuk mince, haptika.
  - Vyzvednuté truhly jsou v `UserProfile.claimedQuests` (posledních 15).
  - Karta je ve Stats pod čísly, aby kroky tutoriálu (Habits, čísla) zůstaly nahoře.

### Poznámky po výhře a Battle log (od J1)
- Na Victory obrazovce volitelné pole „What did you get done?“ (jeden řádek, max 120 znaků).
  - Uloží se s Collect Loot nebo Keep going k právě vyhrané bitvě (`SessionSummary.note`).
  - Prázdné se přeskočí.
- Stats › **Battle log**: datum, boss, focus oblast, délka a poznámka.
  - Filtr podle focus oblasti (jen oblasti z historie).
  - 10 posledních, „Show more“ přidává po 20.

### Widget, Focus Filter, Siri a Zkratky (od J1)
- **Widget na plochu** (malý a střední, `FocusStatusWidget` ve Widget Extension, obsah `FocusWidgetContent` v Shared):
  - ukazuje sérii, dalšího bosse (sprite, jméno, délka) a dnešní minuty vs. Daily focus target,
  - tónované widgety (`widgetAccentable`, iOS 26) i tmavá plocha,
  - klepnutí: `focusquest://fight` (URL schéma v Info.plist) → Home a Fight sheet s dalším bossem.
  - **Data přes App Group** (`WidgetSnapshot`, appka ho zapíše po změně statistik a při návratu do appky):
    - s bezplatným účtem App Group není (Sideloadly ji zahodí),
    - appka to za běhu pozná (`containerURL` je nil) a widget pak ukazuje „Open FocusQuest“.
  - **Náhrada pro testování:** Debug › „Debug widget“ vykreslí stejné views se skutečnými daty.
  - Aktivace App Group: `design/DEVELOPER_ACCOUNT_TODO.md`.
- **Focus Filter** (`FocusQuestFocusFilter`, iOS Nastavení › Focus › Add Filter › FocusQuest):
  - volby „Suggest a battle“ (Home ukáže kartu „Your Focus is on“ s bitvou) a „Mute reminders“ (ruší Daily reminder a Streak in danger),
  - obě výchozí vypnuté: iOS při vypnutí režimu volá filtr s výchozími hodnotami, takže se stav sám vrátí.
  - Po vypnutí režimu se připomínky naplánují znovu, až appka poběží.
  - Návod: Nastavení › Help › „Use with iPhone Focus“.
- **App Intents a App Shortcuts** (`FocusQuestIntents.swift`, bez entitlementu):
  - **Start battle** otevře appku na Fight sheetu: další boss, nebo volitelně délka 5–240 min jako vlastní bitva (`prepareCustomBattle`),
  - **Show streak** odpoví bez otevření (z `WidgetSnapshot`),
  - **Pause battle** použije pauzu v běžící bitvě.
  - Fráze pro Siri a Spotlight; v Nastavení › Help › „Siri & Shortcuts“ i postup pro Action button.
  - Příkazy jdou přes `AppCommandCenter`. Během bitvy, onboardingu a tutoriálu se nic neotevře.

### Úložiště a iCloud (od J1, iCloud vypnutý)
- **Jedna vrstva `AppStateStore`:**
  - celý stav `AppState` = profil + statistiky + nastavení + verze formátu + čas poslední změny (`fq.stateMeta`),
  - `LocalProfileSyncService` a `PreferencesStore` zapisují přes ni a při každém uložení obnoví časovou značku,
  - klíče a velikosti jsou v DEVELOPER_ACCOUNT_TODO.md, aktuální velikost v Debug › Saved data.
- **`CloudSync`** (iCloud Key-Value Store, jeden klíč `fq.state`) za `FeatureFlags.iCloudSync = false`.
  - Pravidla konfliktu viz `CloudSync.merge`: novější vyhrává, odemčené věci a postup se nikdy neztratí, série z historie.
  - Sekce „iCloud sync“ v Nastavení je skrytá, dokud není flag zapnutý.

### Ceny v Shopu (od J1)
Shop má od K1 tři záložky: **Gear** (jen vybavení hrdiny), **Backgrounds** a **Supplies** (Extra pause, Streak freeze).

| Předmět | Cena | Zásoba |
|---|---|---|
| Extra pause | 40 mincí | max 5, v bitvě 1 navíc |
| Streak freeze | 150 mincí | max 2 |
| Truhla týdenního úkolu | odměna 40–100 mincí | 3 za týden |

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
  - přepínače v Settings ukazují skutečný stav a při odmítnutí nabídnou Nastavení iPhonu.
- Onboarding (od F2) povolení neřeší: senzor polohy oprávnění nepotřebuje, notifikace se žádají po první bitvě.
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
  Čeká na něj i **App Group pro widget** a **iCloud sync**: přesný postup je v `design/DEVELOPER_ACCOUNT_TODO.md`.
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
- **`GeometryReader` s `.ignoresSafeArea()` hlásí `safeAreaInsets` = 0.** Kdo potřebuje velikost bezpečné zóny
  a zároveň kreslit přes celou obrazovku, potřebuje dva readery: vnější (respektuje safe area) dá `safeAreaInsets`,
  vnitřní s `.ignoresSafeArea()` dá celou plochu (viz `CoachMarkOverlay`). Kvůli tomu byl Skip tutoriálu přes hodiny.
- **`ImageRenderer` nevykreslil bublinu tutoriálu vůbec** (buildy #77 a #78: ztmavení, výřez a Skip ano, bublina ani
  s plnou výplní místo skla ne). Test overlaye proto běží ve skutečném `UIWindow` testovací appky a snímá ho
  `drawHierarchy` (`testEveryStepShowsABubbleInARealWindow`). Sdílecí karty ImageRenderer používají dál (bez materiálů).
- **Prostředí a listy:** `.environment(x)` platí jen pro obsah pod ním. Modifikátor `.sheet`, který stojí nad ním
  (v řetězci za ním), ho listu nepředá; list ho musí dostat přímo (`.sheet { Obsah().environment(x) }`). Volitelné
  `@Environment(Typ.self) var x: Typ?` pak tiše dá nil (tak se v L1 nejspíš ztratily cíle tutoriálu ve Fight sheetu).
- **Cíle tutoriálu v listu** (od M1): rámečky v `.global` + posun z kořenové sondy (`.coachRoot(sheet: true)`).
  UIKit i SwiftUI hlásí cílovou polohu listu hned na začátku prezentace, proto se na dojetí listu čeká zvlášť
  (transition coordinator). Nový cíl v listu = `.coachMark` uvnitř kořene listu, jinak ho overlay nenajde.
- **Přechod tutoriálu se nesmí rozhodovat až v `.task(id: step)`** (N1/G1): task běží až po vykreslení nového kroku,
  takže text a poloha se rozjely (L1/E3). Typ A se nastavuje synchronně v obsluze Next, typ B se schová v ní.
  Nový rolovací ScrollView s cíli tutoriálu potřebuje `.coachViewport()` (uvnitř `.coachRoot`), jinak overlay
  jede na polohu před odrolováním a pak dojede druhou animací.
- **`containerShape` na iOS 17:**
  - iOS 26 přetížení se nesmí volat mimo `#available(iOS 26.0, *)`, proto `fqContainer` vrací na starších iOS jen `self`,
  - `AnyShape` neumí `strokeBorder`, použít `stroke` + `padding(lineWidth / 2)`.
