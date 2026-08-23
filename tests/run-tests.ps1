[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$failures = [Collections.Generic.List[string]]::new()
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { $failures.Add($Message) } }

$skillText = Get-Content -LiteralPath (Join-Path $root 'SKILL.md') -Raw
Assert-True ($skillText -match 'Do not install, register, or depend on Codex Hooks') 'SKILL.md must explicitly forbid hooks.'
Assert-True ($skillText -match '1,260 seconds') 'SKILL.md must require more than 20 minutes of waiting.'
Assert-True ($skillText -match 'Edit that copied PowerShell file as freely') 'SKILL.md must permit full popup source edits.'
Assert-True ($skillText -match [regex]::Escape('我很忙，一会再说。')) 'SKILL.md must require the exact busy-button label.'
Assert-True ($skillText -match 'non-terminal `deferred`') 'SKILL.md must define deferred as non-terminal.'
Assert-True ($skillText -match '2–4 concise choices') 'SKILL.md must define the compact decision pattern.'
Assert-True ($skillText -match 'value.selectedOption') 'SKILL.md must document structured choice results.'
Assert-True ($skillText -match 'source strip') 'SKILL.md must preserve project and conversation provenance.'
Assert-True ($skillText -match 'codex_app__list_threads') 'SKILL.md must use the official Codex task list for the sidebar title.'
Assert-True ($skillText -match 'use that entry''s `title` exactly') 'SKILL.md must pass the exact sidebar task title.'
Assert-True ($skillText -match 'Do not substitute a summary, the first user message') 'SKILL.md must forbid message-derived task names.'

$dialogText = Get-Content -LiteralPath (Join-Path $root 'src\warm-paper-dialog.ps1') -Raw
Assert-True ($dialogText -match [regex]::Escape('Content="我很忙，一会再说。"')) 'Dialog must always render the exact busy-button label.'
Assert-True ($dialogText -match "Write-DialogResult -Action 'deferred'") 'Busy button must return the deferred action.'
Assert-True ($dialogText -match [regex]::Escape('你需要继续挂起，等待用户回复。')) 'Deferred result must tell Codex to remain suspended.'
Assert-True ($dialogText -match '<RowDefinition Height="46"/><RowDefinition Height="58"/>') 'Status and action buttons must use separate footer rows.'
Assert-True ($dialogText -match '<ColumnDefinition Width="\*"/><ColumnDefinition Width="12"/><ColumnDefinition Width="\*"/>') 'Footer buttons must receive equal-width columns.'
Assert-True ($dialogText -match 'Width="680" Height="560" MinWidth="600" MinHeight="500" MaxHeight="680"') 'Dialog must preserve a safe responsive size.'
Assert-True ($dialogText -match 'VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"') 'Long body content must use a bounded vertical scroller.'
Assert-True ($dialogText -match 'x:Name="MessageText"[^>]+TextWrapping="Wrap"') 'Body copy must wrap inside its content region.'
Assert-True ($dialogText -match 'x:Name="TitleText" Grid.Row="0"') 'Title must remain fixed outside the scrolling body.'
Assert-True ($dialogText -match 'TextTrimming="CharacterEllipsis" MaxHeight="72"') 'Long titles must be capped at two lines.'
Assert-True ($dialogText -match '<Style TargetType="ScrollBar">') 'Long-copy scrollbar must use the dialog visual language.'
Assert-True ($dialogText -match 'x:Name="OptionsPanel"') 'Dialog must provide a decision-options panel.'
Assert-True ($dialogText -match '<UniformGrid x:Name="OptionsPanel" Columns="2"/>') 'Decision options must use a compact two-column layout.'
Assert-True ($dialogText -match 'x:Name="ReplyInput"') 'Dialog must provide a direct-reply input.'
Assert-True ($dialogText -match 'selectedOption = \$selectedOption') 'Dialog must return the selected option.'
Assert-True ($dialogText -match 'input = if') 'Dialog must return direct input.'
Assert-True ($dialogText -match 'SetAutomationId\(\$radio') 'Decision options must expose stable automation identifiers.'
Assert-True ($dialogText -match '\$radio.Add_Checked') 'Selecting a decision option must submit immediately.'
Assert-True ($dialogText -match '\$primaryButton.Visibility = \[Windows.Visibility\]::Collapsed') 'Decision popups must hide the extra submit button.'
Assert-True ($dialogText -match '\$replyInput.Add_KeyDown') 'Text-only replies must submit on Enter.'
Assert-True ($dialogText -match 'x:Name="SendReplyButton"') 'Reply input must contain an inline send control.'
Assert-True ($dialogText -match '\$sendReplyButton.IsEnabled = -not \[string\]::IsNullOrWhiteSpace') 'Send control must enable only when input contains text.'
Assert-True ($dialogText -match '\$sendReplyButton.Add_Click') 'Inline send control must submit typed replies.'
Assert-True ($dialogText.Contains("SetAutomationId(`$sendReplyButton, 'SendReplyButton')")) 'Inline send control must expose a stable automation identifier.'
Assert-True ($dialogText -match [regex]::Escape('补充说明（输入后点箭头，或直接选项）')) 'Decision input must explain how its content is submitted.'
Assert-True ($dialogText -match 'x:Name="SourceText"') 'Dialog must display project and conversation provenance.'
Assert-True ($dialogText -match 'x:Name="MinimizeButton"') 'Dialog must provide a minimize control.'
Assert-True ($dialogText.Contains("SetAutomationId(`$minimizeButton, 'MinimizeButton')")) 'Minimize control must expose a stable automation identifier.'
Assert-True ($dialogText -match '\$window\.WindowState = \[Windows\.WindowState\]::Minimized') 'Minimize control must minimize the window.'
Assert-True ($dialogText -match 'x:Name="OpenConversationButton"') 'Source strip must provide an open-conversation control.'
Assert-True ($dialogText.Contains("SetAutomationId(`$openConversationButton, 'OpenConversationButton')")) 'Open-conversation control must expose a stable automation identifier.'
Assert-True ($dialogText -match [regex]::Escape("'codex://threads/{0}' -f [Uri]::EscapeDataString(`$threadId)")) 'Open-conversation control must use the Codex thread deep link.'
Assert-True ($dialogText -match 'Start-Process -FilePath \$threadUri') 'Open-conversation control must launch the registered Codex protocol.'
Assert-True ($dialogText -match '\$openConversationButton\.Visibility = \[Windows\.Visibility\]::Collapsed') 'Open-conversation control must be hidden without a thread id.'
$openConversationHandler = [regex]::Match($dialogText, '\$openConversationButton\.Add_Click\(\{(?<body>.*?)\}\)\r?\n\$closeButton', [Text.RegularExpressions.RegexOptions]::Singleline).Groups['body'].Value
Assert-True ($openConversationHandler -notmatch 'Write-DialogResult|\.Close\(') 'Opening a conversation must not submit a result or close the popup.'

