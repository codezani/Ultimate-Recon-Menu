#Requires -RunAsAdministrator
<#
    Ultimate Recon Framework - Tools Installer
    Version: 1.7.0
    Installs all required tools for the recon script
#>

Clear-Host
Write-Host "════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "       Ultimate Recon Tools Installer v1.7.0 (Windows)       " -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

$GoBin = "$env:USERPROFILE\go\bin"
$env:PATH += ";$GoBin;C:\Program Files\Go\bin"

# ────────────────────────────── 1. Install Go ──────────────────────────────
function Install-Go {
    Write-Host "`n[+] Checking Go installation..." -ForegroundColor Cyan
    if (Get-Command go -ErrorAction SilentlyContinue) {
        Write-Host "Go is already installed: $(go version)" -ForegroundColor Green
        return
    }

    Write-Host "Go not found. Downloading latest version..." -ForegroundColor Yellow
    $goUrl = "https://go.dev/dl/go1.24.2.windows-amd64.msi"   # Update if newer
    $goMsi = "$env:TEMP\go.msi"

    Invoke-WebRequest -Uri $goUrl -OutFile $goMsi
    Start-Process msiexec.exe -ArgumentList "/i `"$goMsi`" /quiet /qn" -Wait
    Remove-Item $goMsi -Force

    # Refresh PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "Go installed successfully!" -ForegroundColor Green
}

# ────────────────────────────── 2. Install Go Tools ──────────────────────────────
function Install-GoTools {
    Write-Host "`n[+] Installing Go-based tools..." -ForegroundColor Cyan

    $tools = @(
        "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest",
        "github.com/OWASP/Amass/v3/...@latest",
        "github.com/tomnomnom/assetfinder@latest",
        "github.com/projectdiscovery/httpx/cmd/httpx@latest",
        "github.com/lc/gau/v2/cmd/gau@latest",
        "github.com/projectdiscovery/katana/cmd/katana@latest",
        "github.com/hakluke/hakrawler@latest",
        "github.com/jaeles-project/gospider@latest",
        "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest",
        "github.com/projectdiscovery/dnsx/cmd/dnsx@latest",
        "github.com/projectdiscovery/tlsx/cmd/tlsx@latest",
        "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest",
        "github.com/ffuf/ffuf/v2@latest",
        "github.com/ImAyrix/fallparams@latest",
        "github.com/hahwul/dalfox/v2@latest",
        "github.com/tomnomnom/qsreplace@latest"
    )

    foreach ($tool in $tools) {
        $name = ($tool -split '/')[-1] -replace '@.*',''
        Write-Host "Installing $name ..." -ForegroundColor Gray -NoNewline
        try {
            go install -v $tool
            Write-Host " ✓" -ForegroundColor Green
        } catch {
            Write-Host " ✗" -ForegroundColor Red
        }
    }
}

# ────────────────────────────── 3. Install Python Tools ──────────────────────────────
function Install-PythonTools {
    Write-Host "`n[+] Installing Python-based tools..." -ForegroundColor Cyan

    # Check Python
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Host "Python not found. Installing via winget..." -ForegroundColor Yellow
        winget install Python.Python.3 -s winget --silent
    }

    $pipTools = @("arjun", "paramspider")

    foreach ($tool in $pipTools) {
        Write-Host "Installing $tool ..." -ForegroundColor Gray -NoNewline
        pip install $tool -q
        if (Get-Command $tool -ErrorAction SilentlyContinue) {
            Write-Host " ✓" -ForegroundColor Green
        } else {
            Write-Host " ✗" -ForegroundColor Red
        }
    }
}

# ────────────────────────────── 4. Other Tools ──────────────────────────────
function Install-OtherTools {
    Write-Host "`n[+] Installing other tools..." -ForegroundColor Cyan

    # waybackurls
    Write-Host "Installing waybackurls..." -ForegroundColor Gray -NoNewline
    go install github.com/tomnomnom/waybackurls@latest
    Write-Host " ✓" -ForegroundColor Green

    # gf
    Write-Host "Installing gf..." -ForegroundColor Gray -NoNewline
    go install github.com/tomnomnom/gf@latest
    Write-Host " ✓" -ForegroundColor Green

    # getJS
    Write-Host "Installing getJS..." -ForegroundColor Gray -NoNewline
    go install github.com/003random/getJS@latest
    Write-Host " ✓" -ForegroundColor Green

    # x8
    Write-Host "Installing x8..." -ForegroundColor Gray -NoNewline
    go install github.com/Sh1Yo/x8@latest
    Write-Host " ✓" -ForegroundColor Green

    # linkfinder
    Write-Host "Installing linkfinder..." -ForegroundColor Gray -NoNewline
    pip install linkfinder -q
    Write-Host " ✓" -ForegroundColor Green

    # TruffleHog
    Write-Host "Installing trufflehog..." -ForegroundColor Gray -NoNewline
    go install github.com/trufflesecurity/trufflehog/v3@latest
    Write-Host " ✓" -ForegroundColor Green

    # Gitleaks
    Write-Host "Installing gitleaks..." -ForegroundColor Gray -NoNewline
    winget install gitleaks -s winget --silent
    Write-Host " ✓" -ForegroundColor Green
}

# ────────────────────────────── 5. Create Wordlist Directory ──────────────────────────────
function Create-Wordlists {
    Write-Host "`n[+] Creating wordlists directory..." -ForegroundColor Cyan
    $wlDir = Join-Path $PSScriptRoot "wordlists"
    New-Item -ItemType Directory -Force -Path $wlDir | Out-Null

    Write-Host "Wordlists folder created at: $wlDir" -ForegroundColor Green
    Write-Host "You can download common wordlists (dir-medium.txt, params-top.txt, etc.) manually." -ForegroundColor Gray
}

# ────────────────────────────── Main Execution ──────────────────────────────
try {
    Install-Go
    Install-GoTools
    Install-PythonTools
    Install-OtherTools
    Create-Wordlists

    Write-Host "`n════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "All tools installed successfully!" -ForegroundColor Green
    Write-Host "Add this to your recon script if not already there:" -ForegroundColor Cyan
    Write-Host "`$env:PATH = `"`$PSScriptRoot;`$env:USERPROFILE\go\bin;C:\Program Files\Go\bin;`$env:PATH`"" -ForegroundColor White
    Write-Host "`nYou can now run your Ultimate Recon Framework." -ForegroundColor Magenta
    Write-Host "════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green

} catch {
    Write-Host "An error occurred during installation: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "`nPress Enter to exit..."
