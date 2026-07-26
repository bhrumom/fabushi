param(
  [string]$OutDir = "desktop-artifacts"
)

$ErrorActionPreference = "Stop"

$AppName = "global_dharma_sharing"
$CliName = "global_dharma_sharing_cli"
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

# NSIS cannot reliably read source paths longer than MAX_PATH. Stage the
# release bundle under RUNNER_TEMP so deeply nested Node assets remain below it.
$NsisSourceDir = Join-Path $env:RUNNER_TEMP "gds-nsis"
if (Test-Path $NsisSourceDir) {
  Remove-Item $NsisSourceDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $NsisSourceDir | Out-Null
robocopy $BuildDir $NsisSourceDir /E /NFL /NDL /NJH /NJS /NC /NS | Out-Host
if ($LASTEXITCODE -ge 8) {
  throw "Failed to stage Windows release bundle for NSIS: robocopy exit code $LASTEXITCODE"
}
$global:LASTEXITCODE = 0

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
  File /r "$NsisSourceDir\*.*"
  CreateDirectory "`$SMPROGRAMS\Global Dharma Sharing"
  CreateShortCut "`$SMPROGRAMS\Global Dharma Sharing\$DisplayName.lnk" "`$INSTDIR\$AppName.exe"
  CreateShortCut "`$SMPROGRAMS\Global Dharma Sharing\Global Dharma Sharing CLI.lnk" "`$INSTDIR\$CliName.exe" "doctor --json"
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
  Delete "`$SMPROGRAMS\Global Dharma Sharing\Global Dharma Sharing CLI.lnk"
  RMDir "`$SMPROGRAMS\Global Dharma Sharing"
  RMDir /r "`$INSTDIR"
  DeleteRegKey HKLM "$UninstallRegKey"
SectionEnd
"@

Set-Content -Path $NsisPath -Value $NsiContent -Encoding UTF8

$MakeNsisCandidates = @()
if (${env:ProgramFiles(x86)}) {
  $MakeNsisCandidates += Join-Path ${env:ProgramFiles(x86)} "NSIS\makensis.exe"
  $MakeNsisCandidates += Join-Path ${env:ProgramFiles(x86)} "NSIS\Bin\makensis.exe"
}
if ($env:ProgramFiles) {
  $MakeNsisCandidates += Join-Path $env:ProgramFiles "NSIS\makensis.exe"
  $MakeNsisCandidates += Join-Path $env:ProgramFiles "NSIS\Bin\makensis.exe"
}
if ($env:ChocolateyInstall) {
  $MakeNsisCandidates += Join-Path $env:ChocolateyInstall "bin\makensis.exe"
}

$MakeNsis = $MakeNsisCandidates |
  Where-Object { Test-Path $_ -PathType Leaf } |
  Select-Object -First 1

if (-not $MakeNsis) {
  $MakeNsisCommand = Get-Command makensis.exe -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($MakeNsisCommand) {
    $MakeNsis = $MakeNsisCommand.Source
  }
}

if (-not $MakeNsis) {
  $SearchRoots = @(${env:ProgramFiles(x86)}, $env:ProgramFiles, $env:ChocolateyInstall) |
    Where-Object { $_ -and (Test-Path $_ -PathType Container) } |
    Select-Object -Unique
  foreach ($SearchRoot in $SearchRoots) {
    $MakeNsis = Get-ChildItem -Path $SearchRoot -Filter makensis.exe -File -Recurse -ErrorAction SilentlyContinue |
      Select-Object -First 1 -ExpandProperty FullName
    if ($MakeNsis) {
      break
    }
  }
}

if (-not $MakeNsis) {
  throw "NSIS makensis.exe was not found after toolchain installation. Checked: $($MakeNsisCandidates -join ', ')"
}

Write-Host "Using NSIS compiler: $MakeNsis"
& $MakeNsis $NsisPath

Write-Host "Created $InstallerPath"
Write-Host "Created $ZipPath"
