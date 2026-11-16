# FocusQuest: pravidla pro Clauda

## Postup přepisu designu

Při každé práci na sekcích z design/CHANGES.md aktualizuj design/progress.html: při začátku sekce, po commitu, po spuštění buildu, po jeho výsledku a po opravě chyby.

- Měň jen JSON blok `<script id="data" type="application/json">`, ne HTML ani skript kolem něj.
- Pokaždé přepiš `updated` (čas Europe/Prague), `current` a `nextStep`.
- Stavy sekcí: `cekam`, `pracuje`, `build`, `spadl`, `hotovo`. Hotovo je sekce až po zeleném buildu.
- U sekce vyplň `commit`, `build` (`number`, `runId`, `result`) a odškrtni hotové body (`done: true`).
- `note` piš česky: co se nepovedlo, co zbývá, co otestovat na iPhonu.
- design/progress.html commituj spolu se změnami kódu.
