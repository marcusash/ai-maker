# AIMakerTestLib.psm1
# State-capture library for AI Maker installer regression suite
#
# Design spec  : state-capture-library-design.md (FI, 2026-06-17)
# PRD          : installer-test-project/PRD.md    (FR, 2026-06-18)
# Phase        : 1.1 — core snapshot + diff
#
# Exports:
#   Get-FileStateSnapshot        single file or directory entry
#   Get-DirectoryTreeManifest    recursive ordered snapshot
#   Compare-StateManifest        diff two manifests → StateDiff
#   Get-RegistrySnapshot         scoped registry snapshot
#   Export-StateManifest         serialize to JSON (schemaVersion 3)
#   Import-StateManifest         deserialize from JSON
#   Import-LegacySnapshot        wrap baseline-snapshot.json v1/v2 → FileStateEntry[]

Set-StrictMode -Off
$ErrorActionPreference = 'Stop'

# ============================================================
# Private helpers
# ============================================================

function script:Get-Sha256 {
    param([string]$Path)
    $sha = $null
    try {
        $sha   = [System.Security.Cryptography.SHA256]::Create()
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLower()
    } catch {
        return ''
    } finally {
        if ($sha) { $sha.Dispose() }
    }
}

function script:Get-HardLinkCount {
    param([string]$Path)
    try {
        $result = & fsutil hardlink list $Path 2>&1
        $count  = @($result | Where-Object { $_ -and $_.Trim() }).Count
        return [Math]::Max(1, $count)
    } catch {
        return 1
    }
}

function script:Get-AdsNames {
    param([string]$Path)
    try {
        $streams = @(Get-Item -LiteralPath $Path -Stream * -ErrorAction SilentlyContinue)
        return [string[]]@($streams |
            Where-Object { $_.Stream -and $_.Stream -ne ':$DATA' } |
            ForEach-Object { [string]$_.Stream })
    } catch {
        return [string[]]@()
    }
}

function script:Get-IsReparsePoint {
    param([string]$Path)
    try {
        $attrs = [System.IO.File]::GetAttributes($Path)
        return $attrs.HasFlag([System.IO.FileAttributes]::ReparsePoint)
    } catch {
        return $false
    }
}

function script:Get-AclSddl {
    param([string]$Path)
    try {
        return (Get-Acl -LiteralPath $Path).Sddl
    } catch {
        return $null
    }
}

