# Goose-installer (rechtstreeks met een Anthropic-sleutel, zonder proxy). ASCII only (Windows PowerShell 5.1 reads scripts without BOM as ANSI).
# Normal use: double-click Installeer.cmd.  Test use: see the parameters below.
param(
    [string]$ApiKey,
    [string]$InstallRoot = "$env:LOCALAPPDATA\GooseInstaller",
    [string]$ConfigRoot = "$env:APPDATA\Block\goose",
    [string]$PythonPath,
    [switch]$SkipSoftware,   # do not install Goose/Node/Python via winget (they must already exist)
    [switch]$NoEnvKey,       # do not store the API key (testing)
    [switch]$Update          # re-install files and extensions, keep the API key
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$pk = Get-Content (Join-Path $here 'pakket.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$utf8 = New-Object Text.UTF8Encoding $false

function Step($t) { Write-Host "`n== $t" -ForegroundColor Cyan }
function Fail($t) { Write-Host "`nFOUT: $t" -ForegroundColor Red; exit 1 }
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
function Winget-Install($id, $version) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Fail "winget ontbreekt. Installeer 'App Installer' uit de Microsoft Store en probeer opnieuw." }
    $a = @('install', '-e', '--id', $id, '--silent', '--accept-package-agreements', '--accept-source-agreements')
    if ($version) { $a += @('--version', $version) }
    & winget @a | Out-Host
    Refresh-Path
}
function Test-Python($p) {
    if (-not $p -or -not (Test-Path $p)) { return $false }
    if ($p -like '*\WindowsApps\*') { return $false }   # Store alias stub, not a real Python
    try { $r = & $p -c "import sys;print(sys.version_info >= (3, 12))" 2>$null; return ($r -eq 'True') } catch { return $false }
}
function Find-Python {
    $c = @($PythonPath)
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) { $c += $cmd.Source }
    if (Get-Command py -ErrorAction SilentlyContinue) { try { $c += (& py -3 -c "import sys;print(sys.executable)" 2>$null) } catch {} }
    $c += "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe", "C:\Program Files\Python313\python.exe"
    foreach ($p in $c) { if (Test-Python $p) { return $p } }
    return $null
}

Write-Host "$($pk.naam) $($pk.versie) - installatie" -ForegroundColor Green

Step "0/6 Toegangssleutel controleren"
function Test-Key($k) {
    # asks Anthropic which models this key may use; never prints the key
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $r = Invoke-RestMethod 'https://api.anthropic.com/v1/models?limit=100' -Headers @{ 'x-api-key' = $k; 'anthropic-version' = '2023-06-01' } -TimeoutSec 20
        return @($r.data | ForEach-Object { $_.id })
    } catch { return $null }
}
if ($Update) {
    if (-not (Test-Path (Join-Path $InstallRoot 'versie.json'))) { Fail "Goose-installer is nog niet geinstalleerd op deze pc. Gebruik Installeer.cmd." }
    Write-Host "Update: de bestaande API-sleutel blijft behouden."
} else {
    if (-not $ApiKey) {
        # hidden input: the key is never shown on screen
        $sec = Read-Host "Plak de Anthropic API-sleutel die je kreeg (invoer blijft onzichtbaar) en druk Enter" -AsSecureString
        $ApiKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    }
    $ApiKey = $ApiKey.Trim()
    if ($ApiKey -notlike 'sk-ant-*') { Fail "Dit lijkt geen geldige toegangssleutel. Er is niets gewijzigd; start de installatie opnieuw." }
    $levels = Test-Key $ApiKey
    if ($null -eq $levels) { Fail "De sleutel werd niet aanvaard door Anthropic, of er is geen internet. Er is niets gewijzigd." }
    if ($levels -notcontains $pk.model) { Fail "Deze sleutel heeft geen toegang tot $($pk.model). Er is niets gewijzigd." }
    Write-Host "Sleutel aanvaard (model $($pk.model) beschikbaar)."
    $old = [Environment]::GetEnvironmentVariable('ANTHROPIC_API_KEY', 'User')
    if ($old -and $old -ne $ApiKey -and -not $NoEnvKey) {
        $a = Read-Host "Er staat al een andere Anthropic-sleutel op deze pc. Vervangen? Typ JA"
        if ($a -ne 'JA') { Fail "Geannuleerd. Er is niets gewijzigd." }
    }
}

Step "1/6 Goose Desktop"
$gooseExe = "$env:LOCALAPPDATA\Programs\Goose\Goose.exe"
if (-not (Test-Path $gooseExe)) {
    if ($SkipSoftware) { Fail "Goose is niet geinstalleerd." }
    Winget-Install 'AgenticAIFoundation.gooseDesktop' $pk.gooseVersion
}
if (-not (Test-Path $gooseExe)) { Fail "Goose installeren is niet gelukt." }
Write-Host "Goose gevonden."

