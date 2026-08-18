[CmdletBinding()]
param(
    [string] $InstallRoot = (Join-Path $env:USERPROFILE '.codex\skills'),
    [switch] $NoDesktopShortcut
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$customInstructionsZh = '当任务必须由用户本人介入才能继续时，例如登录、扫码、验证码、授权、提供用户专属信息或完成必须人工操作和必须要用户来确认的步骤，请调用 $codex-notifications 弹窗提醒用户。普通进度、可自行解决的错误和任务完成不要提醒。调用后不得结束当前任务；必须按 Skill 规则持续等待用户回应，若用户没有回应，至少等待20分钟，期间不能停止对话，收到有效结果后再继续原任务。执行非必要不打扰原则。'
$customInstructionsEn = 'When a task cannot continue without the user''s direct intervention, such as signing in, scanning a QR code, completing a CAPTCHA, granting authorization, providing user-only information, performing a required manual action, or confirming a required decision, invoke $codex-notifications to alert the user with a popup. Do not notify for ordinary progress, recoverable errors, or task completion. After invoking it, do not end the current task; follow the Skill instructions and keep waiting for the user''s response. If the user does not respond, wait at least 20 minutes without ending the conversation, and continue the original task only after receiving a valid response. Follow the principle of avoiding unnecessary interruptions.'

$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$targetRoot = Join-Path $InstallRoot 'codex-notifications'
New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null

if ((Test-Path -LiteralPath $targetRoot) -and ((Resolve-Path -LiteralPath $targetRoot).Path -ne $sourceRoot)) {
    $stateRoot = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'CodexNotifications' } else { Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'CodexNotifications' }
    $backupRoot = Join-Path $stateRoot 'install-backups'
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $backup = Join-Path $backupRoot ('codex-notifications-{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), ([Guid]::NewGuid().ToString('N').Substring(0, 8)))
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
    customInstructionsModified = $false
    codexMustTellUser = $true
    customInstructionsUiPath = [ordered]@{
        zhCN = '设置 > 个性化 > 自定义指令'
        en = 'Settings > Personalization > Custom instructions'
    }
    customInstructionsText = [ordered]@{
        zhCN = $customInstructionsZh
        en = $customInstructionsEn
    }
    postInstallMessage = [ordered]@{
        zhCN = '安装已完成。请告知用户：若希望 Codex 在每次任务中自动加载此功能，请由用户本人打开“设置 > 个性化 > 自定义指令”，粘贴返回的中文提示词并保存。安装器不会修改现有自定义指令。'
        en = 'Installation is complete. Tell the user: to make Codex load this capability for every task, open Settings > Personalization > Custom instructions, paste the returned English text, and save it. The installer does not modify existing custom instructions.'
    }
} | ConvertTo-Json -Depth 5
