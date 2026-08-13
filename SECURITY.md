# Security Policy

## Reporting a vulnerability

Please report security issues privately through GitHub Security Advisories instead of opening a public issue. Include the affected version, reproduction steps, impact, and any suggested mitigation.

## Security boundaries

- The skill runs local PowerShell scripts and creates local WPF windows.
- It does not install Codex Hooks, change `config.toml`, or make network requests.
- Local state is stored under `%LOCALAPPDATA%\CodexNotifications`.
- Normal desktop windows cannot cross the Windows lock screen or UAC secure desktop boundary.
