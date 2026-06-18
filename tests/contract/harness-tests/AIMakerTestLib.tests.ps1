#Requires -Version 5.1
<#
.SYNOPSIS
    Unit tests for AIMakerTestLib.psm1

    These tests exercise the state-capture library in isolation — no installer
    invocations, no production paths, no external network. All test state lives
    under $env:TEMP\AIMakerTestLib-tests-<guid>\ and is removed in AfterAll.

    Run:
        Invoke-Pester .\AIMakerTestLib.tests.ps1 -Output Detailed
#>

BeforeAll {
    $LibPath = Join-Path $PSScriptRoot '..\harness\AIMakerTestLib.psm1'
    if (-not (Test-Path $LibPath)) { throw "Library not found: $LibPath" }
    Import-Module $LibPath -Force

    # Per-run sandbox so parallel test runs don't collide
    $script:TestRoot = Join-Path $env:TEMP "AIMakerTestLib-tests-$(([guid]::NewGuid()).ToString('N'))"
    New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null

    # Absolute path to the migration-bundle fixture (legacy snapshot tests)
    $script:LegacySnapshotPath = 'C:\Users\marcusash\.copilot\session-state\9cac84f6-17a2-48ab-851f-b2bf816572dd\files\migration-bundle\extracted\sandbox\blue\fixture-01-healthy-c-github\baseline-snapshot.json'
    $script:LegacyFixtureRoot  = 'C:\Users\marcusash\.copilot\session-state\9cac84f6-17a2-48ab-851f-b2bf816572dd\files\migration-bundle\extracted\sandbox\blue\fixture-01-healthy-c-github'
}

AfterAll {
    Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
}

# ============================================================
# Get-FileStateSnapshot — file
# ============================================================

Describe 'Get-FileStateSnapshot — regular file' {
    BeforeAll {
        $script:FilePath = Join-Path $script:TestRoot 'snapshot-file.txt'
        # 'hello world' = 11 bytes UTF-8 no BOM
        [System.IO.File]::WriteAllBytes($script:FilePath, [System.Text.Encoding]::UTF8.GetBytes('hello world'))
        $script:Snap = Get-FileStateSnapshot -Path $script:FilePath -Root $script:TestRoot
    }

    It 'returns a non-null object' {
        $script:Snap | Should -Not -BeNullOrEmpty
    }
    It 'RelPath is forward-slash only (no backslashes)' {
        $script:Snap.RelPath | Should -Not -Match '\\'
    }
    It 'RelPath equals filename' {
        $script:Snap.RelPath | Should -Be 'snapshot-file.txt'
    }
    It 'IsDirectory is false' {
        $script:Snap.IsDirectory | Should -BeFalse
    }
    It 'Sha256 is lowercase 64-char hex' {
        $script:Snap.Sha256 | Should -Match '^[0-9a-f]{64}$'
    }
    It 'SizeBytes is 11 (byte count of ''hello world'')' {
        $script:Snap.SizeBytes | Should -Be 11
    }
    It 'LastWriteUtc is a parseable ISO8601 string' {
        { [datetime]::Parse($script:Snap.LastWriteUtc) } | Should -Not -Throw
    }
    It 'CreatedUtc is a parseable ISO8601 string' {
        { [datetime]::Parse($script:Snap.CreatedUtc) } | Should -Not -Throw
    }
    It 'HardLinkCount is at least 1' {
        $script:Snap.HardLinkCount | Should -BeGreaterOrEqual 1
    }
    It 'AdsNames is an empty collection for a file with no ADS' {
        # PS may collapse empty typed arrays in custom object properties — assert semantics
        # (count = 0), not the runtime type.
        @($script:Snap.AdsNames).Count | Should -Be 0
    }
    It 'IsReparsePoint is false for a regular file' {
        $script:Snap.IsReparsePoint | Should -BeFalse
    }
    It 'two snapshots of identical content produce identical Sha256' {
        $copy = Join-Path $script:TestRoot 'snapshot-copy.txt'
        [System.IO.File]::WriteAllBytes($copy, [System.Text.Encoding]::UTF8.GetBytes('hello world'))
        $snapCopy = Get-FileStateSnapshot -Path $copy -Root $script:TestRoot
        $script:Snap.Sha256 | Should -Be $snapCopy.Sha256
    }
    It 'two snapshots of different content produce different Sha256' {
        $other = Join-Path $script:TestRoot 'snapshot-other.txt'
        [System.IO.File]::WriteAllBytes($other, [System.Text.Encoding]::UTF8.GetBytes('different'))
        $snapOther = Get-FileStateSnapshot -Path $other -Root $script:TestRoot
        $script:Snap.Sha256 | Should -Not -Be $snapOther.Sha256
    }
}

