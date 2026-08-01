[CmdletBinding()]
param(
  [string]$Repository = $(if ($env:CHATGPT_AUTO_CONFIRM_REPOSITORY) { $env:CHATGPT_AUTO_CONFIRM_REPOSITORY } else { 'bhrumom/fabushi' }),
  [int]$WaitSeconds = 600,
  [switch]$OpenLogin,
  # Compatibility aliases. All login switches use the browser-only OAuth flow.
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
$browserProcess = $null
$callbackListener = $null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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

function Find-BrowserExecutable {
  $candidates = @()
  foreach ($commandName in @('msedge.exe', 'chrome.exe')) {
    $command = Get-Command $commandName -ErrorAction SilentlyContinue
    if ($command) { $candidates += $command.Source }
  }
  if ($env:ProgramFiles) {
    $candidates += Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'
    $candidates += Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'
  }
  if (${env:ProgramFiles(x86)}) {
    $candidates += Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'
    $candidates += Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'
  }
  if ($env:LOCALAPPDATA) {
    $candidates += Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\Application\msedge.exe'
    $candidates += Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe'
  }
  $browser = $candidates |
    Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
    Select-Object -First 1
  if (-not $browser) {
    throw 'Microsoft Edge or Google Chrome is required for the browser-only login flow'
  }
  return $browser
}

function Get-FreeTcpPort {
  $probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
  try {
    $probe.Start()
    return ([System.Net.IPEndPoint]$probe.LocalEndpoint).Port
  } finally {
    $probe.Stop()
  }
}

function New-LoopbackCallbackListener {
  foreach ($port in @(1455, 1457)) {
    # Chrome on Windows resolves localhost to IPv4 for this callback. Keep the
    # listener loopback-only while matching the OAuth redirect URI allow-list.
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)
    try {
      $listener.Start()
      return [pscustomobject]@{ Listener = $listener; Port = $port }
    } catch {
      $listener.Stop()
    }
  }
  throw 'the local OAuth callback ports 1455 and 1457 are unavailable'
}

function ConvertTo-UrlValue([string]$value) {
  return [Uri]::EscapeDataString([string]$value)
}

function ConvertTo-Base64Url([byte[]]$bytes) {
  return ([Convert]::ToBase64String($bytes) -replace '\+', '-' -replace '/', '_').TrimEnd('=')
}

function New-RandomBytes([int]$length) {
  $bytes = New-Object byte[] $length
  $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $generator.GetBytes($bytes)
  } finally {
    $generator.Dispose()
  }
  return $bytes
}

function New-PkceValue {
  $verifier = ConvertTo-Base64Url (New-RandomBytes 32)
  $hasher = [Security.Cryptography.SHA256]::Create()
  try {
    $hash = $hasher.ComputeHash([Text.Encoding]::ASCII.GetBytes($verifier))
  } finally {
    $hasher.Dispose()
  }
  return [pscustomobject]@{
    Verifier = $verifier
    Challenge = ConvertTo-Base64Url $hash
  }
}

function New-StateValue {
  return ConvertTo-Base64Url (New-RandomBytes 32)
}

function New-CodexAuthorizeUrl([string]$redirectUri, [string]$state, $pkce) {
  $query = @(
    'response_type=code',
    ('client_id=' + (ConvertTo-UrlValue 'app_EMoamEEZ73f0CkXaXp7hrann')),
    ('redirect_uri=' + (ConvertTo-UrlValue $redirectUri)),
    ('scope=' + (ConvertTo-UrlValue 'openid profile email offline_access api.connectors.read api.connectors.invoke')),
    ('code_challenge=' + (ConvertTo-UrlValue $pkce.Challenge)),
    'code_challenge_method=S256',
    'id_token_add_organizations=true',
    'codex_cli_simplified_flow=true',
    ('state=' + (ConvertTo-UrlValue $state)),
    ('originator=' + (ConvertTo-UrlValue 'codex_cli_rs'))
  ) -join '&'
  return 'https://auth.openai.com/oauth/authorize?' + $query
}

function Get-QueryParameters([string]$query) {
  $parameters = @{}
  foreach ($part in $query.TrimStart('?').Split('&')) {
    if ([string]::IsNullOrWhiteSpace($part)) { continue }
    $pair = $part.Split('=', 2)
    $key = [Uri]::UnescapeDataString(($pair[0] -replace '\+', ' '))
    $value = if ($pair.Count -gt 1) {
      [Uri]::UnescapeDataString(($pair[1] -replace '\+', ' '))
    } else { '' }
    $parameters[$key] = $value
  }
  return $parameters
}

