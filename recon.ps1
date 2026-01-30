#Requires -RunAsAdministrator
<#
    Ultimate Recon Framework – Windows Edition (2026 – MAX Coverage)
    Version: 1.5.13 – Final | All tools kept | Fixed flags + per-tool resume & logging | dnsx instead of puredns
    Purpose: AUTHORIZED TESTING / Bug Bounty / Pentest ONLY
    Warning: Explicit written permission required for any target!
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Domain,

    [string]$WordlistDir = "wordlists",

    [string]$NucleiSeverity = "critical,high,medium,low,unknown",

    [string]$Proxy = "",

    [switch]$Auto,

    [switch]$DryRun
)

# ────────────────────────────── Validation & Banner ──────────────────────────────
if ($Domain -notmatch '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
    Write-Host "ERROR: Invalid domain format (e.g. example.com)" -ForegroundColor Red
    exit 1
}

Clear-Host
Write-Host "════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
Write-Host "       AUTHORIZED SECURITY TESTING ONLY – 2026 MAX RECON COVERAGE        " -ForegroundColor Yellow
Write-Host " Target : $Domain" -ForegroundColor White
if ($Proxy) { Write-Host " Proxy  : $Proxy" -ForegroundColor Cyan }
if ($Auto)  { Write-Host " Mode   : FULL AUTO PIPELINE" -ForegroundColor Green }
Write-Host "════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red

if (-not $Auto) { Read-Host "Press Enter to confirm authorization" | Out-Null }

# ────────────────────────────── Configuration ──────────────────────────────
$Config = @{
    HttpxRate      = 160
    HttpxTimeout   = 10
    HttpxRetries   = 2
    NucleiRate     = 45
    NucleiTimeout  = 10
    FFUFThreads    = 40
    FFUFTimeout    = 8
    KatanaDepth    = 6
    GospiderDepth  = 4
    HakrawlerDepth = 5
    GospiderThreads= 15
    ArjunThreads   = 12
    X8Threads      = 80
    MaxFFUFTargets = 25
    LogFile        = "recon.log"
    
    AmassTimeout   = 30
    AmassDNSQPS    = 100
    AmassMaxQueries= 10000
}

$BaseDir   = $PSScriptRoot
$OutputDir = Join-Path $BaseDir "$Domain-recon"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Set-Location $OutputDir