Step "2/6 Node.js (voor de browser-extensie)"
Refresh-Path
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    if ($SkipSoftware) { Fail "Node.js is niet geinstalleerd." }
    Winget-Install 'OpenJS.NodeJS.LTS' $null
}
$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node) { Fail "Node.js installeren is niet gelukt." }
Write-Host "Node gevonden: $node"

Step "3/6 Python (voor de desktop-extensie)"
$py = Find-Python
if (-not $py) {
    if ($SkipSoftware) { Fail "Python 3.12 of nieuwer is niet gevonden." }
    Winget-Install 'Python.Python.3.13' $null
    $py = Find-Python
}
if (-not $py) { Fail "Python installeren is niet gelukt." }
Write-Host "Python gevonden: $py"

Step "4/6 Extensies installeren"
$ext = Join-Path $InstallRoot 'ext'
$wm = Join-Path $ext 'windows-mcp'
$pw = Join-Path $ext 'playwright-mcp'
New-Item -ItemType Directory -Force $ext | Out-Null
if (-not (Test-Path "$wm\Scripts\python.exe")) { & $py -m venv $wm; if ($LASTEXITCODE) { Fail "Python-omgeving maken is mislukt." } }
& "$wm\Scripts\python.exe" -m pip install -q --disable-pip-version-check "windows-mcp==$($pk.windowsMcpVersion)"
if ($LASTEXITCODE) { Fail "Windows-MCP installeren is mislukt." }
New-Item -ItemType Directory -Force $pw | Out-Null
& cmd /c "npm install --prefix `"$pw`" --no-fund --no-audit --loglevel=error @playwright/mcp@$($pk.playwrightMcpVersion)"
$pwCli = Join-Path $pw 'node_modules\@playwright\mcp\cli.js'
if (-not (Test-Path $pwCli)) { Fail "Playwright MCP installeren is mislukt." }
Write-Host "Windows-MCP $($pk.windowsMcpVersion) en Playwright MCP $($pk.playwrightMcpVersion) staan klaar."

Step "5/6 Goose instellen"
$cfgDir = Join-Path $ConfigRoot 'config'
New-Item -ItemType Directory -Force $cfgDir | Out-Null
$cfg = Join-Path $cfgDir 'config.yaml'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$hints = Join-Path $cfgDir '.goosehints'
# Back up the customer's own settings only on the FIRST install, so uninstall can restore what was there before.
$firstInstall = -not (Test-Path (Join-Path $InstallRoot 'versie.json'))
if ($firstInstall) {
    if (Test-Path $cfg) { Copy-Item $cfg "$cfg.voor-pakket-$stamp"; Write-Host "Back-up van je eigen instellingen: config.yaml.voor-pakket-$stamp" }
    if (Test-Path $hints) { Copy-Item $hints "$hints.voor-pakket-$stamp" }
    [IO.File]::WriteAllText((Join-Path $InstallRoot 'origineel.json'), (@{ hadConfig = [bool](Test-Path $cfg); hadHints = [bool](Test-Path $hints) } | ConvertTo-Json), $utf8)
}
$t = [IO.File]::ReadAllText((Join-Path $here 'bestanden\config.template.yaml'), $utf8)
$t = $t.Replace('{{PROVIDER}}', $pk.provider).Replace('{{MODEL}}', $pk.model).Replace('{{WM_PYTHON}}', "$wm\Scripts\python.exe").Replace('{{NODE}}', $node).Replace('{{PW_CLI}}', $pwCli)
[IO.File]::WriteAllText($cfg, $t, $utf8)
Copy-Item (Join-Path $here 'bestanden\goosehints.txt') $hints -Force
Write-Host "Instellingen en veiligheidsregels geschreven."

Step "6/6 Toegangssleutel opslaan"
if (-not $Update) {
    if ($NoEnvKey) {
        Write-Host "Opslaan overgeslagen (test)."
    } else {
        [Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', $ApiKey, 'User')
        Write-Host "Sleutel opgeslagen voor deze Windows-gebruiker."
    }
}

# keep a copy of the package for updates and uninstall
$keep = Join-Path $InstallRoot 'pakket'
if ($here -ne $keep) {
    if (Test-Path $keep) { Remove-Item $keep -Recurse -Force }
    Copy-Item $here $keep -Recurse -Force
}
function KeyHash($k) { if (-not $k) { return '' }; $b = [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($k)); -join ($b | ForEach-Object { $_.ToString('x2') }) }
$vf = Join-Path $InstallRoot 'versie.json'
$keyHash = if ($Update -and (Test-Path $vf)) { (Get-Content $vf -Raw | ConvertFrom-Json).sleutelHash } elseif ($NoEnvKey) { '' } else { KeyHash $ApiKey }
[IO.File]::WriteAllText($vf, (@{ versie = $pk.versie; datum = (Get-Date -Format 's'); sleutelHash = $keyHash } | ConvertTo-Json), $utf8)

Write-Host "`nKlaar. Sluit Goose als het open staat en start het opnieuw via het Startmenu." -ForegroundColor Green
