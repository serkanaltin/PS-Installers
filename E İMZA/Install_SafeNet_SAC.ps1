$InstallerPath = Join-Path $PSScriptRoot "SAC-x64-10.4.msi"
$proc = Start-Process "msiexec.exe" -ArgumentList "/i `"$InstallerPath`" /qn /norestart" -Wait -PassThru -Verb RunAs
if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) { exit $proc.ExitCode }