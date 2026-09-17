$ErrorActionPreference = 'Stop'
$repo = if ($env:MAHAYANA_CLI_REPOSITORY) { $env:MAHAYANA_CLI_REPOSITORY } else { 'bhrumom/fabushi' }
$channel = if ($env:MAHAYANA_CLI_CHANNEL) { $env:MAHAYANA_CLI_CHANNEL } else { 'mahayana-cli-latest' }
$base = "https://github.com/$repo/releases/download/$channel"
$arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
switch ($arch) {
  'X64' { $machine = 'x86_64' }
  'Arm64' { $machine = 'x86_64' } # Windows ARM64 runs the signed x64 CLI through built-in emulation
  default { throw "Unsupported Windows architecture: $arch" }
}
$asset = "mahayana-windows-$machine.zip"
function Invoke-MahayanaDownload {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [Parameter(Mandatory = $true)][string]$OutFile
  )
  $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
  if ($curl) {
    & $curl.Source --fail --location --silent --show-error --retry 5 --retry-delay 1 --connect-timeout 15 --output $OutFile $Uri
    if ($LASTEXITCODE -ne 0) { throw "Download failed with curl.exe exit code ${LASTEXITCODE}: $Uri" }
    return
  }
  Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $OutFile
}
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("mahayana-cli-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  $archive = Join-Path $tmp $asset
  $sums = Join-Path $tmp 'SHA256SUMS.txt'
  Invoke-MahayanaDownload -Uri "$base/$asset" -OutFile $archive
  Invoke-MahayanaDownload -Uri "$base/SHA256SUMS.txt" -OutFile $sums
  $line = Get-Content $sums | Where-Object { $_ -match "\s\*?$([regex]::Escape($asset))$" } | Select-Object -First 1
  if (-not $line) { throw "No checksum found for $asset" }
  $expected = ($line -split '\s+')[0].ToLowerInvariant()
  $actual = (Get-FileHash -Algorithm SHA256 $archive).Hash.ToLowerInvariant()
  if ($actual -ne $expected) { throw "Checksum verification failed for $asset" }
  Expand-Archive -Path $archive -DestinationPath $tmp -Force
  $source = Join-Path $tmp 'mahayana.exe'
  if (-not (Test-Path $source)) { throw 'Release archive does not contain mahayana.exe' }
  $installDir = if ($env:MAHAYANA_INSTALL_DIR) { $env:MAHAYANA_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Fabushi\Mahayana\bin' }
  New-Item -ItemType Directory -Path $installDir -Force | Out-Null
  $target = Join-Path $installDir 'mahayana.exe'
  Copy-Item $source $target -Force
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $parts = @($userPath -split ';' | Where-Object { $_ })
  if ($parts -notcontains $installDir) {
    [Environment]::SetEnvironmentVariable('Path', (($parts + $installDir) -join ';'), 'User')
  }
  & $target device start *> $null
  Write-Host "Mahayana CLI installed: $target"
  Write-Host 'Open a new terminal and run: mahayana login'
} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
