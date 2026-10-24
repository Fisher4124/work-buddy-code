# 会话记录（jsonl）字段说明

CodeBuddy CLI 把每次会话写成 JSONL，一行一条记录。

## 位置

```
%USERPROFILE%\.codebuddy\projects\<cwd-slug>\<session-id>.jsonl
```

`<cwd-slug>` = 会话启动时的当前目录，路径分隔符和冒号替换成 `-`：

| cwd | slug |
|---|---|
| `D:\proj` | `d-proj` |
| `C:\Users\alice` | `c-Users-alice` |

另有 `%USERPROFILE%\.codebuddy\sessions\<pid>.json`（进程存活时的索引，进程退出后可能被清理）。

## 常见记录类型

| type | 含义 | 关键字段 |
|---|---|---|
| `message` + `role=user` | 用户输入 | `content[]` 内含 `{"type":"input_text","text":...}` |
| `message` + `role=assistant` | 模型回复 | `content[]` 内含 `text` / `tool_use` 块 |
| `reasoning` | 推理过程 | `content`、`providerData.model` |
| `file-history-snapshot` | 文件改动快照 | `snapshot.trackedFileBackups` |

顶层通用字段：`id`、`parentId`（构成对话树）、`timestamp`（毫秒）、`sessionId`、`cwd`、`_meta.traceparent`。

## 快速查看

```bash
# 最近一次会话的文件路径
find "$USERPROFILE/.codebuddy/projects" -name '*.jsonl' -printf '%T@ %p\n' | sort -rn | head -1

# 最后几条记录的类型与角色
tail -3 <file> | grep -o '"type":"[^"]*"\|"role":"[^"]*"'
```

需要完整还原对话（用户说了什么、调了什么工具、工具返回什么）时，用 Python 逐行 `json.loads` 后按
`content[].type` 分别提取，不要用正则硬切，`text` 里可能含引号和换行。
