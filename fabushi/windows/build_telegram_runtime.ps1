param(
  [string]$Configuration = "Debug",
  [Parameter(Mandatory = $true)]
  [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Manifest = Join-Path $ProjectRoot "third_party\mahayana\mahayana-rs\Cargo.toml"
$Profile = "debug"
$CargoArguments = @("build", "--manifest-path", $Manifest, "--package", "mahayana-ffi")

if ($Configuration -ne "Debug") {
  $Profile = "release"
  $CargoArguments += "--release"
}

& cargo @CargoArguments
if ($LASTEXITCODE -ne 0) {
  throw "Cargo failed to build the Mahayana Rust runtime."
}

$Source = Join-Path $ProjectRoot "third_party\mahayana\mahayana-rs\target\$Profile\mahayana_runtime.dll"
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
Copy-Item -Force $Source (Join-Path $OutputDirectory "mahayana_runtime.dll")
