param(
  [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')][string]$Plugin,
  [string]$Catalog = 'https://fabushi.ombhrum.com/.well-known/mahayana/marketplace.json',
  [ValidateSet('windows-x64')][string]$Platform = 'windows-x64',
  [string]$InstallRoot = ''
)

$ErrorActionPreference = 'Stop'
if (-not $InstallRoot) {
  $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
  $InstallRoot = Join-Path $codexHome 'plugins\fabushi-official'
}

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("fabushi-plugin-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp | Out-Null
try {
  $catalogData = Invoke-RestMethod -Uri $Catalog
  $pluginEntry = $catalogData.plugins | Where-Object { $_.id -eq $Plugin } | Select-Object -First 1
  if (-not $pluginEntry) { throw "Plugin not found in catalog: $Plugin" }
  $artifact = $catalogData.artifacts.$Platform
  if (-not $artifact) { throw "Platform not found in catalog: $Platform" }
  $artifactUrl = $artifact.urlTemplate.Replace('{plugin}', $Plugin).Replace('{version}', $pluginEntry.version)
  $checksumUrl = $artifact.sha256UrlTemplate.Replace('{plugin}', $Plugin).Replace('{version}', $pluginEntry.version)
  $archive = Join-Path $temp ([System.IO.Path]::GetFileName(([uri]$artifactUrl).AbsolutePath))
  $checksum = Join-Path $temp ([System.IO.Path]::GetFileName(([uri]$checksumUrl).AbsolutePath))
  Invoke-WebRequest -Uri $artifactUrl -OutFile $archive
  Invoke-WebRequest -Uri $checksumUrl -OutFile $checksum
  $expected = ((Get-Content $checksum -Raw).Trim() -split '\s+')[0].ToLowerInvariant()
  $actual = (Get-FileHash -Algorithm SHA256 $archive).Hash.ToLowerInvariant()
  if ($actual -ne $expected) { throw "SHA-256 mismatch for $archive" }

  $extract = Join-Path $temp 'extract'
  Expand-Archive -Path $archive -DestinationPath $extract -Force
  $source = Join-Path $extract $Plugin
  if (-not (Test-Path $source -PathType Container)) { throw "Archive does not contain $Plugin" }
  $manifest = Get-Content (Join-Path $source '.codex-plugin\plugin.json') -Raw | ConvertFrom-Json
  if ($manifest.name -ne $Plugin) { throw 'Plugin manifest id mismatch' }
  foreach ($required in @('.mahayana\plugin.json', '.mcp.json', 'runtime\wasm\fabushi_official_miniapps_bg.wasm', 'runtime\cli\fabushi-plugin-cli.exe')) {
    if (-not (Test-Path (Join-Path $source $required))) { throw "Missing packaged file: $required" }
  }

  New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
  $destination = Join-Path $InstallRoot $Plugin
  $staging = Join-Path $InstallRoot (".$Plugin.installing." + $PID)
  Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
  Copy-Item $source $staging -Recurse
  Remove-Item $destination -Recurse -Force -ErrorAction SilentlyContinue
  Move-Item $staging $destination
  $cli = Join-Path $destination 'runtime\cli\fabushi-plugin-cli.exe'
  & $cli --help | Out-Null
  Write-Output "Installed $Plugin $($pluginEntry.version) for $Platform at $destination"
}
finally {
  Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}
