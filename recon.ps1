#Requires -RunAsAdministrator
<#
    Ultimate Recon Framework – Windows Edition (Fast & Safe)
    Version: 1.0.2 – Added gospider + fallparams + parameter step
    Purpose: Authorized Security Testing / Bug Bounty / Pentesting ONLY
    Optimized for speed and stability on Windows
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Domain,

    [string]$Wordlist = "wordlists\dir-medium.txt",

    [string]$NucleiSeverity = "critical,high,medium",

    [switch]$DryRun
)

# ───────────── Domain Validation ─────────────
if ($Domain -notmatch '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
    Write-Host "ERROR: Invalid domain format." -ForegroundColor Red
    exit 1
}

# ───────────── Legal Banner ─────────────
Clear-Host
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Red
Write-Host "              AUTHORIZED SECURITY TESTING ONLY" -ForegroundColor Yellow
Write-Host " Target: $Domain" -ForegroundColor White
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Red
Read-Host "Press Enter to confirm authorization" | Out-Null

# ───────────── Configuration ─────────────
$Config = @{
    HttpxRate      = 120
    HttpxTimeout   = 15
    HttpxRetries   = 2
    NucleiRate     = 30
    NucleiTimeout  = 15
    FFUFThreads    = 25          # lowered a bit to avoid blocks
    FFUFTimeout    = 12
    KatanaDepth    = 4           # increased a bit
    GospiderDepth  = 2
    GospiderThreads= 10
    MaxTargets     = 6
    AmassTimeout   = 60          # increased - passive should have more time
    AmassMaxQueries= 5000
    NaabuPorts     = 1000
    LogFile        = "recon.log"
}

# ───────────── Setup ─────────────
$scriptDir = $PSScriptRoot
$Wordlist  = Join-Path $scriptDir $Wordlist   # make path more reliable

$OutDir = "$Domain-recon"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Set-Location $OutDir

# ───────────── Helpers ─────────────
function Log {
    param($Msg, $Lvl = "INFO")
    $t = Get-Date -Format "HH:mm:ss"
    $l = "[$t][$Lvl] $Msg"
    Write-Host $l
    $l | Out-File $Config.LogFile -Append -Encoding utf8
}

function Tool-Exists { 
    param($n) 
    return $null -ne (Get-Command $n -ErrorAction SilentlyContinue) 
}

function Execute {
    param($Cmd)
    if ($DryRun) { 
        Log "[DRY-RUN] $Cmd" "DRY"; 
        return 
    }
    Log "RUN → $Cmd"
    try {
        Invoke-Expression $Cmd
    } catch {
        Log "Command failed: $_" "ERROR"
    }
}

function Step-Done { 
    param($n) 
    Test-Path ".done_$n" 
}

function Mark-Done { 
    param($n) 
    New-Item ".done_$n" -ItemType File -Force | Out-Null 
}

function Require-File {
    param($f, $s)
    if (-not (Test-Path $f)) { 
        Log "Missing $f → run step $s first" "ERROR"; 
        return $false 
    }
    return $true
}

# ───────────── Tool Availability Check ─────────────
$Tools = @("subfinder","amass","httpx","gau","waybackurls","katana","ffuf","nuclei","dalfox","naabu","tlsx","puredns","dnsx","gospider","fallparams")
foreach ($t in $Tools) {
    if (-not (Tool-Exists $t)) { Log "$t not found in PATH - install with go install ..." "WARN" }
}

# ───────────── Recon Steps ─────────────

