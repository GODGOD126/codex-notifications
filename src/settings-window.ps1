[CmdletBinding()]
param([switch] $CaptureOnly, [string] $CapturePath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
. (Join-Path $PSScriptRoot '..\scripts\common.ps1')

function Save-SettingsCapture([Windows.Window] $Window, [string] $Path) {
    $dpi = [Windows.Media.VisualTreeHelper]::GetDpi($Window)
    $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new([int]($Window.ActualWidth * $dpi.DpiScaleX), [int]($Window.ActualHeight * $dpi.DpiScaleY), 96 * $dpi.DpiScaleX, 96 * $dpi.DpiScaleY, [Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($Window)
    $encoder = [Windows.Media.Imaging.PngBitmapEncoder]::new()
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Create)
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
}

$settings = Get-CodexNotificationsSettings
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Codex 提醒设置" Width="560" Height="510" WindowStartupLocation="CenterScreen" ResizeMode="NoResize" Background="#F3EEE6" FontFamily="Microsoft YaHei UI">
  <Window.Resources>
    <Style TargetType="TextBlock"><Setter Property="Foreground" Value="#2A2722"/></Style>
    <Style TargetType="Button"><Setter Property="Height" Value="38"/><Setter Property="Padding" Value="18,0"/><Setter Property="Margin" Value="0,0,10,0"/><Setter Property="Background" Value="#FBF8F2"/><Setter Property="BorderBrush" Value="#B8864A"/><Setter Property="BorderThickness" Value="1"/></Style>
  </Window.Resources>
  <Grid Margin="34">
    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
    <TextBlock Grid.Row="0" Text="Codex 提醒设置" FontSize="26" FontWeight="SemiBold"/>
    <TextBlock Grid.Row="1" Margin="0,8,0,24" Text="仅由 Skill 主动调用，不使用 Hook，也不会修改 Codex 配置。" Foreground="#6F675D"/>
    <CheckBox x:Name="Enabled" Grid.Row="2" Content="启用介入提醒" FontSize="15" Margin="0,0,0,18"/>
    <StackPanel Grid.Row="3" Margin="0,0,0,18"><TextBlock Text="默认弹窗展示时长（秒；0 表示不自动关闭）" Margin="0,0,0,8"/><TextBox x:Name="Duration" Height="36" Padding="9,6"/></StackPanel>
    <StackPanel Grid.Row="4"><CheckBox x:Name="Sound" Content="播放提示音" Margin="0,0,0,14"/><CheckBox x:Name="Foreground" Content="尽力将弹窗置于普通窗口最前端"/></StackPanel>
    <Border Grid.Row="5" Background="#70FFFFFF" CornerRadius="10" Padding="16" Margin="0,24,0,20" BorderBrush="#DDD1C0" BorderThickness="1"><TextBlock TextWrapping="Wrap" LineHeight="22" Foreground="#6F675D">等待规则固定为最低 21 分钟，默认 30 分钟。关闭或到期只关闭弹窗，不会被当作用户已经完成操作。</TextBlock></Border>
    <StackPanel Grid.Row="6" Orientation="Horizontal" HorizontalAlignment="Right"><Button x:Name="Test" Content="测试弹窗"/><Button x:Name="Defaults" Content="恢复默认"/><Button x:Name="Save" Content="保存" Margin="0" Background="#E2B66D"/></StackPanel>
  </Grid>
</Window>
'@
$window = [Windows.Markup.XamlReader]::Parse($xaml)
$enabled = $window.FindName('Enabled'); $duration = $window.FindName('Duration'); $sound = $window.FindName('Sound'); $foreground = $window.FindName('Foreground')
$enabled.IsChecked = [bool]$settings.enabled; $duration.Text = [string]$settings.durationSeconds; $sound.IsChecked = [bool]$settings.soundEnabled; $foreground.IsChecked = [bool]$settings.forceForeground

$window.FindName('Defaults').Add_Click({ $d = Get-CodexNotificationsDefaultSettings; $enabled.IsChecked = $d.enabled; $duration.Text = [string]$d.durationSeconds; $sound.IsChecked = $d.soundEnabled; $foreground.IsChecked = $d.forceForeground })
$window.FindName('Save').Add_Click({
    $seconds = 0
    if (-not [int]::TryParse($duration.Text, [ref]$seconds) -or $seconds -lt 0 -or $seconds -gt 86400) { [Windows.MessageBox]::Show('展示时长必须是 0 到 86400 之间的整数。', '设置无效') | Out-Null; return }
    Save-CodexNotificationsSettings ([ordered]@{ enabled=[bool]$enabled.IsChecked; durationSeconds=$seconds; soundEnabled=[bool]$sound.IsChecked; forceForeground=[bool]$foreground.IsChecked; waitTimeoutSeconds=1800; minimumWaitSeconds=1260 })
    [Windows.MessageBox]::Show('设置已保存。', 'Codex 提醒') | Out-Null
})
$window.FindName('Test').Add_Click({
    $created = & (Join-Path $PSScriptRoot '..\scripts\new-dialog.ps1') -Title '需要你介入' -Message '这是一条暖白纸感测试提醒。' -Status '测试模式 · 不影响任务' -ButtonText '知道了' -DurationSeconds 30 | ConvertFrom-Json
    & (Join-Path $PSScriptRoot '..\scripts\show-dialog.ps1') -RequestDirectory $created.requestDirectory | Out-Null
})
if ($CaptureOnly) { $window.Add_ContentRendered({ if ($CapturePath) { Save-SettingsCapture $window $CapturePath }; $window.Close() }) }
$null = $window.ShowDialog()
