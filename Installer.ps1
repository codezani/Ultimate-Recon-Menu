#Requires -RunAsAdministrator
# Installs reconnaissance tools on Windows (2025/2026 compatible)
# Prerequisites: Go 1.21+ and Git must be installed

Write-Host "Installing Reconnaissance Tools on Windows" -ForegroundColor Cyan
Write-Host "───────────────────────────────────────────────" -ForegroundColor DarkCyan

# ───────────────────────────────────────────────
#  Check prerequisites
# ───────────────────────────────────────────────

$ErrorActionPreference = "Stop"

function Test-CommandExists {
    param ([string]$command)
    return $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
}

Write-Host "Checking prerequisites..." -ForegroundColor Yellow

if (-not (Test-CommandExists "go")) {
    Write-Host "Go programming language is not installed!" -ForegroundColor Red
    Write-Host "Please install Go from the official site first:" -ForegroundColor Yellow
    Write-Host "https://go.dev/dl/" -ForegroundColor Yellow
    Write-Host "After installation, close and reopen your terminal."
    Pause
    exit 1
}

if (-not (Test-CommandExists "git")) {
    Write-Host "Git is not installed!" -ForegroundColor Red
    Write-Host "Please install Git: https://git-scm.com/download/win" -ForegroundColor Yellow
    Pause
    exit 1
}

Write-Host "Go and Git found ✓" -ForegroundColor Green

# Set up GOPATH / GOBIN (very important on Windows)
$goPath = go env GOPATH
$goBin  = Join-Path $goPath "bin"

if (-not ($env:Path -split ";" | Where-Object { $_ -eq $goBin })) {
    Write-Host "Adding $goBin to PATH ..." -ForegroundColor Yellow
    $env:Path += ";$goBin"
    [Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::User)
    Write-Host "PATH updated – please open a new PowerShell window after this script finishes" -ForegroundColor DarkYellow
}

# ───────────────────────────────────────────────
#  Install ProjectDiscovery Tool Manager (pdtm) – recommended way
# ───────────────────────────────────────────────

Write-Host "`nInstalling / updating pdtm (ProjectDiscovery Tool Manager) ..." -ForegroundColor Cyan

go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest

if (-not (Test-CommandExists "pdtm")) {
    Write-Host "pdtm installation failed" -ForegroundColor Red
    Write-Host "You can try manual install:" -ForegroundColor Yellow
    Write-Host "go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest" -ForegroundColor White
    Pause
    exit 1
}

Write-Host "pdtm installed successfully ✓" -ForegroundColor Green

# ───────────────────────────────────────────────
#  Install ProjectDiscovery tools via pdtm
# ───────────────────────────────────────────────

Write-Host "`nInstalling ProjectDiscovery tools ..." -ForegroundColor Cyan

$pdtm_tools = @(
    "subfinder",
    "httpx",
    "nuclei",
    "katana",
    "naabu",
    "tlsx",
    "dnsx"
    # puredns is not official PD – install manually below if needed
)

foreach ($tool in $pdtm_tools) {
    Write-Host "Installing $tool ..." -NoNewline -ForegroundColor Yellow
    & pdtm install $tool -silent
    if ($?) {
        Write-Host " ✓" -ForegroundColor Green
    } else {
        Write-Host " ✗" -ForegroundColor Red
    }
}

# ───────────────────────────────────────────────
#  Install additional / community tools manually
# ───────────────────────────────────────────────

Write-Host "`nInstalling additional tools ..." -ForegroundColor Cyan

# amass (OWASP)
if (-not (Test-CommandExists "amass")) {
    Write-Host "Installing amass ..." -ForegroundColor Yellow
    go install -v github.com/owasp-amass/amass/v4/...@master
}

# gau
if (-not (Test-CommandExists "gau")) {
    Write-Host "Installing gau ..." -ForegroundColor Yellow
    go install github.com/lc/gau/v2/cmd/gau@latest
}

# waybackurls
if (-not (Test-CommandExists "waybackurls")) {
    Write-Host "Installing waybackurls ..." -ForegroundColor Yellow
    go install github.com/tomnomnom/waybackurls@latest
}

# ffuf
if (-not (Test-CommandExists "ffuf")) {
    Write-Host "Installing ffuf ..." -ForegroundColor Yellow
    go install github.com/ffuf/ffuf/v2@latest
}

# dalfox (XSS scanner)
if (-not (Test-CommandExists "dalfox")) {
    Write-Host "Installing dalfox ..." -ForegroundColor Yellow
    go install github.com/hahwul/dalfox/v2@latest
}

# puredns (optional – popular resolver/cleaner)
if (-not (Test-CommandExists "puredns")) {
    Write-Host "Installing puredns ..." -ForegroundColor Yellow
    go install github.com/d3mondev/puredns/v2@latest
}

Write-Host "`n───────────────────────────────────────────────" -ForegroundColor DarkCyan
Write-Host "Installation finished!" -ForegroundColor Green

Write-Host "Important recommendations:" -ForegroundColor Yellow
Write-Host "• Open a NEW PowerShell window now (very important!)" -ForegroundColor White
Write-Host "• Test the tools with these commands:" -ForegroundColor White
Write-Host "  subfinder -version" -ForegroundColor Gray
Write-Host "  httpx -version" -ForegroundColor Gray
Write-Host "  nuclei -update-templates" -ForegroundColor Gray
Write-Host "  pdtm list" -ForegroundColor Gray
Write-Host "  nuclei -update" -ForegroundColor Gray

Write-Host "`nHappy hunting!" -ForegroundColor Magenta
Pause
