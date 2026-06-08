param(
  [string]$ReleaseTag = "latest",
  [string]$AssetPattern = "*windows-x64.zip",
  [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

function Fail($Message) {
  Write-Error $Message
  exit 1
}

$workDir = Join-Path $env:RUNNER_TEMP "fabushi-windows-release-e2e"
$zipDir = Join-Path $workDir "release"
$appDir = Join-Path $workDir "app"
$profileDir = Join-Path $workDir "profile"
New-Item -ItemType Directory -Force -Path $zipDir, $appDir, $profileDir | Out-Null

Write-Host "Downloading Windows release asset: tag=$ReleaseTag pattern=$AssetPattern"
if ($ReleaseTag -eq "latest") {
  gh release download --repo $env:GITHUB_REPOSITORY --pattern $AssetPattern --dir $zipDir --clobber
} else {
  gh release download $ReleaseTag --repo $env:GITHUB_REPOSITORY --pattern $AssetPattern --dir $zipDir --clobber
}

$zip = Get-ChildItem -Path $zipDir -Filter "*.zip" | Select-Object -First 1
if (-not $zip) { Fail "No Windows release zip matched $AssetPattern" }
Expand-Archive -Path $zip.FullName -DestinationPath $appDir -Force

$node = Join-Path $appDir "data\flutter_assets\assets\openclaw\windows-x64\node\node.exe"
$cli = Join-Path $appDir "data\flutter_assets\assets\openclaw\windows-x64\openclaw\bin\openclaw.js"
if (-not (Test-Path $node)) { Fail "Release package is missing embedded node.exe: $node" }
if (-not (Test-Path $cli)) { Fail "Release package is missing embedded openclaw.js: $cli" }

$exe = Get-ChildItem -Path $appDir -Filter "*.exe" | Where-Object { $_.Name -ne "Uninstall.exe" } | Select-Object -First 1
if (-not $exe) { Fail "No app executable found in expanded release zip" }

Write-Host "Launching $($exe.FullName)"
$env:DACHENG_E2E_OPENCLAW_CHAT = "1"
$env:DACHENG_E2E_OPENCLAW_PROMPT = "请用一句话回复：南无阿弥陀佛"
$env:DACHENG_E2E_OPENCLAW_RESULT_DIR = $workDir
$env:LOCALAPPDATA = $profileDir
$env:APPDATA = $profileDir
$process = Start-Process -FilePath $exe.FullName -WorkingDirectory $appDir -PassThru

$resultPath = Join-Path $workDir "openclaw-home-chat-result.json"
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
try {
  while ((Get-Date) -lt $deadline) {
    if (Test-Path $resultPath) {
      $raw = Get-Content -Raw -Path $resultPath
      Write-Host "E2E result: $raw"
      $result = $raw | ConvertFrom-Json
      if ($result.ok -eq $true) {
        exit 0
      }
      Fail "OpenClaw home chat E2E failed: $($result.error)"
    }
    if ($process.HasExited) {
      Fail "App exited before writing E2E result. ExitCode=$($process.ExitCode)"
    }
    Start-Sleep -Seconds 2
  }
  Fail "Timed out waiting for OpenClaw home chat E2E result at $resultPath"
} finally {
  if (-not $process.HasExited) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
  }
  Get-ChildItem -Path $workDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "E2E file: $($_.FullName) size=$($_.Length)"
  }
}
