[CmdletBinding()]
param(
    [string] $Title = '需要你介入',
    [string] $Message = '当前步骤需要你的操作，Codex 正在等待。',
    [string] $Status = '任务已暂停 · 等待用户',
    [string] $ButtonText = '我已完成，继续',
    [string[]] $Options = @(),
    [ValidateRange(-1, 86400)] [int] $DurationSeconds = -1,
    [string] $RequestId,
    [switch] $NoSound
)

. (Join-Path $PSScriptRoot 'common.ps1')

if ($Title.Length -gt 32) { throw 'Title must be 32 characters or fewer. Rewrite it more concisely.' }
if ($Message.Length -gt 120) { throw 'Message must be 120 characters or fewer. Keep detailed background in the Codex conversation.' }
if ($Options.Count -ne 0 -and ($Options.Count -lt 2 -or $Options.Count -gt 4)) { throw 'Options must contain 2 to 4 choices, or be empty for a simple action request.' }
$normalizedOptions = @()
foreach ($option in $Options) {
    $trimmed = [string]$option
    $trimmed = $trimmed.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { throw 'Options cannot contain empty text.' }
    if ($trimmed.Length -gt 14) { throw 'Each option must be 14 characters or fewer.' }
    if ($normalizedOptions -contains $trimmed) { throw 'Options must be unique.' }
    $normalizedOptions += $trimmed
}

$settings = Get-CodexNotificationsSettings
if ($DurationSeconds -lt 0) {
    $DurationSeconds = [int]$settings.durationSeconds
}
if ([string]::IsNullOrWhiteSpace($RequestId)) {
    $RequestId = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), ([Guid]::NewGuid().ToString('N').Substring(0, 8))
}
if ($RequestId -notmatch '^[A-Za-z0-9_-]+$') { throw 'RequestId may contain only letters, digits, underscore, and hyphen.' }

$requestDirectory = Join-Path (Get-CodexNotificationsRequestRoot) $RequestId
if (Test-Path -LiteralPath $requestDirectory) { throw "Request already exists: $requestDirectory" }
New-Item -ItemType Directory -Path $requestDirectory | Out-Null

$dialogScript = Join-Path $requestDirectory 'dialog.ps1'
$resultPath = Join-Path $requestDirectory 'result.json'
$requestPath = Join-Path $requestDirectory 'request.json'
$texturePath = Join-Path $requestDirectory 'paper-texture.png'

Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\src\warm-paper-dialog.ps1') -Destination $dialogScript
$sourceTexture = Join-Path $PSScriptRoot '..\assets\warm-paper-texture.png'
if (Test-Path -LiteralPath $sourceTexture) { Copy-Item -LiteralPath $sourceTexture -Destination $texturePath }

$request = [ordered]@{
    requestId = $RequestId
    title = $Title
    message = $Message
    status = $Status
    buttonText = $ButtonText
    options = $normalizedOptions
    durationSeconds = $DurationSeconds
    soundEnabled = [bool]($settings.soundEnabled -and -not $NoSound)
    forceForeground = [bool]$settings.forceForeground
    createdAt = [DateTimeOffset]::Now.ToString('o')
    resultPath = $resultPath
}
Write-AtomicUtf8Json -Path $requestPath -Value $request

[pscustomobject]@{
    requestId = $RequestId
    requestDirectory = $requestDirectory
    dialogScript = $dialogScript
    requestPath = $requestPath
    resultPath = $resultPath
    texturePath = $texturePath
} | ConvertTo-Json -Depth 5
