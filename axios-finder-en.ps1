# ============================================================
#  axios-finder.ps1
#  Scans package.json and package-lock.json files recursively
#  from the current directory and prints all lines with "axios"
# ============================================================

$targetFiles    = @("package.json", "package-lock.json")
$keyword        = "axios"
$startPath      = $PWD.Path
$dangerVersions = @("1.14.1", "0.30.4")

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Axios Finder — by PowerShell" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Root directory   : $startPath" -ForegroundColor Gray
Write-Host "  Target files     : $($targetFiles -join ', ')" -ForegroundColor Gray
Write-Host "  Keyword          : $keyword" -ForegroundColor Gray
Write-Host "  Dangerous versions: $($dangerVersions -join ', ')" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── Step 1: Find target files ────────────────────────────────
Write-Host "[ STEP 1 ] Searching for files..." -ForegroundColor Yellow

$foundFiles = Get-ChildItem -Path $startPath -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $targetFiles -contains $_.Name }

if ($foundFiles.Count -eq 0) {
    Write-Host "  No files found. Exiting." -ForegroundColor Red
    exit
}

Write-Host "  Files found: $($foundFiles.Count)" -ForegroundColor Green
$foundFiles | ForEach-Object {
    Write-Host "  -> $($_.FullName)" -ForegroundColor DarkGray
}
Write-Host ""

# ── Step 2: Scan for "axios" ─────────────────────────────────
Write-Host "[ STEP 2 ] Scanning for '$keyword'..." -ForegroundColor Yellow
Write-Host ""

$totalMatches = 0

# Collect alarm entries during scanning
$alarmList = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($file in $foundFiles) {
    $lines   = Get-Content -Path $file.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    $hitList = [System.Collections.Generic.List[PSCustomObject]]::new()

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match [regex]::Escape($keyword)) {
            $hitList.Add([PSCustomObject]@{
                Line    = $i + 1
                Content = $lines[$i]
            })

            # Check whether this line also contains a dangerous version
            foreach ($ver in $dangerVersions) {
                if ($lines[$i] -match [regex]::Escape($ver)) {
                    $alarmList.Add([PSCustomObject]@{
                        Version   = $ver
                        File      = $file.Name
                        Directory = $file.DirectoryName
                        FullPath  = $file.FullName
                        LineNum   = $i + 1
                        Content   = $lines[$i].Trim()
                    })
                }
            }
        }
    }

    if ($hitList.Count -gt 0) {
        $totalMatches += $hitList.Count

        Write-Host "┌─ $($file.FullName)" -ForegroundColor Magenta
        Write-Host "│  Matches: $($hitList.Count)" -ForegroundColor Magenta

        foreach ($hit in $hitList) {
            $lineNum = "│  [{0,4}]  " -f $hit.Line
            Write-Host $lineNum -ForegroundColor DarkCyan -NoNewline

            # Highlight "axios" in red, dangerous versions in yellow
            $printLine = $hit.Content
            $parts = $printLine -split "(?i)($keyword)"
            foreach ($part in $parts) {
                if ($part -match "(?i)^$keyword$") {
                    Write-Host $part -ForegroundColor Red -NoNewline
                } else {
                    # Highlight dangerous version numbers within surrounding text
                    $subParts = $part -split "($( ($dangerVersions | ForEach-Object { [regex]::Escape($_) }) -join '|' ))"
                    foreach ($sub in $subParts) {
                        if ($dangerVersions -contains $sub) {
                            Write-Host $sub -ForegroundColor Yellow -NoNewline
                        } else {
                            Write-Host $sub -ForegroundColor White -NoNewline
                        }
                    }
                }
            }
            Write-Host ""
        }

        Write-Host "└$('─' * 60)" -ForegroundColor Magenta
        Write-Host ""
    }
}

# ── Summary ──────────────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Files scanned    : $($foundFiles.Count)" -ForegroundColor Green
Write-Host "  Lines with 'axios': $totalMatches" -ForegroundColor $(if ($totalMatches -gt 0) { 'Green' } else { 'Red' })
Write-Host "========================================" -ForegroundColor Cyan

# ── ALARMS ───────────────────────────────────────────────────
Write-Host ""
if ($alarmList.Count -eq 0) {
    Write-Host "  ✅  No dangerous axios versions detected." -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Host "!                                              !" -ForegroundColor Red
    Write-Host "!   ⚠️  ALARM — DANGEROUS VERSIONS DETECTED  ⚠️   !" -ForegroundColor Red
    Write-Host "!                                              !" -ForegroundColor Red
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Host ""

    foreach ($alarm in $alarmList) {
        Write-Host "  ▶ Version    : $($alarm.Version)"   -ForegroundColor Yellow
        Write-Host "  ▶ File       : $($alarm.File)"      -ForegroundColor Yellow
        Write-Host "  ▶ Directory  : $($alarm.Directory)" -ForegroundColor Yellow
        Write-Host "  ▶ Line #     : $($alarm.LineNum)"   -ForegroundColor Yellow
        Write-Host "  ▶ Content    : $($alarm.Content)"   -ForegroundColor DarkYellow
        Write-Host "  $('-' * 55)"                         -ForegroundColor DarkRed
    }

    Write-Host ""
    Write-Host "  Total alarms: $($alarmList.Count)" -ForegroundColor Red
    Write-Host ""
}