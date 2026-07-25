param(
  [string]$Configuration = "Debug",
  [Parameter(Mandatory = $true)]
  [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Manifest = Join-Path $ProjectRoot "third_party\mahayana\mahayana-rs\Cargo.toml"
if (-not (Test-Path $Manifest)) {
  Write-Host "Submodule manifest not found at $Manifest. Initializing submodules..."
  & git -C $ProjectRoot submodule update --init --recursive
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to initialize Git submodules."
  }
}
$Profile = "debug"
$CargoArguments = @(
  "rustc",
  "--manifest-path", $Manifest,
  "--package", "mahayana-ffi",
  # The shared desktop host only needs the stable command/event ABI. Avoid the
  # default desktop-full graph here: linking the in-process Codex/V8 graph into
  # a Windows cdylib exhausts the hosted MSVC linker and surfaces only MSB8066.
  "--no-default-features",
  "--features", "linux-shared,local-only"
)

if ($Configuration -ne "Debug") {
  $Profile = "release"
  $CargoArguments += "--release"
}
$CargoArguments += ("--crate-type", "cdylib")

& cargo @CargoArguments
if ($LASTEXITCODE -ne 0) {
  throw "Cargo failed to build the Mahayana Rust runtime."
}

$Source = Join-Path $ProjectRoot "third_party\mahayana\mahayana-rs\target\$Profile\mahayana_runtime.dll"
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
Copy-Item -Force $Source (Join-Path $OutputDirectory "mahayana_runtime.dll")
