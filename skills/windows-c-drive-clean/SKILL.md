---
name: windows-c-drive-clean
description: Safely clean a Windows C: drive and investigate high disk usage. Use this skill whenever the user asks to clean C drive, free Windows disk space, reduce used storage, find what is occupying C:, clean AppData/cache/temp files, handle Windows.old/pagefile/restore points, or wants an aggressive-but-safe Windows 10/11 storage cleanup workflow.
---

# Windows C Drive Clean

Use this skill to help a user reclaim space on a Windows C: drive without breaking core Windows or actively used software. Work in tiers: measure first, clean rebuildable/cache data, then move to reviewed personal/app data, and only then suggest uninstalls or admin-only Windows storage cleanup.

## Bundled Scripts

Resolve this skill's installed directory from the location of this `SKILL.md`.
Run the following commands from that directory; no machine-specific installation path is required.

1. Measure usage with `.\scripts\measure-c-drive.ps1`. Add `-Deep` only when a larger inventory is needed.
2. Preview exact cleanup targets with `.\scripts\clean-safe-caches.ps1`. The default mode does not delete files.
3. Show the targets to the user and obtain approval for that cleanup before running `.\scripts\clean-safe-caches.ps1 -Execute`.
4. Measure again and report the change in free space.

The scripts discover user folders at runtime. The cleanup script skips related applications it detects as running; close other applications using the selected caches before execution. Its fixed target list covers only part of the candidates discussed below. Other cleanup actions require separate review.

Reports contain local paths and may include personal filenames when `-Deep` is used. Keep reports private and redact them before sharing. Do not commit reports, local profiles, or machine-specific configuration with this skill.

## Safety Rules

- Start read-only. Record current C: total/free/used space before any deletion.
- Never manually delete core Windows or program folders:
  - `C:\Windows`
  - `C:\Program Files`
  - `C:\Program Files (x86)`
  - `C:\ProgramData\Microsoft\Windows`
  - `C:\System Volume Information`
  - `pagefile.sys`
  - `swapfile.sys`
- Do not reduce or disable pagefile unless the user explicitly accepts stability risk.
- Close target apps before cleaning their caches: Chrome, Edge, WeChat/Tencent, Lark/Feishu, Trae, VS Code/Cursor, Discord, Douyin, Docker, and other apps whose cache will be touched.
- Treat chat databases and app profiles as personal data. Preserve by default:
  - WeChat/Tencent databases such as `message_*.db`, `biz_message_*.db`, `message_fts.db`, `nt_msg.db`
  - browser profiles, passwords, cookies, bookmarks, extensions
  - editor project/workspace state unless the user approves deeper cleanup
- For destructive actions outside the workspace, use the approval/escalation path. Verify resolved absolute paths stay under the intended target roots before deleting.

## Tier 1: Measure And Explain

Run read-only checks first:

```powershell
[System.IO.DriveInfo]::GetDrives() |
  Where-Object {$_.Name -eq 'C:\'} |
  Select-Object Name,
    @{Name='TotalGB';Expression={[math]::Round($_.TotalSize/1GB,2)}},
    @{Name='FreeGB';Expression={[math]::Round($_.AvailableFreeSpace/1GB,2)}},
    @{Name='UsedGB';Expression={[math]::Round(($_.TotalSize-$_.AvailableFreeSpace)/1GB,2)}}
```

Map the usual large zones:

```powershell
$roots=@(
  'C:\Windows','C:\Program Files','C:\Program Files (x86)','C:\ProgramData',
  [Environment]::GetFolderPath('LocalApplicationData'),
  [Environment]::GetFolderPath('ApplicationData'),
  [Environment]::GetFolderPath('MyDocuments'),
  (Join-Path $env:USERPROFILE 'Downloads'),
  (Join-Path $env:USERPROFILE '.vscode'),
  (Join-Path $env:USERPROFILE '.cursor'),
  (Join-Path $env:USERPROFILE '.codex')
)
```

For each existing path, recursively sum file sizes. Also list top child directories inside AppData, Documents, Program Files, and ProgramData.

Call out accounting gaps honestly: visible folder sums often do not equal total used space because Windows may keep protected restore/shadow storage, reserved storage, NTFS metadata, locked files, or admin-only folders.

## Tier 2: Safe Rebuildable Cleanup

Clean these first after closing relevant apps:

- User temp: `AppData\Local\Temp`
- Browser caches only:
  - Chrome/Edge `Cache`
  - `Code Cache`
  - `GPUCache`
  - `Service Worker\CacheStorage`
  - component/extension CRX caches
  - Chrome optimization guide model folders
- Developer caches:
  - `AppData\Local\ms-playwright`
  - `AppData\Local\go-build`
  - `AppData\Local\pnpm-cache`
  - `AppData\Local\pip\Cache`
  - Electron cache folders
- App caches/logs:
  - Trae/Trae CN `logs`, `Cache`, `CachedData`, `GPUCache`, `Crashpad`
  - LarkShell/Feishu `update`, `CodeCache`, shader caches, obvious cache-like model folders
  - VS Code/Cursor/Qoder cached extension VSIX trash
  - Discord old app versions and package/download cache
  - NVIDIA `DXCache`
  - updater `installer.exe` files under app-specific updater folders

Use strict path allowlists before deleting. Prefer deleting whole cache directories only when the app can rebuild them. Some cache folders may remain if files are locked.

## Tier 3: Reviewed Large Files

After cache cleanup, find files larger than 50-100 MB in user-controlled locations. Prioritize:

- installers: `.exe`, `.msi`
- APKs
- downloaded archives: `.zip`, `.7z`, `.rar`
- videos/audio: `.mp4`, `.mov`, `.wav`
- browser/network captures: `.har`
- duplicate transferred files

For WeChat/Tencent folders such as `Documents\xwechat_files`, delete only reviewed transferred files by default. Avoid database folders and `.db` files unless the user explicitly wants to lose local chat/search/offline history.

## Tier 4: Admin-Only Windows Cleanup

If the user needs a large target like 60 GB and normal cleanup is not enough, explain that admin-only storage may be the remaining source. Ask the user to run an elevated terminal or use Windows UI.

Useful admin checks:

```powershell
vssadmin list shadowstorage
Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore
Dism.exe /Online /Cleanup-Image /StartComponentCleanup
```

Use Windows Settings or Disk Cleanup as Administrator for:

- old restore points/shadow copies
- Windows Update cleanup
- Delivery Optimization files
- temporary Windows files
- Recycle Bin, if approved

Keep the latest restore point when possible. Do not manually delete from `System Volume Information`.

## Tier 5: Uninstall Or Move

Once safe cleanup is exhausted, identify uninstall/move candidates instead of deleting installed app folders manually:

- Docker Desktop and Docker/WSL data
- Visual Studio workloads and Windows SDK components
- WSL distributions
- Office only if the user truly does not need it
- large editor extension sets
- large chat/media archives that can be moved to another drive

Use official uninstallers, Windows Apps & Features, Visual Studio Installer, Docker cleanup tools, or app storage-management settings. Do not remove `Program Files` folders by hand except for clearly orphaned folders after uninstall and explicit approval.

## Reporting Format

End with:

- starting free space
- final free space
- GB reclaimed
- what was cleaned
- what was deliberately preserved
- remaining largest candidates
- whether admin-only cleanup or app uninstalls are needed for the user's target

Be candid when there is no more safe junk. A full C: drive is often real installed software, user data, pagefile, Windows component store, restore points, or protected storage rather than disposable cache.
