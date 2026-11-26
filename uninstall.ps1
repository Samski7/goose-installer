# Goose-installer verwijderen. ASCII only. Goose Desktop, Node.js en Python zelf blijven staan.
param(
    [string]$InstallRoot = "$env:LOCALAPPDATA\GooseInstaller",
    [string]$ConfigRoot = "$env:APPDATA\Block\goose",
    [switch]$Force,
    [switch]$KeepKey
)
$ErrorActionPreference = 'Stop'
if (-not $Force) {
    $a = Read-Host "Goose-installer verwijderen (extensies, instellingen van het pakket, API-sleutel)? Typ JA"
    if ($a -ne 'JA') { Write-Host "Geannuleerd."; exit 0 }
}
$cfgDir = Join-Path $ConfigRoot 'config'
foreach ($name in 'config.yaml', '.goosehints') {
    $f = Join-Path $cfgDir $name
    # oldest backup = the customer's own settings from before the first install
    $bak = Get-ChildItem $cfgDir -Force -Filter "$name.voor-pakket-*" -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -First 1
    if ($bak) { Copy-Item $bak.FullName $f -Force; Remove-Item $bak.FullName -Force; Write-Host "$name teruggezet naar je eigen instellingen van voor de installatie." }
    elseif (Test-Path $f) { Remove-Item $f -Force; Write-Host "$name verwijderd (er was voordien geen)." }
}
if (-not $KeepKey) {
    # only remove the key this installer put there (compared by hash), never someone's own key
    $vf = Join-Path $InstallRoot 'versie.json'
    $h = if (Test-Path $vf) { (Get-Content $vf -Raw | ConvertFrom-Json).sleutelHash } else { '' }
    $cur = [Environment]::GetEnvironmentVariable('ANTHROPIC_API_KEY', 'User')
    $curHash = if ($cur) { -join ([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($cur)) | ForEach-Object { $_.ToString('x2') }) } else { '' }
    if ($h -and $curHash -eq $h) { [Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', $null, 'User'); Write-Host "API-sleutel verwijderd van deze pc." }
    elseif ($cur) { Write-Host "De API-sleutel op deze pc is niet door dit pakket gezet; die blijft staan." }
}
if (Test-Path $InstallRoot) {
    # this script may run from inside $InstallRoot\pakket: remove the rest, then schedule nothing else
    Get-ChildItem $InstallRoot -Force | Where-Object { $_.Name -ne 'pakket' } | Remove-Item -Recurse -Force
    Write-Host "Extensies verwijderd. De map $InstallRoot\pakket mag je daarna zelf wissen."
}
Write-Host "Klaar. Goose Desktop zelf verwijder je via Instellingen > Apps als je dat wil."
