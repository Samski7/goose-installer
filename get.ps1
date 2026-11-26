# Installeren met een commando (PowerShell):  irm https://raw.githubusercontent.com/Samski7/goose-installer/main/get.ps1 | iex
# Downloadt de nieuwste versie van GitHub en start de installatie. ASCII only.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tmp = Join-Path $env:TEMP ("goose-installer-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $tmp | Out-Null
try {
    Invoke-WebRequest 'https://github.com/Samski7/goose-installer/archive/refs/heads/main.zip' -OutFile "$tmp\main.zip" -UseBasicParsing
    Expand-Archive "$tmp\main.zip" -DestinationPath "$tmp\x" -Force
    $inst = Get-ChildItem "$tmp\x" -Recurse -Filter install.ps1 | Select-Object -First 1
    & powershell -NoProfile -ExecutionPolicy Bypass -File $inst.FullName
} finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
