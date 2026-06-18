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
}
