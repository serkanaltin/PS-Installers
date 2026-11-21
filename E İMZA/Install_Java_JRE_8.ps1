$InstallerPath = Join-Path $PSScriptRoot "jre-8u513-windows-i586-iftw.exe"
$proc = Start-Process -FilePath $InstallerPath -ArgumentList "/s" -Wait -PassThru -Verb RunAs
if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) { exit $proc.ExitCode }