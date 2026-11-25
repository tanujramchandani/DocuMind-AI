$ErrorActionPreference = 'Stop'

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$userPath;$machinePath;$env:Path"
}

function Install-Package([string]$id) {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "Windows Package Manager (winget) is required to install $id. Install App Installer from Microsoft, then retry."
    }
    & winget.exe install --id $id --exact --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "Could not install $id with winget (exit $LASTEXITCODE)." }
    Refresh-Path
}

if (-not (Get-Command uv.exe -ErrorAction SilentlyContinue)) {
    Install-Package 'astral-sh.uv'
}
$nodeMajor = 0
if ((Get-Command node.exe -ErrorAction SilentlyContinue) -and (Get-Command npm.cmd -ErrorAction SilentlyContinue)) {
    $nodeMajor = [int]((& node.exe -p 'process.versions.node.split(".")[0]'))
}
if ($nodeMajor -lt 20) {
    Install-Package 'OpenJS.NodeJS.LTS'
}
foreach ($command in @('uv.exe', 'node.exe', 'npm.cmd')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "$command is not on PATH after installation. Open a new PowerShell window and run this script again."
    }
}

$backend = Join-Path $PSScriptRoot 'backend'
$frontend = Join-Path $PSScriptRoot 'frontend'
Push-Location $backend
try {
    & uv.exe sync --locked
    if ($LASTEXITCODE -ne 0) { throw 'Backend dependency installation failed.' }
}
finally { Pop-Location }

Push-Location $frontend
try {
    & npm.cmd ci
    if ($LASTEXITCODE -ne 0) { throw 'Frontend dependency installation failed.' }
}
finally { Pop-Location }

Push-Location $backend
try {
    & uv.exe run --locked python (Join-Path $PSScriptRoot 'scripts/configure-env.py')
    if ($LASTEXITCODE -ne 0) { throw 'Environment configuration failed.' }
}
finally { Pop-Location }

Write-Host 'Installation complete. If you skipped the Groq key, add it to backend/.env before using chat.'
Write-Host 'Start the backend:  cd backend; uv run --locked uvicorn app.main:app --reload'
Write-Host 'Start the frontend: cd frontend; npm run dev'
