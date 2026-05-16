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

    if ($env:PGBACKUP_PGDUMP -and (Test-Path -LiteralPath $env:PGBACKUP_PGDUMP)) {
        return $env:PGBACKUP_PGDUMP
    }

    if ($env:PGBIN) {
        foreach ($exe in @('pg_dump.exe', 'pg_dump')) {
            $candidate = Join-Path $env:PGBIN $exe
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }

    $cmd = Get-Command -Name 'pg_dump' -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($cmd) { return $cmd.Source }

    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) |
        Where-Object { $_ } |
        ForEach-Object { Join-Path $_ 'PostgreSQL' }

    $candidates = foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue
    }

    $found = $candidates |
        Sort-Object {
            $v = $null
            $name = [regex]::Match($_.Name, '^\d+(\.\d+)?').Value
            if ($name -and [version]::TryParse(($name + '.0'), [ref]$v)) { $v }
            else { [version]'0.0' }
        } -Descending |
        ForEach-Object { Join-Path $_.FullName 'bin\pg_dump.exe' } |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1

    if ($found) { return $found }

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
