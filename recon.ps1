#Requires -RunAsAdministrator
<#
    Ultimate Recon Framework - Windows Edition
    Version: 1.6.16
    Purpose: Authorized security testing / Bug Bounty / Penetration Testing ONLY
    License: MIT
    Warning: Explicit written permission required before scanning any target!
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
Write-Host "       AUTHORIZED SECURITY TESTING ONLY – MAX RECON COVERAGE        " -ForegroundColor Yellow
Write-Host " Target : $Domain" -ForegroundColor White
if ($Proxy) { Write-Host " Proxy  : $Proxy" -ForegroundColor Cyan }
if ($Auto)  { Write-Host " Mode   : FULL AUTO PIPELINE" -ForegroundColor Green }
Write-Host "════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red

if (-not $Auto) { Read-Host "Press Enter to confirm you are authorized to test this target" | Out-Null }

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
    HakrawlerDepth = 5
    GospiderDepth  = 4
    GospiderThreads= 15
    ArjunThreads   = 12
    X8Threads      = 80
    MaxFFUFTargets = 25
    LogFile        = "recon.log"
    
    AmassTimeout   = 30          # minutes (1800 seconds)
    AmassDNSQPS    = 100
    AmassMaxQueries= 10000
    JitterMin      = 1
    JitterMax      = 4
}

$BaseDir   = $PSScriptRoot
$OutputDir = Join-Path $BaseDir "$Domain-recon"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Set-Location $OutputDir

