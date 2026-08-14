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

function Compress-CodexNotificationsLabel {
    param(
        [AllowNull()] [string] $Text,
        [ValidateRange(4, 120)] [int] $MaxLength
    )
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $normalized = ($Text -replace '\s+', ' ').Trim()
    if ($normalized.Length -le $MaxLength) { return $normalized }
    return $normalized.Substring(0, $MaxLength - 1).TrimEnd() + '…'
}

function Resolve-CodexNotificationsProjectName {
    param(
        [AllowNull()] [string] $ProjectName,
        [AllowNull()] [string] $WorkingDirectory
    )
    if (-not [string]::IsNullOrWhiteSpace($ProjectName)) {
        return (Compress-CodexNotificationsLabel -Text $ProjectName -MaxLength 28)
    }

    $workingPath = $WorkingDirectory
    if ([string]::IsNullOrWhiteSpace($workingPath)) { $workingPath = $PWD.Path }
    $workingPath = $workingPath -replace '^\\\\\?\\', ''
    try {
        $git = Get-Command git.exe -ErrorAction SilentlyContinue
        if (-not $git) { $git = Get-Command git -ErrorAction SilentlyContinue }
        if ($git) {
            $gitRoot = (& $git.Source -C $workingPath rev-parse --show-toplevel 2>$null | Select-Object -First 1)
            if (-not [string]::IsNullOrWhiteSpace($gitRoot)) { $workingPath = [string]$gitRoot }
        }
    } catch {
        # A non-Git working directory is a valid project context.
    }
    $leaf = Split-Path -Leaf ($workingPath.TrimEnd('\', '/'))
    if ([string]::IsNullOrWhiteSpace($leaf)) { $leaf = '当前项目' }
    return (Compress-CodexNotificationsLabel -Text $leaf -MaxLength 28)
}

function Resolve-CodexNotificationsConversationName {
    param(
        [AllowNull()] [string] $ConversationName,
        [AllowNull()] [string] $ThreadId
    )
    if (-not [string]::IsNullOrWhiteSpace($ConversationName)) {
        return (Compress-CodexNotificationsLabel -Text $ConversationName -MaxLength 38)
    }

    if (-not [string]::IsNullOrWhiteSpace($ThreadId)) {
        $databasePath = Join-Path $env:USERPROFILE '.codex\state_5.sqlite'
        try {
            if (Test-Path -LiteralPath $databasePath) {
                $python = Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE '.cache\codex-runtimes') -Filter 'python.exe' -File -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -match '[\\/]dependencies[\\/]python[\\/]python\.exe$' } |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1
                if ($python) {
                    # `title` and `first_user_message` in this database can be the opening
                    # prompt rather than the title shown in the Codex sidebar. Only an
                    # explicit user-assigned `name` is a safe local fallback.
                    $query = "import base64,sqlite3,sys; c=sqlite3.connect('file:'+sys.argv[1]+'?mode=ro',uri=True); r=c.execute(`"select nullif(name,'') from threads where id=?`",(sys.argv[2],)).fetchone(); v=r[0] if r and r[0] else ''; print(base64.b64encode(v.encode('utf-8')).decode('ascii'))"
                    $encoded = (& $python.FullName -c $query $databasePath $ThreadId 2>$null | Select-Object -First 1)
                    if (-not [string]::IsNullOrWhiteSpace($encoded)) {
                        $resolved = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(([string]$encoded).Trim()))
                        return (Compress-CodexNotificationsLabel -Text $resolved -MaxLength 38)
                    }
                }
            }
        } catch {
            # Thread metadata is optional; fall back to a stable short identifier.
        }
        return '任务 ' + (Compress-CodexNotificationsLabel -Text $ThreadId -MaxLength 13)
    }
    return '当前任务'
}
