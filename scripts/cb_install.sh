#!/usr/bin/env bash
# cb_install.sh - 安装 / 校验 CodeBuddy CLI 与调用环境（幂等，可重复运行）
#
# 做的事：
#   1. 检查 CLI 是否已安装（%LOCALAPPDATA%\codebuddy-cli）
#   2. 未安装则用 npm 局部安装（不加 -g，不污染全局环境）
#   3. 校验 node、版本、配置目录
#   4. 用 cb_call.sh 做一次真实连通性测试
#
# 安装后若想在普通终端直接敲 codebuddy，需要把
#   %LOCALAPPDATA%\codebuddy-cli\node_modules\.bin
# 加进用户 PATH——这一步要用 WorkBuddy 的 PowerShell 工具执行，bash 里改不了用户环境变量。

set -u

CB_HOME="${CB_HOME:-${LOCALAPPDATA:-$HOME/AppData/Local}/codebuddy-cli}"
CB_BIN="$CB_HOME/node_modules/.bin/codebuddy"
CFG="${USERPROFILE:-$HOME}/.codebuddy"

echo "== 1. node =="
if command -v node >/dev/null 2>&1; then
  echo "node $(node --version)"
else
  echo "PATH 中无 node，将尝试常见安装位置"
fi

echo
echo "== 2. CLI 安装状态 =="
if [ -f "$CB_BIN" ]; then
  echo "已安装：$CB_BIN"
else
  echo "未安装，开始局部安装到 $CB_HOME"
  mkdir -p "$CB_HOME" || exit 1
  npm install --prefix "$CB_HOME" @tencent-ai/codebuddy-code --no-fund --no-audit || {
    echo "安装失败。若为网络问题，可先设置镜像：npm config set registry https://registry.npmmirror.com" >&2
    exit 1
  }
fi

echo
echo "== 3. 版本与配置目录 =="
"$CB_BIN" --version 2>/dev/null || echo "版本获取失败"
if [ -d "$CFG" ]; then
  echo "配置目录存在：$CFG"
  [ -s "$CFG/mcp.json" ] && echo "  mcp.json 已配置" || echo "  mcp.json 为空（正常）"
else
  echo "配置目录不存在（首次运行 CLI 会自动创建）：$CFG"
fi

echo
echo "== 4. 连通性测试 =="
HERE="$(cd "$(dirname "$0")" && pwd)"
bash "$HERE/cb_call.sh" -p "只回复两个字：在线" --output-format text 2>&1 | tail -3

echo
echo "== 结论 =="
echo "若上面出现『在线』即调用链路正常；出现 Authentication required 则需在真实终端"
echo "运行 codebuddy → 选 Log in via Chinese Site → 浏览器授权 → 等回到对话界面再退出。"