$proxyArg = if ($Proxy) { "-proxy `"$Proxy`"" } else { "" }

$env:PATH = "$PSScriptRoot;$env:USERPROFILE\go\bin;C:\Program Files\Go\bin;$env:PATH"

Write-Host "Current working directory: $(Get-Location)" -ForegroundColor Cyan

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

        [string]$ToolName = $null,

        [string]$OutputFile = $null
    )

    if (-not $ToolName) { $ToolName = ($Cmd -split ' ')[0].Trim() }

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

    if ($OutputFile -and (Test-Path $OutputFile)) {
        $lines = Get-Content $OutputFile -ErrorAction SilentlyContinue
        $count = if ($lines) { $lines.Count } else { 0 }
        Write-Host "$ToolName output: $count lines in $OutputFile" -ForegroundColor Green
        
        if ($count -gt 0) {
            Write-Host "First 3 lines:" -ForegroundColor Cyan
            $lines | Select-Object -First 3 | ForEach-Object { Write-Host $_ }
        }
    }

    Start-Sleep -Seconds (Get-Random -Minimum $Config.JitterMin -Maximum $Config.JitterMax)
    return $success
}

function Step-Done { param([string]$n) Test-Path ".done_$n" }
function Mark-Done { param([string]$n) New-Item ".done_$n" -ItemType File -Force | Out-Null }

function Require-File {
    param([string]$f, [string]$s)
    if (-not (Test-Path $f)) {
        Write-Host "Missing file: $f  → run step '$s' first" -ForegroundColor Red
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
    if (Step-Done "subs") { 
        Write-Host "Subdomains already completed" -ForegroundColor Cyan
        return 
    }

    Log-Step "Subdomains" "STARTED"

    # Passive tools
    if (-not (Test-Path "subfinder.txt")) { 
        Execute-Tool "subfinder -d $Domain -all -silent -o subfinder.txt $proxyArg" -ToolName "subfinder" -OutputFile "subfinder.txt" 
    }
    if (-not (Test-Path "assetfinder.txt")) { 
        Execute-Tool "assetfinder --subs-only $Domain > assetfinder.txt" -ToolName "assetfinder" -OutputFile "assetfinder.txt" 
    }
    if (Tool-Exists "findomain" -and -not (Test-Path "findomain.txt")) { 
        Execute-Tool "findomain -t $Domain -q -u findomain.txt" -ToolName "findomain" -OutputFile "findomain.txt" 
    }

    # Amass passive
    if (-not (Test-Path "amass_passive.txt")) {
        Execute-Tool "amass enum -passive -d $Domain -timeout 1800 -o amass_passive.txt $proxyArg" -ToolName "amass-passive" -OutputFile "amass_passive.txt"
    }

    # Amass active
    if (-not (Test-Path "amass_active.txt")) {
        Write-Host "[+] Running Amass ACTIVE (timeout 30 minutes)..." -ForegroundColor Yellow
        Execute-Tool "amass enum -active -d $Domain -timeout 1800 -dns-qps $($Config.AmassDNSQPS) -max-dns-queries $($Config.AmassMaxQueries) -o amass_active.txt -src $proxyArg" -ToolName "amass-active" -OutputFile "amass_active.txt"
    }

    # Combine all results → only valid FQDNs (strong filter)
    if (-not (Test-Path "scoped_subs.txt")) {
        $files = @("subfinder.txt", "amass_passive.txt", "amass_active.txt", "assetfinder.txt", "findomain.txt")
        $all = @()
        
        foreach ($f in $files) {
            if (Test-Path $f) {
                $content = Get-Content $f -ErrorAction SilentlyContinue |
                    Where-Object {
                        # Only lines that look like valid FQDN / subdomain
                        $_ -match '^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$' -and
                        $_ -notmatch '\s' -and
                        $_ -notmatch '\(' -and
                        $_ -notmatch '-->' -and
                        $_ -notmatch '\(Netblock\)' -and
                        $_ -notmatch '\(ASN\)' -and
                        $_ -notmatch '\(IPAddress\)' -and
                        $_ -notmatch 'announces' -and
                        $_ -notmatch 'contains' -and
                        $_ -notmatch 'managed_by'
                    }
                if ($content) { $all += $content }
                Write-Host "$f → $($content.Count) valid FQDN lines" -ForegroundColor Cyan
            }
        }

        if ($all.Count -gt 0) {
            $all | Sort-Object -Unique | Out-File "scoped_subs.txt" -Encoding utf8
            Write-Host "scoped_subs.txt created → $($all.Count) unique valid subdomains" -ForegroundColor Green
        } else {
            Write-Host "No valid subdomains found after filtering" -ForegroundColor Yellow
            "# No valid subdomains discovered" | Out-File "scoped_subs.txt" -Encoding utf8
        }
    }

    # Final live probing with httpx
    if (-not (Test-Path "live_subs.txt")) {
        Write-Host "[+] Probing live subdomains with httpx..." -ForegroundColor Yellow
        
        $inputForProbe = "scoped_subs.txt"
        if ((Test-Path "amass_active.txt") -and ((Get-Item "amass_active.txt").Length -gt 0)) {
            $inputForProbe = "amass_active.txt"
            Write-Host "Preferring amass_active.txt (better results)" -ForegroundColor Cyan
        }

        Execute-Tool "Get-Content `"$inputForProbe`" | httpx -silent -threads $($Config.HttpxRate) -timeout $($Config.HttpxTimeout) -retries $($Config.HttpxRetries) -title -status-code -ip -tech-detect -o live_subs.txt $proxyArg" -ToolName "httpx-live" -OutputFile "live_subs.txt"
    }

    if (Test-Path "live_subs.txt") {
        Mark-Done "subs"
        Log-Step "Subdomains" "COMPLETED"
        Write-Host "Subdomains & Live resolution completed" -ForegroundColor Green
    }
}

function Step-LiveHosts {
    if (-not (Require-File "live_subs.txt" "subdomains")) { return }
    if (Step-Done "live") { Write-Host "Live Hosts already completed" -ForegroundColor Cyan; return }

    Log-Step "LiveHosts" "STARTED"

    if (-not (Test-Path "live.json")) {
        Execute-Tool "httpx -l live_subs.txt -rl $($Config.HttpxRate) -timeout 1800 -retries $($Config.HttpxRetries) -title -tech-detect -status-code -json -o live.json -tls-probe -http2 -vhost $proxyArg" -ToolName "httpx" -OutputFile "live.json"
    }

    if ((Test-Path "live.json") -and (-not (Test-Path "live_urls.txt"))) {
        Get-Content live.json | ConvertFrom-Json | 
            Where-Object { $_.status_code -and $_.status_code -lt 500 } | 
            Select-Object -ExpandProperty url | 
            Out-File live_urls.txt -Encoding utf8
        Write-Host "Extracted live URLs to live_urls.txt" -ForegroundColor Cyan
    }

    if (Test-Path "live_urls.txt") {
        Mark-Done "live"
        Log-Step "LiveHosts" "COMPLETED"
        Write-Host "LiveHosts completed" -ForegroundColor Green
    }
}

