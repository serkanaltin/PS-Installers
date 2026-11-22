$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
$file = "linkus_desktop_windows_msi_version.msi"
$dlLink = "https://image.yeastar.com/Yeastardownload/$file"
$InstallerPath = Join-Path $env:TEMP $file
(New-Object System.Net.WebClient).DownloadFile($dlLink, $InstallerPath)
$proc = Start-Process msiexec.exe -Wait -PassThru -ArgumentList "/i `"$InstallerPath`" /qn /norestart" -Verb RunAs
Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue
if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) { exit $proc.ExitCode }