$proxyArg = if ($Proxy) { "-proxy `"$Proxy`"" } else { "" }

# ─── Tool search ───────
$env:PATH = "$PSScriptRoot;$env:USERPROFILE\go\bin;C:\Program Files\Go\bin;$env:PATH"

# ────────────────────────────── Helper Functions ──────────────────────────────
function Log-Step {
    param([string]$Msg, [string]$Lvl = "INFO")
    $t = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$t] [$Lvl] $Msg" | Out-File $Config.LogFile -Append -Encoding utf8
}

function Log-Tool {
    param([string]$Tool, [string]$Action, [string]$Extra = "")
    Log-Step "$Tool $Action $Extra" "TOOL"
}

function Tool-Exists { param([string]$n) return $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }

function Execute-Tool {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Cmd,

        [string]$ToolName = $null
    )

    if (-not $ToolName) {
        $ToolName = ($Cmd -split ' ')[0].Trim()
    }

    Log-Tool $ToolName "STARTED" "→ $Cmd"
    Write-Host "Executing $ToolName → $Cmd" -ForegroundColor DarkCyan

    if ($DryRun) {
        Log-Tool $ToolName "DRY-RUN"
        return $true
    }

    $success = $false
    try {
        Invoke-Expression $Cmd
        $success = $true
        Log-Tool $ToolName "FINISHED"
        Write-Host "$ToolName finished" -ForegroundColor Green
    }
    catch {
        Log-Tool $ToolName "FAILED" "- $($_.Exception.Message)"
        Write-Host "$ToolName failed: $($_.Exception.Message)" -ForegroundColor Red
    }

    return $success
}

function Step-Done { param([string]$n) Test-Path ".done_$n" }
function Mark-Done { param([string]$n) New-Item ".done_$n" -ItemType File -Force | Out-Null }

function Require-File {
    param([string]$f, [string]$s)
    if (-not (Test-Path $f)) {
        Write-Host "Missing file: $f  →  run step '$s' first" -ForegroundColor Red
        return $false
    }
    return $true
}

# ────────────────────────────── Tool Availability Warning ──────────────────────────────
$Tools = @(
    "subfinder","amass","assetfinder","findomain","httpx","gau","waymore","waybackurls",
    "katana","hakrawler","gospider","ffuf","nuclei","dalfox","tlsx","dnsx",
    "fallparams","arjun","paramspider","gf","x8","getJS","linkfinder","qsreplace"
)

foreach ($t in $Tools) {
    if (-not (Tool-Exists $t)) {
        Write-Host "Tool not found: $t" -ForegroundColor Yellow
    }
}

# ────────────────────────────── Recon Steps ──────────────────────────────

function Step-Subdomains {
    if (Step-Done "subs") { Write-Host "Subdomains already completed" -ForegroundColor Cyan; return }

    Log-Step "Subdomains" "STARTED"

    if (-not (Test-Path "subfinder.txt"))   { Execute-Tool "subfinder -d $Domain -all -silent -o subfinder.txt $proxyArg" "subfinder" }
    if (-not (Test-Path "amass.txt"))       { Execute-Tool "amass enum -passive -d $Domain -timeout $($Config.AmassTimeout) -dns-qps $($Config.AmassDNSQPS) -max-dns-queries $($Config.AmassMaxQueries) -o amass.txt $proxyArg" "amass" }
    if (Tool-Exists "assetfinder" -and -not (Test-Path "assetfinder.txt")) { Execute-Tool "assetfinder --subs-only $Domain > assetfinder.txt" "assetfinder" }
    if (Tool-Exists "findomain"   -and -not (Test-Path "findomain.txt"))   { Execute-Tool "findomain -t $Domain -q -u findomain.txt" "findomain" }

    if (-not (Test-Path "scoped_subs.txt")) {
        $files = @("subfinder.txt","amass.txt","assetfinder.txt","findomain.txt")
        $all = @()
        foreach ($f in $files) { if (Test-Path $f) { $all += Get-Content $f -ea 0 } }
        $all | Sort-Object -Unique | Out-File scoped_subs.txt
    }

    if (-not (Test-Path "resolved.txt")) {
        Execute-Tool "dnsx -l scoped_subs.txt -silent -resp-only -o resolved.txt $proxyArg" "dnsx"
    }

    if (-not (Test-Path "live_subs.txt")) {
        Execute-Tool "dnsx -l resolved.txt -silent -resp-only -o live_subs.txt $proxyArg" "dnsx"
    }

    if (Test-Path "live_subs.txt") {
        Mark-Done "subs"
        Log-Step "Subdomains" "COMPLETED"
        Write-Host "Subdomains completed" -ForegroundColor Green
    }
}

function Step-LiveHosts {
    if (-not (Require-File "live_subs.txt" "subdomains")) { return }
    if (Step-Done "live") { Write-Host "LiveHosts already completed" -ForegroundColor Cyan; return }

    Log-Step "LiveHosts" "STARTED"

    if (-not (Test-Path "live.json")) {
        Execute-Tool "httpx -l live_subs.txt -rl $($Config.HttpxRate) -timeout $($Config.HttpxTimeout) -retries $($Config.HttpxRetries) -title -tech-detect -status-code -json -o live.json $proxyArg" "httpx"
    }

    if ((Test-Path "live.json") -and (-not (Test-Path "live_urls.txt"))) {
        Get-Content live.json | ConvertFrom-Json | 
            Where-Object { $_.status_code -and $_.status_code -lt 500 } | 
            Select-Object -ExpandProperty url | 
            Out-File live_urls.txt -Encoding utf8
        Write-Host "Extracted live URLs to live_urls.txt" -ForegroundColor Cyan
    }

    if ((Test-Path "live_urls.txt") -and (-not (Test-Path "tls.txt"))) {
        Execute-Tool "tlsx -l live_urls.txt -o tls.txt $proxyArg" "tlsx"
    }

    if (Test-Path "live_urls.txt") {
        Mark-Done "live"
        Log-Step "LiveHosts" "COMPLETED"
        Write-Host "LiveHosts completed" -ForegroundColor Green
    }
}

function Step-URLCollection {
    if (-not (Require-File "live_urls.txt" "livehosts")) { return }
    if (Step-Done "urls") { Write-Host "URLCollection already completed" -ForegroundColor Cyan; return }

    Log-Step "URLCollection" "STARTED"

    if (Tool-Exists "gau" -and -not (Test-Path "gau.txt")) { 
        Execute-Tool "gau $Domain --subs --blacklist png,jpg,woff,css,js > gau.txt" "gau" 
    }

    if (Tool-Exists "waymore" -and -not (Test-Path "waymore.txt")) { 
        Execute-Tool "waymore -i $Domain -oU waymore.txt" "waymore" 
    }

    if (Tool-Exists "waybackurls" -and -not (Test-Path "wayback.txt")) { 
        Execute-Tool "waybackurls $Domain > wayback.txt" "waybackurls" 
    }

    if (-not (Test-Path "katana.txt")) { 
        Execute-Tool "katana -list live_urls.txt -d $($Config.KatanaDepth) -jc -silent -o katana.txt $proxyArg" "katana" 
    }

    if (Tool-Exists "hakrawler" -and -not (Test-Path "hakrawler.txt")) {
        Execute-Tool "Get-Content live_urls.txt | hakrawler -d $($Config.HakrawlerDepth) > hakrawler.txt" "hakrawler"
    }

    if (Tool-Exists "gospider" -and -not (Test-Path "gospider_urls.txt")) {
        Remove-Item "gospider_out" -Recurse -Force -ErrorAction SilentlyContinue
        Execute-Tool "gospider -S live_urls.txt -o gospider_out -c $($Config.GospiderThreads) -d $($Config.GospiderDepth) -q --other-source" "gospider"
        Get-ChildItem "gospider_out" -Recurse -File | Get-Content | Sort-Object -Unique | Out-File gospider_urls.txt
    }

    if (-not (Test-Path "all_urls.txt")) {
        $files = @("gau.txt","waymore.txt","wayback.txt","katana.txt","hakrawler.txt","gospider_urls.txt")
        $all = @()
        foreach ($f in $files) { if (Test-Path $f) { $all += Get-Content $f -ea 0 } }
        $all | Sort-Object -Unique | Out-File all_urls.txt
    }

    if (Test-Path "all_urls.txt") {
        Mark-Done "urls"
        Log-Step "URLCollection" "COMPLETED"
        Write-Host "URLCollection completed – all_urls.txt ready" -ForegroundColor Green
    }
}

function Step-ParametersAndJS {
    if (-not (Require-File "all_urls.txt" "urls")) { return }
    if (Step-Done "params_js") { Write-Host "ParametersAndJS already completed" -ForegroundColor Cyan; return }

    Log-Step "ParametersAndJS" "STARTED"

    New-Item -ItemType Directory -Force -Path "params_js" | Out-Null

    if (Tool-Exists "fallparams" -and -not (Test-Path "params_js/fall.txt")) {
        Execute-Tool "fallparams -u all_urls.txt -c -d 3 -t 20 -o params_js/fall.txt" "fallparams"
    }

    if (Tool-Exists "arjun" -and -not (Test-Path "params_js/arjun.json")) {
        Execute-Tool "arjun -i all_urls.txt -t $($Config.ArjunThreads) -oT params_js/arjun.json" "arjun"
    }

    if (Tool-Exists "paramspider" -and -not (Test-Path "params_js/paramspider.txt")) {
        Execute-Tool "paramspider -d $Domain --output params_js/paramspider.txt" "paramspider"
    }

    if (-not (Test-Path "params_all.txt")) {
        Get-ChildItem "params_js" -File -Filter "*.txt" -ErrorAction SilentlyContinue | 
            Get-Content | Sort-Object -Unique | Out-File params_all.txt
    }

    if (Tool-Exists "getJS" -and -not (Test-Path "params_js/js_files.txt")) {
        Execute-Tool "Get-Content all_urls.txt | getJS --complete > params_js/js_files.txt" "getJS"
    }

    if (Tool-Exists "linkfinder" -and (Test-Path "params_js/js_files.txt") -and -not (Test-Path "params_js/endpoints.txt")) {
        Execute-Tool "Get-Content params_js/js_files.txt | linkfinder -o cli -d > params_js/endpoints.txt" "linkfinder"
    }

    if (Tool-Exists "gf") {
        New-Item -ItemType Directory -Force -Path "gf_patterns" | Out-Null
        @("secret","api","token","aws","firebase","takeover","jsvar","debug_page") | ForEach-Object {
            $patternFile = "gf_patterns/$_.txt"
            if (-not (Test-Path $patternFile)) {
                Execute-Tool "Get-Content all_urls.txt | gf $_ | Sort-Object -Unique | Out-File $patternFile" "gf-$_"
            }
        }
    }

    if (Tool-Exists "qsreplace" -and -not (Test-Path "params_js/urls_with_fuzz.txt")) {
        Execute-Tool "Get-Content all_urls.txt | qsreplace `"FUZZ`" > params_js/urls_with_fuzz.txt" "qsreplace"
    }

    if (Test-Path "params_all.txt") {
        Mark-Done "params_js"
        Log-Step "ParametersAndJS" "COMPLETED"
        Write-Host "ParametersAndJS completed" -ForegroundColor Green
    } else {
        Log-Step "ParametersAndJS" "COMPLETED_PARTIAL"
        Write-Host "ParametersAndJS partially completed (some tools failed)" -ForegroundColor Yellow
    }
}

