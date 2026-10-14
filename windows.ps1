# Run from an elevated Windows PowerShell terminal.
$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run PowerShell as administrator, then run this script again.'
}
function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed ($LASTEXITCODE). Correct the error above and rerun this script." }
}
Write-Output '[1/4] WSL2 + Ubuntu'
$distros = ((& wsl.exe --list --quiet 2>$null) -join "`n") -replace "`0", ''
if ($distros -notmatch '(?m)^Ubuntu\s*$') {
    Invoke-Checked -Program 'wsl.exe' -Arguments @('--install', '-d', 'Ubuntu', '--no-launch')
}
Write-Output '[2/4] 1Password, VS Code, Windows Terminal'
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) { throw 'Install App Installer from Microsoft Store, then rerun this script.' }
foreach ($package in @('AgileBits.1Password', 'AgileBits.1Password.CLI', 'Microsoft.VisualStudioCode', 'Microsoft.WindowsTerminal')) {
    & winget.exe list --id $package --exact --accept-source-agreements | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Invoke-Checked -Program 'winget.exe' -Arguments @('install', '--id', $package, '--exact', '--source', 'winget', '--accept-package-agreements', '--accept-source-agreements')
    }
}
Write-Output '[3/4] VS Code WSL extension'
$code = Get-Command code.cmd -ErrorAction SilentlyContinue
if (-not $code) {
    $codePath = Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'
    if (-not (Test-Path $codePath)) { $codePath = Join-Path $env:ProgramFiles 'Microsoft VS Code\bin\code.cmd' }
} else { $codePath = $code.Source }
Invoke-Checked -Program $codePath -Arguments @('--install-extension', 'ms-vscode-remote.remote-wsl')
Write-Output '[4/4] WSL memory configuration'
$configuration = Join-Path $env:USERPROFILE '.wslconfig'
if (-not (Test-Path $configuration)) {
    $totalGB = [Math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    $memoryGB = [Math]::Max(2, [Math]::Min(8, [Math]::Floor($totalGB / 2)))
    "[wsl2]`nmemory=$($memoryGB)GB`nswap=2GB`nlocalhostForwarding=true`n" | Set-Content -Path $configuration -Encoding ascii
} else { Write-Output 'Keeping your existing .wslconfig.' }
New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Force | Out-Null
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'TorkUbuntu' -Value 'wsl.exe -d Ubuntu'
Write-Output 'In 1Password: Settings > Developer > Integrate with 1Password CLI. Unlock with Windows Hello.'
Write-Output 'After restarting, open Ubuntu and choose a Linux username and password. Paste:'
Write-Output 'curl -fsSL https://raw.githubusercontent.com/torkjacobs/tork-dev-bootstrap/main/install.sh | bash'
$answer = Read-Host 'Done. Restart now? (Y/N)'
if ($answer -eq 'Y') { Restart-Computer }
