# open-skills

可复用的个人技能集合。每个 skill 的说明和配套脚本放在 `skills/<skill-name>/` 下。

| Skill | 用途 |
| --- | --- |
| [windows-c-drive-clean](skills/windows-c-drive-clean/SKILL.md) | Windows C 盘空间分析、缓存清理预览和分级清理流程 |

将对应的整个 skill 文件夹复制到所用工具的 skills 目录，保留 `SKILL.md` 与 `scripts/` 的相对位置。

## Windows C Drive Clean

在 `skills/windows-c-drive-clean/` 目录打开 PowerShell：

```powershell
# 只读分析
.\scripts\measure-c-drive.ps1

# 预览清理目标，不删除文件
.\scripts\clean-safe-caches.ps1

# 审核目标并关闭相关应用后，执行已确认的清理
.\scripts\clean-safe-caches.ps1 -Execute
```

脚本使用运行时用户目录，不依赖作者的用户名或本机安装路径。测量脚本不采集窗口标题。
运行报告仍可能包含本机路径和私人文件名，请脱敏后再分享。仓库不包含个人运行报告、桌面旧脚本或私人下载文件清单。