function Step-Subdomains {
    if (Step-Done "subs") { Log "Subdomains already completed"; return }
    Log "Starting fast subdomain enumeration..."

    Execute "subfinder -d $Domain -all -silent -o subs_subfinder.txt"

    Execute "amass enum -passive -norecursive -timeout $($Config.AmassTimeout) -max-dns-queries $($Config.AmassMaxQueries) -d $Domain -o subs_amass.txt"

    Get-Content subs_*.txt -ErrorAction SilentlyContinue | Sort-Object -Unique | Out-File all_subs.txt -Encoding utf8

    if (Tool-Exists "puredns") {
        Execute "puredns resolve all_subs.txt -q -w resolved.txt" 2>$null
        if (Test-Path resolved.txt) { Execute "dnsx -l resolved.txt -silent -o scoped_subs.txt" }
        else { Copy-Item all_subs.txt scoped_subs.txt }
    } else { Copy-Item all_subs.txt scoped_subs.txt }

    Mark-Done "subs"
    $count = (Get-Content scoped_subs.txt -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
    Log "$count in-scope subdomains found"
}

function Step-LiveHosts {
    if (-not (Require-File "scoped_subs.txt" "1")) { return }
    if (Step-Done "live") { return }
    Log "Probing live hosts..."
    Execute "httpx -l scoped_subs.txt -rl $($Config.HttpxRate) -timeout $($Config.HttpxTimeout) -retries $($Config.HttpxRetries) -title -tech-detect -silent -o live_urls.txt"
    Execute "tlsx -l live_urls.txt -silent -o tls.txt" 2>$null
    Mark-Done "live"
    $count = (Get-Content live_urls.txt -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
    Log "$count live hosts detected"
}

function Step-URLCollection {
    if (-not (Require-File "live_urls.txt" "2")) { return }
    if (Step-Done "urls") { return }
    Log "Collecting URLs (fast + deep mode)..."

    if (Tool-Exists "gau")         { Execute "gau $Domain --subs --o gau.txt" }
    if (Tool-Exists "waybackurls") { Execute "waybackurls $Domain -o wayback.txt" }
    if (Tool-Exists "katana")      { Execute "katana -list live_urls.txt -depth $($Config.KatanaDepth) -jc -silent -o katana.txt" }
    
    # Added: gospider as additional crawler
    if (Tool-Exists "gospider") {
        Log "Running gospider crawler..."
        Execute "gospider -S live_urls.txt -o gospider_out -c $($Config.GospiderThreads) -d $($Config.GospiderDepth) -q -t 5"
        Get-ChildItem gospider_out -File | ForEach-Object { Get-Content $_.FullName } | Sort-Object -Unique | Out-File gospider_urls.txt
    }

    Get-Content gau.txt,wayback.txt,katana.txt,gospider_urls.txt -ErrorAction SilentlyContinue | 
        Sort-Object -Unique | Out-File scoped_urls.txt -Encoding utf8
    
    Mark-Done "urls"
    $count = (Get-Content scoped_urls.txt -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
    Log "$count URLs collected"
}

function Step-Parameters {
    if (-not (Require-File "scoped_urls.txt" "3")) { return }
    if (Step-Done "params") { Log "Parameters already processed"; return }

    if (-not (Tool-Exists "fallparams")) {
        Log "fallparams not found → skipping parameter discovery" "WARN"
        return
    }

    Log "Running fallparams for hidden parameter discovery..."
    New-Item params_results -ItemType Directory -Force | Out-Null

    # Basic mode: feed list of URLs
    Execute "fallparams -u scoped_urls.txt -crawl -depth 2 -o params_results/parameters.txt -t 5"

    # Optional: if you want more aggressive → add -headless (needs browser setup)
    # Execute "fallparams -u scoped_urls.txt -crawl -headless -o params_results/parameters_headless.txt"

    Mark-Done "params"
    if (Test-Path "params_results/parameters.txt") {
        $count = (Get-Content "params_results/parameters.txt" | Measure-Object -Line).Lines
        Log "$count potential parameters found"
    }
}

function Step-DirectoryBrute {
    if (-not (Require-File "live_urls.txt" "2")) { return }

    if (-not (Test-Path $Wordlist)) {
        Clear-Host
        Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host "                   WORDLIST NOT FOUND!" -ForegroundColor Red
        Write-Host "Required: $Wordlist" -ForegroundColor Yellow
        Write-Host "Suggestion:" -ForegroundColor White
        Write-Host "   Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/raft-medium-directories.txt' -OutFile '$Wordlist'" -ForegroundColor Cyan
        Read-Host "Press Enter after fixing..."
        if (-not (Test-Path $Wordlist)) { Log "Wordlist missing – skipping FFUF" "ERROR"; return }
    }

    New-Item ffuf_results -ItemType Directory -Force | Out-Null
    Log "Directory brute-force on top $($Config.MaxTargets) hosts..."

    Get-Content live_urls.txt | Select-Object -First $Config.MaxTargets | ForEach-Object {
        $url = $_.Trim()
        if (-not $url.EndsWith("/")) { $url += "/" }
        $safe = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($url)) -replace '=',''
        Execute "ffuf -u `"$url`FUZZ`" -w $Wordlist -t $($Config.FFUFThreads) -timeout $($Config.FFUFTimeout) -mc 200,301,302,307,308,401,403 -ac -r -o ffuf_results/ffuf_$safe.json"
    }
}

function Step-NucleiScan {
    if (-not (Require-File "live_urls.txt" "2")) { return }
    Log "Running fast Nuclei scan..."
    Execute "nuclei -l live_urls.txt -rate-limit $($Config.NucleiRate) -severity $NucleiSeverity -timeout $($Config.NucleiTimeout) -retries 1 -o nuclei_results.txt"
}

function Step-XSSScan {
    if (-not (Tool-Exists "dalfox")) { Log "dalfox not available" "WARN"; return }
    if (-not (Require-File "scoped_urls.txt" "3")) { return }
    Log "Running XSS scan..."
    Get-Content scoped_urls.txt | & dalfox pipe --only-poc --delay 200 --no-color --output dalfox_results.txt
}

function Step-PortScan {
    if (-not (Require-File "scoped_subs.txt" "1")) { return }
    Log "Port scanning..."
    Execute "naabu -list scoped_subs.txt -top-ports $($Config.NaabuPorts) -silent -o ports.txt"
}

function Generate-HTMLReport {
    Log "Generating HTML report..."
    $files = @("scoped_subs.txt","live_urls.txt","scoped_urls.txt","params_results/parameters.txt","nuclei_results.txt","dalfox_results.txt","ports.txt","tls.txt")
    $html = "<html><head><meta charset='utf-8'><title>Recon Report - $Domain</title><style>body{background:#0d1117;color:#c9d1d9;font-family:Consolas;padding:20px}h1{color:#58a6ff;text-align:center}h2{color:#f0883e}pre{background:#010409;padding:15px;border-radius:8px;max-height:500px;overflow:auto}</style></head><body><h1>Recon Report - $Domain</h1><p>Generated: $(Get-Date)</p>"
    foreach ($f in $files) {
        if (Test-Path $f) {
            $c = Get-Content $f -ErrorAction SilentlyContinue
            $html += "<h2>$f ($($c.Count) lines)</h2><pre>$($c | Select-Object -First 300 | Out-String)</pre>"
        }
    }
    $html += "</body></html>"
    $html | Out-File report.html -Encoding utf8
    Log "Report saved → report.html"
}

# ───────────── Main Menu ─────────────
while ($true) {
    Clear-Host

    Write-Host "════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host " Ultimate Recon Framework – $Domain" -ForegroundColor White
    Write-Host "════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "1  Subdomains    2  Live Hosts    3  URLs"
    Write-Host "8  Parameters    4  FFUF          5  Nuclei"
    Write-Host "6  XSS           7  Ports         13 Report"
    Write-Host "════════════════════════════════════════════════" -ForegroundColor Magenta

    $c = Read-Host "`nSelect"
    switch ($c) {
        "1"  { Step-Subdomains }
        "2"  { Step-LiveHosts }
        "3"  { Step-URLCollection }
        "4"  { Step-DirectoryBrute }
        "5"  { Step-NucleiScan }
        "6"  { Step-XSSScan }
        "7"  { Step-PortScan }
        "8"  { Step-Parameters }
        "13" { Generate-HTMLReport }
        "x"  { 
            Log "Recon session completed."
            Write-Host "`nRecon finished! Results in: $OutDir" -ForegroundColor Green
            break 
        }
        default { Write-Host "Invalid option" -ForegroundColor Red; Pause }
    }

    Write-Host "`nPress Enter to return..." -ForegroundColor Cyan
    Read-Host | Out-Null
}
