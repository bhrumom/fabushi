param(
  [string]$OutDir = "desktop-artifacts"
)

$ErrorActionPreference = "Stop"

$AppName = "global_dharma_sharing"
$DisplayName = "全球法布施"
$AppVersion = if ($env:APP_VERSION) { $env:APP_VERSION } else { "1.0.0" }
$VersionSlug = $AppVersion -replace "\+", "-"
$BuildDir = Join-Path (Get-Location) "build\windows\x64\runner\Release"

if (-not (Test-Path $BuildDir)) {
  throw "Windows release bundle not found: $BuildDir"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$ZipPath = Join-Path $OutDir "$AppName-$VersionSlug-windows-x64.zip"
$InstallerPath = Join-Path $OutDir "$AppName-$VersionSlug-windows-x64-setup.exe"

if (Test-Path $ZipPath) {
  Remove-Item $ZipPath -Force
}
if (Test-Path $InstallerPath) {
  Remove-Item $InstallerPath -Force
}

Compress-Archive -Path (Join-Path $BuildDir "*") -DestinationPath $ZipPath -Force

$NsisPath = Join-Path $env:RUNNER_TEMP "global_dharma_sharing.nsi"
$UninstallRegKey = "Software\Microsoft\Windows\CurrentVersion\Uninstall\GlobalDharmaSharing"
$NsiContent = @"
Unicode true
Name "$DisplayName"
OutFile "$InstallerPath"
InstallDir "`$PROGRAMFILES64\Global Dharma Sharing"
RequestExecutionLevel admin

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Install"
  SetShellVarContext all
  SetOutPath "`$INSTDIR"
  File /r "$BuildDir\*.*"
  CreateDirectory "`$SMPROGRAMS\Global Dharma Sharing"
  CreateShortCut "`$SMPROGRAMS\Global Dharma Sharing\$DisplayName.lnk" "`$INSTDIR\$AppName.exe"
  CreateShortCut "`$DESKTOP\$DisplayName.lnk" "`$INSTDIR\$AppName.exe"
  WriteUninstaller "`$INSTDIR\Uninstall.exe"
  WriteRegStr HKLM "$UninstallRegKey" "DisplayName" "$DisplayName"
  WriteRegStr HKLM "$UninstallRegKey" "DisplayVersion" "$AppVersion"
  WriteRegStr HKLM "$UninstallRegKey" "Publisher" "bhrumom"
  WriteRegStr HKLM "$UninstallRegKey" "InstallLocation" "`$INSTDIR"
  WriteRegStr HKLM "$UninstallRegKey" "UninstallString" "`$INSTDIR\Uninstall.exe"
SectionEnd

Section "Uninstall"
  SetShellVarContext all
  Delete "`$DESKTOP\$DisplayName.lnk"
  Delete "`$SMPROGRAMS\Global Dharma Sharing\$DisplayName.lnk"
  RMDir "`$SMPROGRAMS\Global Dharma Sharing"
  RMDir /r "`$INSTDIR"
  DeleteRegKey HKLM "$UninstallRegKey"
SectionEnd
"@

Set-Content -Path $NsisPath -Value $NsiContent -Encoding UTF8

$MakeNsis = "${env:ProgramFiles(x86)}\NSIS\makensis.exe"
if (-not (Test-Path $MakeNsis)) {
  $MakeNsis = "makensis"
}

& $MakeNsis $NsisPath

Write-Host "Created $InstallerPath"
Write-Host "Created $ZipPath"
