Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CodexNotificationsStateRoot {
    if ($env:LOCALAPPDATA) {
        return (Join-Path $env:LOCALAPPDATA 'CodexNotifications')
    }
    return (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'CodexNotifications')
}

function Get-CodexNotificationsSettingsPath {
    return (Join-Path (Get-CodexNotificationsStateRoot) 'settings.json')
}

function Get-CodexNotificationsDefaultSettings {
    return [ordered]@{
        enabled = $true
        durationSeconds = 30
        soundEnabled = $true
        forceForeground = $true
        waitTimeoutSeconds = 1800
        minimumWaitSeconds = 1260
    }
}

function Write-AtomicUtf8Json {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] $Value,
        [int] $Depth = 10
    )

    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temporary = "$Path.$PID.tmp"
    $json = $Value | ConvertTo-Json -Depth $Depth
    [IO.File]::WriteAllText($temporary, $json, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Get-CodexNotificationsSettings {
    $defaults = Get-CodexNotificationsDefaultSettings
    $path = Get-CodexNotificationsSettingsPath
    if (-not (Test-Path -LiteralPath $path)) { return [pscustomobject]$defaults }

    try {
        $stored = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($key in @($defaults.Keys)) {
            if ($null -ne $stored.PSObject.Properties[$key]) { $defaults[$key] = $stored.$key }
        }
    } catch {
        # Invalid local settings fall back to safe defaults.
    }
    return [pscustomobject]$defaults
}

function Save-CodexNotificationsSettings {
    param([Parameter(Mandatory)] $Settings)
    Write-AtomicUtf8Json -Path (Get-CodexNotificationsSettingsPath) -Value $Settings
}

function Get-CodexNotificationsRequestRoot {
    $path = Join-Path (Get-CodexNotificationsStateRoot) 'requests'
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Resolve-CodexNotificationsPowerShell {
    $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if ($pwsh) { return $pwsh.Source }
    $powershell = Get-Command powershell.exe -ErrorAction Stop
    return $powershell.Source
}
