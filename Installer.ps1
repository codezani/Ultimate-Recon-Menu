# install-tools.ps1
# =============================================================================
# Ultimate Recon Tools Installer - Windows
# Purpose: Install or update common recon tools used in the framework
# Version: 1.0
# License: MIT
# Requirements: Go 1.18+ installed, GOPATH/bin in PATH
# =============================================================================

Write-Host "Ultimate Recon Tools Installer" -ForegroundColor Cyan
Write-Host "This script will install/update the following tools:" -ForegroundColor White
Write-Host "subfinder  amass  assetfinder  findomain  httpx  gau  waymore  waybackurls"
Write-Host "katana  hakrawler  gospider  ffuf  nuclei  dalfox  tlsx  dnsx"
Write-Host "arjun  paramspider  gf  x8  getJS  linkfinder  qsreplace" -ForegroundColor Gray
Write-Host ""

if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Go is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Install Go from https://go.dev/dl/" -ForegroundColor Yellow
    exit 1
}

$goBin = "$env:USERPROFILE\go\bin"
if (-not (Test-Path $goBin)) { New-Item -ItemType Directory -Force -Path $goBin | Out-Null }

function Install-Tool {
    param([string]$ToolName, [string]$RepoPath)
    Write-Host "Installing / updating $ToolName ..." -ForegroundColor Cyan -NoNewline
    try {
        go install -v "$RepoPath@latest" 2>$null
        if ($LASTEXITCODE -eq 0) { Write-Host " OK" -ForegroundColor Green }
        else { Write-Host " FAILED" -ForegroundColor Red }
    }
    catch { Write-Host " ERROR" -ForegroundColor Red }
}

$tools = @(
    @{n="subfinder";   r="github.com/projectdiscovery/subfinder/v2/cmd/subfinder"}
    @{n="amass";       r="github.com/owasp-amass/amass/v4/..."}
    @{n="assetfinder"; r="github.com/tomnomnom/assetfinder"}
    @{n="findomain";   r="github.com/Findomain/Findomain"}
    @{n="httpx";       r="github.com/projectdiscovery/httpx/cmd/httpx"}
    @{n="gau";         r="github.com/lc/gau/v2/cmd/gau"}
    @{n="waymore";     r="github.com/xnl-h4ck3r/waymore"}
    @{n="waybackurls"; r="github.com/tomnomnom/waybackurls"}
    @{n="katana";      r="github.com/projectdiscovery/katana/cmd/katana"}
    @{n="hakrawler";   r="github.com/hakluke/hakrawler"}
    @{n="gospider";    r="github.com/jaeles-project/gospider"}
    @{n="ffuf";        r="github.com/ffuf/ffuf/v2"}
    @{n="nuclei";      r="github.com/projectdiscovery/nuclei/v3/cmd/nuclei"}
    @{n="dalfox";      r="github.com/hahwul/dalfox/v2"}
    @{n="tlsx";        r="github.com/projectdiscovery/tlsx/cmd/tlsx"}
    @{n="dnsx";        r="github.com/projectdiscovery/dnsx/cmd/dnsx"}
    @{n="arjun";       r="github.com/s0md3v/Arjun"}
    @{n="paramspider"; r="github.com/devanshbatham/ParamSpider"}
    @{n="gf";          r="github.com/tomnomnom/gf"}
    @{n="x8";          r="github.com/Sh1Yo/x8"}
    @{n="getJS";       r="github.com/003random/getJS"}
    @{n="linkfinder";  r="github.com/GerbenJavado/LinkFinder"}
    @{n="qsreplace";   r="github.com/tomnomnom/qsreplace"}
)

foreach ($t in $tools) {
    Install-Tool -ToolName $t.n -RepoPath $t.r
}

Write-Host "`nInstallation finished." -ForegroundColor Green
Write-Host "Make sure $env:USERPROFILE\go\bin is in your PATH." -ForegroundColor White
Write-Host "Verify: subfinder -version   amass version   httpx -version" -ForegroundColor Cyan
