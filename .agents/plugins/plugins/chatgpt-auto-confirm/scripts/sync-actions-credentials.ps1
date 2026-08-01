[CmdletBinding()]
param(
  [string]$Repository = $(if ($env:CHATGPT_AUTO_CONFIRM_REPOSITORY) { $env:CHATGPT_AUTO_CONFIRM_REPOSITORY } else { 'bhrumom/fabushi' }),
  [int]$WaitSeconds = 600,
  [switch]$OpenLogin,
  [switch]$WebLogin,
  [switch]$Start
)

$ErrorActionPreference = 'Stop'
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) ('fabushi-chatgpt-sync-' + [Guid]::NewGuid().ToString('N'))
$stage = 'preflight'
$result = $null
$exitCode = 0

function Set-GitHubSecretFromFile([string]$name, [string]$path) {
  $bytes = [IO.File]::ReadAllBytes($path)
  $encoded = [Convert]::ToBase64String($bytes)
  if ($encoded.Length -ge 47000) {
    throw "secret $name exceeds the GitHub secret size budget"
  }
  $encoded | & $script:GitHubCli.Source secret set $name --repo $Repository | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI failed to update $name"
  }
}

function Set-GitHubSecretFromValue([string]$name, [string]$value) {
  if ([string]::IsNullOrWhiteSpace($value) -or $value.Length -ge 47000) {
    throw "secret $name is empty or exceeds the GitHub secret size budget"
  }
  $value | & $script:GitHubCli.Source secret set $name --repo $Repository | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI failed to update $name"
  }
}

