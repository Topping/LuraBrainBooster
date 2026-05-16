[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$AddOnsDir,
    [string]$AddonDir,
    [string]$EnvFile,
    [switch]$Clean,
    [switch]$Plan
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

$AddonName = "LuraBrainBooster"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $ScriptDir "..")).Path

if (-not $EnvFile) {
    $EnvFile = Join-Path $RepoRoot ".env.local"
}

function Read-LocalEnv {
    param([string]$Path)

    $Values = @{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $Values
    }

    foreach ($Line in Get-Content -LiteralPath $Path) {
        $Trimmed = $Line.Trim()
        if (-not $Trimmed -or $Trimmed.StartsWith("#")) {
            continue
        }

        if ($Trimmed -match '^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
            $Name = $Matches[1]
            $Value = $Matches[2].Trim()

            if (($Value.StartsWith('"') -and $Value.EndsWith('"')) -or
                ($Value.StartsWith("'") -and $Value.EndsWith("'"))) {
                $Value = $Value.Substring(1, $Value.Length - 2)
            }

            $Values[$Name] = $Value
        }
    }

    return $Values
}

function Get-ConfigValue {
    param(
        [string]$ParameterValue,
        [string]$Name,
        [hashtable]$LocalEnv
    )

    if ($ParameterValue) {
        return $ParameterValue
    }

    $ProcessValue = [Environment]::GetEnvironmentVariable($Name, "Process")
    if ($ProcessValue) {
        return $ProcessValue
    }

    if ($LocalEnv.ContainsKey($Name)) {
        return $LocalEnv[$Name]
    }

    return $null
}

function Resolve-ConfiguredPath {
    param([string]$Path)

    if (-not $Path) {
        return $null
    }

    $Expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if ($Expanded.StartsWith("~")) {
        $HomeRelativePath = $Expanded.Substring(1).TrimStart("\", "/")
        $Expanded = Join-Path $HOME $HomeRelativePath
    }

    if ([System.IO.Path]::IsPathRooted($Expanded)) {
        return [System.IO.Path]::GetFullPath($Expanded)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Expanded))
}

function Convert-ToBool {
    param([string]$Value)

    if (-not $Value) {
        return $false
    }

    return @("1", "true", "yes", "on").Contains($Value.Trim().ToLowerInvariant())
}

function Add-ManifestPath {
    param(
        [hashtable]$Manifest,
        [string]$RelativePath
    )

    $Normalized = $RelativePath.Trim() -replace '/', '\'
    if (-not $Normalized) {
        return
    }

    if ($Normalized -match '(^|\\)\.\.(\\|$)') {
        throw "Refusing unsafe manifest path: $RelativePath"
    }

    $Manifest[$Normalized] = $true
}

$LocalEnv = Read-LocalEnv -Path $EnvFile
$ConfiguredAddonDir = Get-ConfigValue -ParameterValue $AddonDir -Name "LURA_WOW_ADDON_DIR" -LocalEnv $LocalEnv
$ConfiguredAddOnsDir = Get-ConfigValue -ParameterValue $AddOnsDir -Name "LURA_WOW_ADDONS_DIR" -LocalEnv $LocalEnv
$CleanFromEnv = Convert-ToBool (Get-ConfigValue -ParameterValue $null -Name "LURA_DEPLOY_CLEAN" -LocalEnv $LocalEnv)
$ShouldClean = $Clean.IsPresent -or $CleanFromEnv

if ($ConfiguredAddonDir) {
    $TargetAddonDir = Resolve-ConfiguredPath $ConfiguredAddonDir
} elseif ($ConfiguredAddOnsDir) {
    $TargetAddonDir = Join-Path (Resolve-ConfiguredPath $ConfiguredAddOnsDir) $AddonName
} else {
    throw "Missing deploy target. Set LURA_WOW_ADDONS_DIR in .env.local, or pass -AddOnsDir."
}

