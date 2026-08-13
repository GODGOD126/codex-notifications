[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $RequestDirectory,
    [ValidateRange(1260, 86400)] [int] $TimeoutSeconds = 1800,
    [ValidateRange(1, 30)] [int] $PollSeconds = 2,
    [string[]] $AcceptAction = @('completed', 'submitted', 'confirmed', 'continue', 'acknowledged')
)

. (Join-Path $PSScriptRoot 'common.ps1')

$resolvedDirectory = (Resolve-Path -LiteralPath $RequestDirectory).Path
$resultPath = Join-Path $resolvedDirectory 'result.json'
$waitingPath = Join-Path $resolvedDirectory 'waiting.json'
$startedAt = [DateTimeOffset]::Now
$deadline = $startedAt.AddSeconds($TimeoutSeconds)

while ([DateTimeOffset]::Now -lt $deadline) {
    Write-AtomicUtf8Json -Path $waitingPath -Value ([ordered]@{
        state = 'waiting'
        processId = $PID
        startedAt = $startedAt.ToString('o')
        heartbeatAt = [DateTimeOffset]::Now.ToString('o')
        deadline = $deadline.ToString('o')
    })

    if (Test-Path -LiteralPath $resultPath) {
        try {
            $result = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $action = [string]$result.action
            if ($AcceptAction -contains $action) {
                Write-AtomicUtf8Json -Path $waitingPath -Value ([ordered]@{
                    state = 'resolved'
                    processId = $PID
                    startedAt = $startedAt.ToString('o')
                    resolvedAt = [DateTimeOffset]::Now.ToString('o')
                    action = $action
                })
                [pscustomobject]@{ status = 'resolved'; elapsedSeconds = [int]([DateTimeOffset]::Now - $startedAt).TotalSeconds; result = $result } | ConvertTo-Json -Depth 20
                exit 0
            }
        } catch {
            # The popup may be replacing its atomic result file; retry.
        }
    }
    Start-Sleep -Seconds $PollSeconds
}

Write-AtomicUtf8Json -Path $waitingPath -Value ([ordered]@{
    state = 'timed_out'
    processId = $PID
    startedAt = $startedAt.ToString('o')
    timedOutAt = [DateTimeOffset]::Now.ToString('o')
})
[pscustomobject]@{ status = 'timed_out'; elapsedSeconds = $TimeoutSeconds; requestDirectory = $resolvedDirectory } | ConvertTo-Json
exit 2
