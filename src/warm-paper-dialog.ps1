[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $RequestPath,
    [Parameter(Mandatory)] [string] $ResultPath,
    [string] $CapturePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml

if (-not ('CodexNotifications.NativeWindow' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace CodexNotifications {
    public static class NativeWindow {
        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")]
        public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
        public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
        public const uint SWP_NOMOVE = 0x0002;
        public const uint SWP_NOSIZE = 0x0001;
        public const uint SWP_SHOWWINDOW = 0x0040;
    }
}
'@ -Language CSharp
}

function Write-DialogResult {
    param([Parameter(Mandatory)] [string] $Action, $Value = $null)
    $payload = [ordered]@{
        action = $Action
        value = $Value
        timestamp = [DateTimeOffset]::Now.ToString('o')
    } | ConvertTo-Json -Depth 10
    $temporary = "$ResultPath.$PID.tmp"
    [IO.File]::WriteAllText($temporary, $payload, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporary -Destination $ResultPath -Force
}

function Save-WindowCapture {
    param([Parameter(Mandatory)] [Windows.Window] $Window, [Parameter(Mandatory)] [string] $Path)
    $dpi = [Windows.Media.VisualTreeHelper]::GetDpi($Window)
    $width = [Math]::Max(1, [int]($Window.ActualWidth * $dpi.DpiScaleX))
    $height = [Math]::Max(1, [int]($Window.ActualHeight * $dpi.DpiScaleY))
    $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new($width, $height, 96 * $dpi.DpiScaleX, 96 * $dpi.DpiScaleY, [Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($Window)
    $encoder = [Windows.Media.Imaging.PngBitmapEncoder]::new()
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Create)
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
}

$request = Get-Content -LiteralPath $RequestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$texturePath = Join-Path (Split-Path -Parent $RequestPath) 'paper-texture.png'
$textureUri = if (Test-Path -LiteralPath $texturePath) { ([Uri]$texturePath).AbsoluteUri } else { '' }
$diagnosticPath = Join-Path (Split-Path -Parent $RequestPath) 'dialog.log'
function Write-DialogDiagnostic([string] $Message) {
    [IO.File]::AppendAllText($diagnosticPath, ('{0} {1}{2}' -f [DateTimeOffset]::Now.ToString('o'), $Message, [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
}
Write-DialogDiagnostic ('request-loaded duration={0}' -f [int]$request.durationSeconds)

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="680" Height="560" MinWidth="600" MinHeight="500" MaxHeight="680"
        Title="Codex 需要你介入"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ResizeMode="CanResizeWithGrip" ShowInTaskbar="True" Topmost="True"
        FontFamily="Microsoft YaHei UI" WindowStartupLocation="CenterScreen">
  <Window.Resources>
    <Style x:Key="CloseButton" TargetType="Button">
      <Setter Property="Width" Value="42"/><Setter Property="Height" Value="42"/>
      <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/><Setter Property="FontSize" Value="14"/>
      <Setter Property="Foreground" Value="#322F2A"/><Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="Bg" Background="{TemplateBinding Background}" CornerRadius="10"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bg" Property="Background" Value="#14000000"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="Bg" Property="Background" Value="#24000000"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="PrimaryButton" TargetType="Button">
      <Setter Property="Height" Value="46"/><Setter Property="Padding" Value="18,0"/>
      <Setter Property="FontSize" Value="15"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Foreground" Value="#312A22"/>
      <Setter Property="Background" Value="#FAF7F1"/><Setter Property="BorderBrush" Value="#B68650"/><Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="ButtonBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ButtonBorder" Property="Background" Value="#FFFDFC"/><Setter TargetName="ButtonBorder" Property="BorderBrush" Value="#C8914C"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="ButtonBorder" Property="Background" Value="#EFE5D6"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="BusyButton" TargetType="Button">
      <Setter Property="Height" Value="46"/><Setter Property="Padding" Value="14,0"/>
      <Setter Property="FontSize" Value="14"/><Setter Property="Foreground" Value="#625B52"/>
      <Setter Property="Background" Value="Transparent"/><Setter Property="BorderBrush" Value="#CFC3B4"/><Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="ButtonBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ButtonBorder" Property="Background" Value="#66FFFFFF"/><Setter TargetName="ButtonBorder" Property="BorderBrush" Value="#AFA292"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="ButtonBorder" Property="Background" Value="#E8DED2"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style TargetType="ScrollBar">
      <Setter Property="Width" Value="8"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ScrollBar">
            <Grid Background="Transparent">
              <Track x:Name="PART_Track" IsDirectionReversed="True">
                <Track.DecreaseRepeatButton><RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0" Focusable="False"/></Track.DecreaseRepeatButton>
                <Track.Thumb><Thumb Background="#B9ADA0"><Thumb.Template><ControlTemplate TargetType="Thumb"><Border Background="{TemplateBinding Background}" CornerRadius="4" Margin="1,0"/></ControlTemplate></Thumb.Template></Thumb></Track.Thumb>
                <Track.IncreaseRepeatButton><RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0" Focusable="False"/></Track.IncreaseRepeatButton>
              </Track>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="ChoiceOption" TargetType="RadioButton">
      <Setter Property="Height" Value="42"/><Setter Property="Margin" Value="0,0,8,8"/><Setter Property="Padding" Value="12,0"/>
      <Setter Property="FontSize" Value="14"/><Setter Property="Foreground" Value="#3E3933"/><Setter Property="Background" Value="#55FFFFFF"/>
      <Setter Property="BorderBrush" Value="#D8CEC0"/><Setter Property="BorderThickness" Value="1"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="RadioButton"><Border x:Name="OptionBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8" Padding="{TemplateBinding Padding}"><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="18"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><Ellipse x:Name="OptionCircle" Width="12" Height="12" Stroke="#A99B8C" StrokeThickness="1.5"/><Ellipse x:Name="OptionDot" Width="6" Height="6" Fill="#B8792E" Visibility="Collapsed"/><ContentPresenter Grid.Column="1" VerticalAlignment="Center" Margin="8,0,0,0"/></Grid></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="OptionBorder" Property="BorderBrush" Value="#BCA78F"/></Trigger><Trigger Property="IsChecked" Value="True"><Setter TargetName="OptionBorder" Property="Background" Value="#FFF7E9"/><Setter TargetName="OptionBorder" Property="BorderBrush" Value="#C78A40"/><Setter TargetName="OptionDot" Property="Visibility" Value="Visible"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="ReplyInput" TargetType="TextBox">
      <Setter Property="Padding" Value="13,0,48,0"/><Setter Property="FontSize" Value="14"/>
      <Setter Property="Foreground" Value="#312E2A"/><Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
    </Style>
    <Style x:Key="SendReplyButton" TargetType="Button">
      <Setter Property="Width" Value="34"/><Setter Property="Height" Value="34"/><Setter Property="Margin" Value="0,0,6,0"/>
      <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/><Setter Property="FontSize" Value="15"/>
      <Setter Property="Foreground" Value="#FFFDF9"/><Setter Property="Background" Value="#C17C2B"/>
      <Setter Property="BorderThickness" Value="0"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="SendCircle" Background="{TemplateBinding Background}" CornerRadius="17"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="SendCircle" Property="Background" Value="#A96820"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="SendCircle" Property="Background" Value="#8F5818"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="SendCircle" Property="Background" Value="#DED6CC"/><Setter Property="Foreground" Value="#A99F94"/><Setter Property="Cursor" Value="Arrow"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
    </Style>
  </Window.Resources>
  <Grid Margin="24">
    <Border CornerRadius="17" Background="#FFF8F3EC" BorderBrush="#E3C08B" BorderThickness="1" SnapsToDevicePixels="True">
      <Border.Effect><DropShadowEffect Color="#000000" BlurRadius="34" ShadowDepth="12" Opacity="0.34"/></Border.Effect>
      <Grid ClipToBounds="True">
        <Border CornerRadius="16">
          <Border.Background>
            <ImageBrush ImageSource="$textureUri" Stretch="UniformToFill" Opacity="0.28"/>
          </Border.Background>
        </Border>
        <Border CornerRadius="16" Background="#EFFFFBF5"/>
        <Grid>
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <Grid x:Name="TitleBar" Grid.Row="0" Height="58" Background="Transparent">
            <Button x:Name="CloseButton" Style="{StaticResource CloseButton}" Content="&#xE711;" HorizontalAlignment="Right" Margin="0,8,9,0" VerticalAlignment="Top" ToolTip="关闭提醒"/>
          </Grid>
          <Grid Grid.Row="1" Margin="42,3,34,20" MinHeight="200">
            <Grid.ColumnDefinitions><ColumnDefinition Width="7"/><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Border Grid.Column="0" Width="7" Height="42" CornerRadius="4" Background="#D89B3B" VerticalAlignment="Top" Margin="0,2,0,0"/>
            <Grid Grid.Column="2">
              <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="8"/><RowDefinition Height="Auto"/><RowDefinition Height="14"/><RowDefinition Height="*"/></Grid.RowDefinitions>
              <TextBlock x:Name="TitleText" Grid.Row="0" TextWrapping="Wrap" TextTrimming="CharacterEllipsis" MaxHeight="72" FontSize="27" FontWeight="SemiBold" Foreground="#171512" LineHeight="36"/>
              <TextBlock x:Name="MessageText" Grid.Row="2" TextWrapping="Wrap" TextTrimming="CharacterEllipsis" MaxHeight="75" FontSize="15" Foreground="#49443E" LineHeight="25" HorizontalAlignment="Stretch"/>
              <ScrollViewer Grid.Row="4" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0,0,8,0" CanContentScroll="False">
                <StackPanel>
                  <TextBlock x:Name="ChoiceLabel" Text="请选择" FontSize="12" FontWeight="SemiBold" Foreground="#766D63" Margin="0,0,0,8"/>
                  <UniformGrid x:Name="OptionsPanel" Columns="2"/>
                  <TextBlock x:Name="InputLabel" Text="补充说明（输入后点箭头，或直接选项）" FontSize="12" FontWeight="SemiBold" Foreground="#766D63" Margin="0,4,0,8"/>
                  <Border x:Name="ReplyInputShell" Height="46" Background="#AAFFFFFF" BorderBrush="#D1C6B8" BorderThickness="1" CornerRadius="8">
                    <Grid>
                      <TextBox x:Name="ReplyInput" Style="{StaticResource ReplyInput}" MaxLength="500"/>
                      <Button x:Name="SendReplyButton" Style="{StaticResource SendReplyButton}" Content="&#xE724;" HorizontalAlignment="Right" VerticalAlignment="Center" IsEnabled="False" ToolTip="发送回复"/>
                    </Grid>
                  </Border>
                  <TextBlock x:Name="ValidationText" Foreground="#A34835" FontSize="12" Margin="2,6,0,0" Visibility="Collapsed"/>
                </StackPanel>
              </ScrollViewer>
            </Grid>
          </Grid>
          <Grid Grid.Row="2" Margin="42,0,42,28">
            <Grid.RowDefinitions><RowDefinition Height="1"/><RowDefinition Height="46"/><RowDefinition Height="58"/></Grid.RowDefinitions>
            <Border Grid.Row="0" Background="#D8CEC0" Opacity="0.72"/>
            <StackPanel Grid.Row="1" Orientation="Horizontal" VerticalAlignment="Center">
              <Ellipse Width="11" Height="11" Fill="#D9A04C" Margin="0,0,11,0"/>
              <TextBlock x:Name="StatusText" FontSize="13" Foreground="#625B52" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
              <TextBlock x:Name="CountdownText" FontSize="12" Foreground="#968B7E" Margin="13,0,0,0" VerticalAlignment="Center"/>
            </StackPanel>
            <Grid Grid.Row="2">
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="12"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
              <Button x:Name="BusyButton" Grid.Column="0" Style="{StaticResource BusyButton}" Content="我很忙，一会再说。" HorizontalAlignment="Stretch"/>
              <Button x:Name="PrimaryButton" Grid.Column="2" Style="{StaticResource PrimaryButton}" HorizontalAlignment="Stretch"/>
            </Grid>
          </Grid>
        </Grid>
      </Grid>
    </Border>
  </Grid>
</Window>
"@

$reader = [Xml.XmlNodeReader]::new([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$titleBar = $window.FindName('TitleBar')
$closeButton = $window.FindName('CloseButton')
$busyButton = $window.FindName('BusyButton')
$primaryButton = $window.FindName('PrimaryButton')
$choiceLabel = $window.FindName('ChoiceLabel')
$optionsPanel = $window.FindName('OptionsPanel')
$inputLabel = $window.FindName('InputLabel')
$replyInput = $window.FindName('ReplyInput')
$sendReplyButton = $window.FindName('SendReplyButton')
$validationText = $window.FindName('ValidationText')
$titleText = $window.FindName('TitleText')
$messageText = $window.FindName('MessageText')
$statusText = $window.FindName('StatusText')
$countdownText = $window.FindName('CountdownText')

[Windows.Automation.AutomationProperties]::SetName($replyInput, '直接输入回复')
[Windows.Automation.AutomationProperties]::SetAutomationId($replyInput, 'ReplyInput')
[Windows.Automation.AutomationProperties]::SetName($sendReplyButton, '发送回复')
[Windows.Automation.AutomationProperties]::SetAutomationId($sendReplyButton, 'SendReplyButton')

$titleText.Text = [string]$request.title
$messageText.Text = [string]$request.message
$statusText.Text = [string]$request.status
$primaryButton.Content = [string]$request.buttonText
$optionButtons = [Collections.Generic.List[Windows.Controls.RadioButton]]::new()
$requestOptions = @($request.options)
if ($requestOptions.Count -eq 0) {
    $choiceLabel.Visibility = [Windows.Visibility]::Collapsed
    $optionsPanel.Visibility = [Windows.Visibility]::Collapsed
    $inputLabel.Text = '直接输入回复（点箭头或按 Enter 发送）'
} else {
    $optionIndex = 0
    foreach ($option in $requestOptions) {
        $radio = [Windows.Controls.RadioButton]::new()
        $radio.Content = [string]$option
        $radio.Tag = [string]$option
        $radio.Style = $window.FindResource('ChoiceOption')
        $radio.GroupName = 'DecisionOptions'
        $radio.Name = 'DecisionOption{0}' -f $optionIndex
        [Windows.Automation.AutomationProperties]::SetName($radio, [string]$option)
        [Windows.Automation.AutomationProperties]::SetAutomationId($radio, $radio.Name)
        [Windows.Automation.AutomationProperties]::SetHelpText($radio, '选择：{0}' -f [string]$option)
        $optionButtons.Add($radio)
        $optionsPanel.Children.Add($radio) | Out-Null
        $radio.Add_Checked({
            param($sender, $eventArgs)
            if ($state.TerminalWritten) { return }
            $typedReply = [string]$replyInput.Text
            $typedReply = $typedReply.Trim()
            $state.TerminalWritten = $true
            Write-DialogResult -Action 'submitted' -Value ([ordered]@{
                selectedOption = [string]$sender.Tag
                input = if ([string]::IsNullOrWhiteSpace($typedReply)) { $null } else { $typedReply }
            })
            $window.Close()
        })
        $optionIndex++
    }
    $primaryButton.Visibility = [Windows.Visibility]::Collapsed
    [Windows.Controls.Grid]::SetColumn($busyButton, 0)
    [Windows.Controls.Grid]::SetColumnSpan($busyButton, 3)
    $busyButton.HorizontalAlignment = [Windows.HorizontalAlignment]::Right
    $busyButton.Width = 220
}
$duration = [int]$request.durationSeconds
$state = @{
    TerminalWritten = $false
    CloseReason = 'dismissed'
    Remaining = $duration
}
$timer = [Windows.Threading.DispatcherTimer]::new()
$submitTypedReply = {
    if ($state.TerminalWritten) { return }
    $typedReply = [string]$replyInput.Text
    $typedReply = $typedReply.Trim()
    if ([string]::IsNullOrWhiteSpace($typedReply)) { return }
    $state.TerminalWritten = $true
    Write-DialogResult -Action 'submitted' -Value ([ordered]@{
        selectedOption = $null
        input = $typedReply
    })
    $window.Close()
}

$titleBar.Add_MouseLeftButtonDown({ if ($_.ButtonState -eq [Windows.Input.MouseButtonState]::Pressed) { $window.DragMove() } })
$closeButton.Add_Click({ $state.CloseReason = 'dismissed'; $window.Close() })
$busyButton.Add_Click({
    $state.TerminalWritten = $true
    Write-DialogResult -Action 'deferred' -Value ([ordered]@{
        button = '我很忙，一会再说。'
        message = '用户现在很忙，暂时无法回答你的信息。你需要继续挂起，等待用户回复。'
    })
    $window.Close()
})
$primaryButton.Add_Click({
    $selectedOption = $null
    foreach ($optionButton in $optionButtons) {
        if ($optionButton.IsChecked) { $selectedOption = [string]$optionButton.Tag; break }
    }
    $typedReply = [string]$replyInput.Text
    $typedReply = $typedReply.Trim()
    if ($requestOptions.Count -gt 0 -and -not $selectedOption -and [string]::IsNullOrWhiteSpace($typedReply)) {
        $validationText.Text = '请选择一个选项，或直接输入你的回复。'
        $validationText.Visibility = [Windows.Visibility]::Visible
        return
    }
    $state.TerminalWritten = $true
    Write-DialogResult -Action 'completed' -Value ([ordered]@{
        button = [string]$primaryButton.Content
        selectedOption = $selectedOption
        input = if ([string]::IsNullOrWhiteSpace($typedReply)) { $null } else { $typedReply }
    })
    $window.Close()
})
$replyInput.Add_TextChanged({
    $sendReplyButton.IsEnabled = -not [string]::IsNullOrWhiteSpace([string]$replyInput.Text)
    if ($sendReplyButton.IsEnabled) { $validationText.Visibility = [Windows.Visibility]::Collapsed }
})
$sendReplyButton.Add_Click({ & $submitTypedReply })
$replyInput.Add_KeyDown({ if ($_.Key -eq [Windows.Input.Key]::Enter) { & $submitTypedReply } })

if ($duration -gt 0) {
    $countdownText.Text = "$($state.Remaining) 秒后自动关闭"
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $timer.Add_Tick({
        $state.Remaining = [int]$state.Remaining - 1
        Write-DialogDiagnostic ('timer-tick remaining={0}' -f $state.Remaining)
        if ($state.Remaining -le 0) {
            $timer.Stop()
            $state.CloseReason = 'expired'
            $window.Close()
        } else {
            $countdownText.Text = "$($state.Remaining) 秒后自动关闭"
        }
    })
} else {
    $countdownText.Text = '等待你的操作'
}

$window.Add_SourceInitialized({
    Write-DialogDiagnostic 'source-initialized'
    if ([bool]$request.forceForeground) {
        $handle = [Windows.Interop.WindowInteropHelper]::new($window).Handle
        [CodexNotifications.NativeWindow]::SetWindowPos($handle, [CodexNotifications.NativeWindow]::HWND_TOPMOST, 0, 0, 0, 0, [CodexNotifications.NativeWindow]::SWP_NOMOVE -bor [CodexNotifications.NativeWindow]::SWP_NOSIZE -bor [CodexNotifications.NativeWindow]::SWP_SHOWWINDOW) | Out-Null
        [CodexNotifications.NativeWindow]::SetForegroundWindow($handle) | Out-Null
    }
})

$window.Add_Loaded({
    Write-DialogDiagnostic 'loaded'
    if ([bool]$request.soundEnabled) { [Media.SystemSounds]::Asterisk.Play() }
    if ($duration -gt 0) { $timer.Start(); Write-DialogDiagnostic 'timer-started' }
    $window.Activate() | Out-Null
})

$window.Add_ContentRendered({
    Write-DialogDiagnostic 'content-rendered'
    if ($CapturePath) {
        try { Save-WindowCapture -Window $window -Path $CapturePath; Write-DialogDiagnostic 'capture-saved' }
        catch { Write-DialogDiagnostic ('capture-failed ' + $_.Exception.Message) }
    }
})

$window.Add_Closed({
    $timer.Stop()
    Write-DialogDiagnostic ('closed reason={0}' -f $state.CloseReason)
    if (-not $state.TerminalWritten) { Write-DialogResult -Action $state.CloseReason }
})

Write-DialogDiagnostic 'show-dialog'
$null = $window.ShowDialog()
Write-DialogDiagnostic 'show-dialog-returned'