if ((Split-Path -Leaf $TargetAddonDir) -ne $AddonName) {
    throw "Target addon directory must be named $AddonName. Use -AddOnsDir for the AddOns parent, or set LURA_WOW_ADDON_DIR to ...\$AddonName."
}

$TocPath = Join-Path $RepoRoot "$AddonName.toc"
if (-not (Test-Path -LiteralPath $TocPath -PathType Leaf)) {
    throw "Could not find $AddonName.toc at $TocPath"
}

$Manifest = @{}
Add-ManifestPath -Manifest $Manifest -RelativePath "$AddonName.toc"

foreach ($Line in Get-Content -LiteralPath $TocPath) {
    $Trimmed = $Line.Trim()
    if (-not $Trimmed -or $Trimmed.StartsWith("#")) {
        continue
    }

    Add-ManifestPath -Manifest $Manifest -RelativePath $Trimmed
}

$TexturesDir = Join-Path $RepoRoot "Textures"
if (Test-Path -LiteralPath $TexturesDir -PathType Container) {
    Add-ManifestPath -Manifest $Manifest -RelativePath "Textures"
}

$FilesToCopy = New-Object System.Collections.Generic.List[object]
foreach ($RelativePath in ($Manifest.Keys | Sort-Object)) {
    $SourcePath = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $SourcePath)) {
        throw "Manifest path does not exist: $RelativePath"
    }

    $Item = Get-Item -LiteralPath $SourcePath
    if ($Item.PSIsContainer) {
        foreach ($File in Get-ChildItem -LiteralPath $SourcePath -Recurse -File) {
            $RelativeFilePath = $File.FullName.Substring($RepoRoot.Length).TrimStart("\", "/")
            $FilesToCopy.Add([pscustomobject]@{
                Source = $File.FullName
                RelativePath = $RelativeFilePath
                Target = Join-Path $TargetAddonDir $RelativeFilePath
            })
        }
    } else {
        $FilesToCopy.Add([pscustomobject]@{
            Source = $Item.FullName
            RelativePath = $RelativePath
            Target = Join-Path $TargetAddonDir $RelativePath
        })
    }
}

Write-Host "LuraBrainBooster local deploy"
Write-Host "Source: $RepoRoot"
Write-Host "Target: $TargetAddonDir"
Write-Host "Files:  $($FilesToCopy.Count)"

if ($Plan) {
    foreach ($File in $FilesToCopy) {
        Write-Host "  $($File.RelativePath)"
    }
    return
}

if ($ShouldClean -and (Test-Path -LiteralPath $TargetAddonDir)) {
    $ResolvedTarget = (Resolve-Path -LiteralPath $TargetAddonDir).Path
    if ((Split-Path -Leaf $ResolvedTarget) -ne $AddonName) {
        throw "Refusing to clean unexpected target: $ResolvedTarget"
    }

    if ($PSCmdlet.ShouldProcess($ResolvedTarget, "Remove existing addon directory")) {
        Remove-Item -LiteralPath $ResolvedTarget -Recurse -Force
    }
}

if (-not (Test-Path -LiteralPath $TargetAddonDir)) {
    if ($PSCmdlet.ShouldProcess($TargetAddonDir, "Create addon directory")) {
        New-Item -ItemType Directory -Path $TargetAddonDir -Force | Out-Null
    }
}

foreach ($File in $FilesToCopy) {
    $TargetParent = Split-Path -Parent $File.Target
    if (-not (Test-Path -LiteralPath $TargetParent)) {
        if ($PSCmdlet.ShouldProcess($TargetParent, "Create directory")) {
            New-Item -ItemType Directory -Path $TargetParent -Force | Out-Null
        }
    }

    if ($PSCmdlet.ShouldProcess($File.Target, "Copy $($File.RelativePath)")) {
        Copy-Item -LiteralPath $File.Source -Destination $File.Target -Force
    }
}

if ($WhatIfPreference) {
    Write-Host "WhatIf complete; no files were copied."
} else {
    Write-Host "Deploy complete."
    Write-Host "If texture files were added or renamed while WoW is open, fully restart the game client."
}
