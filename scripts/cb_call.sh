#!/usr/bin/env bash
# cb_call.sh - 安全地调用本机 CodeBuddy CLI（无头模式）
#
# 为什么不直接跑 codebuddy：
#   WorkBuddy 会向子进程注入 CODEBUDDY_CONFIG_DIR=<用户>\.workbuddy，
#   CLI 会把它当成配置目录，那里没有 CodeBuddy 凭证，于是报
#   "Authentication required"——即使终端里明明已经登录成功。
#   本脚本用 env -i 剥离继承环境，并把配置目录固定回 ~/.codebuddy。
#
# 用法：
#   bash cb_call.sh -p "任务" --output-format text
#   bash cb_call.sh -p "任务" --permission-mode acceptEdits
#   bash cb_call.sh --help
#
# 可用环境变量覆盖：
#   CB_HOME     CLI 安装根目录（默认 %LOCALAPPDATA%\codebuddy-cli）
#   CB_CONFIG   CodeBuddy 配置目录（默认 %USERPROFILE%\.codebuddy）
#   CB_PORT     端口（默认 58430，避开默认端口被占用）

set -u

CB_HOME="${CB_HOME:-${LOCALAPPDATA:-$HOME/AppData/Local}/codebuddy-cli}"
CB_BIN="$CB_HOME/node_modules/.bin/codebuddy"
CB_CONFIG="${CB_CONFIG:-${USERPROFILE:-$HOME}/.codebuddy}"
CB_PORT="${CB_PORT:-58430}"

if [ ! -f "$CB_BIN" ]; then
  echo "未找到 CodeBuddy CLI: $CB_BIN" >&2
  echo "先运行: bash cb_install.sh" >&2
  exit 127
fi

# 定位 node（CLI 的启动脚本需要它）
NODE_BIN=""
if command -v node >/dev/null 2>&1; then
  NODE_BIN="$(command -v node)"
else
  for cand in \
    "${LOCALAPPDATA:-$HOME/AppData/Local}/Programs/nodejs/node.exe" \
    "/c/Program Files/nodejs/node.exe" \
    "$HOME"/.nvm/versions/node/*/bin/node \
    /usr/local/bin/node
  do
    [ -x "$cand" ] && NODE_BIN="$cand" && break
  done
fi
if [ -z "$NODE_BIN" ]; then
  echo "找不到 node，可执行文件需在 PATH 或安装到标准位置" >&2
  exit 127
fi
NODE_DIR="$(dirname "$NODE_BIN")"

# 配置目录转成 Windows 形式（CLI 是 Windows 原生程序）
CFG_WIN="$CB_CONFIG"
if command -v cygpath >/dev/null 2>&1; then
  CFG_WIN="$(cygpath -w "$CB_CONFIG" 2>/dev/null || echo "$CB_CONFIG")"
fi

# 未显式指定端口时补默认端口
HAS_PORT=0
for a in "$@"; do
  case "$a" in --port|--port=*) HAS_PORT=1 ;; esac
done
PORT_ARGS=()
[ "$HAS_PORT" -eq 0 ] && PORT_ARGS=(--port "$CB_PORT")

exec env -i \
  HOME="${HOME:-$USERPROFILE}" \
  USERPROFILE="${USERPROFILE:-$HOME}" \
  SystemRoot="${SystemRoot:-C:\\Windows}" \
  TEMP="${TEMP:-${LOCALAPPDATA:-$HOME/AppData/Local}/Temp}" \
  TMP="${TMP:-${LOCALAPPDATA:-$HOME/AppData/Local}/Temp}" \
  CODEBUDDY_CONFIG_DIR="$CFG_WIN" \
  CODEBUDDY_SKIP_GIT_BASH_CHECK=1 \
  PATH="/usr/bin:/bin:$(dirname "$CB_BIN"):$NODE_DIR:/c/Windows/system32:/c/Windows" \
  "$CB_BIN" "$@" "${PORT_ARGS[@]}"