function Send-CallbackResponse($client, [int]$statusCode, [string]$statusText, [string]$body) {
  $bytes = [Text.Encoding]::UTF8.GetBytes($body)
  $headers = "HTTP/1.1 $statusCode $statusText`r`nContent-Type: text/html; charset=utf-8`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
  $headerBytes = [Text.Encoding]::ASCII.GetBytes($headers)
  $stream = $client.GetStream()
  $stream.Write($headerBytes, 0, $headerBytes.Length)
  $stream.Write($bytes, 0, $bytes.Length)
  $stream.Flush()
}

function Wait-ForOAuthCallback($listener, [string]$expectedState, [datetime]$deadline) {
  while ((Get-Date) -lt $deadline) {
    if (-not $listener.Pending()) {
      Start-Sleep -Milliseconds 200
      continue
    }
    $client = $listener.AcceptTcpClient()
    try {
      $reader = [IO.StreamReader]::new($client.GetStream(), [Text.Encoding]::ASCII, $false, 4096, $true)
      $requestLine = $reader.ReadLine()
      while ($null -ne ($header = $reader.ReadLine()) -and $header -ne '') { }
      $parts = if ($requestLine) { $requestLine.Split(' ') } else { @() }
      if ($parts.Count -lt 2) {
        Send-CallbackResponse $client 400 'Bad Request' '<h1>Login callback was invalid.</h1>'
        continue
      }
      $requestUri = [Uri]::new('http://localhost' + $parts[1])
      if ($requestUri.AbsolutePath -ne '/auth/callback') {
        Send-CallbackResponse $client 404 'Not Found' '<h1>Waiting for the ChatGPT login callback.</h1>'
        continue
      }
      $parameters = Get-QueryParameters $requestUri.Query
      if ($parameters['state'] -ne $expectedState) {
        Send-CallbackResponse $client 400 'Bad Request' '<h1>Login state validation failed.</h1>'
        throw 'the OAuth callback state did not match'
      }
      if ($parameters['error']) {
        Send-CallbackResponse $client 400 'Bad Request' '<h1>ChatGPT login was cancelled or rejected.</h1>'
        throw 'ChatGPT login was cancelled or rejected'
      }
      if ([string]::IsNullOrWhiteSpace($parameters['code'])) {
        Send-CallbackResponse $client 400 'Bad Request' '<h1>ChatGPT did not return an authorization code.</h1>'
        throw 'ChatGPT did not return an authorization code'
      }
      Send-CallbackResponse $client 200 'OK' '<h1>Login received. You can close this tab.</h1>'
      return $parameters['code']
    } finally {
      $client.Close()
    }
  }
  throw 'the browser login timed out before the OAuth callback arrived'
}

