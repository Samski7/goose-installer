# Toont het verbruik van vandaag. ASCII only.
$kw = Join-Path $env:LOCALAPPDATA 'GooseInstaller\kostenwacht'
$f = Join-Path $kw 'verbruik.json'
$p = Get-Content (Join-Path $kw 'kostenwacht.json') -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
if (-not $p) { Write-Host "De kostenwacht is niet geinstalleerd."; exit 1 }
$d = if (Test-Path $f) { Get-Content $f -Raw | ConvertFrom-Json } else { $null }
if (-not $d -or $d.datum -ne (Get-Date -Format 'yyyy-MM-dd')) { Write-Host ("Vandaag nog niets verbruikt (limiet EUR {0:N2})." -f [double]$p.limietEurPerDag); exit 0 }
Write-Host ("Verbruik vandaag: EUR {0:N2} van EUR {1:N2} ({2} vragen)." -f ($d.usd / $p.usdPerEur), [double]$p.limietEurPerDag, $d.vragen)
