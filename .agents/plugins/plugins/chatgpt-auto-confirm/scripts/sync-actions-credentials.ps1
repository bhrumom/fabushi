[CmdletBinding()]
param(
  [string]$Repository = $(if ($env:CHATGPT_AUTO_CONFIRM_REPOSITORY) { $env:CHATGPT_AUTO_CONFIRM_REPOSITORY } else { 'bhrumom/fabushi' }),
  [int]$WaitSeconds = 600,
  [switch]$OpenLogin,
  [switch]$DesktopLogin,
  [switch]$WebLogin,
  [switch]$Start
)

$ErrorActionPreference = 'Stop'
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) ('fabushi-chatgpt-sync-' + [Guid]::NewGuid().ToString('N'))
$stage = 'preflight'
$result = $null
$exitCode = 0
$failureDetail = $null
$failureLine = $null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Set-GitHubSecretFromFile([string]$name, [string]$path) {
  $bytes = [IO.File]::ReadAllBytes($path)
  $encoded = [Convert]::ToBase64String($bytes)
  if ($encoded.Length -ge 47000) { throw "secret $name exceeds the GitHub secret size budget" }
  $encoded | & $script:GitHubCli.Source secret set $name --repo $Repository | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "GitHub CLI failed to update $name" }
}

function Set-GitHubSecretFromValue([string]$name, [string]$value) {
  if ([string]::IsNullOrWhiteSpace($value) -or $value.Length -ge 47000) {
    throw "secret $name is empty or exceeds the GitHub secret size budget"
  }
  $value | & $script:GitHubCli.Source secret set $name --repo $Repository | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "GitHub CLI failed to update $name" }
}

function New-RandomBytes([int]$length) {
  $bytes = New-Object byte[] $length
  $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
  try { $generator.GetBytes($bytes) } finally { $generator.Dispose() }
  return $bytes
}