function Step-X8Fuzz {
    if (-not (Require-File "live_urls.txt" "livehosts")) { return }
    if (-not (Tool-Exists "x8")) { Write-Host "x8 not found" -ForegroundColor Yellow; return }
    if (Step-Done "x8") { Write-Host "x8 already completed" -ForegroundColor Cyan; return }

    Log-Step "x8" "STARTED"

    $wordlist = if (Test-Path "params_all.txt") { "params_all.txt" } else { "$WordlistDir/params-top.txt" }
    if (-not (Test-Path $wordlist)) { Write-Host "No wordlist for x8" -ForegroundColor Yellow; return }

    if (-not (Test-Path "x8_results.txt")) {
        Execute-Tool "x8 -l live_urls.txt -w $wordlist -t $($Config.X8Threads) -o x8_results.txt $proxyArg" "x8"
    }

    if (Test-Path "x8_results.txt") {
        Mark-Done "x8"
        Log-Step "x8" "COMPLETED"
        Write-Host "x8 completed" -ForegroundColor Green
    }
}

function Step-DirectoryBrute {
    if (-not (Require-File "live_urls.txt" "livehosts")) { return }
    $wordlist = Join-Path $BaseDir "$WordlistDir\dir-medium.txt"
    if (-not (Test-Path $wordlist)) { Write-Host "Directory wordlist missing" -ForegroundColor Yellow; return }
    if (Step-Done "ffuf") { Write-Host "FFUF already completed" -ForegroundColor Cyan; return }

    Log-Step "FFUF" "STARTED"

    Get-Content live_urls.txt -First $Config.MaxFFUFTargets | ForEach-Object {
        $url = $_.Trim()
        if (-not $url.EndsWith("/")) { $url += "/" }
        $safe = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($url)) -replace '[=/+]', ''
        $outFile = "ffuf_$safe.json"
        if (-not (Test-Path $outFile)) {
            Execute-Tool "ffuf -u `"$url`FUZZ`" -w `"$wordlist`" -t $($Config.FFUFThreads) -timeout $($Config.FFUFTimeout) -mc 200,301,302,307,308,401,403 -ac -r -o $outFile $proxyArg" "ffuf-$safe"
        }
    }

    Mark-Done "ffuf"
    Log-Step "FFUF" "COMPLETED"
    Write-Host "FFUF completed" -ForegroundColor Green
}

function Step-NucleiScan {
    if (-not (Require-File "live_urls.txt" "livehosts")) { return }
    if (Step-Done "nuclei") { Write-Host "Nuclei already completed" -ForegroundColor Cyan; return }

    Log-Step "Nuclei" "STARTED"

    if (-not (Test-Path "nuclei_results.txt")) {
        Execute-Tool "nuclei -l live_urls.txt -severity $NucleiSeverity -rl $($Config.NucleiRate) -timeout $($Config.NucleiTimeout) -o nuclei_results.txt $proxyArg" "nuclei"
    }

    if (Test-Path "nuclei_results.txt") {
        Mark-Done "nuclei"
        Log-Step "Nuclei" "COMPLETED"
        Write-Host "Nuclei completed" -ForegroundColor Green
    }
}

function Step-XSSScan {
    if (-not (Require-File "all_urls.txt" "urls")) { return }
    if (-not (Tool-Exists "dalfox")) { Write-Host "dalfox not found" -ForegroundColor Yellow; return }
    if (Step-Done "xss") { Write-Host "XSS already completed" -ForegroundColor Cyan; return }

    Log-Step "dalfox" "STARTED"

    if (-not (Test-Path "dalfox_results.txt")) {
        Execute-Tool "Get-Content all_urls.txt | dalfox pipe --only-poc --delay 300 -o dalfox_results.txt" "dalfox"
    }

    if (Test-Path "dalfox_results.txt") {
        Mark-Done "xss"
        Log-Step "dalfox" "COMPLETED"
        Write-Host "XSS completed" -ForegroundColor Green
    }
}

function Generate-Report {
    Log-Step "Report" "STARTED"

    $files = @("scoped_subs.txt","live_urls.txt","all_urls.txt","params_all.txt","x8_results.txt","nuclei_results.txt","dalfox_results.txt")
    $html = "<html><head><meta charset='utf-8'><title>Recon Report - $Domain</title><style>body{background:#0d1117;color:#c9d1d9;font-family:Consolas;padding:20px;} h1{color:#58a6ff;text-align:center;} h2{color:#f0883e;} pre{background:#010409;padding:15px;border-radius:8px;max-height:400px;overflow:auto;}</style></head><body><h1>Recon Report – $Domain</h1><p>Generated: $(Get-Date)</p>"

    foreach ($f in $files) {
        if (Test-Path $f) {
            $count = (Get-Content $f -ea 0 | Measure-Object -Line).Lines
            $content = Get-Content $f -First 300 -ea 0 | Out-String
            $html += "<h2>$f ($count lines)</h2><pre>$content</pre>"
        }
    }
    $html += "</body></html>"
    $html | Out-File report.html -Encoding utf8

    Log-Step "Report" "COMPLETED"
    Write-Host "Report generated: report.html" -ForegroundColor Green
}

function Run-FullAuto {
    Write-Host "FULL AUTO started" -ForegroundColor Magenta
    Step-Subdomains
    Step-LiveHosts
    Step-URLCollection
    Step-ParametersAndJS
    Step-X8Fuzz
    Step-DirectoryBrute
    Step-NucleiScan
    Step-XSSScan
    Generate-Report
    Write-Host "FULL AUTO finished" -ForegroundColor Magenta
}

# ────────────────────────────── Main Menu ──────────────────────────────
if ($Auto) {
    Run-FullAuto
    exit
}

while ($true) {
    Clear-Host
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host " Ultimate Recon MAX 2026 – $Domain" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host " 1  Subdomains Enumeration"
    Write-Host " 2  Live Hosts Probing"
    Write-Host " 3  URL Collection"
    Write-Host " 4  Parameters + JS Analysis"
    Write-Host " 5  x8 Fuzzing"
    Write-Host " 6  FFUF Directories"
    Write-Host " 7  Nuclei Scan"
    Write-Host " 8  XSS (dalfox)"
    Write-Host " 9  Generate Report"
    Write-Host "10  FULL AUTO"
    Write-Host " x  Exit"
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Magenta

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1"  { Step-Subdomains }
        "2"  { Step-LiveHosts }
        "3"  { Step-URLCollection }
        "4"  { Step-ParametersAndJS }
        "5"  { Step-X8Fuzz }
        "6"  { Step-DirectoryBrute }
        "7"  { Step-NucleiScan }
        "8"  { Step-XSSScan }
        "9"  { Generate-Report }
        "10" { Run-FullAuto }
        "x"  {
            Write-Host "`nSession ended. Results in: $OutputDir" -ForegroundColor Green
            break
        }
        default { Write-Host "Invalid option" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }

    if ($choice -ne "x") {
        Write-Host "`nPress Enter to continue..." -ForegroundColor Cyan
        Read-Host | Out-Null
    }
}
