[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $InstallRoot = (Join-Path $env:USERPROFILE '.codex\skills'),
    [switch] $KeepSettings
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$targetRoot = Join-Path $InstallRoot 'codex-notifications'
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Codex 提醒设置.lnk'
$stateRoot = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'CodexNotifications' } else { Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'CodexNotifications' }

if ((Test-Path -LiteralPath $shortcutPath) -and $PSCmdlet.ShouldProcess($shortcutPath, 'Remove shortcut')) { Remove-Item -LiteralPath $shortcutPath -Force }
if ((Test-Path -LiteralPath $targetRoot) -and $PSCmdlet.ShouldProcess($targetRoot, 'Remove installed skill')) { Remove-Item -LiteralPath $targetRoot -Recurse -Force }
if (-not $KeepSettings -and (Test-Path -LiteralPath $stateRoot) -and $PSCmdlet.ShouldProcess($stateRoot, 'Remove local settings and requests')) { Remove-Item -LiteralPath $stateRoot -Recurse -Force }

[pscustomobject]@{ uninstalled=$true; hooksChanged=$false; codexConfigModified=$false } | ConvertTo-Json
