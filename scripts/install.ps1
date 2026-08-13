[CmdletBinding()]
param(
    [string] $InstallRoot = (Join-Path $env:USERPROFILE '.codex\skills'),
    [switch] $NoDesktopShortcut
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$targetRoot = Join-Path $InstallRoot 'codex-notifications'
New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null

if ((Test-Path -LiteralPath $targetRoot) -and ((Resolve-Path -LiteralPath $targetRoot).Path -ne $sourceRoot)) {
    $stateRoot = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'CodexNotifications' } else { Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'CodexNotifications' }
    $backupRoot = Join-Path $stateRoot 'install-backups'
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $backup = Join-Path $backupRoot ('codex-notifications-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Move-Item -LiteralPath $targetRoot -Destination $backup
}

if ($targetRoot -ne $sourceRoot) {
    New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
    foreach ($name in @('SKILL.md', 'README.md', 'agents', 'assets', 'references', 'scripts', 'src')) {
        $source = Join-Path $sourceRoot $name
        if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination $targetRoot -Recurse -Force }
    }
}

. (Join-Path $targetRoot 'scripts\common.ps1')
if (-not (Test-Path -LiteralPath (Get-CodexNotificationsSettingsPath))) {
    Save-CodexNotificationsSettings (Get-CodexNotificationsDefaultSettings)
}

$shortcutPath = $null
if (-not $NoDesktopShortcut) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktop 'Codex 提醒设置.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $powershell = Resolve-CodexNotificationsPowerShell
    $shortcut.TargetPath = $powershell
    $shortcut.Arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f (Join-Path $targetRoot 'scripts\open-settings.ps1')
    $shortcut.WorkingDirectory = $targetRoot
    $shortcut.Description = '打开 Codex 介入提醒设置'
    $shortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll,221"
    $shortcut.Save()
}

[pscustomobject]@{
    installed = $true
    skillPath = $targetRoot
    settingsPath = Get-CodexNotificationsSettingsPath
    desktopShortcut = $shortcutPath
    hooksInstalled = $false
    codexConfigModified = $false
} | ConvertTo-Json -Depth 5