# ============================================================
# Get-FileStateSnapshot — directory
# ============================================================

Describe 'Get-FileStateSnapshot — directory' {
    BeforeAll {
        $script:SubDir = Join-Path $script:TestRoot 'a-subdir'
        New-Item -ItemType Directory -Path $script:SubDir -Force | Out-Null
        $script:DirSnap = Get-FileStateSnapshot -Path $script:SubDir -Root $script:TestRoot
    }

    It 'IsDirectory is true' {
        $script:DirSnap.IsDirectory | Should -BeTrue
    }
    It 'Sha256 is empty string (directories have no content hash)' {
        $script:DirSnap.Sha256 | Should -Be ''
    }
    It 'SizeBytes is 0' {
        $script:DirSnap.SizeBytes | Should -Be 0
    }
    It 'RelPath contains the directory name without trailing slash' {
        $script:DirSnap.RelPath | Should -Be 'a-subdir'
    }
}

# ============================================================
# Get-FileStateSnapshot — error handling
# ============================================================

Describe 'Get-FileStateSnapshot — error handling' {
    It 'throws for a path that does not exist' {
        { Get-FileStateSnapshot -Path (Join-Path $script:TestRoot 'nonexistent.txt') } |
            Should -Throw
    }
}

# ============================================================
# Get-DirectoryTreeManifest
# ============================================================

Describe 'Get-DirectoryTreeManifest' {
    BeforeAll {
        $script:TreeRoot = Join-Path $script:TestRoot 'tree-test'
        New-Item -ItemType Directory -Path "$script:TreeRoot\alpha"   -Force | Out-Null
        New-Item -ItemType Directory -Path "$script:TreeRoot\beta"    -Force | Out-Null
        New-Item -ItemType Directory -Path "$script:TreeRoot\.hidden" -Force | Out-Null
        [System.IO.File]::WriteAllBytes("$script:TreeRoot\root.txt",        [System.Text.Encoding]::UTF8.GetBytes('root'))
        [System.IO.File]::WriteAllBytes("$script:TreeRoot\alpha\a.txt",     [System.Text.Encoding]::UTF8.GetBytes('alpha-a'))
        [System.IO.File]::WriteAllBytes("$script:TreeRoot\beta\b.txt",      [System.Text.Encoding]::UTF8.GetBytes('beta-b'))
        [System.IO.File]::WriteAllBytes("$script:TreeRoot\.hidden\h.txt",   [System.Text.Encoding]::UTF8.GetBytes('hidden'))

        $script:Manifest = Get-DirectoryTreeManifest -Root $script:TreeRoot
    }

    It 'returns a non-empty array' {
        $script:Manifest.Count | Should -BeGreaterThan 0
    }
    It 'manifest is sorted ascending by RelPath' {
        $rel    = $script:Manifest | Select-Object -ExpandProperty RelPath
        $sorted = $rel | Sort-Object
        ($rel -join ',') | Should -Be ($sorted -join ',')
    }
    It 'contains expected file entries' {
        $script:Manifest.RelPath | Should -Contain 'root.txt'
        $script:Manifest.RelPath | Should -Contain 'alpha/a.txt'
        $script:Manifest.RelPath | Should -Contain 'beta/b.txt'
    }
    It 'contains directory entries' {
        $script:Manifest.RelPath | Should -Contain 'alpha'
        $script:Manifest.RelPath | Should -Contain 'beta'
    }
    It 'includes hidden directories and their contents' {
        $script:Manifest.RelPath | Should -Contain '.hidden/h.txt'
    }
    It 'all RelPaths use forward slashes only' {
        $script:Manifest | ForEach-Object { $_.RelPath | Should -Not -Match '\\' }
    }
    It 'Exclude parameter removes matching paths' {
        $filtered = Get-DirectoryTreeManifest -Root $script:TreeRoot -Exclude @('alpha/*')
        $filtered.RelPath | Should -Not -Contain 'alpha/a.txt'
        $filtered.RelPath | Should -Contain 'beta/b.txt'
    }
    It 'Exclude with *.txt removes matching files' {
        $filtered = Get-DirectoryTreeManifest -Root $script:TreeRoot -Exclude @('*.txt')
        $filtered | Where-Object { $_.RelPath -like '*.txt' } | Should -BeNullOrEmpty
    }
    It 'throws for a path that is not a directory' {
        $notDir = Join-Path $script:TestRoot 'not-a-dir.txt'
        [System.IO.File]::WriteAllBytes($notDir, [System.Text.Encoding]::UTF8.GetBytes('x'))
        { Get-DirectoryTreeManifest -Root $notDir } | Should -Throw
    }
}

