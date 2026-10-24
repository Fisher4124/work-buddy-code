#!/usr/bin/env bash
# cb_status.sh - 一眼看清 CodeBuddy 现在有没有在干活
#
# 用法：
#   bash cb_status.sh            # 用当前目录作为项目目录
#   bash cb_status.sh D:\proj      # 指定项目目录，看最近写入
#
# 输出四块：进程 / GPU / 磁盘活动 / 最近会话记录。
# 判定要点：
#   - 无 python.exe / node.exe 相关进程 + GPU 低 + 无新写入 => 已停摆（多半是崩了）
#   - 进程在 + GPU 忙 + 日志不动 => 可能是 tqdm 缓冲，仍在跑
# 注意：本脚本只用 bash 可调用的命令。要进程命令行或事件日志，
# 改用 WorkBuddy 的 PowerShell 工具（bash 里调 powershell 会被安全策略拦截）。

set -u

PROJ="${1:-$(pwd)}"
CFG="${USERPROFILE:-$HOME}/.codebuddy"

echo "== 时间 =="
date '+%Y-%m-%d %H:%M:%S'

echo
echo "== 进程 =="
PY=$(tasklist 2>/dev/null | grep -ci '^python.exe')
ND=$(tasklist 2>/dev/null | grep -ci '^node.exe')
IDE=$(tasklist 2>/dev/null | grep -ci 'CodeBuddy')
echo "python.exe : $PY"
echo "node.exe   : $ND"
echo "CodeBuddy  : $IDE （IDE 进程数，不作为任务是否运行的依据）"
if [ "$PY" -gt 0 ] || [ "$ND" -gt 0 ]; then
  tasklist 2>/dev/null | grep -E '^(python|node)\.exe' | awk '{printf "  %-12s pid=%-7s mem=%s %s\n", $1, $2, $5, $6}'
fi

echo
echo "== GPU =="
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu \
    --format=csv,noheader 2>/dev/null || echo "nvidia-smi 执行失败"
else
  echo "无 nvidia-smi"
fi

echo
echo "== 磁盘活动（$PROJ，最近 10 个写入）=="
if [ -d "$PROJ" ]; then
  find "$PROJ" -type f -newermt '-24 hours' 2>/dev/null \
    | while read -r f; do printf '%s %s\n' "$(date -r "$f" '+%m-%d %H:%M:%S' 2>/dev/null)" "$f"; done \
    | sort -r | head -10
  echo "--- 最近一次写入距今 ---"
  NEWEST=$(find "$PROJ" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
  if [ -n "${NEWEST:-}" ]; then
    echo "$NEWEST  ($(date -r "$NEWEST" '+%H:%M:%S'))"
  else
    echo "（目录内无文件）"
  fi
else
  echo "目录不存在：$PROJ"
fi

echo
echo "== 最近会话记录 =="
if [ -d "$CFG/projects" ]; then
  LATEST=$(find "$CFG/projects" -name '*.jsonl' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
  if [ -n "${LATEST:-}" ]; then
    echo "文件：$LATEST"
    echo "修改：$(date -r "$LATEST" '+%m-%d %H:%M:%S')"
    echo "--- 最后 3 条记录（type / role）---"
    tail -3 "$LATEST" | grep -o '"type":"[^"]*"\|"role":"[^"]*"' | paste - - 2>/dev/null
  else
    echo "无会话记录"
  fi
else
  echo "无 projects 目录：$CFG/projects"
fi

echo
echo "== 最近日志 =="
find "$CFG/logs" -name '*.log' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -3 \
  | while read -r ts p; do echo "$(date -d @"${ts%%.*}" '+%m-%d %H:%M:%S' 2>/dev/null || echo "$ts")  $p"; done
