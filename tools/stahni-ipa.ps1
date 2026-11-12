# Stahne nejnovejsi FocusQuest.ipa z GitHub Actions do slozky dist\
# Pouziti (v PowerShellu ve slozce projektu):  .\tools\stahni-ipa.ps1
# Volitelne: .\tools\stahni-ipa.ps1 -Cekat   -> nejdriv pocka, az dobehne rozjety build
param([switch]$Cekat)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

if ($Cekat) {
    $latest = gh run list --workflow ios.yml --limit 1 --json databaseId,status | ConvertFrom-Json | Select-Object -First 1
    if ($latest -and $latest.status -ne 'completed') {
        Write-Host "Cekam na build $($latest.databaseId) ..."
        gh run watch $latest.databaseId | Out-Null
    }
}

$runs = gh run list --workflow ios.yml --limit 15 --json databaseId,status,conclusion,headSha,createdAt | ConvertFrom-Json
$done = $runs | Where-Object { $_.status -eq 'completed' }
if (-not $done) { throw 'Zadny dokonceny build. Zkontroluj: gh run list' }

foreach ($run in $done) {
    if (Test-Path dist) { Remove-Item -Recurse -Force dist }
    gh run download $run.databaseId -n FocusQuest-ipa -D dist 2>$null
    if (Test-Path dist\FocusQuest.ipa) {
        $sha = $run.headSha.Substring(0, 7)
        Write-Host ""
        Write-Host "OK: dist\FocusQuest.ipa  (commit $sha, $($run.createdAt), vysledek: $($run.conclusion))"
        if ($run.conclusion -ne 'success') {
            Write-Host "Pozor: IPA se sestavila, ale testy neprosly. Detaily: gh run view $($run.databaseId) --log-failed"
        }
        Write-Host "Ted ji otevri v Sideloadly a nainstaluj do iPhonu."
        explorer.exe (Resolve-Path dist).Path
        exit 0
    }
}
throw 'V zadnem z poslednich buildu neni IPA (build pravdepodobne spadl pri kompilaci). Viz: gh run list'
