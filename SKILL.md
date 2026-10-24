---
name: work-buddy-code
description: 连接并监控本机 CodeBuddy CLI（CodeBuddy Code）——用无头模式把编码/跑脚本任务派给 CodeBuddy 并取回结果，或读取它的会话记录、日志、进程与 GPU 状态来判断它现在在干什么、是不是卡住了、为什么失败。当用户提到 CodeBuddy、要让 CodeBuddy 干活、或要查它的任务进度/是否卡死/崩溃原因时使用本技能。
agent_created: true
---

# CodeBuddy 互联与监控

## 用途

把本机安装的 CodeBuddy CLI（`codebuddy` / `cbc`）当成可被调用的执行器，并具备观察它的能力：

- **派活**：以无头模式（`-p`）把任务交给 CodeBuddy 拿回完整输出，必要时允许其改文件。
- **监控**：读取会话记录（jsonl）、运行日志、进程与 GPU 状态，回答"它在干什么 / 是不是卡住了 / 为什么失败"。

**边界**：CodeBuddy **IDE**（`CodeBuddy CN.exe`）的内部状态无法读取，只能通过进程存活、磁盘写入、系统事件日志间接判断。IDE 与 CLI 的登录凭证互不相通。

## 快速开始

三条命令覆盖 90% 的场景（脚本都在本技能 `scripts/` 下）：

| 目的 | 命令 |
|---|---|
| 确认能否调用 | `bash scripts/cb_call.sh -p "只回复两个字：在线" --output-format text` |
| 派活并允许改文件 | `bash scripts/cb_call.sh -p "<任务描述>" --permission-mode acceptEdits` |
| 看它现在在干什么 | `bash scripts/cb_status.sh [项目目录]` |

首次使用或换机器时，先跑 `bash scripts/cb_install.sh` 安装/校验环境。

## 关键事实（先读，否则必踩坑）

1. **禁止裸调 `codebuddy`。** WorkBuddy 会给子进程注入 `CODEBUDDY_CONFIG_DIR=<用户>\.workbuddy`，CLI 会去读 WorkBuddy 的配置目录，那里没有 CodeBuddy 凭证 → 报 `Authentication required`，而**登录其实早就成功了**。必须用 `scripts/cb_call.sh`（它用 `env -i` 剥离继承环境，并把配置目录固定到 `~\.codebuddy`）。
2. **默认端口常被占用。** 不加 `--port` 会报 `EADDRINUSE ... 127.0.0.1:58341`。`cb_call.sh` 默认带 `--port 58430`。
3. **IDE 登录 ≠ CLI 登录。** IDE 账号数据在 `%APPDATA%\CodeBuddy CN`（Electron），CLI 凭证在 `~\.codebuddy`。CLI 首次需在真实终端启动 `codebuddy` 走 `/login` 浏览器授权，且**必须等回到对话界面再退出**，否则凭证不落盘。
4. **无头模式默认不允许改文件。** 需要写文件/跑命令时加 `--permission-mode acceptEdits`。
5. **bash 里调用 PowerShell 会被安全策略拦截**，`schtasks.exe`、`reg.exe` 也在程序黑名单。需要进程命令行、事件日志时，用 WorkBuddy 的 PowerShell 工具直接执行，不要写进 bash 脚本。

## 派活流程

1. 先跑连通性检查，确认返回的是内容而不是 `Authentication required`。
2. `cd` 到目标任务目录再调用（CLI 以 cwd 为工作根）。
3. 要实时过程用 `--output-format stream-json`；只要最终结果用默认 `text` 或 `json`。
4. 需要结构化结果时用 `--json-schema` 约束输出。
5. 调用结束后核对产物（文件是否存在、大小是否合理），不要只信它的自述。

## 监控与诊断流程

**第一步：判断"在跑"还是"已死"。** 跑 `bash scripts/cb_status.sh <项目目录>`，看三项：

- 是否有 `python.exe` / `node.exe` 在执行任务 → 没有即进程已退出
- GPU 利用率 → 长时间 0~10% 且无相关进程，说明没在算
- 最近文件写入时间 → 超过 15 分钟无新字节，基本可判定停摆

**第二步：区分"慢"和"崩"。** 两者表面都是"没动静"，证据不同：

- 日志停在某行且**再无新字节**、进程消失、stderr 为空 → **原生崩溃**（如 PyTorch `c10.dll` 访问违例 0xc0000005），不是卡住
- 进程仍在、GPU 有占用、只是进度条不动 → 多为 tqdm 输出到文件被缓冲（4KB 才 flush），属于"看着卡、其实在跑"

查崩溃读 Windows 事件日志（用 PowerShell 工具，不用 bash）：

```powershell
Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddHours(-2)} -MaxEvents 10 |
  Where-Object { $_.Message -match 'python|node' } | ForEach-Object { ($_.Message -replace "\s+"," ") }
```

**第三步：读会话记录还原它做过什么。** 会话 jsonl 位于 `~\.codebuddy\projects\<cwd-slug>\<session>.jsonl`，slug 由 cwd 的路径分隔符替换成 `-` 得到（`D:\proj` → `d-proj`）。每条记录含 `type`（`message` / `reasoning` / `file-history-snapshot`）、`role`、`content`（数组，块类型 `input_text` / `text` / `tool_use` / `tool_result`）。字段细节见 `references/session-format.md`。

## 环境约定

- CLI 安装位置（npm 局部安装，不污染全局）：`%LOCALAPPDATA%\codebuddy-cli`，可用 `CB_HOME` 覆盖
- 可执行：`<CB_HOME>\node_modules\.bin\codebuddy`，同目录还有短别名 `cbc`
- 配置目录：`%USERPROFILE%\.codebuddy`，可用 `CB_CONFIG` 覆盖
- 端口：默认 58341，常被占用；本技能统一改用 58430，可用 `CB_PORT` 覆盖

## 平台适配

脚本按 **Windows + Git Bash** 编写并实测（`tasklist`、`nvidia-smi`、`cygpath` 为 Windows 语义）。
移植到 macOS / Linux 时需改三处：

| 位置 | Windows 写法 | 替代 |
|---|---|---|
| `cb_status.sh` 进程检查 | `tasklist` | `ps -eo pid,comm` |
| `cb_call.sh` 配置目录转换 | `cygpath -w` | 不需要，直接用 POSIX 路径 |
| `references/troubleshooting.md` 事件日志 | `Get-WinEvent` | `dmesg` / `journalctl` |

## 故障排查

遇到登录失败、端口冲突、崩溃、输出目录找不到等情况，按 `references/troubleshooting.md` 的对照表逐条核对，不要凭猜测改配置。
