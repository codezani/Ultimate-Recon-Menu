# Ultimate Recon Framework – Windows Edition

A clean, safe, and modular PowerShell reconnaissance framework designed for authorized security testing, bug bounty hunting, and penetration testing on Windows systems.

**IMPORTANT**: This tool is for **authorized testing only**. You must have explicit permission to scan any target.

## Features

- Modular step-by-step workflow with resume support
- Safe rate limits optimized for Windows
- Live output for long-running tools (ffuf, nuclei, dalfox)
- Automatic logging (`recon.log`)
- Professional HTML report generation
- Dry-run mode for testing commands
- Tool availability checks and graceful degradation
- Clean, anonymous code – ready for public sharing

## Prerequisites

Install the following tools and ensure they are in your PATH:

- subfinder
- amass
- httpx
- gau
- waybackurls
- katana
- ffuf
- nuclei
- dalfox
- naabu
- tlsx
- puredns (optional)
- dnsx (optional)

Wordlist: Place a directory wordlist at `wordlists\dir-medium.txt` (e.g., from SecLists).

## Usage

```powershell
# Basic usage
.\Ultimate-Recon.ps1 -Domain example.com

# Custom severity and wordlist
.\Ultimate-Recon.ps1 -Domain example.com -NucleiSeverity "critical,high" -Wordlist "wordlists/custom.txt"

# Dry run (preview commands only)
.\Ultimate-Recon.ps1 -Domain example.com -DryRun