try {
  New-Item -ItemType Directory -Path $temporaryDirectory -Force | Out-Null

  $script:GitHubCli = (Get-Command gh.exe -ErrorAction SilentlyContinue)
  if (-not $script:GitHubCli) {
    $script:GitHubCli = (Get-Command gh -ErrorAction SilentlyContinue)
  }
  if (-not $script:GitHubCli) {
    throw 'GitHub CLI (gh) was not found; install it and run gh auth login first'
  }
  & $script:GitHubCli.Source auth status *> $null
  if ($LASTEXITCODE -ne 0) {
    throw 'GitHub CLI is not authenticated; run gh auth login first'
  }

  if ($OpenLogin -and $WebLogin) {
    throw 'desktop login and web login cannot be requested together'
  }

  $authPath = if ($env:CHATGPT_CODEX_AUTH_PATH) {
    $env:CHATGPT_CODEX_AUTH_PATH
  } else {
    Join-Path $env:USERPROFILE '.codex\auth.json'
  }
  if ($WebLogin) {
    $stage = 'web_login'
    $codex = Get-Command codex.exe -ErrorAction SilentlyContinue
    if (-not $codex) { $codex = Get-Command codex.cmd -ErrorAction SilentlyContinue }
    if (-not $codex) { $codex = Get-Command codex -ErrorAction SilentlyContinue }
    if (-not $codex) {
      $packageRoots = Get-ChildItem -LiteralPath (Join-Path $env:ProgramFiles 'WindowsApps') -Directory -Filter 'OpenAI.Codex_*' -ErrorAction SilentlyContinue
      $codex = $packageRoots |
        ForEach-Object { Get-Item -LiteralPath (Join-Path $_.FullName 'app\Codex.exe') -ErrorAction SilentlyContinue } |
        Select-Object -First 1
    }
    if (-not $codex) {
      throw 'Codex CLI was not found; install the official Codex CLI, then run this web-login command again'
    }
    $codexPath = if ($codex.Source) { $codex.Source } else { $codex.FullName }
    $loginProcess = Start-Process -FilePath $codexPath -ArgumentList @('--login') -Wait -PassThru -WindowStyle Normal
    if ($loginProcess.ExitCode -ne 0) {
      throw 'the Codex web login was cancelled or did not complete'
    }
  }

  if (-not (Test-Path -LiteralPath $authPath -PathType Leaf)) {
    $stage = 'auth'
    throw 'the local Codex auth.json was not found after login'
  }
  if ((Get-Item -LiteralPath $authPath).Length -eq 0) {
    $stage = 'auth'
    throw 'the local Codex auth.json is empty after login'
  }

  $stage = 'cookie_extract'
  $cookiePath = Join-Path $temporaryDirectory 'session-cookies.json'
  $helperPath = Join-Path $scriptDirectory 'extract-windows-chatgpt-cookies.py'
  $python = Get-Command py.exe -ErrorAction SilentlyContinue
  $cookieSource = if ($WebLogin) { 'browser' } else { 'desktop' }
  $verifyAccountArgument = if ($WebLogin) { @('--verify-account') } else { @() }
  if ($python) {
    $pythonArguments = @('-3', $helperPath, '--output', $cookiePath, '--auth', $authPath, '--source', $cookieSource) + $verifyAccountArgument
  } else {
    $python = Get-Command python.exe -ErrorAction SilentlyContinue
    if (-not $python) {
      $python = Get-Command python -ErrorAction SilentlyContinue
    }
    if (-not $python) {
      throw 'Python 3 was not found; install Python, pywin32, and pycryptodome for desktop credential extraction'
    }
    $pythonArguments = @($helperPath, '--output', $cookiePath, '--auth', $authPath, '--source', $cookieSource) + $verifyAccountArgument
  }
  if ($OpenLogin) {
    Start-Process 'shell:AppsFolder\OpenAI.Codex_2p2nqsd0c76g0!App' | Out-Null
  }
  $deadline = (Get-Date).AddSeconds([Math]::Min(1800, [Math]::Max(30, $WaitSeconds)))
  $summary = $null
  do {
    $extractOutput = @(& $python.Source @pythonArguments 2>&1)
    $summaryLine = ($extractOutput | ForEach-Object { [string]$_ } | Where-Object { $_ -match '^\{' } | Select-Object -Last 1)
    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $cookiePath -PathType Leaf) -and $summaryLine) {
      $candidate = $summaryLine | ConvertFrom-Json
      if ($candidate.ok -and [int]$candidate.cookieCount -gt 0) {
        $summary = $candidate
        break
      }
    }
    if (-not ($OpenLogin -or $WebLogin) -or (Get-Date) -ge $deadline) {
      if ($WebLogin) {
        throw 'no usable same-account ChatGPT browser session was found after web login; finish login in Edge or Chrome and retry'
      }
      throw 'no usable ChatGPT desktop session cookies were found; close the desktop app after login and retry so its locked profile can be read'
    }
    if (Test-Path -LiteralPath $cookiePath) {
      Remove-Item -LiteralPath $cookiePath -Force -ErrorAction SilentlyContinue
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
    if (-not $statePath) {
      throw 'start was requested but the local queue-state.json was not found'
    }
    $node = Get-Command node.exe -ErrorAction SilentlyContinue
    if (-not $node) { $node = Get-Command node -ErrorAction SilentlyContinue }
    if (-not $node) { throw 'Node.js was not found; it is required to export the Action queue state' }
    $env:CHATGPT_AUTO_CONFIRM_QUEUE_STATE = $statePath
    $initialState = [string]::Join('', @(& $node.Source (Join-Path $scriptDirectory 'export-action-state.mjs')))
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($initialState)) {
      throw 'the local Action queue state could not be exported'
    }
    if ($initialState.Length -ge 47000) { throw 'the Action queue state exceeds the GitHub secret size budget' }
    Set-GitHubSecretFromValue 'CHATGPT_AUTO_CONFIRM_INITIAL_STATE_B64' $initialState
    $uploadedSecrets += 'CHATGPT_AUTO_CONFIRM_INITIAL_STATE_B64'

    $stage = 'state_key'
    $secretNames = @(& $script:GitHubCli.Source secret list --repo $Repository --json name --jq '.[].name')
    if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI could not list repository secrets' }
    if ($secretNames -notcontains 'CHATGPT_AUTO_CONFIRM_STATE_KEY') {
      $keyBytes = New-Object byte[] 48
      [Security.Cryptography.RandomNumberGenerator]::Fill($keyBytes)
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
    credentialSource = [string]$summary.credentialSource
    browserSources = @($summary.browserSources)
    accountVerified = [bool]$summary.accountVerified
    repository = $Repository
    secretsUploaded = $uploadedSecrets
    started = [bool]$Start
  }
} catch {
  $exitCode = 1
  $messages = @{
    preflight = 'Windows credential sync preflight failed'
    auth = 'the local Codex credential file is unavailable'
    web_login = 'the official Codex web login could not be completed'
    cookie_extract = 'no usable ChatGPT browser session was found'
    upload = 'GitHub Secrets upload failed'
    state = 'the local Action queue state is unavailable'
    state_key = 'the GitHub Action state key could not be prepared'
    dispatch = 'the GitHub Action runner could not be started'
  }
  $result = [ordered]@{
    ok = $false
    errorCode = "windows_credential_sync_$stage"
    message = $messages[$stage]
  }
} finally {
  if (Test-Path -LiteralPath $temporaryDirectory) {
    Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
  }
}

[Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 5))
exit $exitCode
