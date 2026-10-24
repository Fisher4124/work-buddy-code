# work-buddy-code

一个 WorkBuddy skill：**调用、观测本机的 CodeBuddy CLI**。

A WorkBuddy skill that connects to your local **CodeBuddy CLI**: dispatch coding tasks in headless mode, and inspect what it is actually doing (or why it died).

> **非官方项目。** 与腾讯 / CodeBuddy 官方无关，不包含、不分发 CodeBuddy 本体。使用前需自行安装并登录 CodeBuddy CLI，遵守其服务条款。

---

## 它解决什么问题

WorkBuddy 与 CodeBuddy 是两个独立产品，目前没有官方互通通道。本技能提供两条可用的桥：

1. **派活**：`codebuddy -p "<任务>"` 无头执行，拿回结构化输出，必要时允许其改文件。
2. **观测**：读取会话 jsonl、运行日志、进程与 GPU 状态，区分「它在慢」和「它已经崩了」。

同时把一批真实踩过的坑写成了对照表——这些坑不写下来，每次都要重新踩一遍。

## 快速开始

```bash
# 1. 安装 / 校验（幂等，可重复运行）
bash scripts/cb_install.sh

# 2. 连通性测试
bash scripts/cb_call.sh -p "只回复两个字：在线" --output-format text

# 3. 派活并允许改文件
bash scripts/cb_call.sh -p "在当前目录创建 hello.txt" --permission-mode acceptEdits

# 4. 看它现在在干什么
bash scripts/cb_status.sh D:\proj
```

把本目录整体复制到 `~/.workbuddy/skills/work-buddy-code/` 即可被 WorkBuddy 识别为技能。

## 不能直接调 `codebuddy`

WorkBuddy 会向子进程注入 `CODEBUDDY_CONFIG_DIR=<用户>\.workbuddy`。CLI 会把这个目录当成自己的配置目录，而那里没有 CodeBuddy 凭证，于是报：

```
Authentication required. Please use /login command to sign in to your account
```

**即使终端里明明已经登录成功。**

`cb_call.sh` 的做法：用 `env -i` 构造干净环境，只放行必要变量，并把 `CODEBUDDY_CONFIG_DIR` 固定回 `~/.codebuddy`。

```bash
exec env -i \
  HOME=... USERPROFILE=... SystemRoot=... TEMP=... \
  CODEBUDDY_CONFIG_DIR="C:\Users\<you>\.codebuddy" \
  PATH="/usr/bin:/bin:<codebuddy bin>:<node dir>:..." \
  "$CB_BIN" "$@" --port 58430
```

## 脚本一览

| 文件 | 作用 |
|---|---|
| `scripts/cb_call.sh` | 安全调用 CLI：环境隔离、配置目录固定、默认端口、node 自动定位 |
| `scripts/cb_status.sh` | 体检：进程 / GPU / 磁盘活动 / 最近会话记录 四段输出 |
| `scripts/cb_install.sh` | 幂等安装（npm 局部安装，不加 `-g`）+ 连通性自测 |
| `references/troubleshooting.md` | 现象 → 根因 → 处置 对照表 |
| `references/session-format.md` | 会话 jsonl 字段说明（还原它做过什么） |

可覆盖的环境变量：`CB_HOME`（安装根目录）、`CB_CONFIG`（配置目录）、`CB_PORT`（默认 58430）。

## 卡顿判断

两者表面都是「没动静」，证据不同：

| 证据 | 结论 |
|---|---|
| 进程消失 + GPU 空闲 + 日志再无新字节 + stderr 为空 | **原生崩溃**（如 PyTorch `c10.dll` 访问违例 `0xc0000005`），不是卡住 |
| 进程还在 + GPU 有占用 + 进度条不动 | 多半是 tqdm 输出重定向后按块缓冲（约 4KB 才 flush），其实在跑 |
| 日志停在某一步且文件 mtime 不再变化 | 看 `cb_status.sh` 的最近写入时间，超过 15 分钟基本可判定停摆 |

查崩溃（Windows）：

```powershell
Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddHours(-2)} -MaxEvents 10 |
  Where-Object { $_.Message -match 'python|node' } | ForEach-Object { ($_.Message -replace "\s+"," ") }
```

重点看 `错误模块名称`、`异常代码`，以及同一秒是否有其他进程一起崩（如 `dwm.exe` 同崩 → 显卡驱动异常）。

## 已知限制

- **平台**：脚本按 Windows + Git Bash 编写并实测；macOS / Linux 需替换 `tasklist`、`cygpath`、`Get-WinEvent`（见 SKILL.md「平台适配」）。
- **IDE 不可观测**：CodeBuddy IDE 的内部状态读不到，只能靠进程、磁盘写入、系统事件间接判断；IDE 与 CLI 的登录凭证互不连通。
- **安全策略**：部分环境下 `schtasks.exe`、`reg.exe` 会被程序黑名单拦截，bash 中调用 PowerShell 也可能被判定为绕过安全检查——需要时改用宿主的 PowerShell 工具。
- **无头模式默认不允许改文件**，写文件必须加 `--permission-mode acceptEdits`。

## License

MIT，见 [LICENSE](LICENSE)。