$newDialogText = Get-Content -LiteralPath (Join-Path $root 'scripts\new-dialog.ps1') -Raw
Assert-True ($newDialogText -match '\[string\] \$ProjectName') 'Dialog factory must accept an explicit project name.'
Assert-True ($newDialogText -match '\[string\] \$ConversationName') 'Dialog factory must accept an explicit conversation name.'
Assert-True ($newDialogText -match '\[string\] \$ThreadId = \$env:CODEX_THREAD_ID') 'Dialog factory must bind the current Codex thread id.'

$commonText = Get-Content -LiteralPath (Join-Path $root 'scripts\common.ps1') -Raw
Assert-True ($commonText -match "select nullif\(name,''\) from threads where id=\?") 'Local thread lookup must use only the explicit name field.'
Assert-True ($commonText -notmatch "coalesce\(nullif\(name,''\),nullif\(title,''\),nullif\(first_user_message,''\)\)") 'Local lookup must never fall back to title or first_user_message.'
. (Join-Path $root 'scripts\common.ps1')

$waiterText = Get-Content -LiteralPath (Join-Path $root 'scripts\wait-result.ps1') -Raw
Assert-True ($waiterText -match 'ValidateRange\(1260, 86400\)') 'Waiter must enforce a minimum of 1260 seconds.'

