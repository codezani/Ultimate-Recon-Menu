# ================================
# Ultimate Recon – Windows Installer
# ================================

Write-Host "[*] Installing Recon Tools (Windows)" -ForegroundColor Cyan

# Check Go
if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    Write-Host "[!] Go is not installed. Install Go first." -ForegroundColor Red
    exit
}

$env:Path += ";$env:USERPROFILE\go\bin"

function Install-GoTool {
    param($Repo)
    Write-Host "[+] Installing $Repo"
    go install "$Repo@latest"
}

# Core tools
Install-GoTool "github.com/projectdiscovery/subfinder/v2/cmd/subfinder"
Install-GoTool "github.com/owasp-amass/amass/v4/..."
Install-GoTool "github.com/projectdiscovery/httpx/cmd/httpx"
Install-GoTool "github.com/projectdiscovery/dnsx/cmd/dnsx"
Install-GoTool "github.com/d3mondev/puredns/v2"
Install-GoTool "github.com/projectdiscovery/tlsx/cmd/tlsx"
Install-GoTool "github.com/lc/gau/v2/cmd/gau"
Install-GoTool "github.com/tomnomnom/waybackurls"
Install-GoTool "github.com/projectdiscovery/katana/cmd/katana"
Install-GoTool "github.com/ffuf/ffuf/v2"
Install-GoTool "github.com/projectdiscovery/nuclei/v3/cmd/nuclei"
Install-GoTool "github.com/hahwul/dalfox/v2"
Install-GoTool "github.com/projectdiscovery/naabu/v2/cmd/naabu"
Install-GoTool "github.com/tomnomnom/gf"
Install-GoTool "github.com/projectdiscovery/notify/cmd/notify"

# Nuclei templates
Write-Host "[+] Updating nuclei templates"
nuclei -update-templates

# GF patterns
$gfDir = "$env:USERPROFILE\.gf"
if (-not (Test-Path $gfDir)) {
    git clone https://github.com/1ndianl33t/Gf-Patterns $gfDir
}

# DNS resolvers
$resolvers = "$PSScriptRoot\resolvers.txt"
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/janmasarik/resolvers/master/resolvers.txt" `
  -OutFile $resolvers

Write-Host "[✓] All tools installed successfully" -ForegroundColor Green
Write-Host "Restart PowerShell if some commands are not recognized."
