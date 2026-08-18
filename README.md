# Codex Notifications

[简体中文](README.zh-CN.md)

A lightweight Windows skill that lets Codex show a task-specific, always-on-top popup when work is genuinely blocked on human intervention.

![Codex Notifications popup](docs/images/popup.png)

## What it does

- Notifies you only when Codex cannot safely continue without you, such as login, QR scanning, CAPTCHA, authorization, user-only information, or a consequential choice with no safe default.
- Creates a fresh copy of the popup source for every request, so Codex can freely adapt the layout, fields, buttons, validation, and interaction to the current task.
- Shows the originating project and exact Codex sidebar task name in a compact source strip, making simultaneous blocked tasks easy to identify.
- Keeps the current Codex task waiting for your real response instead of treating popup close or expiry as approval.
- Always includes **“我很忙，一会再说。”** (“I’m busy, ask me later”) as a non-terminal response.
- Provides a desktop settings shortcut for duration, sound, enable/disable, and foreground behavior.
- Uses no Codex Hooks and does not modify `config.toml`.

## Requirements

- Windows 10 or Windows 11
- Codex Desktop with local Skills support
- PowerShell 7 (`pwsh`)
- Git, or use **Code → Download ZIP** on the GitHub repository page

## 5-minute quick start

### 1. Download and install

Open PowerShell 7 and run:

```powershell
git clone https://github.com/GODGOD126/codex-notifications.git
cd codex-notifications
pwsh -NoProfile -File .\scripts\install.ps1
```

If you downloaded the ZIP, extract it, open PowerShell 7 in the extracted folder, and run only the final installer command.

The installer:

- Copies the skill to `%USERPROFILE%\.codex\skills\codex-notifications`
- Creates `%LOCALAPPDATA%\CodexNotifications\settings.json`
- Adds **Codex 提醒设置** to the desktop

Quit and reopen Codex after installation so it discovers the new skill.

To install without the desktop shortcut:

```powershell
pwsh -NoProfile -File .\scripts\install.ps1 -NoDesktopShortcut
```

### 2. Tell Codex when to use it

Add the rule below to either location:

- **All projects:** `%USERPROFILE%\.codex\AGENTS.md`
- **One project only:** `AGENTS.md` in that project's root directory

Create the file if it does not exist. Project instructions take precedence over global instructions.

Append:

```text
When the task cannot safely continue without my direct intervention—such as login, QR scan, CAPTCHA, authorization, user-only information, or a required physical action—use $codex-notifications to alert me. Do not notify for normal progress, recoverable errors, or completion. After notifying, keep the current task active and wait according to the skill instructions. Do not use Hooks.
```

Start a new Codex task after changing the instructions so the new rule is loaded.

### 3. Show a test popup

This command verifies the installation and UI without changing Codex configuration:

```powershell
$skillRoot = Join-Path $env:USERPROFILE '.codex\skills\codex-notifications'
$created = & "$skillRoot\scripts\new-dialog.ps1" `
  -Title 'Installation complete' `
  -Message 'If you can see this window, the popup component is working.' `
  -Options @('Looks correct', 'Need help') `
  -ProjectName 'codex-notifications' `
  -ConversationName 'First install test' `
  -DurationSeconds 120 `
  -NoSound | ConvertFrom-Json
& "$skillRoot\scripts\show-dialog.ps1" -RequestDirectory $created.requestDirectory
```

You should see a warm white topmost window with a source label in the upper-left. Selecting an option submits immediately; typed text is sent with the inline arrow. The test popup closes automatically after two minutes.

### 4. Use it normally

You do not need to run a script for each task. Ask Codex to perform ordinary work, for example:

- “Check the review status of my order on this website.”
- “Publish this content in the admin dashboard.”
- “Find out why I cannot finish setting up my account.”

Codex should show the popup only if the task reaches a login, QR scan, CAPTCHA, authorization, user-only input, or another step that truly requires you. After you act or reply, the original task should continue. Normal progress and completion do not trigger a popup.

## Update

For a Git clone installation:

```powershell
cd codex-notifications
git pull --ff-only
pwsh -NoProfile -File .\scripts\install.ps1
```

Restart Codex afterward. For a ZIP installation, download the latest ZIP, extract it, and run the installer again.

## Settings

Open **Codex 提醒设置** from the desktop.

![Codex Notifications settings](docs/images/settings.png)

The waiting safety rule is intentionally not editable in the settings window: the default wait is 30 minutes and the enforced minimum is 21 minutes. Popup dismissal, expiry, or “I’m busy” never counts as consent or completion.

## Uninstall

Run this from the cloned repository or the installed skill folder:

```powershell
pwsh -NoProfile -File .\scripts\uninstall.ps1
```

Use `-KeepSettings` to preserve local settings and request history.

## Troubleshooting

### `pwsh` is not recognized

Install [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows), open a new terminal, and run `pwsh --version`. Avoid Windows PowerShell 5.1 for scripts containing Chinese text.

### Codex does not invoke the skill

Check that `%USERPROFILE%\.codex\skills\codex-notifications\SKILL.md` exists, quit and reopen Codex, and confirm that the invocation rule is present in the global or project `AGENTS.md`. The popup is intentionally limited to genuine human-intervention blockers.

### The test command does not show a window

Open **Codex 提醒设置**, confirm notifications are enabled, leave exclusive full-screen mode, and retry. A normal window cannot appear above the lock screen or UAC secure desktop.

### The popup shows the wrong task name

During normal use, the skill matches the current `CODEX_THREAD_ID` against the official Codex task list. If no trustworthy title is available, it shows a short task ID instead of using the opening prompt as a title.

## Developer verification (not required for installation)

```powershell
pwsh -NoProfile -File .\tests\run-tests.ps1
$env:PYTHONUTF8 = '1'
py -3 "$env:USERPROFILE\.codex\skills\.system\skill-creator\scripts\quick_validate.py" .
```

The test suite verifies the no-Hook contract, waiting minimum, dynamic popup copy, structured results, installer behavior, option validation, and that `config.toml` remains unchanged.

The second command requires the Python Launcher and Codex's bundled `skill-creator`. Regular users only need the test popup in step 3.

## Limitations

- A normal desktop process cannot appear above the Windows lock screen or UAC secure desktop.
- Exclusive full-screen games may prevent ordinary topmost windows from appearing.
- The current Codex task must remain active while it waits; the popup alone cannot wake a task that has already ended.

## Privacy and security

- No telemetry and no network requests are built into the skill.
- No credentials are stored by the installer.
- Request files are kept locally under `%LOCALAPPDATA%\CodexNotifications\requests`.
- The Codex app task list is the preferred source for the displayed task name. If no explicit name is passed, the script may read only the user-assigned `name` field from `%USERPROFILE%\.codex\state_5.sqlite` in read-only mode; it never uses the opening prompt as a title.
- Avoid entering secrets into a popup unless the current task explicitly designs a safe lifecycle for them.

## License

[MIT](LICENSE)