function Start-ChatGptDesktopApp {
  $appId = if ($env:CHATGPT_DESKTOP_APP_ID) {
    [string]$env:CHATGPT_DESKTOP_APP_ID
  } else {
    'OpenAI.Codex_2p2nqsd0c76g0!App'
  }
  Start-Process -FilePath ('shell:AppsFolder\' + $appId) | Out-Null
}

function Start-ChatGptWebLogin {
  $loginUrl = if ($env:CHATGPT_WEB_LOGIN_URL) {
    [string]$env:CHATGPT_WEB_LOGIN_URL
  } else {
    'https://chatgpt.com/auth/login'
  }
  Start-Process -FilePath $loginUrl | Out-Null
}

function Get-PythonCommand {
  $command = Get-Command py.exe -ErrorAction SilentlyContinue
  if ($command) { return [pscustomobject]@{ Command = $command; Prefix = @('-3', $script:HelperPath) } }
  $command = Get-Command python.exe -ErrorAction SilentlyContinue
  if (-not $command) { $command = Get-Command python -ErrorAction SilentlyContinue }
  if (-not $command) { throw 'Python 3 was not found; install pywin32 and pycryptodome for ChatGPT credential extraction' }
  return [pscustomobject]@{ Command = $command; Prefix = @($script:HelperPath) }
}

function Get-SessionCookieSummary([string]$authPath, [string]$cookiePath, [string]$source) {
  if (Test-Path -LiteralPath $cookiePath) {
    [IO.File]::Delete($cookiePath)
  }
  $arguments = $script:Python.Prefix + @(
    '--output', $cookiePath,
    '--auth', $authPath,
    '--source', $source,
    '--verify-account'
  )
  $extractOutput = @(& $script:Python.Command.Source @arguments 2>&1)
  $extractExitCode = $LASTEXITCODE
  $summaryLine = ($extractOutput | ForEach-Object { [string]$_ } |
    Where-Object { $_ -match '^\{' } | Select-Object -Last 1)
  if ($extractExitCode -ne 0 -or -not $summaryLine -or
      -not (Test-Path -LiteralPath $cookiePath -PathType Leaf)) {
    return $null
  }
  try { $summary = $summaryLine | ConvertFrom-Json } catch { return $null }
  if (-not $summary.ok -or -not $summary.accountVerified -or [int]$summary.cookieCount -le 0) {
    return $null
  }
  return $summary
}

try {
  New-Item -ItemType Directory -Path $temporaryDirectory -Force | Out-Null

  $script:GitHubCli = Get-Command gh.exe -ErrorAction SilentlyContinue
  if (-not $script:GitHubCli) { $script:GitHubCli = Get-Command gh -ErrorAction SilentlyContinue }
  if (-not $script:GitHubCli) { throw 'GitHub CLI (gh) was not found; install it and run gh auth login first' }
  & $script:GitHubCli.Source auth status *> $null
  if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI is not authenticated; run gh auth login first' }

  $desktopLoginRequested = $OpenLogin -or $DesktopLogin
  $webLoginRequested = $WebLogin
  if ((@($desktopLoginRequested, $webLoginRequested) | Where-Object { $_ }).Count -gt 1) {
    throw 'desktop and web login were requested together'
  }

  $authPath = if ($env:CHATGPT_CODEX_AUTH_PATH) {
    [string]$env:CHATGPT_CODEX_AUTH_PATH
  } else {
    Join-Path $env:USERPROFILE '.codex\auth.json'
  }
  if (-not (Test-Path -LiteralPath $authPath -PathType Leaf)) {
    $stage = 'auth'
    throw 'the local Codex auth.json was not found; sign in to the ChatGPT desktop app first'
  }
  if ((Get-Item -LiteralPath $authPath).Length -eq 0) {
    $stage = 'auth'
    throw 'the local Codex auth.json is empty'
  }

  $stage = 'cookie_extract'
  $script:HelperPath = Join-Path $scriptDirectory 'extract-windows-chatgpt-cookies.py'
  if (-not (Test-Path -LiteralPath $script:HelperPath -PathType Leaf)) {
    throw 'the Windows desktop cookie extractor is missing'
  }
  $script:Python = Get-PythonCommand
  $cookiePath = Join-Path $temporaryDirectory 'session-cookies.json'
  $summary = $null

  $cookieSource = if ($webLoginRequested) { 'browser' } else { 'desktop' }
  $credentialSource = if ($webLoginRequested) { 'browser' } else { 'desktop-app' }

  if ($desktopLoginRequested) {
    Start-ChatGptDesktopApp
  }
  if ($webLoginRequested) {
    Start-ChatGptWebLogin
  }

  $deadline = (Get-Date).AddSeconds([Math]::Min(1800, [Math]::Max(30, $WaitSeconds)))
  do {
    $summary = Get-SessionCookieSummary $authPath $cookiePath $cookieSource
    if ($summary) { break }
    if (-not ($desktopLoginRequested -or $webLoginRequested) -or (Get-Date) -ge $deadline) {
      throw "the ChatGPT $cookieSource session is unavailable or belongs to a different account; sign in and retry"
    }
    Start-Sleep -Seconds 3
  } while ($true)

  $stage = 'upload'
  Set-GitHubSecretFromFile 'CHATGPT_CODEX_AUTH_B64' $authPath
  Set-GitHubSecretFromFile 'CHATGPT_SESSION_COOKIES_B64' $cookiePath
  $uploadedSecrets = @('CHATGPT_CODEX_AUTH_B64', 'CHATGPT_SESSION_COOKIES_B64')

  if ($Start) {
    $stage = 'state'
    $stateCandidates = @(
      $env:CHATGPT_AUTO_CONFIRM_QUEUE_STATE,
      (Join-Path $env:LOCALAPPDATA 'Mahayana\plugins\chatgpt-auto-confirm\queue-state.json'),
      (Join-Path $env:APPDATA 'Mahayana\plugins\chatgpt-auto-confirm\queue-state.json')
    ) | Where-Object { $_ }
    $statePath = $stateCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $statePath) { throw 'start was requested but the local queue-state.json was not found' }
    $node = Get-Command node.exe -ErrorAction SilentlyContinue
    if (-not $node) { $node = Get-Command node -ErrorAction SilentlyContinue }
    if (-not $node) { throw 'Node.js was not found; it is required to export the Action queue state' }
    $env:CHATGPT_AUTO_CONFIRM_QUEUE_STATE = $statePath
    $initialState = [string]::Join('', @(& $node.Source (Join-Path $scriptDirectory 'export-action-state.mjs')))
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($initialState)) { throw 'the local Action queue state could not be exported' }
    if ($initialState.Length -ge 47000) { throw 'the Action queue state exceeds the GitHub secret size budget' }
    Set-GitHubSecretFromValue 'CHATGPT_AUTO_CONFIRM_INITIAL_STATE_B64' $initialState
    $uploadedSecrets += 'CHATGPT_AUTO_CONFIRM_INITIAL_STATE_B64'

    $stage = 'state_key'
    $secretNames = @(& $script:GitHubCli.Source secret list --repo $Repository --json name --jq '.[].name')
    if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI could not list repository secrets' }
    if ($secretNames -notcontains 'CHATGPT_AUTO_CONFIRM_STATE_KEY') {
      $keyBytes = New-RandomBytes 48
      Set-GitHubSecretFromValue 'CHATGPT_AUTO_CONFIRM_STATE_KEY' ([Convert]::ToBase64String($keyBytes))
      $uploadedSecrets += 'CHATGPT_AUTO_CONFIRM_STATE_KEY'
    }

    $stage = 'dispatch'
    & $script:GitHubCli.Source workflow run chatgpt-auto-confirm-runner.yml --repo $Repository --ref main | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI could not dispatch the Action runner' }
  }

  $result = [ordered]@{
    ok = $true
    credentialsSynchronized = $true
    cookieCount = [int]$summary.cookieCount
    credentialSource = $credentialSource
    browserSources = @($summary.browserSources)
    accountVerified = [bool]$summary.accountVerified
    repository = $Repository
    secretsUploaded = $uploadedSecrets
    started = [bool]$Start
  }
} catch {
  $exitCode = 1
  $failureDetail = if ($_.Exception -and $_.Exception.Message) { [string]$_.Exception.Message } else { 'unknown failure' }
  $failureLine = [int]$_.InvocationInfo.ScriptLineNumber
  $messages = @{
    preflight = 'Windows desktop credential sync preflight failed'
    auth = 'the local Codex credential file is unavailable'
    cookie_extract = 'no verified same-account ChatGPT browser or desktop session was found'
    upload = 'GitHub Secrets upload failed'
    state = 'the local Action queue state is unavailable'
    state_key = 'the GitHub Action state key could not be prepared'
    dispatch = 'the GitHub Action runner could not be started'
  }
  $result = [ordered]@{
    ok = $false
    errorCode = "windows_credential_sync_$stage"
    message = if ($messages[$stage]) { $messages[$stage] } else { 'Windows desktop credential sync failed' }
    detail = $failureDetail
    line = $failureLine
  }
} finally {
  if (Test-Path -LiteralPath $temporaryDirectory) {
    Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
  }
}

[Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 5))
exit $exitCode
