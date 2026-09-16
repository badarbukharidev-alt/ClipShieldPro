# Builds a reseller's copy of the app, from PowerShell.
#
# Same job as tools/build_reseller.sh, for Windows. In PowerShell `bash` resolves
# to WSL rather than Git Bash, so the .sh version fails with "no installed
# distributions" on a machine that has Git but not WSL.
#
# The reseller code is compiled in, because it is what the panel keys off to
# return that reseller's support number and that reseller's update -- it has to
# be known before the app's first API call.
#
# A reseller build also has the in-app admin tools compiled out. Those screens
# mint licence keys on the device with no quota and no record, which would let a
# reseller -- or anyone holding a copy of their APK -- issue unlimited keys and
# bypass their allowance entirely.
#
# Usage:   .\tools\build_reseller.ps1 abrar
#
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Reseller
)

$ErrorActionPreference = 'Stop'

# Run from the project root regardless of where this was invoked from.
Set-Location (Join-Path $PSScriptRoot '..')

$code = $Reseller.Trim().ToLower()

# The same rule the panel applies. A code that fails here would compile into an
# app that silently reports itself as a house build.
if ($code -notmatch '^[a-z0-9][a-z0-9_-]{1,31}$') {
    Write-Host "ERROR: `"$code`" is not a valid reseller code." -ForegroundColor Red
    Write-Host "       2-32 characters: lowercase letters, digits, hyphen, underscore."
    exit 1
}

$secretFile = 'android/api_secret.txt'

if (-not (Test-Path $secretFile)) {
    Write-Host "ERROR: android/api_secret.txt is missing." -ForegroundColor Red
    Write-Host "       Without it the task reward system stays disabled."
    Write-Host "       See tools/build_release.sh for how to create one."
    exit 1
}

$secret = (Get-Content $secretFile -Raw) -replace '\s', ''

if ($secret.Length -lt 32) {
    Write-Host "ERROR: secret in $secretFile is only $($secret.Length) chars; needs at least 32." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path 'android/key.properties')) {
    Write-Host "WARNING: android/key.properties is missing - this build will be signed" -ForegroundColor Yellow
    Write-Host "         with the debug key, which breaks upgrades and licensing." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Clear the previous build's Flutter intermediates.
#
# Two separate problems live here, and only doing one of them is why this kept
# failing:
#
#  1. A --dart-define change does not invalidate the intermediates, so the asset
#     copy walks into files left by the last build: "Cannot create a file when
#     that file already exists".
#  2. Gradle keeps a daemon alive after a build, and that daemon holds open
#     handles on those same files. Deleting them then fails with "Access is
#     denied" -- and so does Flutter's own cleanup a moment later, which is what
#     produced the tool crash.
#
# So: stop the daemons first, then delete. Switching between the house build and
# a reseller build is exactly when both bite.
# ---------------------------------------------------------------------------
$intermediates = 'build/app/intermediates/flutter'

function Test-IntermediatesGone {
    return -not (Test-Path $intermediates)
}

if (-not (Test-IntermediatesGone)) {
    Write-Host "Stopping Gradle daemons so the previous build releases its files..." -ForegroundColor DarkGray
    Push-Location 'android'
    try {
        & cmd /c "gradlew.bat --stop" 2>&1 | Out-Null
    } catch {
        # No daemon running, or no wrapper. Either is fine; the delete below is
        # what actually matters.
    }
    Pop-Location

    Write-Host "Clearing intermediates from the previous build..." -ForegroundColor DarkGray
    Remove-Item $intermediates -Recurse -Force -ErrorAction SilentlyContinue

    if (-not (Test-IntermediatesGone)) {
        # Something still has a handle -- an editor, an indexer, a second build.
        # A full clean is slower but does not negotiate.
        Write-Host "Still locked. Falling back to a full 'flutter clean'..." -ForegroundColor Yellow
        flutter clean | Out-Null

        if (-not (Test-IntermediatesGone)) {
            Write-Host "ERROR: could not clear $intermediates." -ForegroundColor Red
            Write-Host "       Something is holding those files open. Close any other build,"
            Write-Host "       editor or file explorer in this folder and run this again."
            exit 1
        }
    }
}

Write-Host "Building reseller APK for `"$code`"..." -ForegroundColor Cyan

flutter build apk --release `
    --dart-define=CLIPSHIELD_API_SECRET="$secret" `
    --dart-define=CLIPSHIELD_RESELLER="$code"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed." -ForegroundColor Red
    exit $LASTEXITCODE
}

$out = 'build/app/outputs/flutter-apk/app-release.apk'
$dest = "release/ClipShieldPro-$code.apk"

if (-not (Test-Path 'release')) { New-Item -ItemType Directory -Path 'release' | Out-Null }
Copy-Item $out $dest -Force

$sizeMb = [math]::Round((Get-Item $dest).Length / 1MB, 1)

Write-Host ""
Write-Host "Built: $dest ($sizeMb MB)" -ForegroundColor Green
Write-Host ""
Write-Host "Next: upload it somewhere reachable over https, then record it in the"
Write-Host "admin panel under Resellers > $code > Publish a build. The reseller"
Write-Host "then sees it on their portal as the version to hand out."