function script:Normalize-RelPath {
    param([string]$AbsPath, [string]$Root)
    $rootTrimmed = $Root.TrimEnd('\')
    if ($AbsPath.Length -le $rootTrimmed.Length) { return '' }
    return $AbsPath.Substring($rootTrimmed.Length).TrimStart('\').Replace('\', '/')
}

# ============================================================
# Public: Get-FileStateSnapshot
# ============================================================

function Get-FileStateSnapshot {
    <#
    .SYNOPSIS
        Returns a FileStateEntry snapshot for a single file or directory.
    .PARAMETER Path
        Absolute path to the file or directory.
    .PARAMETER Root
        Root path for RelPath computation. Defaults to immediate parent.
    .OUTPUTS
        PSCustomObject with fields: RelPath, Sha256, IsDirectory, SizeBytes,
        LastWriteUtc, CreatedUtc, AclSddl, IsReparsePoint, HardLinkCount, AdsNames
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path,
        [string]$Root = ''
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Get-FileStateSnapshot: not found: $Path"
    }

    $item  = Get-Item -LiteralPath $Path -Force
    $isDir = $item.PSIsContainer

    # Canonicalize Root so 8.3 short paths don't skew Normalize-RelPath
    if ($Root -eq '') {
        $Root = $item.Parent.FullName
    } elseif (Test-Path -LiteralPath $Root) {
        $Root = (Get-Item -LiteralPath $Root -Force).FullName
    }

    $relPath = script:Normalize-RelPath -AbsPath $item.FullName -Root $Root
    $sha256  = if ($isDir) { '' } else { script:Get-Sha256 -Path $item.FullName }
    $size    = if ($isDir) { 0L } else { $item.Length }
    $links   = if ($isDir) { 1 }  else { script:Get-HardLinkCount -Path $item.FullName }

    $adsNames = [string[]](script:Get-AdsNames -Path $item.FullName)
    if ($null -eq $adsNames) { $adsNames = [string[]]@() }

    return [pscustomobject]@{
        RelPath        = $relPath
        Sha256         = $sha256
        IsDirectory    = $isDir
        SizeBytes      = $size
        LastWriteUtc   = $item.LastWriteTimeUtc.ToString('o')
        CreatedUtc     = $item.CreationTimeUtc.ToString('o')
        AclSddl        = (script:Get-AclSddl -Path $item.FullName)
        IsReparsePoint = (script:Get-IsReparsePoint -Path $item.FullName)
        HardLinkCount  = $links
        AdsNames       = $adsNames
    }
}

# ============================================================
# Public: Get-DirectoryTreeManifest
# ============================================================

function Get-DirectoryTreeManifest {
    <#
    .SYNOPSIS
        Returns an ordered FileStateEntry[] for all items under Root.
    .PARAMETER Root
        Directory to snapshot recursively.
    .PARAMETER Exclude
        Glob patterns matched against RelPath (forward-slash). Matching entries
        are omitted. E.g. @('.git/*', '*.exe', 'node_modules/*')
    .OUTPUTS
        FileStateEntry[] sorted ascending by RelPath.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Root,
        [string[]]$Exclude = @()
    )

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        throw "Get-DirectoryTreeManifest: not a directory: $Root"
    }

    $rootFull = (Get-Item -LiteralPath $Root -Force).FullName
    $entries  = [System.Collections.Generic.List[object]]::new()

    $allItems = Get-ChildItem -LiteralPath $rootFull -Recurse -Force -ErrorAction SilentlyContinue

    foreach ($item in $allItems) {
        $relPath = script:Normalize-RelPath -AbsPath $item.FullName -Root $rootFull

        $excluded = $false
        foreach ($pattern in $Exclude) {
            if ($relPath -like $pattern) { $excluded = $true; break }
        }
        if ($excluded) { continue }

        $entry = Get-FileStateSnapshot -Path $item.FullName -Root $rootFull
        $entries.Add($entry)
    }

    return @($entries | Sort-Object RelPath)
}

# ============================================================
# Public: Compare-StateManifest
# ============================================================

function Compare-StateManifest {
    <#
    .SYNOPSIS
        Diffs two FileStateEntry[] manifests.
    .PARAMETER Before
        Manifest captured before the operation.
    .PARAMETER After
        Manifest captured after the operation.
    .OUTPUTS
        StateDiff PSCustomObject:
          Added   : FileStateEntry[]   paths in After not in Before
          Removed : FileStateEntry[]   paths in Before not in After
          Changed : ChangeRecord[]     paths in both with at least one differing field
        ChangeRecord: { RelPath: string; Fields: FieldChange[] }
        FieldChange:  { Field: string; Before: string; After: string }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [PSCustomObject[]]$Before,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [PSCustomObject[]]$After
    )

    $beforeMap = @{}
    foreach ($e in $Before) { if ($e) { $beforeMap[$e.RelPath] = $e } }

    $afterMap  = @{}
    foreach ($e in $After)  { if ($e) { $afterMap[$e.RelPath]  = $e } }

    $added   = [System.Collections.Generic.List[object]]::new()
    $removed = [System.Collections.Generic.List[object]]::new()
    $changed = [System.Collections.Generic.List[object]]::new()

    foreach ($key in $afterMap.Keys) {
        if (-not $beforeMap.ContainsKey($key)) { $added.Add($afterMap[$key]) }
    }

    foreach ($key in $beforeMap.Keys) {
        if (-not $afterMap.ContainsKey($key)) {
            $removed.Add($beforeMap[$key])
        } else {
            $b     = $beforeMap[$key]
            $a     = $afterMap[$key]
            $diffs = [System.Collections.Generic.List[object]]::new()

            foreach ($prop in @('Sha256','AclSddl','LastWriteUtc','CreatedUtc',
                                'IsReparsePoint','HardLinkCount','SizeBytes','IsDirectory')) {
                $bv = [string]$b.$prop
                $av = [string]$a.$prop
                if ($bv -ne $av) {
                    $diffs.Add([pscustomobject]@{ Field = $prop; Before = $bv; After = $av })
                }
            }

            $bAds = ($b.AdsNames | Sort-Object) -join ','
            $aAds = ($a.AdsNames | Sort-Object) -join ','
            if ($bAds -ne $aAds) {
                $diffs.Add([pscustomobject]@{ Field = 'AdsNames'; Before = $bAds; After = $aAds })
            }

            if ($diffs.Count -gt 0) {
                $changed.Add([pscustomobject]@{ RelPath = $key; Fields = @($diffs) })
            }
        }
    }

    return [pscustomobject]@{
        Added   = @($added   | Sort-Object RelPath)
        Removed = @($removed | Sort-Object RelPath)
        Changed = @($changed | Sort-Object RelPath)
    }
}

