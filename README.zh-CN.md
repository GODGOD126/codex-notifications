# Codex Notifications

[English](README.md)

一个轻量的 Windows Codex Skill：当任务确实必须由用户本人介入时，动态生成置顶弹窗提醒用户，并让当前 Codex 任务继续等待真实结果。

![Codex Notifications 弹窗](docs/images/popup.png)

## 功能

- 仅在没有用户介入就无法安全继续时提醒，例如登录、扫码、验证码、授权、用户专属信息、物理操作或没有安全默认项的重要选择。
- 每次请求复制一份完整弹窗源码，Codex 可针对当次任务自由修改布局、字段、按钮、验证和交互。
- 弹窗左上角显示来源项目和 Codex 侧边栏中的准确任务名，多个任务同时等待时也能快速区分。
- 关闭弹窗、弹窗到期或选择“我很忙，一会再说。”都不会被当作确认、授权或任务完成。
- 提供桌面设置入口，可调整启用状态、展示时长、提示音和前台显示。
- 不使用 Codex Hook，也不修改 `config.toml`。

## 环境要求

- Windows 10 或 Windows 11
- Codex Desktop，并支持本地 Skills
- PowerShell 7（命令名为 `pwsh`）
- Git；如果不使用 Git，也可以在 GitHub 页面选择 **Code → Download ZIP**

## 5 分钟快速开始

### 第一步：下载并安装

打开 PowerShell 7，运行：

```powershell
git clone https://github.com/GODGOD126/codex-notifications.git
cd codex-notifications
pwsh -NoProfile -File .\scripts\install.ps1
```

如果下载的是 ZIP，请先解压，在解压后的目录中打开 PowerShell 7，然后只运行最后一条安装命令。

安装程序会：

- 把 Skill 复制到 `%USERPROFILE%\.codex\skills\codex-notifications`
- 创建 `%LOCALAPPDATA%\CodexNotifications\settings.json`
- 在桌面创建“Codex 提醒设置”快捷方式

安装完成后退出并重新打开 Codex，让它发现新 Skill。

如果不需要桌面快捷方式：

```powershell
pwsh -NoProfile -File .\scripts\install.ps1 -NoDesktopShortcut
```

### 第二步：告诉 Codex 什么时候调用

把下面的规则添加到以下任一位置：

- **所有项目生效：** `%USERPROFILE%\.codex\AGENTS.md`
- **仅当前项目生效：** 当前项目根目录下的 `AGENTS.md`

文件不存在时可以新建。项目内的规则优先级高于全局规则。

追加以下内容：

```text
当任务必须由用户本人介入才能安全继续时，例如登录、扫码、验证码、授权、提供用户专属信息或完成必须人工操作的步骤，调用 $codex-notifications 弹窗提醒用户。普通进度、可自行解决的错误和任务完成不要提醒。调用后不得结束当前任务，必须按 Skill 规则持续等待用户的真实回应。不使用 Hook。
```

修改指令后，新建一个 Codex 任务，确保新规则被加载。

### 第三步：显示一次测试弹窗

以下命令只用于确认安装和界面是否正常，不会修改 Codex 配置：

```powershell
$skillRoot = Join-Path $env:USERPROFILE '.codex\skills\codex-notifications'
$created = & "$skillRoot\scripts\new-dialog.ps1" `
  -Title '安装成功' `
  -Message '如果你看到这个窗口，说明弹窗组件已经可以正常运行。' `
  -Options @('显示正常', '需要排查') `
  -ProjectName 'codex-notifications' `
  -ConversationName '首次安装测试' `
  -DurationSeconds 120 `
  -NoSound | ConvertFrom-Json
& "$skillRoot\scripts\show-dialog.ps1" -RequestDirectory $created.requestDirectory
```

正常情况下，你会看到一个暖白色置顶窗口：左上角显示来源，选择任一选项会立即提交；也可以在输入框中填写文字后点击箭头。测试弹窗两分钟后自动关闭。

### 第四步：正常使用

你不需要每次手动启动脚本。照常给 Codex 下任务即可，例如：

- “帮我查看网站上的订单审核状态。”
- “帮我把这份内容发布到后台。”
- “检查一下我的账号为什么无法完成设置。”

如果过程中遇到必须由你完成的登录、扫码、验证码、授权或专属信息输入，Codex 才会弹窗。完成操作或回复后，原任务应继续执行；普通进度和任务完成不会弹窗。

## 更新

如果使用 Git 克隆安装：

```powershell
cd codex-notifications
git pull --ff-only
pwsh -NoProfile -File .\scripts\install.ps1
```

然后重新启动 Codex。使用 ZIP 安装时，请重新下载最新 ZIP，解压后再次运行安装脚本。

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

## 常见问题

### 找不到 `pwsh`

安装 [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)，重新打开终端后运行 `pwsh --version`。建议不要使用旧版 Windows PowerShell 5.1 执行包含中文内容的脚本。

### Codex 没有自动调用 Skill

确认 `%USERPROFILE%\.codex\skills\codex-notifications\SKILL.md` 已存在，完全退出并重新打开 Codex，然后检查调用规则是否已写入全局或项目 `AGENTS.md`。只有真实需要用户介入时才会触发，普通任务不会弹窗。

### 测试命令没有显示窗口

双击“Codex 提醒设置”，确认提醒已启用，并退出独占全屏程序后重试。普通窗口无法覆盖锁屏和 UAC 安全桌面。

### 弹窗中的任务名称不正确

正常执行时，Skill 会按当前 `CODEX_THREAD_ID` 从 Codex 官方任务列表读取侧边栏标题。读取不到可信标题时只显示短任务 ID，不会使用第一条消息冒充标题。

## 开发者验证（普通安装无需执行）

```powershell
pwsh -NoProfile -File .\tests\run-tests.ps1
$env:PYTHONUTF8 = '1'
py -3 "$env:USERPROFILE\.codex\skills\.system\skill-creator\scripts\quick_validate.py" .
```

第二条命令需要 Python Launcher 和 Codex 自带的 `skill-creator`。普通用户只需完成“第三步”的测试弹窗即可。

## 限制

- 普通桌面窗口无法覆盖锁屏和 UAC 安全桌面。
- 部分独占全屏游戏可能阻止置顶窗口显示。
- Codex 当前任务必须保持运行；弹窗不能唤醒已经结束的任务。

## 隐私与安全

- 不含遥测或网络请求。
- 安装程序不保存凭据。
- 临时请求文件只保存在 `%LOCALAPPDATA%\CodexNotifications\requests`。
- 显示任务名时优先使用 Codex 官方任务列表。未显式传入任务名时，脚本只会以只读方式查询 `%USERPROFILE%\.codex\state_5.sqlite` 中用户明确设置的 `name` 字段，绝不会把第一条提示词当作标题。
- 除非当前任务明确设计了安全的数据生命周期，否则不要在弹窗中输入敏感信息。

## 许可证

[MIT](LICENSE)
