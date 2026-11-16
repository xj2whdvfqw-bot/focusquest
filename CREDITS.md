# Použitý obsah třetích stran

## Hudba

Lo-fi skladby ve složce [FocusQuest/Resources/Audio](FocusQuest/Resources/Audio) složil **HoliznaCC0**
a vydal je pod licencí **CC0 1.0 Universal** (volné dílo – lze je používat, upravovat i šířit bez omezení
a bez povinnosti uvádět autora). Autora přesto uvádíme tady i v Nastavení appky.

| Soubor | Skladba | Album | Zdroj |
|---|---|---|---|
| `calm-currents.mp3` | Calm Currents ( Lofi , Relax , Calm ) | Public Domain Lofi | <https://freemusicarchive.org/music/holiznacc0/public-domain-lofi/> |
| `tokyo-sunset.mp3` | Tokyo Sunset ( Lofi , Peaceful , Soft ) | Public Domain Lofi | <https://freemusicarchive.org/music/holiznacc0/public-domain-lofi/> |
| `peaceful-drift.mp3` | Peaceful Drift ( Lofi , Nostalgic , Calm ) | Public Domain Lofi | <https://freemusicarchive.org/music/holiznacc0/public-domain-lofi/> |

- Licence: <https://creativecommons.org/publicdomain/zero/1.0/>
- Staženo z Free Music Archive 12. 11. 2026; licence CC0 byla ověřena na stránce každé skladby.
- Soubory jsou beze změny (MP3, 320 kb/s).

### Jak přidat další skladbu

1. Zkopíruj `.mp3` do `FocusQuest/Resources/Audio/` (ověř si licenci a doplň řádek do tabulky výše).
2. Přidej `case` do `AmbientTrack` v [AppPreferences.swift](FocusQuest/Models/Domain/AppPreferences.swift)
   (název, `title` a `resourceName` = název souboru bez přípony).
3. Doplň název souboru do kontroly v [scripts/ci-build-ipa.sh](scripts/ci-build-ipa.sh).

## Písmo

`FocusQuest/Resources/Fonts/PixelifySans-Medium.ttf` je **Pixelify Sans** (řez Medium 500), © 2021 The Pixelify Sans Project Authors,
licence **SIL Open Font License 1.1** (smí se vkládat do aplikací a šířit s nimi, nesmí se prodávat samostatně).

- Zdroj: Google Fonts, <https://fonts.google.com/specimen/Pixelify+Sans> (projekt: <https://github.com/eifetx/Pixelify-Sans>)
- Licence: <https://openfontlicense.org/open-font-license-official-text/>
- Soubor je beze změny. Používá se jen pro nadpisy obrazovek.