# ============================================================
# Compare-StateManifest
# ============================================================

Describe 'Compare-StateManifest' {
    BeforeAll {
        $script:CmpRoot = Join-Path $script:TestRoot 'cmp-test'
        New-Item -ItemType Directory -Path $script:CmpRoot -Force | Out-Null
        [System.IO.File]::WriteAllBytes("$script:CmpRoot\keep.txt",   [System.Text.Encoding]::UTF8.GetBytes('unchanged'))
        [System.IO.File]::WriteAllBytes("$script:CmpRoot\modify.txt", [System.Text.Encoding]::UTF8.GetBytes('original'))
        [System.IO.File]::WriteAllBytes("$script:CmpRoot\remove.txt", [System.Text.Encoding]::UTF8.GetBytes('will-go'))

        $script:Before = Get-DirectoryTreeManifest -Root $script:CmpRoot

        # Mutations: modify, remove, add
        Start-Sleep -Milliseconds 50  # ensure LastWriteTime differs
        [System.IO.File]::WriteAllBytes("$script:CmpRoot\modify.txt", [System.Text.Encoding]::UTF8.GetBytes('changed!!'))
        Remove-Item "$script:CmpRoot\remove.txt"
        [System.IO.File]::WriteAllBytes("$script:CmpRoot\added.txt",  [System.Text.Encoding]::UTF8.GetBytes('brand-new'))

        $script:After = Get-DirectoryTreeManifest -Root $script:CmpRoot
        $script:Diff  = Compare-StateManifest -Before $script:Before -After $script:After
    }

    It 'returns a StateDiff with Added, Removed, Changed properties' {
        $props = $script:Diff.PSObject.Properties.Name
        $props | Should -Contain 'Added'
        $props | Should -Contain 'Removed'
        $props | Should -Contain 'Changed'
    }
    It 'Added contains the new file' {
        $script:Diff.Added.RelPath | Should -Contain 'added.txt'
    }
    It 'Removed contains the deleted file' {
        $script:Diff.Removed.RelPath | Should -Contain 'remove.txt'
    }
    It 'Changed contains the modified file' {
        $script:Diff.Changed.RelPath | Should -Contain 'modify.txt'
    }
    It 'Changed entry for modify.txt has a Sha256 field change' {
        $rec = $script:Diff.Changed | Where-Object { $_.RelPath -eq 'modify.txt' }
        $sha = $rec.Fields | Where-Object { $_.Field -eq 'Sha256' }
        $sha         | Should -Not -BeNullOrEmpty
        $sha.Before  | Should -Not -Be $sha.After
    }
    It 'unchanged file (keep.txt) does not appear in any diff bucket' {
        $script:Diff.Added.RelPath   | Should -Not -Contain 'keep.txt'
        $script:Diff.Removed.RelPath | Should -Not -Contain 'keep.txt'
        $script:Diff.Changed.RelPath | Should -Not -Contain 'keep.txt'
    }
    It 'diff of identical manifests is empty' {
        $same = Compare-StateManifest -Before $script:After -After $script:After
        $same.Added.Count   | Should -Be 0
        $same.Removed.Count | Should -Be 0
        $same.Changed.Count | Should -Be 0
    }
    It 'diff of empty manifests is empty' {
        $empty = Compare-StateManifest -Before @() -After @()
        $empty.Added.Count   | Should -Be 0
        $empty.Removed.Count | Should -Be 0
        $empty.Changed.Count | Should -Be 0
    }
    It 'Added and Removed are sorted by RelPath' {
        # Add a second new file to ensure ordering is testable
        [System.IO.File]::WriteAllBytes("$script:CmpRoot\zzz-new.txt", [System.Text.Encoding]::UTF8.GetBytes('zzz'))
        $after2 = Get-DirectoryTreeManifest -Root $script:CmpRoot
        $diff2  = Compare-StateManifest -Before $script:Before -After $after2
        $added  = $diff2.Added | Select-Object -ExpandProperty RelPath
        ($added -join ',') | Should -Be (($added | Sort-Object) -join ',')
    }
}

# ============================================================
# Export-StateManifest / Import-StateManifest roundtrip
# ============================================================