# ============================================================
# Public: Get-RegistrySnapshot
# ============================================================

function Get-RegistrySnapshot {
    <#
    .SYNOPSIS
        Snapshots a scoped set of registry keys (declared installer surface only).
    .PARAMETER KeyPaths
        Registry paths in PowerShell drive format (e.g. 'HKCU:\Software\AIMaker').
    .OUTPUTS
        RegistryEntry[] with fields: KeyPath, Exists, Values (hashtable name→{Data,Type})
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]]$KeyPaths
    )

    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($keyPath in $KeyPaths) {
        try {
            $key    = Get-Item -Path $keyPath -ErrorAction Stop
            $values = @{}
            foreach ($name in $key.GetValueNames()) {
                try {
                    $data = $key.GetValue($name, $null, 'DoNotExpandEnvironmentNames')
                    $type = $key.GetValueKind($name).ToString()
                    $values[$name] = @{ Data = [string]$data; Type = $type }
                } catch {}
            }
            $results.Add([pscustomobject]@{ KeyPath = $keyPath; Exists = $true;  Values = $values })
        } catch {
            $results.Add([pscustomobject]@{ KeyPath = $keyPath; Exists = $false; Values = @{} })
        }
    }

    return @($results)
}

# ============================================================
# Public: Export-StateManifest / Import-StateManifest
# ============================================================

function Export-StateManifest {
    <#
    .SYNOPSIS
        Serializes a FileStateEntry[] to a JSON file (schemaVersion 3).
        Output is ConvertTo-Json -Depth 10 compatible; FF's gate runner can
        deserialize with ConvertFrom-Json without an adapter.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [PSCustomObject[]]$Manifest,
        [Parameter(Mandatory)] [string]$Path
    )

    $wrapper = [pscustomobject]@{
        schemaVersion = 3
        capturedAt    = (Get-Date).ToString('o')
        entryCount    = $Manifest.Count
        entries       = $Manifest
    }

    $wrapper | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
}

