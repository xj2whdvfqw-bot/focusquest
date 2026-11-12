# FocusQuest – vývoj iOS appky jen z Windows (zdarma)

## Jak to funguje

```
 Windows (VS Code + Claude)          GitHub Actions (Mac zdarma)            Windows → iPhone
 ─────────────────────────           ───────────────────────────            ────────────────
 úprava Swift kódu  ── git push ──►  xcodegen → .xcodeproj                  tools\stahni-ipa.ps1
                                     sestavení FocusQuest.ipa   ── stáhnout ──►  Sideloadly
                                     unit testy na simulátoru                 (podepíše tvým
                                     screenshot ze simulátoru                  Apple ID zdarma)
                                                                               ▼
                                                                             iPhone 17
```

- **Žádný Mac ani Xcode lokálně** – projekt (`.xcodeproj`) se generuje až na Macu v cloudu z [project.yml](project.yml).
- **Nic se nepředplácí:** GitHub Free + Actions, bezplatné Apple ID, Sideloadly zdarma.
  - **Veřejný** repozitář: macOS buildy zdarma a bez limitu.
  - **Soukromý** repozitář: jen měsíční kvóta zdarma (u macOS strojů vystačí zhruba na desítky buildů).
    Pokud na GitHubu nemáš zadanou platební kartu, po vyčerpání se buildy jen zastaví – nic se nestrhne.

## Jednorázové nastavení

### 1. GitHub repozitář
`gh` máš nainstalované a přihlášené. Claude ti repozitář vytvoří a nahraje kód (stačí říct, jestli má být veřejný, nebo soukromý).

### 2. Windows – instalace Sideloadly
1. Nainstaluj **iTunes z webu Apple** (apple.com/itunes – verzi pro Windows z webu, **ne** z Microsoft Store). Sideloadly přes něj komunikuje s iPhonem.
2. Stáhni a nainstaluj **Sideloadly** ze <https://sideloadly.io> (zdarma).
3. Připoj iPhone USB-C kabelem, odemkni ho a potvrď „Důvěřovat tomuto počítači“.

### 3. iPhone – Režim vývojáře
1. Po první instalaci appky přes Sideloadly: **Nastavení → Soukromí a zabezpečení → Režim vývojáře → zapnout** (iPhone se restartuje).
2. **Nastavení → Obecné → Správa VPN a zařízení →** tvoje Apple ID **→ Důvěřovat**.

> Doporučení: na podepisování používej klidně vedlejší (nové) Apple ID, ne nutně své hlavní.

## Každodenní smyčka

1. Řekni Claudovi, co změnit (nebo uprav kód sám).
2. `git push` → na GitHubu se spustí build (cca 5–15 min). Stav: `gh run watch`
3. Stažení hotové appky:
   ```powershell
   .\tools\stahni-ipa.ps1          # stáhne poslední IPA do dist\
   .\tools\stahni-ipa.ps1 -Cekat   # nejdřív počká, až build doběhne
   ```
4. V Sideloadly: přetáhni `dist\FocusQuest.ipa`, zadej Apple ID, klikni **Start**.
5. Zkoušej na iPhonu.

Rychlá kontrola bez telefonu: v každém buildu je artefakt **screenshoty** (screenshot appky ze simulátoru iPhonu)
a výsledky unit testů. Když build nebo test spadne, Claude si přes `gh run view --log-failed` přečte chybu a opraví ji.

## Omezení bezplatného Apple ID (důležité)

| Omezení | Co to znamená |
|---|---|
| Appka platí **7 dní** | Pak ji v Sideloadly nainstaluj znovu (stejné Apple ID → data v appce zůstanou). |
| Max. **3 vlastní appky** naráz | Pro jeden projekt nevadí. |
| Max. **10 App ID za 7 dní** | Neměň zbytečně Bundle ID. |
| Některé funkce nejdou | **App Attest, push notifikace, iCloud, App Groups** vyžadují placený Apple Developer účet (99 USD/rok). Appka teď běží se simulovaným backendem (`FOCUSQUEST_SIMULATED_BACKEND = YES`), takže to zatím nevadí. |
| Bundle ID obsazené | Když Sideloadly hlásí chybu s App ID, změň v *Advanced options* Bundle ID např. na `com.tvojejmeno.focusquest`. |

Placený účet budeš potřebovat až pro **TestFlight / App Store** – to je až na konec vývoje.

## Co z Windows nejde (a čím to nahrazujeme)

| Na Macu | Tady |
|---|---|
| Xcode, SwiftUI Preview | Screenshot ze simulátoru v CI + instalace do iPhonu |
| Lokální spuštění testů | Unit testy běží v CI na simulátoru iPhonu |
| Debugger | Logy (`print`/`Logger`) – zobrazíš je v Sideloadly / přes *Console* nebo do appky přidáme debug obrazovku |

## Soubory, které tohle zajišťují

- [project.yml](project.yml) – definice Xcode projektu (XcodeGen)
- [FocusQuest/Config/Development.xcconfig](FocusQuest/Config/Development.xcconfig) – build nastavení
- [Support/FocusQuest-Info.plist](Support/FocusQuest-Info.plist) – Info.plist s vlastními klíči appky
- [.github/workflows/ios.yml](.github/workflows/ios.yml) – automatický build a testy
- [scripts/](scripts/) – skripty běžící na Macu v CI
- [tools/stahni-ipa.ps1](tools/stahni-ipa.ps1) – stažení IPA na Windows

## Známé TODO

- **Live Activity / Dynamic Island** ([FocusBattleLiveActivity.swift](FocusQuest/Widgets/FocusBattleLiveActivity.swift)) potřebuje samostatný *Widget Extension* target – zatím je jen v hlavní appce, takže se nezobrazí. Přidáme, až bude jádro appky běžet.
- Ikona appky (Assets.xcassets / AppIcon) zatím chybí.