function Step-URLCollection {
    if (-not (Require-File "live_urls.txt" "livehosts")) { return }
    if (Step-Done "urls") { Write-Host "URL Collection already completed" -ForegroundColor Cyan; return }

    Log-Step "URLCollection" "STARTED"

    if (Tool-Exists "gau" -and -not (Test-Path "gau.txt")) { 
        Execute-Tool "gau $Domain --subs --blacklist png,jpg,woff,css,js > gau.txt" -ToolName "gau" -OutputFile "gau.txt" 
    }

    if (Tool-Exists "waymore" -and -not (Test-Path "waymore.txt")) { 
        Execute-Tool "waymore -i $Domain -oU waymore.txt" -ToolName "waymore" -OutputFile "waymore.txt" 
    }

    if (Tool-Exists "waybackurls" -and -not (Test-Path "wayback.txt")) { 
        Execute-Tool "waybackurls $Domain > wayback.txt" -ToolName "waybackurls" -OutputFile "wayback.txt" 
    }

    if (-not (Test-Path "katana.txt")) { 
        Execute-Tool "katana -list live_urls.txt -d $($Config.KatanaDepth) -jc -silent -o katana.txt -timeout 1800 $proxyArg" -ToolName "katana" -OutputFile "katana.txt" 
    }

    if (Tool-Exists "hakrawler" -and -not (Test-Path "hakrawler.txt")) {
        Execute-Tool "Get-Content live_urls.txt | hakrawler -d $($Config.HakrawlerDepth) > hakrawler.txt" -ToolName "hakrawler" -OutputFile "hakrawler.txt"
    }

    if (Tool-Exists "gospider" -and -not (Test-Path "gospider_urls.txt")) {
        Remove-Item "gospider_out" -Recurse -Force -ErrorAction SilentlyContinue
        Execute-Tool "gospider -S live_urls.txt -o gospider_out -c $($Config.GospiderThreads) -d $($Config.GospiderDepth) -q --other-source" -ToolName "gospider"
        Get-ChildItem "gospider_out" -Recurse -File | Get-Content | Sort-Object -Unique | Out-File gospider_urls.txt
    }

    if (-not (Test-Path "all_urls.txt")) {
        $files = @("gau.txt","waymore.txt","wayback.txt","katana.txt","hakrawler.txt","gospider_urls.txt")
        $all = @()
        foreach ($f in $files) { if (Test-Path $f) { $all += Get-Content $f -ea 0 } }
        $all | Sort-Object -Unique | Out-File all_urls.txt
    }

    # ─── In-scope filtering (safe & robust regex) ────────────────────────────────
    if (-not (Test-Path "all_urls_inscope.txt")) {
        # Collect clean domains/subdomains
        $domainsForRegex = @($Domain)
        $subdomains = Get-Content "scoped_subs.txt" -ErrorAction SilentlyContinue | 
            Where-Object { 
                $_ -match '^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$' 
            }

        $domainsForRegex += $subdomains

        # Build safe regex
        $scopeParts = $domainsForRegex | ForEach-Object { [regex]::Escape($_) }
        $scopeRegex = if ($scopeParts) { $scopeParts -join '|' } else { $null }

        if ($scopeRegex) {
            Write-Host "Filtering in-scope URLs with regex: $scopeRegex" -ForegroundColor DarkGray
            Get-Content all_urls.txt | 
                Where-Object { $_ -match $scopeRegex } | 
                Sort-Object -Unique | 
                Out-File all_urls_inscope.txt -Encoding utf8
        } else {
            Write-Host "No valid scope domains found → copying all URLs as fallback" -ForegroundColor Yellow
            Copy-Item all_urls.txt all_urls_inscope.txt -Force
        }
    }

    if (Test-Path "all_urls.txt") {
        Mark-Done "urls"
        Log-Step "URLCollection" "COMPLETED"
        Write-Host "URLCollection completed – all_urls.txt ready" -ForegroundColor Green
    }
}

