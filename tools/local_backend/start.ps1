<#
    Starts the local development backend: PostgreSQL, PostgREST and the
    Supabase-compatible gateway.

    LOCAL DEVELOPMENT ONLY. See gateway.py's header for what is emulated and
    why none of it is safe outside a developer machine.

    Usage:
        .\tools\local_backend\start.ps1            # start everything
        .\tools\local_backend\start.ps1 -Init      # rebuild the database first
#>

[CmdletBinding()]
param(
    [switch] $Init,
    [string] $Database = 'bsms_dev',
    [int]    $PgPort = 55432,
    [int]    $PostgrestPort = 3010,
    [int]    $GatewayPort = 54321
)

$ErrorActionPreference = 'Stop'

$root      = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$localdev  = Join-Path $root '.localdev'
$pgBin     = Join-Path $localdev 'pg\pgsql\bin'
$pgData    = Join-Path $localdev 'pgdata'
$logDir    = Join-Path $localdev 'logs'

$psql      = Join-Path $pgBin 'psql.exe'
$pgCtl     = Join-Path $pgBin 'pg_ctl.exe'
$postgrest = Join-Path $localdev 'postgrest\postgrest.exe'

foreach ($required in @($psql, $pgCtl, $postgrest)) {
    if (-not (Test-Path $required)) {
        throw "Missing $required. See tools/local_backend/README.md for how to populate .localdev/."
    }
}

New-Item -ItemType Directory -Force -Path $logDir | Out-Null

# --- PostgreSQL -----------------------------------------------------------

Write-Host ''
Write-Host '  [1/3] PostgreSQL' -ForegroundColor Cyan

# Test the port rather than `pg_ctl status`: an unclean shutdown leaves a
# stale postmaster.pid behind, which makes `status` report a running server
# that is not there and makes `start` warn about one.
$listening = @(Get-NetTCPConnection -LocalPort $PgPort -State Listen -ErrorAction SilentlyContinue).Count -gt 0

if ($listening) {
    Write-Host "        already running on port $PgPort"
} else {
    Write-Host '        starting (after an unclean shutdown this replays the'
    Write-Host '        write-ahead log and fsyncs the data directory, which'
    Write-Host '        can take a few minutes - it is not stuck)'

    # -w waits for the server to actually accept connections, so nothing below
    # races ahead of a cluster still in recovery.
    & $pgCtl -D $pgData -l (Join-Path $logDir 'postgres.log') -o "-p $PgPort" -w -t 600 start
    if ($LASTEXITCODE -ne 0) {
        throw "PostgreSQL did not start. See $logDir\postgres.log."
    }
    Write-Host "        running on port $PgPort"
}

# --- Database -------------------------------------------------------------

if ($Init) {
    Write-Host ''
    Write-Host "  [*] Rebuilding database '$Database' from migrations" -ForegroundColor Yellow

    & $psql -h 127.0.0.1 -p $PgPort -U postgres -d postgres -v ON_ERROR_STOP=1 `
        -c "drop database if exists $Database;" -c "create database $Database;"
    if ($LASTEXITCODE -ne 0) { throw 'Could not recreate the database.' }

    # The shim supplies the auth/storage schemas and the anon/authenticated
    # roles that a real Supabase project provides. It is NOT an application
    # migration and must never run against a hosted project.
    $shim = Join-Path $root 'supabase\tests\00_supabase_shim.sql'
    & $psql -h 127.0.0.1 -p $PgPort -U postgres -d $Database -v ON_ERROR_STOP=1 -q -f $shim
    if ($LASTEXITCODE -ne 0) { throw 'The Supabase shim failed to apply.' }

    Get-ChildItem (Join-Path $root 'supabase\migrations') -Filter '*.sql' |
        Sort-Object Name |
        ForEach-Object {
            Write-Host ("        {0}" -f $_.Name)
            & $psql -h 127.0.0.1 -p $PgPort -U postgres -d $Database -v ON_ERROR_STOP=1 -q -f $_.FullName
            if ($LASTEXITCODE -ne 0) { throw "Migration $($_.Name) failed." }
        }

    Write-Host '        migrations applied' -ForegroundColor Green
}

$exists = & $psql -h 127.0.0.1 -p $PgPort -U postgres -d postgres -tAc `
    "select 1 from pg_database where datname = '$Database';"
if (-not $exists) {
    throw "Database '$Database' does not exist. Re-run with -Init."
}

# --- PostgREST ------------------------------------------------------------

Write-Host ''
Write-Host '  [2/3] PostgREST' -ForegroundColor Cyan

Get-Process postgrest -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500

$conf = Join-Path $localdev 'postgrest\postgrest.conf'
# `server-host` is load-bearing. PostgREST defaults to !4 — every IPv4
# interface — so without this line the database is reachable from the whole
# local network, authenticated only by a JWT signed with the development
# secret that is committed to this repository. The gateway in front of it
# binds to loopback; this makes PostgREST behind it do the same, so the claim
# that the local backend is loopback-only is actually true.
$confText = @"
db-uri = "postgres://postgres@127.0.0.1:$PgPort/$Database"
db-schemas = "public"
db-anon-role = "anon"
jwt-secret = "this-is-a-local-test-only-jwt-secret-32chars-min"
server-host = "127.0.0.1"
server-port = $PostgrestPort
db-pool = 5
log-level = "error"
"@

# Written without a byte-order mark. Windows PowerShell's `-Encoding utf8`
# always emits one, and PostgREST's config parser treats the BOM as a stray
# character and refuses to start ("unexpected '\65279'").
[System.IO.File]::WriteAllText(
    $conf, $confText, (New-Object System.Text.UTF8Encoding $false)
)

# The argument must carry its own quotes: this project's path contains a
# space, and Start-Process splits an unquoted -ArgumentList string on
# whitespace, which makes PostgREST see several filenames and print its usage
# text instead of starting.
Start-Process -FilePath $postgrest -ArgumentList "`"$conf`"" -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $logDir 'postgrest.out.log') `
    -RedirectStandardError  (Join-Path $logDir 'postgrest.err.log')

# Wait for it to accept connections rather than assuming a fixed delay; on a
# cold schema cache the first load takes noticeably longer than three seconds.
$deadline = (Get-Date).AddSeconds(60)
do {
    Start-Sleep -Milliseconds 500
    $up = @(Get-NetTCPConnection -LocalPort $PostgrestPort -State Listen -ErrorAction SilentlyContinue).Count -gt 0
} while (-not $up -and (Get-Date) -lt $deadline)

if (-not $up) {
    throw "PostgREST did not start. See $logDir\postgrest.err.log."
}
Write-Host "        running on port $PostgrestPort"

# --- Gateway --------------------------------------------------------------

Write-Host ''
Write-Host '  [3/3] Gateway' -ForegroundColor Cyan

$env:BSMS_PGDATABASE      = $Database
$env:BSMS_PGPORT          = "$PgPort"
$env:BSMS_POSTGREST_PORT  = "$PostgrestPort"
$env:BSMS_GATEWAY_PORT    = "$GatewayPort"

python (Join-Path $PSScriptRoot 'gateway.py') serve
