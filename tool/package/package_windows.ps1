# Build and package the Windows release bundle.
#
# Produces (in dist/):
#   compositor-<version>-windows-x64.zip                always
#   compositor-<version>-windows-x64-setup.exe          when Inno Setup's iscc is on PATH
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tool\package\package_windows.ps1 [-SkipBuild]

param([switch]$SkipBuild)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path "$PSScriptRoot\..\.."
Set-Location $Root

$versionMatch = Select-String -Path "pubspec.yaml" -Pattern '^version:\s*([0-9][^+\s]*)' |
    Select-Object -First 1
if (-not $versionMatch) { throw "could not read version from pubspec.yaml" }
$Version = $versionMatch.Matches[0].Groups[1].Value

$Bundle = "build\windows\x64\runner\Release"
if (-not $SkipBuild) {
    Write-Host "==> flutter build windows --release"
    flutter build windows --release
}
if (-not (Test-Path $Bundle)) {
    throw "release bundle not found at $Bundle; run without -SkipBuild"
}

$Dist = "dist"
if (Test-Path $Dist) { Remove-Item -Recurse -Force $Dist }
New-Item -ItemType Directory -Force -Path $Dist | Out-Null
$Name = "compositor-$Version-windows-x64"

Write-Host "==> zip"
Compress-Archive -Path "$Bundle\*" -DestinationPath "$Dist\$Name.zip" -Force

$Iscc = Get-Command iscc.exe -ErrorAction SilentlyContinue
if (-not $Iscc) {
    Write-Host "==> iscc.exe not found; skipping installer (install Inno Setup to build it)"
} else {
    Write-Host "==> Inno Setup"
    $env:COMPOSITOR_VERSION = $Version
    & $Iscc.Source "$PSScriptRoot\compositor.iss"
    if ($LASTEXITCODE -ne 0) { throw "iscc failed with exit code $LASTEXITCODE" }
}

Write-Host ""
Write-Host "Artifacts in ${Dist}:"
Get-ChildItem $Dist | Format-Table Name, Length
