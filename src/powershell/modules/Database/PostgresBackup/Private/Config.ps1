function Get-PgVersionFromName {
    # Parse a PostgreSQL install-dir name (e.g. '17', '9.6') into a [version].
    param([Parameter(Mandatory = $true)][string]$Name)
    $v = $null
    $match = [regex]::Match($Name, '^\d+(\.\d+)?').Value
    if ($match -and [version]::TryParse(($match + '.0'), [ref]$v)) { return $v }
    return [version]'0.0'
}

function Resolve-PgDumpFromEnvOverride {
    # 1. PGBACKUP_PGDUMP environment variable (explicit override).
    if ($env:PGBACKUP_PGDUMP -and (Test-Path -LiteralPath $env:PGBACKUP_PGDUMP)) {
        return $env:PGBACKUP_PGDUMP
    }
}

function Resolve-PgDumpFromPgBin {
    # 2. PGBIN environment variable (libpq convention) + pg_dump[.exe].
    if (-not $env:PGBIN) { return }
    foreach ($exe in @('pg_dump.exe', 'pg_dump')) {
        $candidate = Join-Path $env:PGBIN $exe
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
}

function Resolve-PgDumpFromPath {
    # 3. pg_dump on PATH.
    $cmd = Get-Command -Name 'pg_dump' -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($cmd) { return $cmd.Source }
}

function Resolve-PgDumpFromInstallRoots {
    # 4. Standard Windows install roots, newest major version first. Candidate
    #    directories from all roots are pooled and sorted globally so the newest
    #    version wins regardless of which root it lives under.
    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) |
        Where-Object { $_ } |
        ForEach-Object { Join-Path $_ 'PostgreSQL' }

    $candidates = foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue
    }

    $candidates |
        Sort-Object { Get-PgVersionFromName $_.Name } -Descending |
        ForEach-Object { Join-Path $_.FullName 'bin\pg_dump.exe' } |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1
}

function Resolve-PgDumpPath {
    <#
    .SYNOPSIS
        Resolves the full path to the pg_dump executable.
    .DESCRIPTION
        Resolution order:
          1. PGBACKUP_PGDUMP environment variable (explicit override).
          2. PGBIN environment variable (libpq convention) + pg_dump[.exe].
          3. pg_dump on PATH.
          4. Standard Windows install roots (%ProgramFiles%\PostgreSQL\<ver>\bin),
             newest major version first.
        Returns $null if pg_dump cannot be located.
    #>
    [CmdletBinding()]
    param()

    $resolvers = @(
        ${function:Resolve-PgDumpFromEnvOverride},
        ${function:Resolve-PgDumpFromPgBin},
        ${function:Resolve-PgDumpFromPath},
        ${function:Resolve-PgDumpFromInstallRoots}
    )

    foreach ($resolver in $resolvers) {
        $found = & $resolver
        if ($found) { return $found }
    }

    return $null
}

$pg_dump_path = Resolve-PgDumpPath              # Path to pg_dump executable (auto-detected)
if (-not $pg_dump_path) {
    Write-Warning ("Could not auto-detect pg_dump. Set the PGBACKUP_PGDUMP environment " +
        "variable to the full path of pg_dump(.exe), or add it to PATH.")
}

$service_name = "postgresql-x64-17"                              # PostgreSQL service name
$service_start_wait = 5                                          # Seconds to wait between service status checks
$max_wait_time = 15                                              # Maximum seconds to wait for service status change
