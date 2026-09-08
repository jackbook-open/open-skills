[CmdletBinding()]
param(
    [switch]$Deep,
    [ValidateRange(50, 10240)]
    [int]$LargeFileThresholdMB = 100,
    [ValidateRange(5, 100)]
    [int]$TopCount = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

$drive = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.Name -eq 'C:\' }
if ($null -eq $drive) {
    throw 'C: drive was not found.'
}

$cacheCandidates = foreach ($target in $cacheTargets) {
    $exists = Test-Path -LiteralPath $target.Path -PathType Container
    $sizeBytes = if ($exists) { Get-DirectorySizeBytes -Path $target.Path } else { [int64]0 }
    $runningProcesses = @(Get-RunningProcessNames -Names $target.ProcessNames)
    [pscustomobject]@{
        Label            = $target.Label
        Path             = $target.Path
        Exists           = $exists
        SizeGB           = [math]::Round($sizeBytes / 1GB, 3)
        RunningProcesses = @($runningProcesses)
        Status           = if (-not $exists) { 'Missing' } elseif ($runningProcesses.Count -gt 0) { 'AppRunning' } else { 'ReadyForDryRun' }
    }
}

$relatedProcessNames = @($cacheTargets.ProcessNames | ForEach-Object { $_ } | Sort-Object -Unique)
$relatedProcesses = foreach ($processName in $relatedProcessNames) {
    Get-Process -Name $processName -ErrorAction SilentlyContinue |
        Select-Object @{Name='Name';Expression={$_.ProcessName}}, Id
}

$topUserLocations = @()
$largeUserFiles = @()
if ($Deep) {
    $locationPaths = @(
        (Join-Path $userProfilePath 'Documents'),
        (Join-Path $userProfilePath 'Downloads'),
        (Join-Path $userProfilePath 'Desktop'),
        (Join-Path $userProfilePath '.m2'),
        (Join-Path $userProfilePath '.vscode'),
        (Join-Path $userProfilePath '.cursor'),
        (Join-Path $userProfilePath '.codex'),
        (Join-Path $userProfilePath 'go'),
        $localAppDataPath,
        $roamingAppDataPath
    ) | Sort-Object -Unique

    $topUserLocations = @(
        foreach ($locationPath in $locationPaths) {
            if (Test-Path -LiteralPath $locationPath -PathType Container) {
                $sizeBytes = Get-DirectorySizeBytes -Path $locationPath
                [pscustomobject]@{
                    Path   = $locationPath
                    SizeGB = [math]::Round($sizeBytes / 1GB, 3)
                }
            }
        }
    ) | Sort-Object SizeGB -Descending | Select-Object -First $TopCount

    $largeFileRoots = @(
        (Join-Path $userProfilePath 'Downloads'),
        (Join-Path $userProfilePath 'Documents'),
        (Join-Path $userProfilePath 'Desktop')
    )
    $thresholdBytes = [int64]$LargeFileThresholdMB * 1MB
    $largeUserFiles = @(
        foreach ($largeFileRoot in $largeFileRoots) {
            if (Test-Path -LiteralPath $largeFileRoot -PathType Container) {
                Get-ChildItem -LiteralPath $largeFileRoot -Recurse -Force -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Length -ge $thresholdBytes } |
                    ForEach-Object {
                        [pscustomobject]@{
                            Path          = $_.FullName
                            SizeGB        = [math]::Round($_.Length / 1GB, 3)
                            LastWriteTime = $_.LastWriteTime
                            ReviewOnly    = $true
                        }
                    }
            }
        }
    ) | Sort-Object SizeGB -Descending | Select-Object -First $TopCount
}

$report = [pscustomobject]@{
    GeneratedAt       = (Get-Date).ToString('o')
    Mode              = if ($Deep) { 'DeepReadOnly' } else { 'QuickReadOnly' }
    Drive             = [pscustomobject]@{
        Name    = $drive.Name
        TotalGB = [math]::Round($drive.TotalSize / 1GB, 3)
        FreeGB  = [math]::Round($drive.AvailableFreeSpace / 1GB, 3)
        UsedGB  = [math]::Round(($drive.TotalSize - $drive.AvailableFreeSpace) / 1GB, 3)
    }
    CacheCandidates   = @($cacheCandidates | Sort-Object SizeGB -Descending)
    RelatedProcesses  = @($relatedProcesses)
    TopUserLocations  = @($topUserLocations)
    LargeUserFiles    = @($largeUserFiles)
    Notes             = @(
        'This script is read-only.',
        'Visible folder totals may not include restore storage, reserved storage, NTFS metadata, or locked files.',
        'Large user files are review-only and must not be deleted automatically.'
    )
}

$report | ConvertTo-Json -Depth 7