$configPath = Join-Path $env:USERPROFILE '.codex\config.toml'
$beforeHash = if (Test-Path -LiteralPath $configPath) { (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash } else { $null }
$globalAgentsPath = Join-Path $env:USERPROFILE '.codex\AGENTS.md'
$beforeAgentsHash = if (Test-Path -LiteralPath $globalAgentsPath) { (Get-FileHash -LiteralPath $globalAgentsPath -Algorithm SHA256).Hash } else { $null }
$testInstall = Join-Path $root 'test-output\skills'
$installJson = & (Join-Path $root 'scripts\install.ps1') -InstallRoot $testInstall -NoDesktopShortcut | ConvertFrom-Json
Assert-True ($installJson.hooksInstalled -eq $false) 'Installer must report no hooks.'
Assert-True ($installJson.codexConfigModified -eq $false) 'Installer must report no Codex config mutation.'
Assert-True ($installJson.customInstructionsModified -eq $false) 'Installer must not modify custom instructions.'
Assert-True ($installJson.codexMustTellUser -eq $true) 'Codex-assisted installs must require a user-facing custom-instructions handoff.'
Assert-True ($installJson.customInstructionsUiPath.zhCN -eq '设置 > 个性化 > 自定义指令') 'Installer must return the Chinese custom-instructions path.'
Assert-True ($installJson.customInstructionsUiPath.en -eq 'Settings > Personalization > Custom instructions') 'Installer must return the English custom-instructions path.'
$expectedCustomInstructionsZh = '当任务必须由用户本人介入才能继续时，例如登录、扫码、验证码、授权、提供用户专属信息或完成必须人工操作和必须要用户来确认的步骤，请调用 $codex-notifications 弹窗提醒用户。普通进度、可自行解决的错误和任务完成不要提醒。调用后不得结束当前任务；必须按 Skill 规则持续等待用户回应，若用户没有回应，至少等待20分钟，期间不能停止对话，收到有效结果后再继续原任务。执行非必要不打扰原则。'
Assert-True ($installJson.customInstructionsText.zhCN -ceq $expectedCustomInstructionsZh) 'Installer must return the exact approved Chinese custom instructions.'
Assert-True ($installJson.customInstructionsText.en -match 'wait at least 20 minutes') 'Installer must return equivalent English custom instructions.'
$afterHash = if (Test-Path -LiteralPath $configPath) { (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash } else { $null }
$afterAgentsHash = if (Test-Path -LiteralPath $globalAgentsPath) { (Get-FileHash -LiteralPath $globalAgentsPath -Algorithm SHA256).Hash } else { $null }
Assert-True ($beforeHash -eq $afterHash) 'Installer changed Codex config.toml.'
Assert-True ($beforeAgentsHash -eq $afterAgentsHash) 'Installer changed the user global AGENTS.md.'
Assert-True (Test-Path -LiteralPath (Join-Path $testInstall 'codex-notifications\SKILL.md')) 'Installed SKILL.md is missing.'
Assert-True (Test-Path -LiteralPath (Join-Path $testInstall 'codex-notifications\scripts\open-settings.ps1')) 'Installed settings launcher is missing.'
Assert-True (Test-Path -LiteralPath (Join-Path $testInstall 'codex-notifications\src\settings-window.ps1')) 'Installed settings window is missing.'
Assert-True (Test-Path -LiteralPath $installJson.settingsPath) 'Installer did not create settings.json.'

$created = & (Join-Path $root 'scripts\new-dialog.ps1') -Title '测试标题' -Message '测试正文' -Options @('选项一', '选项二') -ProjectName '测试项目' -ConversationName '测试会话' -ThreadId 'thread-test-001' -DurationSeconds 2 -RequestId ('test-' + [Guid]::NewGuid().ToString('N').Substring(0,8)) -NoSound | ConvertFrom-Json
Assert-True (Test-Path -LiteralPath $created.dialogScript) 'Dynamic dialog copy was not created.'
Assert-True (Test-Path -LiteralPath $created.requestPath) 'Request JSON was not created.'
$request = Get-Content -LiteralPath $created.requestPath -Raw | ConvertFrom-Json
Assert-True ($request.title -eq '测试标题') 'Request title did not round-trip.'
Assert-True (@($request.options).Count -eq 2) 'Request options did not round-trip.'
Assert-True ($request.options[1] -eq '选项二') 'Request option text changed.'
Assert-True ($request.projectName -eq '测试项目') 'Request project name did not round-trip.'
Assert-True ($request.conversationName -eq '测试会话') 'Request conversation name did not round-trip.'
Assert-True ($request.threadId -eq 'thread-test-001') 'Request thread id did not round-trip.'
Assert-True ($request.sourceLabel -eq '测试项目  ·  测试会话') 'Request source label was not composed correctly.'

$fallbackThreadId = 'sidebar-title-missing-987654321'
$fallbackName = Resolve-CodexNotificationsConversationName -ThreadId $fallbackThreadId
Assert-True ($fallbackName -match '^任务 .+…$') 'Missing sidebar titles must fall back to a short task id.'
Assert-True ($fallbackName -notmatch '我现在想做一些视频') 'Missing sidebar titles must never fall back to the opening message.'

$messageRejected = $false
try { & (Join-Path $root 'scripts\new-dialog.ps1') -Message ('长' * 121) -RequestId ('too-long-' + [Guid]::NewGuid().ToString('N').Substring(0,8)) -NoSound | Out-Null } catch { $messageRejected = $true }
Assert-True $messageRejected 'Messages over 120 characters must be rejected.'

$optionCountRejected = $false
try { & (Join-Path $root 'scripts\new-dialog.ps1') -Options @('只有一个') -RequestId ('one-option-' + [Guid]::NewGuid().ToString('N').Substring(0,8)) -NoSound | Out-Null } catch { $optionCountRejected = $true }
Assert-True $optionCountRejected 'Decision popups must use 2 to 4 options.'

$optionLengthRejected = $false
try { & (Join-Path $root 'scripts\new-dialog.ps1') -Options @('这是一个明显超过十四个字符限制的选项', '简短选项') -RequestId ('long-option-' + [Guid]::NewGuid().ToString('N').Substring(0,8)) -NoSound | Out-Null } catch { $optionLengthRejected = $true }
Assert-True $optionLengthRejected 'Option labels over 14 characters must be rejected.'

$result = @{ action='completed'; value='ok'; timestamp=[DateTimeOffset]::Now.ToString('o') } | ConvertTo-Json
[IO.File]::WriteAllText($created.resultPath, $result, [Text.UTF8Encoding]::new($false))
$waitResult = & (Join-Path $root 'scripts\wait-result.ps1') -RequestDirectory $created.requestDirectory -TimeoutSeconds 1260 -PollSeconds 1 | ConvertFrom-Json
Assert-True ($waitResult.status -eq 'resolved') 'Waiter did not resolve an accepted result.'

if ($failures.Count -gt 0) { $failures | ForEach-Object { Write-Error $_ }; exit 1 }
Write-Output ('PASS: {0} checks completed.' -f 81)
