# Builds the house app and every reseller's app, in two compiles.
#
# ## How this avoids one build per reseller
#
# The reseller code lives in a bundled asset, not a compile-time constant, so it
# can be rewritten inside a finished APK. That means:
#
#   1. Compile the house app          (admin tools in, no reseller code)
#   2. Compile the reseller base once (admin tools compiled OUT)
#   3. For each reseller: copy the base, stamp their code into the asset,
#      re-align, re-sign. Seconds each.
#
# Twenty resellers is two compiles and twenty stamps, not twenty-two compiles.
#
# The admin tools stay a compile-time exclusion rather than a runtime check
# precisely because the asset is editable: those screens mint licence keys with
# no quota and no record, so in a reseller build they must be absent, not merely
# hidden behind a flag someone repackaging the APK could flip back.
#
# ## Usage
#
#   .\tools\build_all.ps1                  # fetch resellers, build everything
#   .\tools\build_all.ps1 -Push            # ...and push the APKs to GitHub
#   .\tools\build_all.ps1 -SkipHouse       # resellers only
#   .\tools\build_all.ps1 -Only abrar,zain # just these resellers
#   .\tools\build_all.ps1 -Offline         # skip the API, use -Only as the list
#
param(
    [switch]$Push,
    [switch]$SkipHouse,
    [string[]]$Only = @(),
    [switch]$Offline
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

$PanelUrl = 'https://clipshieldpro.toolsfinity.io'
$ResellerDir = 'resellers'

# ---------------------------------------------------------------- preflight
$secretFile = 'android/api_secret.txt'
if (-not (Test-Path $secretFile)) {
    Write-Host "ERROR: android/api_secret.txt is missing." -ForegroundColor Red
    exit 1
}
$secret = (Get-Content $secretFile -Raw) -replace '\s', ''
if ($secret.Length -lt 32) {
    Write-Host "ERROR: the API secret is too short." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path 'android/key.properties')) {
    Write-Host "ERROR: android/key.properties is missing." -ForegroundColor Red
    Write-Host "       Stamped APKs must be signed with the release key or they"
    Write-Host "       will not install over an existing ClipShield."
    exit 1
}

$version = (Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()
$versionName = $version.Split('+')[0]

Write-Host ""
Write-Host "ClipShield build run - version $version" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------- reseller list
function Get-Resellers {
    $ts = [int][double]::Parse((Get-Date -UFormat %s))
    $nonce = -join ((1..16) | ForEach-Object { '{0:x}' -f (Get-Random -Max 16) })

    # Canonical form must match api_canonical() exactly:
    #   action|device|ts|nonce|extra
    $canonical = "build.resellers||$ts|$nonce|"

    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = [Text.Encoding]::UTF8.GetBytes($secret)
    $sig = ($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($canonical)) |
            ForEach-Object { $_.ToString('x2') }) -join ''

    $url = "$PanelUrl/api/resellers.php?ts=$ts&nonce=$nonce&sig=$sig"

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 30
    } catch {
        Write-Host "Could not reach the panel: $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }

    if (-not $response.ok) {
        Write-Host "Panel refused the request: $($response.error)" -ForegroundColor Yellow
        return $null
    }

    return $response.resellers
}

$resellers = @()

# -File passes "-Only a,b" as one string, and a single-item pipeline result has
# no .Count in PowerShell 5.1. Both are normalised here so the rest of the
# script can just treat this as a list.
$Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })

if ($Offline) {
    if ($Only.Count -eq 0) {
        Write-Host "ERROR: -Offline needs -Only to say which resellers to build." -ForegroundColor Red
        exit 1
    }
    $resellers = @($Only | ForEach-Object { [pscustomobject]@{ code = $_; display_name = $_; has_whatsapp = $true } })
    Write-Host "Offline: building $($resellers.Count) reseller(s) from -Only." -ForegroundColor DarkGray
} else {
    Write-Host "Fetching resellers from the panel..." -ForegroundColor DarkGray
    $fetched = Get-Resellers

    if ($null -eq $fetched) {
        Write-Host ""
        Write-Host "No reseller list. Building the house app only." -ForegroundColor Yellow
        Write-Host "Use -Offline -Only <codes> to build resellers without the panel."
        $resellers = @()
    } else {
        $resellers = @($fetched)
        if ($Only.Count -gt 0) {
            $resellers = @($resellers | Where-Object { $Only -contains $_.code })
        }
        Write-Host "  $($resellers.Count) active reseller(s)." -ForegroundColor DarkGray
    }
}