function Import-StateManifest {
    <#
    .SYNOPSIS
        Deserializes a FileStateEntry[] from a JSON file produced by Export-StateManifest.
        Explicitly re-types all fields so PS 7's auto-datetime deserialization of
        ISO8601 strings does not cause spurious diffs in Compare-StateManifest.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path
    )

    $data = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($data.schemaVersion -ne 3) {
        Write-Warning "Import-StateManifest: expected schemaVersion 3, got $($data.schemaVersion). Use Import-LegacySnapshot for older formats."
    }

    return @($data.entries | ForEach-Object {
        # PS 7 ConvertFrom-Json silently parses ISO8601 strings into [datetime].
        # Re-serialize datetimes back to the canonical 'o' (roundtrip) format so
        # Compare-StateManifest sees identical strings to what Get-FileStateSnapshot wrote.
        $lwUtc = if ($_.LastWriteUtc -is [datetime]) {
            ([datetime]$_.LastWriteUtc).ToUniversalTime().ToString('o')
        } else { [string]$_.LastWriteUtc }

        $crUtc = if ($_.CreatedUtc -is [datetime]) {
            ([datetime]$_.CreatedUtc).ToUniversalTime().ToString('o')
        } elseif ($null -eq $_.CreatedUtc) { $null } else { [string]$_.CreatedUtc }

        [pscustomobject]@{
            RelPath        = [string]$_.RelPath
            Sha256         = [string]$_.Sha256
            IsDirectory    = [bool]$_.IsDirectory
            SizeBytes      = [long]$_.SizeBytes
            LastWriteUtc   = $lwUtc
            CreatedUtc     = $crUtc
            AclSddl        = if ($null -eq $_.AclSddl) { $null } else { [string]$_.AclSddl }
            IsReparsePoint = [bool]$_.IsReparsePoint
            HardLinkCount  = [int]$_.HardLinkCount
            AdsNames       = [string[]]@($_.AdsNames | ForEach-Object { [string]$_ })
        }
    })
}

# ============================================================
# Public: Import-LegacySnapshot
# ============================================================

function Import-LegacySnapshot {
    <#
    .SYNOPSIS
        Converts a legacy baseline-snapshot.json (schemaVersion 1 or 2, from
        FP's migration-test-bundle.zip) to FileStateEntry[].
        Fields not present in the legacy schema (AclSddl, CreatedUtc,
        IsReparsePoint, HardLinkCount, AdsNames) are set to null / defaults
        and marked as UNPROVEN — callers must not assert preservation on these
        fields without re-snapshotting with Get-DirectoryTreeManifest.
    .PARAMETER Path
        Path to baseline-snapshot.json.
    .PARAMETER FixtureRoot
        Absolute path to the fixture root directory. Used to compute RelPath.
        Overrides the fixtureRoot embedded in the JSON (which may reference
        a different machine's paths).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path,
        [string]$FixtureRoot = ''
    )

    $data = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json

    $effectiveRoot = if ($FixtureRoot -ne '') { $FixtureRoot } else { $data.fixtureRoot }
    $effectiveRoot = $effectiveRoot.TrimEnd('\')

    $entries = [System.Collections.Generic.List[object]]::new()

    foreach ($root in $data.roots) {
        foreach ($file in $root.files) {
            $abs = $file.absolutePath

            # Compute RelPath relative to the effective fixture root.
            $relPath = if ($abs.StartsWith($effectiveRoot)) {
                $abs.Substring($effectiveRoot.Length).TrimStart('\').Replace('\', '/')
            } else {
                # Fallback: root-relative path within fixture, using the JSON's
                # fixtureRoot to strip the prefix, then prepend the root's
                # relative position inside the fixture.
                $rootRel = $root.rootPath.Substring($data.fixtureRoot.TrimEnd('\').Length).TrimStart('\').Replace('\', '/')
                ($rootRel + '/' + $file.relativePath.Replace('\', '/')).TrimStart('/')
            }

            $entries.Add([pscustomobject]@{
                RelPath        = $relPath
                Sha256         = $file.sha256.ToLower()
                IsDirectory    = $false
                SizeBytes      = [long]$file.sizeBytes
                LastWriteUtc   = $file.lastWriteTime
                CreatedUtc     = $null    # UNPROVEN — not in legacy schema
                AclSddl        = $null    # UNPROVEN — not in legacy schema
                IsReparsePoint = $false   # UNPROVEN — assumed false
                HardLinkCount  = 1        # UNPROVEN — assumed 1
                AdsNames       = @()      # UNPROVEN — not in legacy schema
            })
        }
    }

    return @($entries | Sort-Object RelPath)
}

# ============================================================
# Module exports
# ============================================================

Export-ModuleMember -Function @(
    'Get-FileStateSnapshot',
    'Get-DirectoryTreeManifest',
    'Compare-StateManifest',
    'Get-RegistrySnapshot',
    'Export-StateManifest',
    'Import-StateManifest',
    'Import-LegacySnapshot'
)
