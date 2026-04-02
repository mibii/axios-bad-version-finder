# ============================================================
#  axios-finder.ps1
#  Ищет package.json и package-lock.json в текущей директории
#  и всех подпапках, выводит строки содержащие "axios"
# ============================================================

$targetFiles    = @("package.json", "package-lock.json")
$keyword        = "axios"
$startPath      = $PWD.Path
$dangerVersions = @("1.14.1", "0.30.4")

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Axios Finder — by PowerShell" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Корневая папка   : $startPath" -ForegroundColor Gray
Write-Host "  Файлы            : $($targetFiles -join ', ')" -ForegroundColor Gray
Write-Host "  Ключевое слово   : $keyword" -ForegroundColor Gray
Write-Host "  Опасные версии   : $($dangerVersions -join ', ')" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── Шаг 1: Поиск файлов ─────────────────────────────────────
Write-Host "[ ШАГ 1 ] Поиск файлов..." -ForegroundColor Yellow

$foundFiles = Get-ChildItem -Path $startPath -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $targetFiles -contains $_.Name }

if ($foundFiles.Count -eq 0) {
    Write-Host "  Файлы не найдены. Скрипт завершён." -ForegroundColor Red
    exit
}

Write-Host "  Найдено файлов: $($foundFiles.Count)" -ForegroundColor Green
$foundFiles | ForEach-Object {
    Write-Host "  -> $($_.FullName)" -ForegroundColor DarkGray
}
Write-Host ""

# ── Шаг 2: Сканирование на "axios" ──────────────────────────
Write-Host "[ ШАГ 2 ] Сканирование на наличие '$keyword'..." -ForegroundColor Yellow
Write-Host ""

$totalMatches = 0

# Список для алармов — собираем по ходу сканирования
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

            # Проверяем — есть ли в этой строке опасная версия
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
        Write-Host "│  Совпадений: $($hitList.Count)" -ForegroundColor Magenta

        foreach ($hit in $hitList) {
            $lineNum = "│  [{0,4}]  " -f $hit.Line
            Write-Host $lineNum -ForegroundColor DarkCyan -NoNewline

            # Подсветка "axios" красным, опасных версий — жёлтым
            $printLine = $hit.Content
            $parts = $printLine -split "(?i)($keyword)"
            foreach ($part in $parts) {
                if ($part -match "(?i)^$keyword$") {
                    Write-Host $part -ForegroundColor Red -NoNewline
                } else {
                    # Внутри обычного текста подсветим опасную версию жёлтым
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

# ── Итог ────────────────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Файлов проверено : $($foundFiles.Count)" -ForegroundColor Green
Write-Host "  Строк с 'axios'  : $totalMatches" -ForegroundColor $(if ($totalMatches -gt 0) { 'Green' } else { 'Red' })
Write-Host "========================================" -ForegroundColor Cyan

# ── АЛАРМЫ ──────────────────────────────────────────────────
Write-Host ""
if ($alarmList.Count -eq 0) {
    Write-Host "  ✅  Опасных версий axios не обнаружено." -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Host "!                                              !" -ForegroundColor Red
    Write-Host "!   ⚠️  АЛАРМ — ОБНАРУЖЕНЫ ОПАСНЫЕ ВЕРСИИ  ⚠️   !" -ForegroundColor Red
    Write-Host "!                                              !" -ForegroundColor Red
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Host ""

    foreach ($alarm in $alarmList) {
        Write-Host "  ▶ Версия    : $($alarm.Version)"   -ForegroundColor Yellow
        Write-Host "  ▶ Файл      : $($alarm.File)"      -ForegroundColor Yellow
        Write-Host "  ▶ Директория: $($alarm.Directory)" -ForegroundColor Yellow
        Write-Host "  ▶ Строка №  : $($alarm.LineNum)"   -ForegroundColor Yellow
        Write-Host "  ▶ Содержимое: $($alarm.Content)"   -ForegroundColor DarkYellow
        Write-Host "  $('-' * 55)"                        -ForegroundColor DarkRed
    }

    Write-Host ""
    Write-Host "  Итого алармов: $($alarmList.Count)" -ForegroundColor Red
    Write-Host ""
}