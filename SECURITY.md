# Security Policy

## Reporting a vulnerability

Please report security issues privately through GitHub Security Advisories instead of opening a public issue. Include the affected version, reproduction steps, impact, and any suggested mitigation.

## Security boundaries

- The skill runs local PowerShell scripts and creates local WPF windows.
- It does not install Codex Hooks, change `config.toml`, or make network requests.
- Local state is stored under `%LOCALAPPDATA%\CodexNotifications`.
- The displayed task name should come from the Codex app task list. As an optional local fallback, the script opens `%USERPROFILE%\.codex\state_5.sqlite` read-only and queries only the explicit user-assigned `threads.name` field; it does not use `title` or `first_user_message`.
- Normal desktop windows cannot cross the Windows lock screen or UAC secure desktop boundary.