function Step-ParametersAndJS {
    if (-not (Require-File "all_urls.txt" "urls")) { return }
    if (Step-Done "params_js") { Write-Host "Parameters and JS analysis already completed" -ForegroundColor Cyan; return }

    Log-Step "ParametersAndJS" "STARTED"

    New-Item -ItemType Directory -Force -Path "params_js" | Out-Null

    $arjunInput = "all_urls.txt"
    if (Test-Path "all_urls.txt") {
        $bytes = Get-Content "all_urls.txt" -Encoding Byte -ReadCount 2 -TotalCount 2 -ErrorAction SilentlyContinue
        if ($bytes -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
            Write-Host "UTF-16 BOM detected → converting to UTF-8" -ForegroundColor Yellow
            Get-Content "all_urls.txt" -Raw | Set-Content "all_urls_utf8.txt" -Encoding UTF8
            $arjunInput = "all_urls_utf8.txt"
        }
    }

    if (Tool-Exists "fallparams" -and -not (Test-Path "params_js/fall.txt")) {
        if ((Test-Path $arjunInput) -and ((Get-Content $arjunInput -First 1 -ErrorAction SilentlyContinue))) {
            Execute-Tool "fallparams -u $arjunInput -c -d 3 -t 20 -o params_js/fall.txt" -ToolName "fallparams" -OutputFile "params_js/fall.txt"
        }
    }

    if (Tool-Exists "arjun" -and -not (Test-Path "params_js/arjun.json")) {
        Execute-Tool "arjun -i $arjunInput -t $($Config.ArjunThreads) -oT params_js/arjun.json" -ToolName "arjun" -OutputFile "params_js/arjun.json"
    }

    if (Tool-Exists "paramspider" -and -not (Test-Path "params_js/paramspider.txt")) {
        Execute-Tool "paramspider -d $Domain > params_js/paramspider.txt" -ToolName "paramspider" -OutputFile "params_js/paramspider.txt"
    }

    if (-not (Test-Path "params_all.txt")) {
        Get-ChildItem "params_js" -File -Filter "*.txt" -ErrorAction SilentlyContinue | 
            Get-Content | Sort-Object -Unique | Out-File params_all.txt
    }

    if (Tool-Exists "getJS" -and -not (Test-Path "params_js/js_files.txt")) {
        Execute-Tool "Get-Content all_urls.txt | getJS --complete > params_js/js_files.txt" -ToolName "getJS" -OutputFile "params_js/js_files.txt"
    }

    if (Tool-Exists "linkfinder" -and (Test-Path "params_js/js_files.txt") -and -not (Test-Path "params_js/endpoints.txt")) {
        Execute-Tool "Get-Content params_js/js_files.txt | linkfinder -o cli -d > params_js/endpoints.txt" -ToolName "linkfinder" -OutputFile "params_js/endpoints.txt"
    }

    if (Tool-Exists "gf") {
        New-Item -ItemType Directory -Force -Path "gf_patterns" | Out-Null
        @("secret","api","token","aws","firebase","takeover","jsvar","debug_page") | ForEach-Object {
            $patternFile = "gf_patterns/$_.txt"
            if (-not (Test-Path $patternFile)) {
                Execute-Tool "Get-Content all_urls.txt | gf $_ | Sort-Object -Unique | Out-File $patternFile" -ToolName "gf-$_" -OutputFile $patternFile
            }
        }
    }

    if (Tool-Exists "qsreplace" -and -not (Test-Path "params_js/urls_with_fuzz.txt")) {
        Execute-Tool "Get-Content all_urls.txt | qsreplace `"FUZZ`" > params_js/urls_with_fuzz.txt" -ToolName "qsreplace" -OutputFile "params_js/urls_with_fuzz.txt"
    }

    if (Test-Path "params_all.txt") {
        Mark-Done "params_js"
        Log-Step "ParametersAndJS" "COMPLETED"
        Write-Host "Parameters and JS analysis completed" -ForegroundColor Green
    }
}

function Step-X8Fuzz {
    if (-not (Require-File "live_urls.txt" "livehosts")) { return }
    if (-not (Tool-Exists "x8")) { Write-Host "x8 not found" -ForegroundColor Yellow; return }
    if (Step-Done "x8") { Write-Host "x8 fuzzing already completed" -ForegroundColor Cyan; return }

    Log-Step "x8" "STARTED"

    $wordlist = if (Test-Path "params_all.txt") { "params_all.txt" } else { "$WordlistDir/params-top.txt" }
    if (-not (Test-Path $wordlist)) { Write-Host "No wordlist for x8" -ForegroundColor Yellow; return }

    Get-Content live_urls.txt | ForEach-Object {
        $url = $_.Trim()
        if ($url) {
            Execute-Tool "x8 -u `"$url`" -w `"$wordlist`" -t $($Config.X8Threads) --append -o x8_results.txt $proxyArg" -ToolName "x8"
        }
    }

    if (Test-Path "x8_results.txt") {
        Mark-Done "x8"
        Log-Step "x8" "COMPLETED"
        Write-Host "x8 fuzzing completed" -ForegroundColor Green
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
            Execute-Tool "ffuf -u `"$url`FUZZ`" -w `"$wordlist`" -t $($Config.FFUFThreads) -timeout 1800 -mc 200,301,302,307,308,401,403 -ac -r -o $outFile $proxyArg" -ToolName "ffuf-$safe" -OutputFile $outFile
        }
    }

    Mark-Done "ffuf"
    Log-Step "FFUF" "COMPLETED"
    Write-Host "FFUF directory brute completed" -ForegroundColor Green
}

function Step-NucleiScan {
    if (-not (Require-File "live_urls.txt" "livehosts")) { return }
    if (Step-Done "nuclei") { Write-Host "Nuclei scan already completed" -ForegroundColor Cyan; return }

    Log-Step "Nuclei" "STARTED"

    if (-not (Test-Path "nuclei_results.txt")) {
        Execute-Tool "nuclei -l live_urls.txt -severity $NucleiSeverity -rl $($Config.NucleiRate) -timeout 1800 -o nuclei_results.txt $proxyArg" -ToolName "nuclei" -OutputFile "nuclei_results.txt"
    }

    if (Test-Path "nuclei_results.txt") {
        Mark-Done "nuclei"
        Log-Step "Nuclei" "COMPLETED"
        Write-Host "Nuclei scan completed" -ForegroundColor Green
    }
}

function Step-XSSScan {
    if (-not (Require-File "all_urls.txt" "urls")) { return }
    if (-not (Tool-Exists "dalfox")) { Write-Host "dalfox not found" -ForegroundColor Yellow; return }
    if (Step-Done "xss") { Write-Host "XSS scan already completed" -ForegroundColor Cyan; return }

    Log-Step "dalfox" "STARTED"

    if (-not (Test-Path "dalfox_results.txt")) {
        Execute-Tool "Get-Content all_urls.txt | dalfox pipe --only-poc --delay 300 -o dalfox_results.txt" -ToolName "dalfox" -OutputFile "dalfox_results.txt"
    }

    if (Test-Path "dalfox_results.txt") {
        Mark-Done "xss"
        Log-Step "dalfox" "COMPLETED"
        Write-Host "XSS scan completed" -ForegroundColor Green
    }
}

function Generate-Report {
    Log-Step "Report" "STARTED"

    $files = @("scoped_subs.txt","live_subs.txt","live_urls.txt","all_urls.txt","params_all.txt","x8_results.txt","nuclei_results.txt","dalfox_results.txt")
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
    Write-Host " Ultimate Recon Framework - $Domain" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host " 1  Subdomains Enumeration (Amass active + resolve)"
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
            Write-Host "`nSession ended. Results saved in: $OutputDir" -ForegroundColor Green
            break
        }
        default { Write-Host "Invalid option" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }

    if ($choice -ne "x") {
        Write-Host "`nPress Enter to continue..." -ForegroundColor Cyan
        Read-Host | Out-Null
    }
}