# ------------------------------------------------------------ build helper
function Clear-Intermediates {
    # Gradle's daemon holds handles on these after a build; deleting them while
    # it is alive fails with "Access is denied", and so does Flutter's own
    # cleanup a moment later -- which crashes the tool rather than failing
    # cleanly.
    $dir = 'build/app/intermediates/flutter'
    if (-not (Test-Path $dir)) { return }

    Push-Location 'android'
    try { & cmd /c "gradlew.bat --stop" 2>&1 | Out-Null } catch { }
    Pop-Location

    Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue

    if (Test-Path $dir) {
        Write-Host "  intermediates still locked; running flutter clean..." -ForegroundColor Yellow
        flutter clean | Out-Null
    }
}

$built = @()
$failed = @()

# --------------------------------------------------------------- house app
if (-not $SkipHouse) {
    Write-Host ""
    Write-Host "[1/2] Building the house app..." -ForegroundColor Cyan
    Clear-Intermediates

    flutter build apk --release --dart-define=CLIPSHIELD_API_SECRET="$secret"
    if ($LASTEXITCODE -ne 0) { Write-Host "House build failed." -ForegroundColor Red; exit 1 }

    if (-not (Test-Path 'release')) { New-Item -ItemType Directory -Path 'release' | Out-Null }
    $houseApk = "release/ClipShieldPro-v$versionName.apk"
    Copy-Item 'build/app/outputs/flutter-apk/app-release.apk' $houseApk -Force

    $mb = [math]::Round((Get-Item $houseApk).Length / 1MB, 1)
    Write-Host "  $houseApk ($mb MB)" -ForegroundColor Green
    $built += $houseApk
}

# ------------------------------------------------------------ reseller base
if ($resellers.Count -gt 0) {
    Write-Host ""
    Write-Host "[2/2] Building the reseller base (admin tools compiled out)..." -ForegroundColor Cyan
    Clear-Intermediates

    flutter build apk --release `
        --dart-define=CLIPSHIELD_API_SECRET="$secret" `
        --dart-define=CLIPSHIELD_RESELLER_BASE=true
    if ($LASTEXITCODE -ne 0) { Write-Host "Reseller base build failed." -ForegroundColor Red; exit 1 }

    $baseApk = 'build/reseller-base.apk'
    Copy-Item 'build/app/outputs/flutter-apk/app-release.apk' $baseApk -Force
    Write-Host "  base ready" -ForegroundColor Green

    if (-not (Test-Path $ResellerDir)) { New-Item -ItemType Directory -Path $ResellerDir | Out-Null }

    Write-Host ""
    Write-Host "Stamping $($resellers.Count) reseller APK(s)..." -ForegroundColor Cyan

    foreach ($r in $resellers) {
        $code = $r.code
        $out = "$ResellerDir/ClipShieldPro-$code.apk"

        python tools/stamp_reseller.py $baseApk $code $out

        if ($LASTEXITCODE -eq 0) {
            $built += $out
            if (-not $r.has_whatsapp) {
                Write-Host "    note: $code has not set a WhatsApp number yet, so their" -ForegroundColor Yellow
                Write-Host "          customers still see the default ClipShield number." -ForegroundColor Yellow
            }
        } else {
            $failed += $code
        }
    }

    Remove-Item $baseApk -Force -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------------- push
if ($Push -and $built.Count -gt 0) {
    Write-Host ""
    Write-Host "Pushing to GitHub..." -ForegroundColor Cyan

    git add release $ResellerDir 2>&1 | Out-Null
    $pending = git status --porcelain -- release $ResellerDir

    if ([string]::IsNullOrWhiteSpace($pending)) {
        Write-Host "  nothing changed." -ForegroundColor DarkGray
    } else {
        $summary = "Build v$version" +
                   $(if ($resellers.Count -gt 0) { " + $($resellers.Count) reseller APK(s)" } else { "" })
        git commit -q -m $summary
        git push origin main
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  pushed." -ForegroundColor Green
        } else {
            Write-Host "  push failed - the APKs are committed locally." -ForegroundColor Yellow
        }
    }
}

# ---------------------------------------------------------------- summary
Write-Host ""
Write-Host "Done. $($built.Count) APK(s):" -ForegroundColor Green
foreach ($b in $built) { Write-Host "  $b" }

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
