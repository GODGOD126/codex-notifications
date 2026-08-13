[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $RequestDirectory,
    [switch] $Wait,
    [switch] $PassThru
)

. (Join-Path $PSScriptRoot 'common.ps1')

$resolvedDirectory = (Resolve-Path -LiteralPath $RequestDirectory).Path
$dialogScript = Join-Path $resolvedDirectory 'dialog.ps1'
$requestPath = Join-Path $resolvedDirectory 'request.json'
$resultPath = Join-Path $resolvedDirectory 'result.json'
if (-not (Test-Path -LiteralPath $dialogScript)) { throw "Dialog script missing: $dialogScript" }
if (-not (Test-Path -LiteralPath $requestPath)) { throw "Request file missing: $requestPath" }

$settings = Get-CodexNotificationsSettings
if (-not $settings.enabled) {
    [pscustomobject]@{ started = $false; reason = 'disabled'; requestDirectory = $resolvedDirectory } | ConvertTo-Json
    exit 0
}

$executable = Resolve-CodexNotificationsPowerShell
$arguments = @('-NoProfile')
if ([IO.Path]::GetFileName($executable) -ieq 'powershell.exe') { $arguments += @('-ExecutionPolicy', 'Bypass') }
$arguments += @('-STA', '-File', ('"{0}"' -f $dialogScript), '-RequestPath', ('"{0}"' -f $requestPath), '-ResultPath', ('"{0}"' -f $resultPath))

$process = Start-Process -FilePath $executable -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait:$Wait
$payload = [pscustomobject]@{
    started = $true
    processId = $process.Id
    requestDirectory = $resolvedDirectory
    resultPath = $resultPath
}
if ($PassThru) { return $process }
$payload | ConvertTo-Json
