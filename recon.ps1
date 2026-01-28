# PowerShell script to install reconnaissance tools (2026 compatible)
# Run this script as Administrator (many tools work better with elevated privileges)

#Requires -RunAsAdministrator

Write-Host "Installing Bug Bounty / Recon Tools on Windows" -ForegroundColor Cyan
Write-Host "──────────────────────────────────────────────────────────────" -ForegroundColor DarkCyan

$ErrorActionPreference = "Stop"

# ───────────────────────────────────────────────
# Helper function to check if command exists
# ───────────────────────────────────────────────
function Test-CommandExists {
    param ([string]$cmd)
    return $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

# ───────────────────────────────────────────────
# Check prerequisites: Go and Git
# ───────────────────────────────────────────────
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

if (-not (Test-CommandExists "go")) {
    Write-Host "ERROR: Go is not installed!" -ForegroundColor Red
    Write-Host "Download and install the latest Go from: https://go.dev/dl/" -ForegroundColor Yellow
    Write-Host "After installation, close and reopen PowerShell as Administrator."
    Pause
    exit 1
}

if (-not (Test-CommandExists "git")) {
    Write-Host "ERROR: Git is not installed!" -ForegroundColor Red
    Write-Host "Download and install Git from: https://git-scm.com/download/win" -ForegroundColor Yellow
    Pause
    exit 1
}

Write-Host "Go and Git detected ✓" -ForegroundColor Green

# ───────────────────────────────────────────────
# Ensure GOBIN is in PATH (very important on Windows)
# ───────────────────────────────────────────────
$goPath = (go env GOPATH)
$gobin  = Join-Path $goPath "bin"

if (-not ($env:Path -split ";" | Where-Object { $_ -eq $gobin })) {
    Write-Host "Adding $gobin to user PATH..." -ForegroundColor Yellow
    $env:Path += ";$gobin"
    [Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::User)
    Write-Host "PATH updated. A new PowerShell window is required after this script finishes." -ForegroundColor DarkYellow
}

# ───────────────────────────────────────────────
# Install pdtm (ProjectDiscovery Tool Manager)
# ───────────────────────────────────────────────
Write-Host "`nInstalling pdtm (recommended tool manager)..." -ForegroundColor Cyan

go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest

if (-not (Test-CommandExists "pdtm")) {
    Write-Host "pdtm installation failed." -ForegroundColor Red
    Write-Host "Try manually: go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest" -ForegroundColor Yellow
    Pause
    exit 1
}

Write-Host "pdtm installed successfully ✓" -ForegroundColor Green

# ───────────────────────────────────────────────
# Install ProjectDiscovery tools using pdtm
# ───────────────────────────────────────────────
Write-Host "`nInstalling ProjectDiscovery tools via pdtm..." -ForegroundColor Cyan

$pdtm_tools = @(
    "subfinder",
    "httpx",
    "nuclei",
    "katana",
    "naabu",
    "tlsx",
    "dnsx"
)

foreach ($tool in $pdtm_tools) {
    Write-Host "→ $tool " -NoNewline -ForegroundColor Yellow
    & pdtm install $tool --silent
    if ($?) { Write-Host "✓" -ForegroundColor Green } else { Write-Host "✗" -ForegroundColor Red }
}

# Optional: install ALL PD tools at once (uncomment if you want)
# & pdtm install-all --silent

# ───────────────────────────────────────────────
# Install other popular recon tools manually
# ───────────────────────────────────────────────
Write-Host "`nInstalling additional tools..." -ForegroundColor Cyan

$manual_tools = @{
    "amass"       = "github.com/owasp-amass/amass/v4/...@master"
    "gau"         = "github.com/lc/gau/v2/cmd/gau@latest"
    "waybackurls" = "github.com/tomnomnom/waybackurls@latest"
    "ffuf"        = "github.com/ffuf/ffuf/v2@latest"
    "dalfox"      = "github.com/hahwul/dalfox/v2@latest"
    "gospider"    = "github.com/jaeles-project/gospider@latest"
    "puredns"     = "github.com/d3mondev/puredns/v2@latest"
    "fallparams"  = "github.com/ImAyrix/fallparams@latest"
}

foreach ($tool in $manual_tools.Keys) {
    if (-not (Test-CommandExists $tool)) {
        Write-Host "Installing $tool ..." -ForegroundColor Yellow
        go install -v $manual_tools[$tool]
        if ($?) { Write-Host "✓" -ForegroundColor Green } else { Write-Host "✗" -ForegroundColor Red }
    } else {
        Write-Host "$tool already installed ✓" -ForegroundColor Green
    }
}

# ───────────────────────────────────────────────
# Final instructions
# ───────────────────────────────────────────────
Write-Host "`n──────────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
Write-Host "Installation completed!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Close this PowerShell window" -ForegroundColor White
Write-Host "2. Open a NEW PowerShell (preferably as Administrator)" -ForegroundColor White
Write-Host "3. Test the tools:" -ForegroundColor White
Write-Host "   subfinder -version" -ForegroundColor Gray
Write-Host "   httpx -version"     -ForegroundColor Gray
Write-Host "   nuclei -update-templates" -ForegroundColor Gray
Write-Host "   pdtm list"           -ForegroundColor Gray
Write-Host "   pdtm update-all     # to update everything later" -ForegroundColor Gray
Write-Host "`nIf any tool is still missing → run the go install command manually for that tool."
Write-Host "Happy hunting!" -ForegroundColor Magenta

Pause
