[CmdletBinding()]
param(
    [switch]$Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FreeBytes {
    $drive = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.Name -eq 'C:\' }
    if ($null -eq $drive) {
        throw 'C: drive was not found.'
    }
    return [int64]$drive.AvailableFreeSpace
}

function Get-DirectorySizeBytes {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return [int64]0
    }

    try {
        $measurement = Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum
        if ($null -eq $measurement.Sum) {
            return [int64]0
        }
        return [int64]$measurement.Sum
    }
    catch {
        return [int64]0
    }
}

function New-CacheTarget {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Path,
        [string[]]$ProcessNames = @()
    )

    [pscustomobject]@{
        Label        = $Label
        Path         = [System.IO.Path]::GetFullPath($Path)
        ProcessNames = @($ProcessNames)
    }
}

function Get-RunningProcessNames {
    param([string[]]$Names)

    $running = foreach ($processName in $Names) {
        if (Get-Process -Name $processName -ErrorAction SilentlyContinue) {
            $processName
        }
    }
    return @($running | Sort-Object -Unique)
}

function Add-BrowserTargets {
    param(
        [Parameter(Mandatory)][string]$BrowserName,
        [Parameter(Mandatory)][string]$UserDataPath,
        [Parameter(Mandatory)][string]$ProcessName
    )

    if (-not (Test-Path -LiteralPath $UserDataPath -PathType Container)) {
        return @()
    }

    $profiles = Get-ChildItem -LiteralPath $UserDataPath -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' }
    $relativeCaches = @('Cache', 'Code Cache', 'GPUCache', 'Service Worker\CacheStorage')

    $targets = foreach ($profile in $profiles) {
        foreach ($relativeCache in $relativeCaches) {
            New-CacheTarget -Label "$BrowserName $($profile.Name) $relativeCache" `
                -Path (Join-Path $profile.FullName $relativeCache) -ProcessNames @($ProcessName)
        }
    }
    return @($targets)
}

$userProfilePath = [Environment]::GetFolderPath('UserProfile')
$localAppDataPath = [Environment]::GetFolderPath('LocalApplicationData')
$roamingAppDataPath = [Environment]::GetFolderPath('ApplicationData')
$normalizedUserRoot = [System.IO.Path]::GetFullPath($userProfilePath).TrimEnd('\')
$normalizedWindowsTemp = [System.IO.Path]::GetFullPath('C:\Windows\Temp').TrimEnd('\')

$cacheTargets = @(
    (New-CacheTarget -Label 'User Temp' -Path (Join-Path $localAppDataPath 'Temp'))
    (New-CacheTarget -Label 'Windows Temp' -Path 'C:\Windows\Temp')
    (New-CacheTarget -Label 'Playwright browsers' -Path (Join-Path $localAppDataPath 'ms-playwright'))
    (New-CacheTarget -Label 'Chromium snapshots' -Path (Join-Path $userProfilePath '.chromium-browser-snapshots'))
    (New-CacheTarget -Label 'Go build cache' -Path (Join-Path $localAppDataPath 'go-build'))
    (New-CacheTarget -Label 'pnpm cache' -Path (Join-Path $localAppDataPath 'pnpm-cache'))
    (New-CacheTarget -Label 'pip cache' -Path (Join-Path $localAppDataPath 'pip\Cache'))
    (New-CacheTarget -Label 'NVIDIA DXCache' -Path (Join-Path $localAppDataPath 'NVIDIA\DXCache'))
    (New-CacheTarget -Label 'LarkShell update' -Path (Join-Path $roamingAppDataPath 'LarkShell\update') -ProcessNames @('Lark', 'Feishu'))
    (New-CacheTarget -Label 'LarkShell CodeCache' -Path (Join-Path $roamingAppDataPath 'LarkShell\CodeCache') -ProcessNames @('Lark', 'Feishu'))
    (New-CacheTarget -Label 'LarkShell GrShaderCache' -Path (Join-Path $roamingAppDataPath 'LarkShell\GrShaderCache') -ProcessNames @('Lark', 'Feishu'))
    (New-CacheTarget -Label 'LarkShell sdk_storage' -Path (Join-Path $roamingAppDataPath 'LarkShell\sdk_storage') -ProcessNames @('Lark', 'Feishu'))
    (New-CacheTarget -Label 'Trae logs' -Path (Join-Path $roamingAppDataPath 'Trae\logs') -ProcessNames @('Trae'))
    (New-CacheTarget -Label 'Trae Cache' -Path (Join-Path $roamingAppDataPath 'Trae\Cache') -ProcessNames @('Trae'))
    (New-CacheTarget -Label 'Trae Code Cache' -Path (Join-Path $roamingAppDataPath 'Trae\Code Cache') -ProcessNames @('Trae'))
    (New-CacheTarget -Label 'Trae GPUCache' -Path (Join-Path $roamingAppDataPath 'Trae\GPUCache') -ProcessNames @('Trae'))
    (New-CacheTarget -Label 'Trae CachedData' -Path (Join-Path $roamingAppDataPath 'Trae\CachedData') -ProcessNames @('Trae'))
    (New-CacheTarget -Label 'Trae blob_storage' -Path (Join-Path $roamingAppDataPath 'Trae\blob_storage') -ProcessNames @('Trae'))
    (New-CacheTarget -Label 'Trae Crashpad reports' -Path (Join-Path $roamingAppDataPath 'Trae\Crashpad\reports') -ProcessNames @('Trae'))
    (New-CacheTarget -Label 'Discord downloads' -Path (Join-Path $localAppDataPath 'Discord\download') -ProcessNames @('Discord'))
    (New-CacheTarget -Label 'Discord packages' -Path (Join-Path $localAppDataPath 'Discord\packages') -ProcessNames @('Discord'))
    (New-CacheTarget -Label 'DouyuLive logs' -Path (Join-Path $localAppDataPath 'DouyuLive\logs') -ProcessNames @('DouyuLive'))
    (New-CacheTarget -Label 'DouyuLive cache' -Path (Join-Path $localAppDataPath 'DouyuLive\cache') -ProcessNames @('DouyuLive'))
    (New-CacheTarget -Label 'VS Code cached VSIX' -Path (Join-Path $roamingAppDataPath 'Code\CachedExtensionVSIXs') -ProcessNames @('Code'))
    (New-CacheTarget -Label 'Cursor cached VSIX' -Path (Join-Path $roamingAppDataPath 'Cursor\CachedExtensionVSIXs') -ProcessNames @('Cursor'))
    (New-CacheTarget -Label 'Qoder cached VSIX' -Path (Join-Path $roamingAppDataPath 'Qoder\CachedExtensionVSIXs') -ProcessNames @('Qoder'))
)

$cacheTargets += Add-BrowserTargets -BrowserName 'Chrome' `
    -UserDataPath (Join-Path $localAppDataPath 'Google\Chrome\User Data') -ProcessName 'chrome'
$cacheTargets += Add-BrowserTargets -BrowserName 'Edge' `
    -UserDataPath (Join-Path $localAppDataPath 'Microsoft\Edge\User Data') -ProcessName 'msedge'

$blockedExactPaths = @(
    'C:\Windows',
    'C:\Program Files',
    'C:\Program Files (x86)',
    'C:\ProgramData\Microsoft\Windows',
    'C:\System Volume Information'
) | ForEach-Object { [System.IO.Path]::GetFullPath($_).TrimEnd('\') }

$startingFreeBytes = Get-FreeBytes
$targetResults = foreach ($target in $cacheTargets) {
    $result = [ordered]@{
        Label              = $target.Label
        Path               = $target.Path
        Status             = 'Missing'
        BeforeGB           = 0.0
        AfterGB            = 0.0
        RemovedGB          = 0.0
        RunningProcesses   = @()
        SkippedReparseItem = 0
        Errors             = 0
        Note               = ''
    }

    if (-not (Test-Path -LiteralPath $target.Path -PathType Container)) {
        [pscustomobject]$result
        continue
    }

    $item = Get-Item -LiteralPath $target.Path -Force
    $normalizedPath = [System.IO.Path]::GetFullPath($item.FullName).TrimEnd('\')
    $expectedPath = [System.IO.Path]::GetFullPath($target.Path).TrimEnd('\')
    $beforeBytes = Get-DirectorySizeBytes -Path $normalizedPath
    $result.BeforeGB = [math]::Round($beforeBytes / 1GB, 3)
    $result.AfterGB = $result.BeforeGB

    $runningProcesses = @(Get-RunningProcessNames -Names $target.ProcessNames)
    $result.RunningProcesses = @($runningProcesses)
    if ($runningProcesses.Count -gt 0) {
        $result.Status = 'SkippedRunning'
        $result.Note = 'Close the related application and rerun the preview.'
        [pscustomobject]$result
        continue
    }

    $isUnderUserProfile = $normalizedPath.StartsWith(
        $normalizedUserRoot + '\',
        [System.StringComparison]::OrdinalIgnoreCase
    )
    $isWindowsTemp = $normalizedPath.Equals(
        $normalizedWindowsTemp,
        [System.StringComparison]::OrdinalIgnoreCase
    )
    $isBlockedExact = $blockedExactPaths -contains $normalizedPath
    $isReparseTarget = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0

    if (-not $normalizedPath.Equals($expectedPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        (-not $isUnderUserProfile -and -not $isWindowsTemp) -or
        $isBlockedExact -or
        $isReparseTarget) {
        $result.Status = 'Blocked'
        $result.Note = 'Target failed exact-path, root, protected-path, or reparse-point validation.'
        [pscustomobject]$result
        continue
    }

    if (-not $Execute) {
        $result.Status = 'WouldClean'
        $result.Note = 'Dry-run only; no files were deleted.'
        [pscustomobject]$result
        continue
    }

    $children = @(Get-ChildItem -LiteralPath $normalizedPath -Force -ErrorAction SilentlyContinue)
    foreach ($child in $children) {
        if (($child.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            $result.SkippedReparseItem++
            continue
        }
        try {
            Remove-Item -LiteralPath $child.FullName -Recurse -Force -ErrorAction Stop
        }
        catch {
            $result.Errors++
        }
    }

    $afterBytes = Get-DirectorySizeBytes -Path $normalizedPath
    $removedBytes = [math]::Max([int64]0, $beforeBytes - $afterBytes)
    $result.AfterGB = [math]::Round($afterBytes / 1GB, 3)
    $result.RemovedGB = [math]::Round($removedBytes / 1GB, 3)
    $result.Status = if ($afterBytes -eq 0 -and $result.Errors -eq 0 -and $result.SkippedReparseItem -eq 0) {
        'Cleaned'
    } else {
        'PartiallyCleaned'
    }
    if ($result.Status -eq 'PartiallyCleaned') {
        $result.Note = 'Some files were locked, recreated, failed deletion, or were reparse points.'
    }
    [pscustomobject]$result
}

$endingFreeBytes = Get-FreeBytes
$report = [pscustomobject]@{
    GeneratedAt      = (Get-Date).ToString('o')
    Mode             = if ($Execute) { 'Execute' } else { 'DryRun' }
    StartingFreeGB   = [math]::Round($startingFreeBytes / 1GB, 3)
    EndingFreeGB     = [math]::Round($endingFreeBytes / 1GB, 3)
    DriveFreeDeltaGB = [math]::Round(($endingFreeBytes - $startingFreeBytes) / 1GB, 3)
    Targets          = @($targetResults | Sort-Object BeforeGB -Descending)
    Preserved        = @(
        'Browser profiles, passwords, cookies, bookmarks, extensions, and history databases',
        'Editor project and workspace state',
        'WeChat and Tencent databases and chat data',
        'Downloads, Desktop, Documents, and Recycle Bin',
        'Program Files, Windows core folders, pagefile, swapfile, restore data, and component store',
        'Docker images, containers, volumes, and WSL data',
        'Hibernation configuration'
    )
}

$report | ConvertTo-Json -Depth 7
