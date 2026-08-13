[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'common.ps1')
$executable = Resolve-CodexNotificationsPowerShell
$settingsScript = Join-Path $PSScriptRoot '..\src\settings-window.ps1'
$arguments = @('-NoProfile')
if ([IO.Path]::GetFileName($executable) -ieq 'powershell.exe') { $arguments += @('-ExecutionPolicy', 'Bypass') }
$arguments += @('-STA', '-File', ('"{0}"' -f $settingsScript))
Start-Process -FilePath $executable -ArgumentList $arguments -WindowStyle Hidden | Out-Null
