[CmdletBinding()]
param(
    [Parameter(Mandatory)] [int] $ProcessId,
    [string] $ButtonName = '知道了',
    [ValidateRange(1, 30)] [int] $TimeoutSeconds = 10
)

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
while ([DateTime]::UtcNow -lt $deadline) {
    $root = [Windows.Automation.AutomationElement]::RootElement
    $condition = [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ProcessIdProperty, $ProcessId)
    $window = $root.FindFirst([Windows.Automation.TreeScope]::Children, $condition)
    if ($window) {
        $buttonCondition = [Windows.Automation.AndCondition]::new(
            [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty, [Windows.Automation.ControlType]::Button),
            [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::NameProperty, $ButtonName)
        )
        $button = $window.FindFirst([Windows.Automation.TreeScope]::Descendants, $buttonCondition)
        if ($button) {
            $pattern = $button.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern)
            $pattern.Invoke()
            Write-Output 'clicked'
            exit 0
        }
    }
    Start-Sleep -Milliseconds 200
}
throw "Button '$ButtonName' was not found for process $ProcessId."
