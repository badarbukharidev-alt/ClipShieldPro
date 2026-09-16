# Packages the Build Station into a single .exe.
#
# Output lands at tools/builder_app/dist/ClipShieldBuilder.exe. Copy it into the
# project folder and double-click it -- it locates the project by looking for
# pubspec.yaml next to itself, then one level up from a dist/ folder.
#
# Usage:  .\tools\builder_app\build_exe.ps1
#
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

python -m pip install --quiet --upgrade pyinstaller
if ($LASTEXITCODE -ne 0) { Write-Host "Could not install PyInstaller." -ForegroundColor Red; exit 1 }

Write-Host "Packaging ClipShieldBuilder.exe..." -ForegroundColor Cyan

# --noconsole: it is a GUI, and a console window flashing behind it looks broken.
# --onefile:   one thing to copy, rather than a folder of DLLs to keep together.
python -m PyInstaller `
    --noconfirm `
    --onefile `
    --noconsole `
    --name ClipShieldBuilder `
    --clean `
    clipshield_builder.py

if ($LASTEXITCODE -ne 0) { Write-Host "Packaging failed." -ForegroundColor Red; exit 1 }

$exe = Join-Path $PSScriptRoot 'dist\ClipShieldBuilder.exe'
$mb = [math]::Round((Get-Item $exe).Length / 1MB, 1)

Write-Host ""
Write-Host "Built: $exe ($mb MB)" -ForegroundColor Green
Write-Host ""
Write-Host "Copy it to the project root and run it from there."
