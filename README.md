---
title: Hunting Vulnerable axios Versions Across Your Node.js Monorepo
published: true
description: When a dependency ships a bad version, your node_modules tree doesn't warn you. Here's a small PowerShell script that does.
tags: powershell, security, nodejs, tooling
---

When a dependency ships a bad version, your `node_modules` tree doesn't warn you. Here's a small PowerShell script that does.

## The problem

Large Node.js projects accumulate dependencies fast. A monorepo with dozens of services can have hundreds of nested `package.json` and `package-lock.json` files, each potentially pinning a different version of a shared library.

When a specific version of a popular library — say, `axios` — turns out to carry a bug or a security regression, you need to know _exactly_ where it's referenced, across every file, at a glance. Grepping by hand doesn't scale, and most dependency auditing tools only look at the top-level lockfile.

> ⚠️ **Why these versions?**
> Versions `1.14.1` and `0.30.4` are the target of this scanner — known problematic releases that should be identified and upgraded as soon as possible.

---

## The approach

The script is a two-phase scanner written in PowerShell. It's designed to be dropped anywhere in your repo and run with a single command — no dependencies, no config files.

**Phase 1** recursively walks the directory tree from wherever the script lives, collecting all `package.json` and `package-lock.json` files:

```powershell
$foundFiles = Get-ChildItem -Path $startPath -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $targetFiles -contains $_.Name }
```

**Phase 2** reads each file line by line, looking for the keyword `axios`. Every matching line is printed to the console with its line number, and the keyword is highlighted in red so you can spot it instantly.

```powershell
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match [regex]::Escape($keyword)) {
        $hitList.Add([PSCustomObject]@{
            Line    = $i + 1
            Content = $lines[$i]
        })
    }
}
```

> 💡 **Gotcha — reserved variable name**
> PowerShell's automatic variable `$matches` is populated by the `-match` operator itself. Using it as a collection causes a cryptic runtime error: _"A hash table can only be added to another hash table."_
> The fix: name your collection `$hitList` and use `List[PSCustomObject]` instead of a plain array.

```powershell
# WRONG — $matches is reserved by PowerShell
$matches = @()
$matches += [PSCustomObject]@{ ... }  # runtime error!

# CORRECT
$hitList = [System.Collections.Generic.List[PSCustomObject]]::new()
$hitList.Add([PSCustomObject]@{ ... })
```

---

## The alarm system

Beyond general search, the script maintains a second collection — `$alarmList` — that fires only when a line contains one of the flagged version strings. This runs in the same loop, so there's zero extra I/O cost.

```powershell
$dangerVersions = @("1.14.1", "0.30.4")

foreach ($ver in $dangerVersions) {
    if ($lines[$i] -match [regex]::Escape($ver)) {
        $alarmList.Add([PSCustomObject]@{
            Version   = $ver
            File      = $file.Name
            Directory = $file.DirectoryName  # full path to folder
            LineNum   = $i + 1
            Content   = $lines[$i].Trim()
        })
    }
}
```

After all files are scanned, the alarm block prints a consolidated summary at the very bottom — version found, filename, directory path, and the exact line — so there's no ambiguity about what needs updating:

```
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!                                              !
!   ⚠️  ALARM — VULNERABLE VERSIONS DETECTED  ⚠️  !
!                                              !
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  ▶ Version    : 0.30.4
  ▶ File       : package-lock.json
  ▶ Directory  : C:\projects\my-app\services\api
  ▶ Line #     : 1042
  ▶ Content    : "version": "0.30.4",
  ───────────────────────────────────────────────────
```

The console output also uses color: `axios` keyword in red, dangerous version numbers in yellow, file headers in magenta — making it easy to scan hundreds of lines at a glance.

---

## Running the script

Save the file as `axios-finder.ps1`, place it anywhere inside your project root, then run:

```powershell
.\axios-finder.ps1
```

If your execution policy blocks unsigned scripts:

```powershell
powershell -ExecutionPolicy Bypass -File .\axios-finder.ps1
```

No Node.js, no npm, no extra modules required. It runs on any machine with PowerShell 5.1 or later — which means any modern Windows box, out of the box.


---

_Found this useful? Drop a ❤️ or leave a comment — happy to extend the script to support other libraries or output formats._