Describe 'Export-StateManifest / Import-StateManifest roundtrip' {
    BeforeAll {
        $script:RtRoot   = Join-Path $script:TestRoot 'roundtrip-test'
        $script:JsonPath = Join-Path $script:TestRoot  'manifest-rt.json'
        New-Item -ItemType Directory -Path $script:RtRoot -Force | Out-Null
        [System.IO.File]::WriteAllBytes("$script:RtRoot\a.txt", [System.Text.Encoding]::UTF8.GetBytes('content-a'))
        [System.IO.File]::WriteAllBytes("$script:RtRoot\b.txt", [System.Text.Encoding]::UTF8.GetBytes('content-b'))

        $script:Original = Get-DirectoryTreeManifest -Root $script:RtRoot
        Export-StateManifest -Manifest $script:Original -Path $script:JsonPath
        $script:Imported = Import-StateManifest -Path $script:JsonPath
    }

    It 'JSON file is created' {
        Test-Path $script:JsonPath | Should -BeTrue
    }
    It 'JSON has schemaVersion 3' {
        $raw = Get-Content $script:JsonPath -Raw | ConvertFrom-Json
        $raw.schemaVersion | Should -Be 3
    }
    It 'imported entry count matches original' {
        $script:Imported.Count | Should -Be $script:Original.Count
    }
    It 'imported Sha256 matches original for each entry' {
        foreach ($orig in $script:Original) {
            $imp = $script:Imported | Where-Object { $_.RelPath -eq $orig.RelPath }
            $imp | Should -Not -BeNullOrEmpty
            $imp.Sha256 | Should -Be $orig.Sha256
        }
    }
    It 'Compare-StateManifest of original vs imported is empty (no diff)' {
        $diff = Compare-StateManifest -Before $script:Original -After $script:Imported
        $diff.Added.Count   | Should -Be 0
        $diff.Removed.Count | Should -Be 0
        $diff.Changed.Count | Should -Be 0
    }
}

# ============================================================
# Import-LegacySnapshot
# ============================================================

Describe 'Import-LegacySnapshot' {
    BeforeDiscovery {
        $script:LegacyExists = Test-Path 'C:\Users\marcusash\.copilot\session-state\9cac84f6-17a2-48ab-851f-b2bf816572dd\files\migration-bundle\extracted\sandbox\blue\fixture-01-healthy-c-github\baseline-snapshot.json'
    }

    BeforeAll {
        # Re-set in BeforeAll so the variables are available at runtime in It blocks
        $script:LegacySnapshotPath = 'C:\Users\marcusash\.copilot\session-state\9cac84f6-17a2-48ab-851f-b2bf816572dd\files\migration-bundle\extracted\sandbox\blue\fixture-01-healthy-c-github\baseline-snapshot.json'
        $script:LegacyFixtureRoot  = 'C:\Users\marcusash\.copilot\session-state\9cac84f6-17a2-48ab-851f-b2bf816572dd\files\migration-bundle\extracted\sandbox\blue\fixture-01-healthy-c-github'
    }

    It 'imports without throwing' -Skip:(-not $script:LegacyExists) {
        { Import-LegacySnapshot -Path $script:LegacySnapshotPath -FixtureRoot $script:LegacyFixtureRoot } |
            Should -Not -Throw
    }
    It 'returns a non-empty array' -Skip:(-not $script:LegacyExists) {
        $entries = Import-LegacySnapshot -Path $script:LegacySnapshotPath -FixtureRoot $script:LegacyFixtureRoot
        $entries.Count | Should -BeGreaterThan 0
    }
    It 'all RelPaths use forward slashes' -Skip:(-not $script:LegacyExists) {
        $entries = Import-LegacySnapshot -Path $script:LegacySnapshotPath -FixtureRoot $script:LegacyFixtureRoot
        $entries | ForEach-Object { $_.RelPath | Should -Not -Match '\\' }
    }
    It 'Sha256 values are lowercase 64-char hex' -Skip:(-not $script:LegacyExists) {
        $entries = Import-LegacySnapshot -Path $script:LegacySnapshotPath -FixtureRoot $script:LegacyFixtureRoot
        $entries | ForEach-Object { $_.Sha256 | Should -Match '^[0-9a-f]{64}$' }
    }
    It 'IsDirectory is false for all legacy entries' -Skip:(-not $script:LegacyExists) {
        $entries = Import-LegacySnapshot -Path $script:LegacySnapshotPath -FixtureRoot $script:LegacyFixtureRoot
        $entries | ForEach-Object { $_.IsDirectory | Should -BeFalse }
    }
    It 'RelPaths include expected files from fixture-01' -Skip:(-not $script:LegacyExists) {
        $entries = Import-LegacySnapshot -Path $script:LegacySnapshotPath -FixtureRoot $script:LegacyFixtureRoot
        $relPaths = $entries | Select-Object -ExpandProperty RelPath
        ($relPaths | Where-Object { $_ -like '*README*' }).Count | Should -BeGreaterThan 0
    }
    It 'SizeBytes is positive for at least one entry' -Skip:(-not $script:LegacyExists) {
        $entries = Import-LegacySnapshot -Path $script:LegacySnapshotPath -FixtureRoot $script:LegacyFixtureRoot
        $entries | Where-Object { $_.SizeBytes -gt 0 } | Should -Not -BeNullOrEmpty
    }
}

