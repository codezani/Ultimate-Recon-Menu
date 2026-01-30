#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Ultimate Recon Tools Installer (Windows)
    Installs / updates all required tools for the reconnaissance framework

.DESCRIPTION
    This script installs or updates all Go-based and Python-based tools 
    commonly used in bug bounty and authorized reconnaissance workflows.

    Tools installed:
    - Go-based: subfinder, amass, assetfinder, findomain, httpx, gau, hakrawler, gospider, 
      ffuf, nuclei, dalfox, tlsx, dnsx, naabu, fallparams, x8, getJS, qsreplace, gf
    - Python-based: arjun, paramspider, waymore

.NOTES
    Requirements:
    - Windows 10/11
    - PowerShell 5.1+
    - Go 1.18+ installed (https://go.dev/dl/)
    - Python 3.9+ and pip installed
    - Git installed (optional but recommended)
    - Internet connection

    Run as Administrator for best results.
#>

Write-Host "Ultimate Recon Tools Installer" -ForegroundColor Cyan
Write-Host "Installing / updating all required tools..." -ForegroundColor Yellow
Write-Host "This may take 5-15 minutes depending on your connection." -ForegroundColor Yellow
Write-Host ""

# ────────────────────────────────────────
#  0. Pre-checks
# ────────────────────────────────────────

# Check Go
if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Go not found." -ForegroundColor Red
    Write-Host "Please install Go from https://go.dev/dl/" -ForegroundColor Red
    Write-Host "After installation, restart your terminal and run this script again." -ForegroundColor Red
    pause
    exit 1
}

$goVer = (go version) -replace '.*go', ''
Write-Host "Go version detected: $goVer" -ForegroundColor Green

# Check Python & pip
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Python not found." -ForegroundColor Red
    Write-Host "Please install Python 3.9+ from https://www.python.org/downloads/" -ForegroundColor Red
    pause
    exit 1
}

# Check pipx (recommended for clean Python tool installs)
if (-not (Get-Command pipx -ErrorAction SilentlyContinue)) {
    Write-Host "pipx not found - installing..." -ForegroundColor Yellow
    python -m pip install --user pipx
    python -m pipx ensurepath
    Write-Host "pipx installed. Please close and reopen your terminal, then run this script again." -ForegroundColor Yellow
    pause
    exit 0
}

# Optional: Chocolatey for extra utilities (not strictly required)
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# ────────────────────────────────────────
#  1. Go-based tools (go install)
# ────────────────────────────────────────

Write-Host "`nInstalling / updating Go-based tools..." -ForegroundColor Cyan

$goTools = @(
    "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest",
    "github.com/owasp-amass/amass/v4/...@master",
    "github.com/tomnomnom/assetfinder@latest",
    "github.com/Findomain/Findomain@latest",
    "github.com/projectdiscovery/httpx/cmd/httpx@latest",
    "github.com/lc/gau/v2/cmd/gau@latest",
    "github.com/hakluke/hakrawler@latest",
    "github.com/jaeles-project/gospider@latest",
    "github.com/ffuf/ffuf/v2@latest",
    "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest",
    "github.com/hahwul/dalfox/v2@latest",
    "github.com/projectdiscovery/tlsx/cmd/tlsx@latest",
    "github.com/projectdiscovery/dnsx/cmd/dnsx@latest",
    "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest",
    "github.com/ImAyrix/fallparams@latest",
    "github.com/s0md3v/Arjun@latest",
    "github.com/sh1yo/x8@latest",
    "github.com/003random/getJS@latest",
    "github.com/GerbenJavado/LinkFinder@latest",
    "github.com/hahwul/qsreplace@latest",
    "github.com/tomnomnom/gf@latest"
)

foreach ($tool in $goTools) {
    Write-Host "Installing/updating: $tool" -ForegroundColor DarkCyan
    go install -v $tool
}

# Install gf patterns (after gf tool is installed)
Write-Host "Installing gf patterns..." -ForegroundColor DarkCyan
if (Tool-Exists "gf") {
    gf install
} else {
    Write-Host "gf not installed yet - patterns will be installed after restart" -ForegroundColor Yellow
}

# ────────────────────────────────────────
#  2. Python-based tools (via pipx)
# ────────────────────────────────────────

Write-Host "`nInstalling / updating Python-based tools..." -ForegroundColor Cyan

$pythonTools = @(
    "arjun",
    "git+https://github.com/0xasm0d3us/paramspider.git",
    "waymore"
)

foreach ($pkg in $pythonTools) {
    Write-Host "Installing/updating: $pkg" -ForegroundColor DarkCyan
    pipx install $pkg --force
}

# ────────────────────────────────────────
#  3. Final checks & instructions
# ────────────────────────────────────────

Write-Host "`nChecking installed tools..." -ForegroundColor Cyan

$checkTools = @(
    "subfinder","amass","assetfinder","findomain","httpx","gau","waymore","waybackurls",
    "katana","hakrawler","gospider","ffuf","nuclei","dalfox","tlsx","dnsx",
    "fallparams","arjun","paramspider","gf","x8","getJS","linkfinder","qsreplace"
)

foreach ($tool in $checkTools) {
    if (Tool-Exists $tool) {
        Write-Host "$tool → Installed" -ForegroundColor Green
    } else {
        Write-Host "$tool → Not found (may require restart or PATH check)" -ForegroundColor Yellow
    }
}

Write-Host "`nInstallation / update completed!" -ForegroundColor Green
Write-Host "Next steps:"
Write-Host "  1. Close and reopen your terminal / PowerShell"
Write-Host "  2. Verify PATH includes: $env:USERPROFILE\go\bin"
Write-Host "  3. Run your recon script: .\recon.ps1 example.com"
Write-Host ""
Write-Host "If any tool is still missing, run this installer again after restarting." -ForegroundColor Yellow

Write-Host "`nHappy hunting (with permission only)!" -ForegroundColor Magenta
pause
