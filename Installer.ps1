# install-tools.ps1
# =============================================================================
# Ultimate Recon Tools Installer - Windows
# Purpose: Install or update common Go-based recon tools used in the framework
# Version: 1.0
# License: MIT
# Requirements: Go 1.18+ installed, $GOPATH/bin in PATH
# Usage: .\install-tools.ps1
# =============================================================================

Write-Host "Ultimate Recon Tools Installer" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "This script will install/update the following tools:" -ForegroundColor White
Write-Host "  - subfinder        - amass           - assetfinder" -ForegroundColor Gray
Write-Host "  - findomain        - httpx            - gau" -ForegroundColor Gray
Write-Host "  - waymore          - waybackurls     - katana" -ForegroundColor Gray
Write-Host "  - hakrawler        - gospider        - ffuf" -ForegroundColor Gray
Write-Host "  - nuclei           - dalfox          - tlsx" -ForegroundColor Gray
Write-Host "  - dnsx             - arjun           - paramspider" -ForegroundColor Gray
Write-Host "  - gf               - x8              - getJS" -ForegroundColor Gray
Write-Host "  - linkfinder       - qsreplace" -ForegroundColor Gray
Write-Host "" -ForegroundColor White

# ─── Check Go is installed ──────────────────────────────────────────────────────
if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Go is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install Go from https://go.dev/dl/ and add %USERPROFILE%\go\bin to PATH" -ForegroundColor Yellow
    exit 1
}

$goVersion = (go version) -replace 'go version go', ''
Write-Host "Go version detected: $goVersion" -ForegroundColor Green

# ─── Create GOPATH bin if missing ───────────────────────────────────────────────
$goBin = "$env:USERPROFILE\go\bin"
if (-not (Test-Path $goBin)) {
    New-Item -ItemType Directory -Force -Path $goBin | Out-Null
}

# ─── Helper function to install / update a tool ─────────────────────────────────
function Install-Tool {
    param (
        [string]$ToolName,
        [string]$RepoPath
    )

    Write-Host "Installing / updating $ToolName ..." -ForegroundColor Cyan -NoNewline
    try {
        & go install -v "$RepoPath@latest" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host " OK" -ForegroundColor Green
        } else {
            Write-Host " FAILED" -ForegroundColor Red
        }
    }
    catch {
        Write-Host " ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ─── List of tools and their repositories ───────────────────────────────────────
$tools = @(
    @{ Name = "subfinder";   Repo = "github.com/projectdiscovery/subfinder/v2/cmd/subfinder" }
    @{ Name = "amass";       Repo = "github.com/owasp-amass/amass/v4/..." }
    @{ Name = "assetfinder"; Repo = "github.com/tomnomnom/assetfinder" }
    @{ Name = "findomain";   Repo = "github.com/Findomain/Findomain" }
    @{ Name = "httpx";       Repo = "github.com/projectdiscovery/httpx/cmd/httpx" }
    @{ Name = "gau";         Repo = "github.com/lc/gau/v2/cmd/gau" }
    @{ Name = "waymore";     Repo = "github.com/xnl-h4ck3r/waymore" }
    @{ Name = "waybackurls"; Repo = "github.com/tomnomnom/waybackurls" }
    @{ Name = "katana";      Repo = "github.com/projectdiscovery/katana/cmd/katana" }
    @{ Name = "hakrawler";   Repo = "github.com/hakluke/hakrawler" }
    @{ Name = "gospider";    Repo = "github.com/jaeles-project/gospider" }
    @{ Name = "ffuf";        Repo = "github.com/ffuf/ffuf/v2" }
    @{ Name = "nuclei";      Repo = "github.com/projectdiscovery/nuclei/v3/cmd/nuclei" }
    @{ Name = "dalfox";      Repo = "github.com/hahwul/dalfox/v2" }
    @{ Name = "tlsx";        Repo = "github.com/projectdiscovery/tlsx/cmd/tlsx" }
    @{ Name = "dnsx";        Repo = "github.com/projectdiscovery/dnsx/cmd/dnsx" }
    @{ Name = "arjun";       Repo = "github.com/s0md3v/Arjun" }
    @{ Name = "paramspider"; Repo = "github.com/devanshbatham/ParamSpider" }
    @{ Name = "gf";          Repo = "github.com/tomnomnom/gf" }
    @{ Name = "x8";          Repo = "github.com/Sh1Yo/x8" }
    @{ Name = "getJS";       Repo = "github.com/003random/getJS" }
    @{ Name = "linkfinder";  Repo = "github.com/GerbenJavado/LinkFinder" }
    @{ Name = "qsreplace";   Repo = "github.com/tomnomnom/qsreplace" }
)

# ─── Install all tools ──────────────────────────────────────────────────────────
Write-Host "`nStarting installation / update of tools..." -ForegroundColor Yellow

foreach ($tool in $tools) {
    Install-Tool -ToolName $tool.Name -RepoPath $tool.Repo
}

# ─── Final instructions ─────────────────────────────────────────────────────────
Write-Host "`nInstallation finished." -ForegroundColor Green
Write-Host "Make sure the following directory is in your PATH:" -ForegroundColor White
Write-Host "  $env:USERPROFILE\go\bin" -ForegroundColor Cyan
Write-Host "`nYou can add it permanently by running:" -ForegroundColor White
Write-Host '  [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$env:USERPROFILE\go\bin", "User")' -ForegroundColor Gray
Write-Host "`nVerify tools:" -ForegroundColor White
Write-Host "  subfinder -version" -ForegroundColor Gray
Write-Host "  amass -version" -ForegroundColor Gray
Write-Host "  httpx -version" -ForegroundColor Gray
Write-Host "  nuclei -version" -ForegroundColor Gray

Write-Host "`nHappy hunting! (only on targets you are authorized to test)" -ForegroundColor Magenta