function Invoke-CodexTokenExchange([string]$code, [string]$redirectUri, [string]$verifier) {
  $body = @(
    'grant_type=authorization_code',
    ('code=' + (ConvertTo-UrlValue $code)),
    ('redirect_uri=' + (ConvertTo-UrlValue $redirectUri)),
    ('client_id=' + (ConvertTo-UrlValue 'app_EMoamEEZ73f0CkXaXp7hrann')),
    ('code_verifier=' + (ConvertTo-UrlValue $verifier))
  ) -join '&'
  try {
    return Invoke-RestMethod -Uri 'https://auth.openai.com/oauth/token' -Method Post `
      -ContentType 'application/x-www-form-urlencoded' -Body $body -Headers @{ Accept = 'application/json' }
  } catch {
    throw 'the OAuth authorization code could not be exchanged for Codex credentials'
  }
}

function Get-AuthIdentity([string]$idToken) {
  $parts = $idToken.Split('.')
  if ($parts.Count -lt 2) { throw 'the OAuth id token is incomplete' }
  $payloadPart = $parts[1].Replace('-', '+').Replace('_', '/')
  while (($payloadPart.Length % 4) -ne 0) { $payloadPart += '=' }
  $payload = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payloadPart)) | ConvertFrom-Json
  $claims = $payload.'https://api.openai.com/auth'
  $accountId = [string]$claims.chatgpt_account_id
  $userId = [string]$claims.chatgpt_user_id
  if ([string]::IsNullOrWhiteSpace($accountId) -or [string]::IsNullOrWhiteSpace($userId)) {
    throw 'the OAuth id token does not contain a complete ChatGPT identity'
  }
  return [pscustomobject]@{ AccountId = $accountId; UserId = $userId }
}

function Write-TemporaryAuthBundle([string]$path, $tokens) {
  if ([string]::IsNullOrWhiteSpace([string]$tokens.id_token) -or
      [string]::IsNullOrWhiteSpace([string]$tokens.access_token) -or
      [string]::IsNullOrWhiteSpace([string]$tokens.refresh_token)) {
    throw 'the OAuth response did not contain the complete Codex credential bundle'
  }
  $identity = Get-AuthIdentity ([string]$tokens.id_token)
  $bundle = [ordered]@{
    auth_mode = 'chatgpt'
    OPENAI_API_KEY = $null
    tokens = [ordered]@{
      id_token = [string]$tokens.id_token
      access_token = [string]$tokens.access_token
      refresh_token = [string]$tokens.refresh_token
      account_id = $identity.AccountId
    }
    last_refresh = [DateTime]::UtcNow.ToString('o')
  }
  $json = $bundle | ConvertTo-Json -Compress -Depth 6
  [IO.File]::WriteAllText($path, $json, [Text.UTF8Encoding]::new($false))
  return $identity
}

try {
  New-Item -ItemType Directory -Path $temporaryDirectory -Force | Out-Null

  $script:GitHubCli = (Get-Command gh.exe -ErrorAction SilentlyContinue)
  if (-not $script:GitHubCli) { $script:GitHubCli = (Get-Command gh -ErrorAction SilentlyContinue) }
  if (-not $script:GitHubCli) { throw 'GitHub CLI (gh) was not found; install it and run gh auth login first' }
  & $script:GitHubCli.Source auth status *> $null
  if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI is not authenticated; run gh auth login first' }

  $browserLoginRequested = $OpenLogin -or $DesktopLogin -or $WebLogin
  if ((@($OpenLogin, $DesktopLogin, $WebLogin) | Where-Object { $_ }).Count -gt 1) {
    throw 'browser login was requested more than once'
  }

  $localAuthPath = if ($env:CHATGPT_CODEX_AUTH_PATH) {
    $env:CHATGPT_CODEX_AUTH_PATH
  } else {
    Join-Path $env:USERPROFILE '.codex\auth.json'
  }
  $authPath = $localAuthPath
  $cookiePath = Join-Path $temporaryDirectory 'session-cookies.json'
  $summary = $null

  if ($browserLoginRequested) {
    $stage = 'browser_login'
    $isolatedBrowserProfile = Join-Path $temporaryDirectory 'browser-profile'
    $isolatedCodexHome = Join-Path $temporaryDirectory 'codex-home'
    $authPath = Join-Path $isolatedCodexHome 'auth.json'
    New-Item -ItemType Directory -Path $isolatedBrowserProfile, $isolatedCodexHome -Force | Out-Null

    $callback = New-LoopbackCallbackListener
    $callbackListener = $callback.Listener
    $redirectUri = 'http://localhost:' + $callback.Port + '/auth/callback'
    $state = New-StateValue
    $pkce = New-PkceValue
    $authorizeUrl = New-CodexAuthorizeUrl $redirectUri $state $pkce
    # This is the browser URL used by the desktop app. The app normally creates
    # authorizeUrl through app-server; the browser-only command creates the same
    # PKCE URL locally and uses the same desktop-auth handoff page.
    $loginUrl = 'https://chatgpt.com/codex/desktop-auth?authorize_url=' + (ConvertTo-UrlValue $authorizeUrl)
    $debugPort = Get-FreeTcpPort
    $browserPath = Find-BrowserExecutable
    $browserArguments = @(
      ('--user-data-dir="' + $isolatedBrowserProfile + '"'),
      ('--remote-debugging-port=' + $debugPort),
      '--remote-allow-origins=*',
      '--no-first-run',
      '--no-default-browser-check',
      $loginUrl
    )
    $browserProcess = Start-Process -FilePath $browserPath -ArgumentList $browserArguments -PassThru
    $deadline = (Get-Date).AddSeconds([Math]::Min(1800, [Math]::Max(30, $WaitSeconds)))
    $authorizationCode = Wait-ForOAuthCallback $callbackListener $state $deadline
    $tokens = Invoke-CodexTokenExchange $authorizationCode $redirectUri $pkce.Verifier
    $identity = Write-TemporaryAuthBundle $authPath $tokens
    $callbackListener.Stop()
    $callbackListener = $null

    $stage = 'browser_cookie_extract'
    $node = Get-Command node.exe -ErrorAction SilentlyContinue
    if (-not $node) { $node = Get-Command node -ErrorAction SilentlyContinue }
    if (-not $node) { throw 'Node.js was not found; it is required to capture the temporary browser session' }
    $captureScript = Join-Path $scriptDirectory 'capture-browser-chatgpt-cookies.mjs'
    $captureOutput = @(& $node.Source $captureScript '--port' $debugPort '--output' $cookiePath '--auth' $authPath 2>&1)
    $captureExitCode = $LASTEXITCODE
    $summaryLine = ($captureOutput | ForEach-Object { [string]$_ } | Where-Object { $_ -match '^\{' } | Select-Object -Last 1)
    if ($captureExitCode -ne 0 -or -not $summaryLine -or -not (Test-Path -LiteralPath $cookiePath -PathType Leaf)) {
      throw 'the temporary browser ChatGPT session could not be captured and verified'
    }
    $summary = $summaryLine | ConvertFrom-Json
    if (-not $summary.ok -or -not $summary.accountVerified -or [int]$summary.cookieCount -le 0) {
      throw 'the temporary browser ChatGPT session could not be verified for the same account'
    }
  } else {
    if (-not (Test-Path -LiteralPath $authPath -PathType Leaf)) {
      $stage = 'auth'
      throw 'the local Codex auth.json was not found'
    }
    if ((Get-Item -LiteralPath $authPath).Length -eq 0) {
      $stage = 'auth'
      throw 'the local Codex auth.json is empty'
    }
    $stage = 'cookie_extract'
    $helperPath = Join-Path $scriptDirectory 'extract-windows-chatgpt-cookies.py'
    $python = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($python) {
      $pythonPrefix = @('-3', $helperPath)
    } else {
      $python = Get-Command python.exe -ErrorAction SilentlyContinue
      if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue }
      if (-not $python) { throw 'Python 3 was not found; install Python, pywin32, and pycryptodome for browser credential extraction' }
      $pythonPrefix = @($helperPath)
    }
    $pythonArguments = $pythonPrefix + @(
      '--output', $cookiePath,
      '--auth', $authPath,
      '--source', 'auto',
      '--verify-account'
    )
    $extractOutput = @(& $python.Source @pythonArguments 2>&1)
    $summaryLine = ($extractOutput | ForEach-Object { [string]$_ } | Where-Object { $_ -match '^\{' } | Select-Object -Last 1)
    if ($LASTEXITCODE -ne 0 -or -not $summaryLine -or -not (Test-Path -LiteralPath $cookiePath -PathType Leaf)) {
      throw 'no usable same-account ChatGPT browser session was found'
    }
    $summary = $summaryLine | ConvertFrom-Json
    if (-not $summary.ok -or -not $summary.accountVerified -or [int]$summary.cookieCount -le 0) {
      throw 'no usable same-account ChatGPT browser session was found'
    }
  }

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
    browser_login = 'the browser-only ChatGPT login flow could not be completed'
    browser_cookie_extract = 'the temporary browser ChatGPT session could not be captured or verified'
    cookie_extract = 'no usable same-account ChatGPT browser session was found'
    upload = 'GitHub Secrets upload failed'
    state = 'the local Action queue state is unavailable'
    state_key = 'the GitHub Action state key could not be prepared'
    dispatch = 'the GitHub Action runner could not be started'
  }
  $result = [ordered]@{
    ok = $false
    errorCode = "windows_credential_sync_$stage"
    message = if ($messages[$stage]) { $messages[$stage] } else { 'Windows credential sync failed' }
  }
} finally {
  if ($callbackListener) {
    try { $callbackListener.Stop() } catch {}
  }
  if ($browserProcess -and -not $browserProcess.HasExited) {
    & taskkill.exe /PID $browserProcess.Id /T /F *> $null
  }
  if (Test-Path -LiteralPath $temporaryDirectory) {
    Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
  }
}

[Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 5))
exit $exitCode
