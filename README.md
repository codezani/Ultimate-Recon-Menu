# Ultimate Recon Framework – Windows Edition

**Fast, safe, and interactive reconnaissance pipeline for authorized security testing only.**

A PowerShell-based framework optimized for Windows environments, designed for bug bounty hunters, penetration testers, and red teamers who have **explicit permission** to test targets.

**Important Legal Notice**  
This tool is provided **strictly for authorized use only** (bug bounty programs, penetration testing engagements with written permission). Unauthorized scanning is illegal. Always confirm authorization before running.

## Features

- Interactive menu-driven workflow
- Step-by-step recon pipeline:  
  1. Subdomain enumeration  
  2. Live host probing  
  3. URL collection (historical + crawling)  
  4. Parameter discovery  
  5. Directory brute-forcing  
  6. Vulnerability scanning (Nuclei)  
  7. XSS testing (Dalfox)  
  8. Port scanning  
- Progress tracking with `.done_*` marker files  
- Rate limiting, timeouts, and retries for stability  
- Simple HTML report generation  
- Dry-run mode (`-DryRun`) for testing commands without execution  
- Wordlist auto-check with helpful setup instructions

### Tools Integrated

| Category              | Tools                                      | Purpose                              |
|-----------------------|--------------------------------------------|--------------------------------------|
| Subdomain Enum        | subfinder, amass, puredns, dnsx            | Passive & resolved subdomains        |
| Probing               | httpx, tlsx                                | Live hosts, titles, tech detection, TLS info |
| Crawling / URLs       | gau, waybackurls, katana, gospider         | Historical + active URL collection   |
| Parameters            | fallparams                                 | Hidden parameter discovery           |
| Brute-force           | ffuf                                       | Directory / file brute-forcing       |
| Vulnerability Scan    | nuclei                                     | Template-based vuln detection        |
| XSS                   | dalfox                                     | Reflected & blind XSS hunting        |
| Ports                 | naabu                                      | Top ports scanning                   |

## Requirements

- Windows 10 / 11  
- PowerShell 5.1+ (or PowerShell 7 recommended)  
- **Go 1.21+** installed (https://go.dev/dl/)  
- **Git** installed (https://git-scm.com/download/win)  
- Run scripts **as Administrator** (required for network tools stability)

## Installation

1. Clone the repository:
   ```powershell
   git clone https://github.com/codezani/ultimate-recon-windows.git
   cd ultimate-recon-windows


Install required tools (run as Administrator):powershell

.\Installer.ps1

If pdtm fails with "api is down" → the script falls back to direct go install  
After installation → close and reopen PowerShell (new session needed for PATH)

(Optional) Manual install of ProjectDiscovery tools if needed:powershell

go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
nuclei -update-templates
# ... and similarly for katana, naabu, tlsx, dnsx

Download a good wordlist (if not already present):powershell

New-Item -ItemType Directory -Force -Path wordlists
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/raft-medium-directories.txt" -OutFile "wordlists\dir-medium.txt"

UsageRun the main script as Administrator:powershell

.\recon.ps1 -Domain example.com
# or with custom wordlist
.\recon.ps1 -Domain example.com -Wordlist "C:\tools\wordlists\big.txt"

Follow the menu (1–13 options)
Press x to exit
Results are saved in ./example.com-recon/

Menu Overview

1  Subdomains    2  Live Hosts    3  URLs
8  Parameters    4  FFUF          5  Nuclei
6  XSS           7  Ports         13 Report

Output Structure

example.com-recon/
├── scoped_subs.txt
├── live_urls.txt
├── scoped_urls.txt
├── params_results/
├── ffuf_results/
├── nuclei_results.txt
├── dalfox_results.txt
├── ports.txt
├── tls.txt
├── report.html
└── recon.log

TroubleshootingTool not found? → Run go install manually or re-run the installer  
Wordlist missing? → Script shows download instructions  
Permission denied? → Always run PowerShell as Administrator  
Nuclei templates outdated? → nuclei -update-templates

ContributingPull requests welcome! Especially:Better error handling
Automatic chaining of steps
More parameter/wordlist sources
Cloud/axiom integration ideas

LicenseMIT License – but remember: use only on targets you have explicit permission to test.

