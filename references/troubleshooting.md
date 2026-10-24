# 故障排查对照表

按"现象 → 根因 → 处置"查，不要凭猜测改配置。

## 调用类

| 现象 | 根因 | 处置 |
|---|---|---|
| `Authentication required. Please use /login command`，但终端里明明登录成功 | WorkBuddy 注入了 `CODEBUDDY_CONFIG_DIR=<用户>\.workbuddy`，CLI 去读 WorkBuddy 的配置目录，那里没有凭证 | 用 `scripts/cb_call.sh` 调用（内部用 `env -i` 剥离环境并固定配置目录）。**不要**自己 export `CODEBUDDY_CONFIG_DIR` |
| 同上，且确实是首次使用 | CLI 凭证从未写入 | 在真实终端跑 `codebuddy` → 选 `Log in via Chinese Site` → 浏览器授权 → **必须等终端回到对话界面**再 `/exit`。中途关窗口凭证不落盘 |
| `listen EADDRINUSE: address already in use 127.0.0.1:58341` | 默认端口被别的实例占用 | 加 `--port <未占用端口>`，`cb_call.sh` 默认 58430 |
| `command not found: codebuddy` | 安装目录不在 PATH | 把 `%LOCALAPPDATA%\codebuddy-cli\node_modules\.bin` 加入用户 PATH（用 PowerShell 工具，bash 改不了） |
| 安装时 `irm ... \| iex` 被拦 | 安全策略禁止 `Invoke-Expression` 执行远程内容 | 改用 npm 局部安装（`cb_install.sh` 已内置） |
| 输出里出现 `wmic 不存在`、`pwsh 检测失败`、`reg.exe 被拦截` | 环境探测噪声，安全黑名单所致 | 忽略，与任务结果无关 |

## 任务停滞类

| 现象 | 根因 | 处置 |
|---|---|---|
| 日志停在某行、进程消失、stderr 为空 | **原生崩溃**（如 `c10.dll` 访问违例 `0xc0000005`），来不及写 traceback | 查事件日志（见下），重跑；若复现则查驱动/环境，不是脚本逻辑问题 |
| 进程还在、GPU 有占用、进度条不动 | tqdm 输出重定向到文件时按块缓冲（约 4KB 才 flush） | 不要据此判定卡死；看 GPU 与文件 mtime。想看实时进度改为输出到终端或禁用缓冲 |
| 日志和产物都找不到 | 脚本用相对路径，CLI 以 cwd 为根，产物落在 `<cwd>/<相对目录>` | 先确认脚本里的 cwd，再用绝对路径定位；不要猜目录名 |
| 监控脚本 `/lib` 里找不到刚跑完的文件 | 轮询路径写错且加了 `-ErrorAction SilentlyContinue`，错误被静默吞掉 | 去掉静默，先 `Test-Path` 确认路径存在再轮询 |

## 查崩溃（用 PowerShell 工具，不用 bash）

```powershell
Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddHours(-2)} -MaxEvents 10 |
  Where-Object { $_.Message -match 'python|node' } | ForEach-Object { ($_.Message -replace "\s+"," ") }
```

重点看三样：`错误模块名称`（哪个 DLL 崩的）、`异常代码`（`0xc0000005` 访问违例 / `0xc0000409` 栈溢出）、
是否同一秒有其他进程也崩（例如 `dwm.exe` 同崩 → 显卡驱动/显示栈异常）。

## 系统能力限制

- `schtasks.exe`、`reg.exe` 在程序黑名单，无法创建计划任务或读写注册表。
- bash 中调用 PowerShell 会被判定为绕过安全检查，必须改用 WorkBuddy 的 PowerShell 工具。
- 后台看守类脚本跑在 WorkBuddy 的受管后台任务里，关闭 WorkBuddy 即失效；不要向用户承诺"关掉应用也会执行"。
