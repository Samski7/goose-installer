# Goose-installer bijwerken naar de nieuwste versie op GitHub. ASCII only.
param([string]$InstallRoot = "$env:LOCALAPPDATA\GooseInstaller")
$ErrorActionPreference = 'Stop'
$pkFile = Join-Path $InstallRoot 'pakket\pakket.json'
if (-not (Test-Path $pkFile)) { Write-Host "Goose-installer is niet geinstalleerd. Gebruik eerst Installeer.cmd."; exit 1 }
$pk = Get-Content $pkFile -Raw -Encoding UTF8 | ConvertFrom-Json
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tmp = Join-Path $env:TEMP ("goose-installer-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $tmp | Out-Null
try {
    $zip = Join-Path $tmp 'main.zip'
    Invoke-WebRequest "https://github.com/$($pk.repo)/archive/refs/heads/main.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive $zip -DestinationPath "$tmp\x" -Force
    $new = Get-ChildItem "$tmp\x" -Recurse -Filter pakket.json | Select-Object -First 1
    if (-not $new) { throw "Ongeldige download." }
    $nv = (Get-Content $new.FullName -Raw -Encoding UTF8 | ConvertFrom-Json).versie
    if ([version]$nv -le [version]$pk.versie) { Write-Host "Je hebt al de nieuwste versie ($($pk.versie))."; return }
    Write-Host "Nieuwe versie $nv gevonden (je hebt $($pk.versie)). Bijwerken..."
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $new.DirectoryName 'install.ps1') -Update -InstallRoot $InstallRoot
} finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
