$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    Start-Process winget.exe -Wait -ArgumentList "install --id VMware.WorkstationPlayer --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity" -WindowStyle Hidden
}