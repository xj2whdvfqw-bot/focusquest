# Co zapnout s placeným Apple Developer účtem

Appka se teď instaluje přes Sideloadly s bezplatným Apple ID. To neumí iCloud a App Group
(Sideloadly ji při podepisování zahodí). Kód pro obojí je hotový, ale vypnutý. Build projde i bez těchto capabilities.

Tenhle soubor popisuje přesné kroky, jak obojí zapnout, až bude placený účet (99 USD/rok).

## 0. Společné kroky

1. V [developer.apple.com](https://developer.apple.com) › Certificates, Identifiers & Profiles:
   - App ID `com.focusquest.app` (appka),
   - App ID `com.focusquest.app.widgets` (Widget Extension).
2. V `project.yml` doplnit tým do obou targetů (`FocusQuest`, `FocusQuestWidgets`):
   ```yaml
   settings:
     base:
       DEVELOPMENT_TEAM: XXXXXXXXXX   # Team ID z developer.apple.com › Membership
   ```
3. Podepisování v CI: App Store Connect API klíč do GitHub Secrets (viz DECISIONS.md › Otevřené body).

## 1. App Group: widget se skutečnými daty (C1)

**Teď:**
- Widget (malý a střední) funguje a klepnutím otevře výběr bitvy (`focusquest://fight`).
- Bez App Group ale nevidí data appky a ukazuje „Open FocusQuest“.
- Skutečná data jsou zatím vidět v Debug › „Debug widget“.

**Postup:**
1. Na developer.apple.com vytvořit App Group `group.com.focusquest.app`.
   Oběma App ID zapnout capability App Groups a přiřadit tuto skupinu.
2. Vytvořit dva soubory s entitlements:
   - `Support/FocusQuest.entitlements`
   - `Support/FocusQuestWidgets.entitlements`

   Oba se stejným obsahem:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>com.apple.security.application-groups</key>
       <array>
           <string>group.com.focusquest.app</string>
       </array>
   </dict>
   </plist>
   ```
3. V `project.yml` přidat do `settings.base` obou targetů:
   - `CODE_SIGN_ENTITLEMENTS: Support/FocusQuest.entitlements` (appka),
   - `CODE_SIGN_ENTITLEMENTS: Support/FocusQuestWidgets.entitlements` (widget).
4. Příznak `FeatureFlags.appGroupWidgetSync` v `Shared/WidgetSnapshot.swift` je už `true`, nic se nepřepíná.
   Appka si za běhu sama ověří, že App Group existuje (`containerURL(forSecurityApplicationGroupIdentifier:)`).
   Bez entitlementu snímek ukládá jen do sebe.
5. **Otestovat:**
   - Debug › Debug widget › řádek App Group ukazuje „Shared with widget“.
   - Widget na ploše ukazuje sérii, dalšího bosse a dnešní minuty.
   - Po bitvě se widget do pár sekund obnoví.
   - O půlnoci se dnešní minuty vynulují.
   - Tónovaná plocha (iOS 26) a tmavá plocha.
   - Klepnutí otevře Fight sheet s dalším bossem.

## 2. iCloud synchronizace (C7)

**Teď:**
- Všechno je v `UserDefaults` appky, viz `FocusQuest/Utilities/AppStateStore.swift`.
- Klíče a velikosti:

  | Klíč | Obsah | Velikost |
  |---|---|---|
  | `focusquest.local-profile` | profil | ~1–2 kB |
  | `focusquest.local-stats` | statistiky a historie bitev | ~0,5 kB + ~250 B na bitvu (100 bitev ≈ 25 kB) |
  | `focusquest.sensory-preferences` | nastavení a postup ve světech | ~2 kB |
  | `fq.stateMeta` | verze formátu a čas poslední změny | |

- Aktuální velikost ukazuje Debug › „Saved data“.
- Celý stav (`AppState`) se do iCloud Key-Value Store ukládá jako jeden klíč `fq.state`.
  KVS má limit 1 MB, takže se vejdou tisíce bitev.

**Postup:**
1. Jen App ID appky `com.focusquest.app` (widget iCloud nepotřebuje): zapnout capability iCloud › Key-value storage.
2. Do `Support/FocusQuest.entitlements` přidat:
   ```xml
   <key>com.apple.developer.ubiquity-kvstore-identifier</key>
   <string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
   ```
   Pokud entitlements ještě nejsou, nastavit je v `project.yml` stejně jako v kroku 1.3.
3. V `Shared/WidgetSnapshot.swift` přepnout `FeatureFlags.iCloudSync = true`.
4. V Nastavení se objeví sekce **iCloud sync** s přepínačem „Sync with iCloud“ (výchozí vypnutý) a řádkem „Last synced“.
5. **Chování:**
   - Při spuštění se stav z iCloudu sloučí s místním (`CloudSync.pullAndMerge`, ještě před načtením služeb).
   - Každé uložení nahraje celý stav (`AppStateStore.touch` › `CloudSync.scheduleUpload`).
   - Změny z jiného zařízení se projeví při dalším spuštění.
6. **Pravidla konfliktu** (`CloudSync.merge`, pokryté testem `WeeklyQuestsAndSyncTests`):
   - Novější stav (`modifiedAt`) vyhrává: mince, nastavení, hrdina, zásoby.
   - Odemčené věci se nikdy neztratí, berou se ze sjednocení:
     - vybavení, pozadí, easter eggy,
     - odhalené světy, zamrzlé dny, vyzvednuté truhly.
   - Postup ve světech: v každém světě vyšší hodnota.
   - Historie bitev: sjednocení podle id.
   - XP, výhry a bitvy: maximum.
   - Série se přepočítá z historie dnů a zamrzlých dnů.
7. **Otestovat:**
   - Dva iPhony (nebo iPhone a smazání a reinstalace appky) se stejným Apple ID.
   - Zapnout sync na obou.
   - Bitva na prvním, pak spuštění druhého: historie, XP, postup na mapě.
   - Nákup na obou offline a pak online: oba předměty zůstanou.
   - **Reset progress na jednom zařízení:**
     - nahraje do iCloudu čerstvý stav s novější značkou,
     - druhé zařízení pak převezme nové mince a nastavení, ale odemčené věci a historii si podle pravidel nechá.
     - **Rozhodnout před zapnutím:** má reset mazat i iCloud? Pak v `AppDIContainer.resetProgress` smazat klíč `fq.state` v KVS a vypnout přepínač.
   - Velikost v Debug › Saved data.
8. **Až by se historie blížila 1 MB:** v `AppState` posílat jen posledních N bitev
   a starší shrnout do denních součtů (Habits). Dnes to není potřeba.

## 3. Co funguje i bez placeného účtu (nic nepřepínat)

- Focus Filter (`FocusQuest/Intents/FocusFilter.swift`).
- App Intents a App Shortcuts: Siri, Spotlight, Zkratky, Action button (`FocusQuest/Intents/FocusQuestIntents.swift`).
- Widget a deep link `focusquest://fight` (jen bez dat, viz výše).
- Lokální notifikace včetně „Streak in danger“.
- Live Activity.

## 4. Další věci, které čekají na účet (z DECISIONS.md)

- TestFlight a App Store (podepisování v CI).
- Push notifikace nejsou potřeba (vše je lokální).
- Rate this app (až bude App Store ID).
