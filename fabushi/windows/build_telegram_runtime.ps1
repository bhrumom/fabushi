param(
  [string]$Configuration = "Debug",
  [Parameter(Mandatory = $true)]
  [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Manifest = Join-Path $ProjectRoot "native\telegram-runtime\Cargo.toml"
$Profile = "debug"
$CargoArguments = @("build", "--manifest-path", $Manifest)

if ($Configuration -ne "Debug") {
  $Profile = "release"
  $CargoArguments += "--release"
}

& cargo @CargoArguments
if ($LASTEXITCODE -ne 0) {
  throw "Cargo failed to build the Telegram Rust runtime."
}

$Source = Join-Path $ProjectRoot "native\telegram-runtime\target\$Profile\fabushi_telegram_runtime.dll"
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
Copy-Item -Force $Source (Join-Path $OutputDirectory "fabushi_telegram_runtime.dll")