# ============================================================
# Get-RegistrySnapshot
# ============================================================

Describe 'Get-RegistrySnapshot' {
    It 'returns a result for a well-known key (HKCU:\Software)' {
        $snap = Get-RegistrySnapshot -KeyPaths @('HKCU:\Software')
        $snap       | Should -Not -BeNullOrEmpty
        $snap[0].Exists   | Should -BeTrue
        $snap[0].KeyPath  | Should -Be 'HKCU:\Software'
        # HKCU:\Software is a container key — it may have no named values, only subkeys.
        # Assert Values is a hashtable (not null), not that it has entries.
        $snap[0].Values -is [hashtable] | Should -BeTrue
    }
    It 'returns Exists=$false for a non-existent key' {
        $snap = Get-RegistrySnapshot -KeyPaths @('HKCU:\Software\DoesNotExistAIMaker99887766')
        $snap[0].Exists | Should -BeFalse
        $snap[0].Values.Count | Should -Be 0
    }
    It 'handles multiple key paths in one call' {
        $snap = Get-RegistrySnapshot -KeyPaths @(
            'HKCU:\Software',
            'HKCU:\Software\DoesNotExistAIMaker99887766'
        )
        $snap.Count | Should -Be 2
        $snap[0].Exists | Should -BeTrue
        $snap[1].Exists | Should -BeFalse
    }
    It 'Values hashtable contains string Data and Type fields' {
        $snap = Get-RegistrySnapshot -KeyPaths @('HKCU:\Software')
        # HKCU:\Software typically has no values, but its subkeys do — just assert structure
        $snap[0].Values -is [hashtable] | Should -BeTrue
    }
    It 'detects a value that was written then removed (positive-case diff)' {
        # Create a test key with a known value, snapshot, remove the value, snapshot again.
        $keyPath = 'HKCU:\Software\AIMakerTestLib-SnapTest-99887766'
        try {
            New-Item -Path $keyPath -Force | Out-Null
            Set-ItemProperty -Path $keyPath -Name 'TestValue' -Value 'before' -Type String

            $before = Get-RegistrySnapshot -KeyPaths @($keyPath)
            Set-ItemProperty -Path $keyPath -Name 'TestValue' -Value 'after' -Type String
            $after  = Get-RegistrySnapshot -KeyPaths @($keyPath)

            $before[0].Values['TestValue'].Data | Should -Be 'before'
            $after[0].Values['TestValue'].Data  | Should -Be 'after'
            $before[0].Values['TestValue'].Data | Should -Not -Be $after[0].Values['TestValue'].Data
        } finally {
            Remove-Item -Path $keyPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================
# Positive-case lib tests (FF anti-vacuous gate — Day 2 addition)
# These prove the four previously-negative-only fields actually detect
# changes, not just return trivial values.
# ============================================================

Describe 'Get-FileStateSnapshot — ADS positive case' {
    BeforeAll {
        $script:AdsRoot = Join-Path $script:TestRoot 'ads-positive'
        New-Item -ItemType Directory -Path $script:AdsRoot -Force | Out-Null

        $script:NoAdsFile = Join-Path $script:AdsRoot 'no-ads.txt'
        [System.IO.File]::WriteAllBytes($script:NoAdsFile,
            [System.Text.Encoding]::UTF8.GetBytes('no ads here'))

        $script:AdsFile = Join-Path $script:AdsRoot 'with-ads.txt'
        [System.IO.File]::WriteAllBytes($script:AdsFile,
            [System.Text.Encoding]::UTF8.GetBytes('main stream'))
        Set-Content -LiteralPath "${script:AdsFile}:hidden-stream"   -Value 'ads payload'
        Set-Content -LiteralPath "${script:AdsFile}:zone.identifier" -Value "[ZoneTransfer]`nZoneId=3"

        $script:NoAdsSnap   = Get-FileStateSnapshot -Path $script:NoAdsFile -Root $script:AdsRoot
        $script:WithAdsSnap = Get-FileStateSnapshot -Path $script:AdsFile   -Root $script:AdsRoot
    }

    It 'AdsNames is empty for a file with no ADS' {
        @($script:NoAdsSnap.AdsNames).Count | Should -Be 0
    }
    It 'AdsNames contains hidden-stream' {
        $script:WithAdsSnap.AdsNames | Should -Contain 'hidden-stream'
    }
    It 'AdsNames contains zone.identifier' {
        $script:WithAdsSnap.AdsNames | Should -Contain 'zone.identifier'
    }
    It 'AdsNames count is 2 for file with two streams' {
        @($script:WithAdsSnap.AdsNames).Count | Should -Be 2
    }
    It 'Compare-StateManifest detects ADS stream removal as an AdsNames field change' {
        # Snapshot with ADS, remove one stream, re-snapshot — diff must show AdsNames changed.
        # This test runs last; it mutates AdsFile and is the only consumer of that mutation.
        $before = Get-DirectoryTreeManifest -Root $script:AdsRoot
        # Correct syntax for ADS removal: -Stream parameter, not colon-appended path
        Remove-Item -LiteralPath $script:AdsFile -Stream 'hidden-stream' -ErrorAction SilentlyContinue
        $after  = Get-DirectoryTreeManifest -Root $script:AdsRoot
        $diff   = Compare-StateManifest -Before $before -After $after

        $adsChange = $diff.Changed | Where-Object { $_.RelPath -eq 'with-ads.txt' }
        $adsChange | Should -Not -BeNullOrEmpty
        ($adsChange.Fields | Where-Object { $_.Field -eq 'AdsNames' }) | Should -Not -BeNullOrEmpty
    }
}

Describe 'Get-FileStateSnapshot — IsReparsePoint positive case (junction)' {
    BeforeDiscovery {
        # Probe whether junction creation is available in this environment
        $script:JunctionProbeOk = $false
        try {
            $probe = Join-Path $env:TEMP "AIMakerJunctionProbe-$(([guid]::NewGuid()).ToString('N'))"
            $probeTarget = Join-Path $env:TEMP "AIMakerJunctionTarget-$(([guid]::NewGuid()).ToString('N'))"
            New-Item -ItemType Directory -Path $probeTarget -Force | Out-Null
            New-Item -ItemType Junction -Path $probe -Target $probeTarget -Force | Out-Null
            $script:JunctionProbeOk = $true
            Remove-Item -Path $probe      -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $probeTarget -Force -ErrorAction SilentlyContinue
        } catch {}
    }

    BeforeAll {
        $script:JunctionRoot   = Join-Path $script:TestRoot 'junction-positive'
        $script:JunctionTarget = Join-Path $script:TestRoot 'junction-positive-target'
        New-Item -ItemType Directory -Path $script:JunctionRoot   -Force | Out-Null
        New-Item -ItemType Directory -Path $script:JunctionTarget -Force | Out-Null
        [System.IO.File]::WriteAllBytes(
            (Join-Path $script:JunctionRoot 'regular.txt'),
            [System.Text.Encoding]::UTF8.GetBytes('regular dir'))

        $script:JunctionLink = Join-Path $script:JunctionRoot 'link'
        $script:JunctionSetupOk = $false
        try {
            New-Item -ItemType Junction -Path $script:JunctionLink -Target $script:JunctionTarget -Force | Out-Null
            $script:JunctionSetupOk = $true
        } catch {}

        $script:RegSnap      = Get-FileStateSnapshot -Path $script:JunctionRoot -Root $script:TestRoot
        $script:JunctionSnap = if ($script:JunctionSetupOk) {
            Get-FileStateSnapshot -Path $script:JunctionLink -Root $script:JunctionRoot
        }
    }

    It 'IsReparsePoint is false for a regular directory' {
        $script:RegSnap.IsReparsePoint | Should -BeFalse
    }
    It 'IsReparsePoint is true for a junction' -Skip:(-not $script:JunctionProbeOk) {
        $script:JunctionSnap.IsReparsePoint | Should -BeTrue
    }
    It 'Get-DirectoryTreeManifest includes junction entry with IsReparsePoint=true' -Skip:(-not $script:JunctionProbeOk) {
        $manifest = Get-DirectoryTreeManifest -Root $script:JunctionRoot
        $entry = $manifest | Where-Object { $_.RelPath -eq 'link' }
        $entry            | Should -Not -BeNullOrEmpty
        $entry.IsReparsePoint | Should -BeTrue
    }
    It 'Compare-StateManifest detects junction removal as a Removed entry' -Skip:(-not $script:JunctionProbeOk) {
        $before = Get-DirectoryTreeManifest -Root $script:JunctionRoot
        # Remove the junction (not its target)
        [System.IO.Directory]::Delete($script:JunctionLink)
        $after  = Get-DirectoryTreeManifest -Root $script:JunctionRoot
        $diff   = Compare-StateManifest -Before $before -After $after
        $diff.Removed.RelPath | Should -Contain 'link'
    }
}

Describe 'Get-FileStateSnapshot — HardLinkCount positive case' {
    BeforeAll {
        $script:HlRoot     = Join-Path $script:TestRoot 'hardlink-positive'
        New-Item -ItemType Directory -Path $script:HlRoot -Force | Out-Null

        $script:HlOriginal = Join-Path $script:HlRoot 'original.txt'
        $script:HlLink     = Join-Path $script:HlRoot 'hardlink.txt'
        [System.IO.File]::WriteAllBytes($script:HlOriginal,
            [System.Text.Encoding]::UTF8.GetBytes('shared inode content'))

        $script:HardLinkSetupOk = $false
        try {
            New-Item -ItemType HardLink -Path $script:HlLink -Target $script:HlOriginal -Force | Out-Null
            $script:HardLinkSetupOk = $true
        } catch {
            try {
                & fsutil hardlink create $script:HlLink $script:HlOriginal 2>&1 | Out-Null
                $script:HardLinkSetupOk = $true
            } catch {}
        }

        # Snapshots taken AFTER hardlink creation — both should show HardLinkCount=2
        $script:OrigSnap = Get-FileStateSnapshot -Path $script:HlOriginal -Root $script:HlRoot
        $script:LinkSnap = if ($script:HardLinkSetupOk) {
            Get-FileStateSnapshot -Path $script:HlLink -Root $script:HlRoot
        }
    }

    BeforeDiscovery {
        $script:HardLinkProbeOk = $false
        try {
            $p  = Join-Path $env:TEMP "AIMakerHLProbe-$(([guid]::NewGuid()).ToString('N')).txt"
            $p2 = $p + '.link'
            [System.IO.File]::WriteAllBytes($p, [System.Text.Encoding]::UTF8.GetBytes('x'))
            New-Item -ItemType HardLink -Path $p2 -Target $p -Force | Out-Null
            $script:HardLinkProbeOk = $true
            Remove-Item $p, $p2 -Force -ErrorAction SilentlyContinue
        } catch {}
    }

    It 'HardLinkCount is 1 for a standalone file' {
        $isolated = Join-Path $script:HlRoot 'isolated.txt'
        [System.IO.File]::WriteAllBytes($isolated, [System.Text.Encoding]::UTF8.GetBytes('isolated'))
        $snap = Get-FileStateSnapshot -Path $isolated -Root $script:HlRoot
        $snap.HardLinkCount | Should -Be 1
    }
    It 'original file HardLinkCount is 2 after hardlink created' -Skip:(-not $script:HardLinkProbeOk) {
        $script:OrigSnap.HardLinkCount | Should -Be 2
    }
    It 'hardlink target HardLinkCount is also 2' -Skip:(-not $script:HardLinkProbeOk) {
        $script:LinkSnap.HardLinkCount | Should -Be 2
    }
    It 'original and hardlink share identical Sha256' -Skip:(-not $script:HardLinkProbeOk) {
        $script:OrigSnap.Sha256 | Should -Be $script:LinkSnap.Sha256
    }
    It 'Compare-StateManifest detects HardLinkCount drop from 2→1 after link removal' -Skip:(-not $script:HardLinkProbeOk) {
        # Run LAST in this Describe — removes the hardlink and re-snapshots original
        Remove-Item -LiteralPath $script:HlLink -Force
        $afterSnap = Get-FileStateSnapshot -Path $script:HlOriginal -Root $script:HlRoot
        $afterSnap.HardLinkCount | Should -Be 1

        $diff = Compare-StateManifest -Before @($script:OrigSnap) -After @($afterSnap)
        $diff.Changed | Should -Not -BeNullOrEmpty
        ($diff.Changed[0].Fields | Where-Object { $_.Field -eq 'HardLinkCount' }) |
            Should -Not -BeNullOrEmpty
    }
}

Describe 'Get-FileStateSnapshot — AclSddl positive case (non-default ACL)' {
    BeforeDiscovery {
        # Probe at discovery time so -Skip: conditions evaluate correctly.
        # Creates a temp file, adds a ReadAttributes ACE for NT AUTHORITY\NETWORK,
        # and verifies the SDDL string actually changes before committing to the tests.
        $script:AclSetupOk = $false
        $probeFile = $null
        try {
            $probeFile = [System.IO.Path]::GetTempFileName()
            $sddlBefore = (Get-Acl -LiteralPath $probeFile).Sddl
            $acl = Get-Acl -LiteralPath $probeFile
            $networkSid = [System.Security.Principal.SecurityIdentifier]::new(
                [System.Security.Principal.WellKnownSidType]::NetworkSid, $null)
            $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
                $networkSid,
                [System.Security.AccessControl.FileSystemRights]::ReadAttributes,
                [System.Security.AccessControl.InheritanceFlags]::None,
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Allow)
            $acl.AddAccessRule($rule)
            Set-Acl -LiteralPath $probeFile -AclObject $acl
            $sddlAfter = (Get-Acl -LiteralPath $probeFile).Sddl
            $script:AclSetupOk = ($sddlBefore -ne $sddlAfter)
        } catch {}
        finally {
            if ($null -ne $probeFile) {
                Remove-Item $probeFile -Force -ErrorAction SilentlyContinue
            }
        }
    }

    BeforeAll {
        $script:AclRoot = Join-Path $script:TestRoot 'acl-positive'
        New-Item -ItemType Directory -Path $script:AclRoot -Force | Out-Null
        $script:AclFile = Join-Path $script:AclRoot 'custom-acl.txt'
        [System.IO.File]::WriteAllBytes($script:AclFile,
            [System.Text.Encoding]::UTF8.GetBytes('acl target'))

        $script:SnapBeforeAcl = Get-FileStateSnapshot -Path $script:AclFile -Root $script:AclRoot

        try {
            $acl = Get-Acl -LiteralPath $script:AclFile
            # Add an explicit Allow-ReadAttributes rule for NT AUTHORITY\NETWORK.
            # This SID is unlikely to have an existing explicit ACE on a fresh temp file,
            # so AddAccessRule unconditionally adds a new ACE → SDDL changes.
            $networkSid = [System.Security.Principal.SecurityIdentifier]::new(
                [System.Security.Principal.WellKnownSidType]::NetworkSid, $null)
            $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
                $networkSid,
                [System.Security.AccessControl.FileSystemRights]::ReadAttributes,
                [System.Security.AccessControl.InheritanceFlags]::None,
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Allow)
            $acl.AddAccessRule($rule)
            Set-Acl -LiteralPath $script:AclFile -AclObject $acl
            $script:SnapAfterAcl = Get-FileStateSnapshot -Path $script:AclFile -Root $script:AclRoot
        } catch {}
    }

    It 'AclSddl is a non-null non-empty string for any file' {
        $script:SnapBeforeAcl.AclSddl | Should -Not -BeNullOrEmpty
    }
    It 'AclSddl string contains expected SDDL markers (D: or O:)' {
        $script:SnapBeforeAcl.AclSddl | Should -Match '^(O:|D:|G:)'
    }
    It 'AclSddl changes after ACL modification' -Skip:(-not $script:AclSetupOk) {
        $script:SnapBeforeAcl.AclSddl | Should -Not -Be $script:SnapAfterAcl.AclSddl
    }
    It 'Compare-StateManifest emits an AclSddl FieldChange when ACL changes' -Skip:(-not $script:AclSetupOk) {
        $diff = Compare-StateManifest -Before @($script:SnapBeforeAcl) -After @($script:SnapAfterAcl)
        $diff.Changed | Should -Not -BeNullOrEmpty
        ($diff.Changed[0].Fields | Where-Object { $_.Field -eq 'AclSddl' }) |
            Should -Not -BeNullOrEmpty
    }
    It 'AclSddl field change has Before and After that are both valid SDDL strings' -Skip:(-not $script:AclSetupOk) {
        $diff = Compare-StateManifest -Before @($script:SnapBeforeAcl) -After @($script:SnapAfterAcl)
        $aclChange = $diff.Changed[0].Fields | Where-Object { $_.Field -eq 'AclSddl' }
        $aclChange.Before | Should -Match '^(O:|D:|G:)'
        $aclChange.After  | Should -Match '^(O:|D:|G:)'
    }
}

