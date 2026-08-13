# Codex Notifications

[English](README.md)

一个轻量的 Windows Codex Skill：当任务确实必须由用户本人介入时，动态生成置顶弹窗提醒用户，并让当前 Codex 任务继续等待真实结果。

![Codex Notifications 弹窗](docs/images/popup.png)

## 功能

- 仅在没有用户介入就无法安全继续时提醒，例如登录、扫码、验证码、授权、用户专属信息、物理操作或没有安全默认项的重要选择。
- 每次请求复制一份完整弹窗源码，Codex 可针对当次任务自由修改布局、字段、按钮、验证和交互。
- 关闭弹窗、弹窗到期或选择“我很忙，一会再说。”都不会被当作确认、授权或任务完成。
- 提供桌面设置入口，可调整启用状态、展示时长、提示音和前台显示。
- 不使用 Codex Hook，也不修改 `config.toml`。

## 环境要求

- Windows 10 或 Windows 11
- 推荐 PowerShell 7（`pwsh`），同时兼容 Windows PowerShell 5.1
- 支持本地 Skills 的 Codex

## 安装

```powershell
git clone https://github.com/GODGOD126/codex-notifications.git
cd codex-notifications
pwsh -NoProfile -File .\scripts\install.ps1
```

安装程序会把 Skill 复制到 `%USERPROFILE%\.codex\skills\codex-notifications`，创建本地设置文件，并在桌面创建“Codex 提醒设置”快捷方式。首次安装后请重启 Codex，让它重新发现 Skill。

如果不需要桌面快捷方式：

```powershell
pwsh -NoProfile -File .\scripts\install.ps1 -NoDesktopShortcut
```

## 让 Codex 自动调用

把下面这段加入你的 Codex 指令：

```text
当任务必须由用户本人介入才能安全继续时，例如登录、扫码、验证码、授权、提供用户专属信息或完成必须人工操作的步骤，调用 $codex-notifications 弹窗提醒用户。普通进度、可自行解决的错误和任务完成不要提醒。调用后不得结束当前任务，必须按 Skill 规则持续等待用户的真实回应。不使用 Hook。
```

## 设置

双击桌面的“Codex 提醒设置”。

![Codex Notifications 设置窗口](docs/images/settings.png)

等待规则不会开放给设置窗口修改：默认等待 30 分钟，最低等待 21 分钟。关闭、到期和“我很忙”都不是同意或完成。

## 卸载

在克隆目录或已安装的 Skill 目录运行：

```powershell
pwsh -NoProfile -File .\scripts\uninstall.ps1
```

使用 `-KeepSettings` 可保留本地设置和请求记录。

## 验证

```powershell
pwsh -NoProfile -File .\tests\run-tests.ps1
$env:PYTHONUTF8 = '1'
py -3 "$env:USERPROFILE\.codex\skills\.system\skill-creator\scripts\quick_validate.py" .
```

## 限制

- 普通桌面窗口无法覆盖锁屏和 UAC 安全桌面。
- 部分独占全屏游戏可能阻止置顶窗口显示。
- Codex 当前任务必须保持运行；弹窗不能唤醒已经结束的任务。

## 隐私与安全

- 不含遥测或网络请求。
- 安装程序不保存凭据。
- 临时请求文件只保存在 `%LOCALAPPDATA%\CodexNotifications\requests`。
- 除非当前任务明确设计了安全的数据生命周期，否则不要在弹窗中输入敏感信息。

## 许可证

[MIT](LICENSE)
