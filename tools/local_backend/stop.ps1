<#
    Stops the local development backend started by start.ps1.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

$root     = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$localdev = Join-Path $root '.localdev'
$pgCtl    = Join-Path $localdev 'pg\pgsql\bin\pg_ctl.exe'
$pgData   = Join-Path $localdev 'pgdata'

Get-Process postgrest -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "  stopping postgrest ($($_.Id))"
    Stop-Process -Id $_.Id -Force
}

# The gateway is a plain `python gateway.py serve`, so match on the command
# line rather than the image name - other Python processes must survive.
Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" |
    Where-Object { $_.CommandLine -like '*gateway.py*' } |
    ForEach-Object {
        Write-Host "  stopping gateway ($($_.ProcessId))"
        Stop-Process -Id $_.ProcessId -Force
    }

if (Test-Path $pgCtl) {
    & $pgCtl -D $pgData -m fast stop
}

Write-Host '  Local backend stopped.'
