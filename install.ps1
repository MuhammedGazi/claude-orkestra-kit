<#
.SYNOPSIS
    claude-orkestra-kit kurulum betiği (Windows PowerShell 5.1 uyumlu).
.DESCRIPTION
    skills, agents, CLAUDE.md, settings.json ve GEMINI.md bileşenlerini
    hedef kullanıcı klasörüne (.claude ve .gemini) yedekli ve güvenli biçimde kurar.
.PARAMETER TargetHome
    Kurulum yapılacak kök kullanıcı klasörü (test/izolasyon için; permissions.allow kuralları ~ ile kalır).
.PARAMETER Only
    Yalnızca belirtilen bileşenleri kurar (skills, agents, claudemd, settings, gemini).
.PARAMETER DryRun
    Hiçbir dosyayı değiştirmeden yapılacak işlemleri listeler.
.PARAMETER Force
    Mevcut statusLine ayarını üzerine yazar.
.PARAMETER Restore
    Belirtilen yedek klasöründeki manifest.json dosyasına göre önceki duruma geri yükler.
#>
[CmdletBinding()]
param(
    [string]$TargetHome = $env:USERPROFILE,
    [string[]]$Only = @(),
    [switch]$DryRun,
    [switch]$Force,
    [string]$Restore
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
}

$scriptRoot = $PSScriptRoot
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

$validComponents = @('skills', 'agents', 'claudemd', 'settings', 'gemini')
$selectedComponents = @()

if ($null -eq $Only -or @($Only).Count -eq 0) {
    $selectedComponents = $validComponents
} else {
    foreach ($item in $Only) {
        if ($null -eq $item) { continue }
        $normalized = $item.Trim().ToLowerInvariant()
        if ([string]::IsNullOrEmpty($normalized)) { continue }
        if ($validComponents -notcontains $normalized) {
            throw "Geçersiz -Only değeri: '$item'. Geçerli değerler: $($validComponents -join ', ')"
        }
        if ($selectedComponents -notcontains $normalized) {
            $selectedComponents += $normalized
        }
    }
    if (@($selectedComponents).Count -eq 0) {
        $selectedComponents = $validComponents
    }
}

if ([string]::IsNullOrWhiteSpace($TargetHome)) {
    throw "TargetHome boş olamaz."
}
if (-not [System.IO.Path]::IsPathRooted($TargetHome)) {
    $TargetHome = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $TargetHome))
} else {
    $TargetHome = [System.IO.Path]::GetFullPath($TargetHome)
}
if ($TargetHome.Length -gt 3) {
    $TargetHome = $TargetHome.TrimEnd('\', '/')
}
$forwardHome = $TargetHome.TrimEnd('\', '/').Replace('\', '/')

$claudeDir = Join-Path $TargetHome '.claude'
$geminiDir = Join-Path $TargetHome '.gemini'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path (Join-Path $claudeDir 'backups') ("orkestra-kit-$timestamp")

$script:BackupCreated = $false
$installed = New-Object System.Collections.ArrayList
$skipped = New-Object System.Collections.ArrayList
$planOps = New-Object System.Collections.ArrayList
$planWarnings = New-Object System.Collections.ArrayList

function Write-DryAction {
    param(
        [string]$Action,
        [string]$Path
    )
    Write-Host "[DRY] $Action $Path"
}

function Get-RelativePath {
    param(
        [string]$BasePath,
        [string]$FullPath
    )
    $baseFull = [System.IO.Path]::GetFullPath($BasePath)
    $targetFull = [System.IO.Path]::GetFullPath($FullPath)
    $basePrefix = if ($baseFull.EndsWith('\') -or $baseFull.EndsWith('/')) { $baseFull } else { "$baseFull\" }
    if (-not $targetFull.StartsWith($basePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Hedef yol temel klasör dışında: $FullPath"
    }
    return $targetFull.Substring($basePrefix.Length).TrimStart('\', '/')
}

function Resolve-SafeChildPath {
    param(
        [string]$BasePath,
        [string]$RelativePath
    )
    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw "Manifest içinde boş göreli yol bulundu."
    }
    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Manifest içinde mutlak yol izinli değil: $RelativePath"
    }
    if (($RelativePath -split '[/\\]') -contains '..') {
        throw "Manifest içinde '..' içeren yol izinli değil: $RelativePath"
    }
    $baseFull = [System.IO.Path]::GetFullPath($BasePath)
    $basePrefix = if ($baseFull.EndsWith('\') -or $baseFull.EndsWith('/')) { $baseFull } else { "$baseFull\" }
    $combined = [System.IO.Path]::GetFullPath((Join-Path $baseFull $RelativePath))
    if (-not $combined.StartsWith($basePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Güvensiz göreli yol (kapsam dışı): $RelativePath"
    }
    return $combined
}

function Ensure-DirectoryTracked {
    param(
        [string]$DirectoryPath,
        [string]$BaseHome,
        [System.Collections.ArrayList]$CreatedDirs
    )
    if (Test-Path -LiteralPath $DirectoryPath -PathType Container) {
        return
    }
    if (Test-Path -LiteralPath $DirectoryPath -PathType Leaf) {
        throw "Klasör beklenirken dosya bulundu: $DirectoryPath"
    }
    if (-not (Test-Path -LiteralPath $BaseHome -PathType Container)) {
        New-Item -ItemType Directory -Path $BaseHome -Force | Out-Null
    }
    $toCreate = New-Object System.Collections.ArrayList
    $curr = [System.IO.Path]::GetFullPath($DirectoryPath)
    $baseNorm = [System.IO.Path]::GetFullPath($BaseHome).TrimEnd('\', '/')
    while (-not [string]::IsNullOrEmpty($curr) -and $curr.TrimEnd('\', '/') -ine $baseNorm) {
        if (Test-Path -LiteralPath $curr -PathType Container) {
            break
        }
        [void]$toCreate.Add($curr)
        $parent = Split-Path -Path $curr -Parent
        if ($parent -eq $curr) {
            break
        }
        $curr = $parent
    }
    for ($i = $toCreate.Count - 1; $i -ge 0; $i--) {
        $dirToMake = $toCreate[$i]
        New-Item -ItemType Directory -Path $dirToMake -Force | Out-Null
        $relDir = Get-RelativePath -BasePath $BaseHome -FullPath $dirToMake
        if ($CreatedDirs -notcontains $relDir) {
            [void]$CreatedDirs.Add($relDir)
        }
    }
}

function Backup-ExistingFile {
    param(
        [string]$TargetPath
    )
    if ($DryRun) {
        return
    }
    if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
        return
    }
    $relPath = Get-RelativePath -BasePath $TargetHome -FullPath $TargetPath
    $backupDest = Join-Path $backupRoot $relPath
    if (-not $script:BackupCreated) {
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        $script:BackupCreated = $true
    }
    $parent = Split-Path -Path $backupDest -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $TargetPath -Destination $backupDest -Force
}

function Test-JsonProp {
    param(
        [object]$Obj,
        [string]$Name
    )
    if ($null -eq $Obj) {
        return $false
    }
    return ($null -ne $Obj.PSObject.Properties[$Name])
}

function Set-JsonProp {
    param(
        [object]$Obj,
        [string]$Name,
        [object]$Value
    )
    if (Test-JsonProp -Obj $Obj -Name $Name) {
        $Obj.$Name = $Value
    } else {
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name $Name -Value $Value
    }
}

function Unescape-JsonHtmlChars {
    param(
        [string]$JsonText
    )
    if ([string]::IsNullOrEmpty($JsonText)) {
        return $JsonText
    }
    return [regex]::Replace(
        $JsonText,
        '(?<=(?:^|[^\\])(?:\\\\)*)\\u00(27|3[cC]|3[eE]|26)',
        {
            param($m)
            switch ($m.Groups[1].Value.ToLowerInvariant()) {
                '27' { return "'" }
                '3c' { return '<' }
                '3e' { return '>' }
                '26' { return '&' }
            }
        }
    )
}

function ConvertTo-SafeJson {
    param(
        [object]$InputObject,
        [int]$Depth = 20
    )
    $raw = ConvertTo-Json -InputObject $InputObject -Depth $Depth
    $unescaped = Unescape-JsonHtmlChars -JsonText $raw
    try {
        $null = $unescaped | ConvertFrom-Json
    } catch {
        throw "Oluşturulan JSON doğrulamadan geçemedi: $($_.Exception.Message)"
    }
    return $unescaped
}

function Get-MarkedMarkdownPlan {
    param(
        [string]$TemplatePath,
        [string]$TargetPath,
        [string]$Label
    )
    if (-not (Test-Path -LiteralPath $TemplatePath -PathType Leaf)) {
        throw "Kaynak şablon bulunamadı: $TemplatePath"
    }

    $startMarker = '<!-- orkestra-kit:start -->'
    $endMarker = '<!-- orkestra-kit:end -->'

    $templateRaw = [System.IO.File]::ReadAllText($TemplatePath, [System.Text.Encoding]::UTF8)
    $templateBody = $templateRaw.TrimEnd("`r", "`n")

    $exists = Test-Path -LiteralPath $TargetPath
    if (-not $exists) {
        $nl = "`n"
        $normalizedBody = $templateBody -replace "`r`n", "`n"
        $markedBlock = "$startMarker$nl$normalizedBody$nl$endMarker$nl"
        return [PSCustomObject]@{
            Kind    = 'WriteText'
            IsNew   = $true
            Target  = $TargetPath
            Content = $markedBlock
            Label   = "$Label ($TargetPath)"
            DryVerb = 'EKLE'
        }
    }

    if (Test-Path -LiteralPath $TargetPath -PathType Container) {
        throw "Hedefte dosya yerine klasör var: $TargetPath"
    }

    $existingText = [System.IO.File]::ReadAllText($TargetPath, [System.Text.Encoding]::UTF8)
    $nl = if ($existingText.Contains("`r`n")) { "`r`n" } else { "`n" }
    $normalizedBody = ($templateBody -replace "`r`n", "`n") -replace "`n", $nl
    $markedBlock = "$startMarker$nl$normalizedBody$nl$endMarker"

    # Satırları karakter ofsetleriyle tara; işaretler yalnızca kendi satırında (trim sonrası tam eşleşme) sayılır.
    $lines = New-Object System.Collections.ArrayList
    $startIndices = New-Object System.Collections.ArrayList
    $endIndices = New-Object System.Collections.ArrayList
    $pos = 0
    $len = $existingText.Length
    while ($pos -lt $len) {
        $lineStart = $pos
        while ($pos -lt $len -and $existingText[$pos] -ne "`r" -and $existingText[$pos] -ne "`n") {
            $pos++
        }
        $contentEnd = $pos
        if ($pos -lt $len) {
            if ($existingText[$pos] -eq "`r" -and ($pos + 1) -lt $len -and $existingText[$pos + 1] -eq "`n") {
                $pos += 2
            } else {
                $pos += 1
            }
        }
        $trimmed = $existingText.Substring($lineStart, $contentEnd - $lineStart).Trim()
        $lineIdx = $lines.Count
        [void]$lines.Add([PSCustomObject]@{
            Start      = $lineStart
            ContentEnd = $contentEnd
        })
        if ($trimmed -ceq $startMarker) {
            [void]$startIndices.Add($lineIdx)
        } elseif ($trimmed -ceq $endMarker) {
            [void]$endIndices.Add($lineIdx)
        }
    }

    $newContent = $null
    if ($startIndices.Count -eq 0 -and $endIndices.Count -eq 0) {
        if ($existingText.Length -eq 0) {
            $newContent = "$markedBlock$nl"
        } elseif ($existingText.EndsWith("`r`n`r`n") -or $existingText.EndsWith("`n`n")) {
            $newContent = "$existingText$markedBlock$nl"
        } elseif ($existingText.EndsWith("`n") -or $existingText.EndsWith("`r")) {
            $newContent = "$existingText$nl$markedBlock$nl"
        } else {
            $newContent = "$existingText$nl$nl$markedBlock$nl"
        }
        return [PSCustomObject]@{
            Kind    = 'WriteText'
            IsNew   = $false
            Target  = $TargetPath
            Content = $newContent
            Label   = "$Label ($TargetPath)"
            DryVerb = 'EKLE'
        }
    } elseif ($startIndices.Count -eq 1 -and $endIndices.Count -eq 1) {
        $sIdx = $startIndices[0]
        $eIdx = $endIndices[0]
        if ($sIdx -ge $eIdx) {
            throw "Bozuk işaret bölümü ($TargetPath): bitiş işareti başlangıç işaretinden önce geliyor (ters sıra)."
        }
        $before = $existingText.Substring(0, $lines[$sIdx].Start)
        $after = $existingText.Substring($lines[$eIdx].ContentEnd)
        $newContent = $before + $markedBlock + $after
        if ($newContent -ceq $existingText) {
            return $null
        }
        return [PSCustomObject]@{
            Kind    = 'WriteText'
            IsNew   = $false
            Target  = $TargetPath
            Content = $newContent
            Label   = "$Label ($TargetPath)"
            DryVerb = 'DEĞİŞTİR'
        }
    } elseif ($startIndices.Count -eq 1 -and $endIndices.Count -eq 0) {
        throw "Bozuk işaret bölümü ($TargetPath): başlangıç işareti var ancak bitiş işareti bulunamadı."
    } elseif ($startIndices.Count -eq 0 -and $endIndices.Count -eq 1) {
        throw "Bozuk işaret bölümü ($TargetPath): bitiş işareti var ancak başlangıç işareti bulunamadı."
    } else {
        throw "Bozuk işaret bölümü ($TargetPath): birden fazla işaret bulundu (start: $($startIndices.Count), end: $($endIndices.Count))."
    }
}

function Invoke-Restore {
    param(
        [string]$RestorePath,
        [string]$CliTargetHome,
        [switch]$DryRun
    )
    if ([string]::IsNullOrWhiteSpace($RestorePath)) {
        throw "Restore yedek klasörü yolu boş olamaz."
    }
    $restoreRoot = if (-not [System.IO.Path]::IsPathRooted($RestorePath)) {
        [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $RestorePath))
    } else {
        [System.IO.Path]::GetFullPath($RestorePath)
    }
    if (-not (Test-Path -LiteralPath $restoreRoot -PathType Container)) {
        throw "Yedek klasörü bulunamadı: $restoreRoot"
    }
    $manifestPath = Join-Path $restoreRoot 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Manifest dosyası bulunamadı: $manifestPath"
    }

    $manifestRaw = [System.IO.File]::ReadAllText($manifestPath, [System.Text.Encoding]::UTF8)
    try {
        $manifest = $manifestRaw | ConvertFrom-Json
    } catch {
        throw "Geçersiz manifest.json ($manifestPath): $($_.Exception.Message)"
    }
    if ($null -eq $manifest) {
        throw "Geçersiz veya boş manifest.json ($manifestPath)."
    }
    if (-not (Test-JsonProp -Obj $manifest -Name 'created') -and -not (Test-JsonProp -Obj $manifest -Name 'replaced')) {
        throw "Geçersiz manifest.json ($manifestPath): 'created' veya 'replaced' alanı yok."
    }

    $effectiveHome = $CliTargetHome
    if (-not (Test-JsonProp -Obj $manifest -Name 'targetHome') -or [string]::IsNullOrWhiteSpace([string]$manifest.targetHome)) {
        throw "Geçersiz manifest.json ($manifestPath): 'targetHome' alanı yok veya boş."
    }
    $manifestHome = [System.IO.Path]::GetFullPath([string]$manifest.targetHome)
    if ($manifestHome.Length -gt 3) {
        $manifestHome = $manifestHome.TrimEnd('\', '/')
    }
    if ($manifestHome -ine $effectiveHome) {
        throw "Manifest targetHome ('$manifestHome') hedef ev ('$effectiveHome') ile eşleşmiyor."
    }

    $replacedList = if ((Test-JsonProp -Obj $manifest -Name 'replaced') -and $null -ne $manifest.replaced) { @($manifest.replaced) } else { @() }
    $createdList = if ((Test-JsonProp -Obj $manifest -Name 'created') -and $null -ne $manifest.created) { @($manifest.created) } else { @() }
    $createdDirsList = if ((Test-JsonProp -Obj $manifest -Name 'createdDirs') -and $null -ne $manifest.createdDirs) { @($manifest.createdDirs) } else { @() }

    # Aşama 1: tüm yolları ve yedek dosyalarını doğrula
    $replacePairs = New-Object System.Collections.ArrayList
    foreach ($rel in $replacedList) {
        if ($null -eq $rel) { continue }
        $relStr = [string]$rel
        try {
            $backupFile = Resolve-SafeChildPath -BasePath $restoreRoot -RelativePath $relStr
            $targetFile = Resolve-SafeChildPath -BasePath $effectiveHome -RelativePath $relStr
        } catch {
            Write-Warning "Güvensiz veya geçersiz 'replaced' girdisi atlandı ('$relStr'): $($_.Exception.Message)"
            continue
        }
        if (-not (Test-Path -LiteralPath $backupFile -PathType Leaf)) {
            throw "Yedekte geri yüklenecek dosya bulunamadı: $backupFile"
        }
        [void]$replacePairs.Add([PSCustomObject]@{
            BackupFile = $backupFile
            TargetFile = $targetFile
        })
    }

    $deleteFiles = New-Object System.Collections.ArrayList
    $deleteFileSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($rel in $createdList) {
        if ($null -eq $rel) { continue }
        $relStr = [string]$rel
        try {
            $targetFile = Resolve-SafeChildPath -BasePath $effectiveHome -RelativePath $relStr
        } catch {
            Write-Warning "Güvensiz veya geçersiz 'created' girdisi atlandı ('$relStr'): $($_.Exception.Message)"
            continue
        }
        [void]$deleteFiles.Add($targetFile)
        [void]$deleteFileSet.Add($targetFile)
    }

    $candidateDirSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($relDir in $createdDirsList) {
        if ($null -eq $relDir) { continue }
        $relDirStr = [string]$relDir
        try {
            $dirFull = Resolve-SafeChildPath -BasePath $effectiveHome -RelativePath $relDirStr
        } catch {
            Write-Warning "Güvensiz veya geçersiz 'createdDirs' girdisi atlandı ('$relDirStr'): $($_.Exception.Message)"
            continue
        }
        [void]$candidateDirSet.Add($dirFull)
    }

    $sortedDirs = @($candidateDirSet | Sort-Object -Property { $_.Length } -Descending)

    # Aşama 2: uygula veya DryRun listele
    if ($DryRun) {
        Write-Host "[DRY] Geri yükleme deneme modu: hiçbir dosya değiştirilmeyecek."
    }

    $restoredCount = 0
    $deletedCount = 0
    $removedDirCount = 0

    foreach ($pair in $replacePairs) {
        if ($DryRun) {
            Write-DryAction -Action 'GERİ YÜKLE' -Path $pair.TargetFile
        } else {
            $parent = Split-Path -Path $pair.TargetFile -Parent
            if (-not (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            Copy-Item -LiteralPath $pair.BackupFile -Destination $pair.TargetFile -Force
            Write-Host "  [GERİ YÜKLE] $($pair.TargetFile)"
        }
        $restoredCount++
    }

    foreach ($targetFile in $deleteFiles) {
        if (Test-Path -LiteralPath $targetFile -PathType Leaf) {
            if ($DryRun) {
                Write-DryAction -Action 'SİL' -Path $targetFile
            } else {
                Remove-Item -LiteralPath $targetFile -Force
                Write-Host "  [SİL] $($targetFile)"
            }
            $deletedCount++
        }
    }

    $dryRemovedDirs = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($dirPath in $sortedDirs) {
        if (-not (Test-Path -LiteralPath $dirPath -PathType Container)) {
            continue
        }
        $children = @(Get-ChildItem -LiteralPath $dirPath -Force)
        if ($DryRun) {
            $remains = $false
            foreach ($child in $children) {
                if ($child.PSIsContainer) {
                    if (-not $dryRemovedDirs.Contains($child.FullName)) {
                        $remains = $true
                        break
                    }
                } else {
                    if (-not $deleteFileSet.Contains($child.FullName)) {
                        $remains = $true
                        break
                    }
                }
            }
            if (-not $remains) {
                Write-DryAction -Action 'KLASÖR SİL' -Path $dirPath
                [void]$dryRemovedDirs.Add($dirPath)
                $removedDirCount++
            }
        } else {
            if ($children.Count -eq 0) {
                Remove-Item -LiteralPath $dirPath -Force
                Write-Host "  [KLASÖR SİL] $dirPath"
                $removedDirCount++
            }
        }
    }

    Write-Host ""
    Write-Host "=== Geri Yükleme Özeti ==="
    Write-Host "Yedek: $restoreRoot"
    Write-Host "Hedef: $effectiveHome"
    Write-Host "Geri yüklenen: $restoredCount | Silinen dosya: $deletedCount | Silinen boş klasör: $removedDirCount"
}

if ($PSBoundParameters.ContainsKey('Restore')) {
    Invoke-Restore -RestorePath $Restore -CliTargetHome $TargetHome -DryRun:$DryRun
    return
}

# --- Ön kontrol (yalnızca uyarı) ---
Write-Host "=== Ön Kontrol ==="
if ($null -eq (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Warning "git PATH'te bulunamadı."
}
if ($null -eq (Get-Command bash -ErrorAction SilentlyContinue)) {
    Write-Warning "bash (Git Bash) PATH'te bulunamadı."
}
if ($null -eq (Get-Command agy -ErrorAction SilentlyContinue)) {
    Write-Warning "agy PATH'te bulunamadı: Yalnızca Claude modu."
}
if ($null -eq (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Warning "node PATH'te bulunamadı."
}

if ($DryRun) {
    Write-Host "[DRY] Deneme modu etkin: hiçbir dosya yazılmayacak veya yedeklenmeyecek."
}

# ============================================================
# AŞAMA 1: PLANLAMA VE DOĞRULAMA (hiçbir dosyaya yazılmaz)
# ============================================================

# --- 1. skills ---
if ($selectedComponents -contains 'skills') {
    $skillsSrcRoot = Join-Path (Join-Path $scriptRoot 'claude') 'skills'
    if (-not (Test-Path -LiteralPath $skillsSrcRoot -PathType Container)) {
        throw "Kaynak skills klasörü bulunamadı: $skillsSrcRoot"
    }
    $skillsDestRoot = Join-Path $claudeDir 'skills'
    $skillDirs = @(Get-ChildItem -LiteralPath $skillsSrcRoot -Directory)
    foreach ($skillDir in $skillDirs) {
        $destSkillDir = Join-Path $skillsDestRoot $skillDir.Name
        if ((Test-Path -LiteralPath $destSkillDir) -and -not (Test-Path -LiteralPath $destSkillDir -PathType Container)) {
            throw "Hedefte klasör yerine dosya var: $destSkillDir"
        }
        $srcFiles = @(Get-ChildItem -LiteralPath $skillDir.FullName -Recurse -File -Force)
        $skillChangedCount = 0
        foreach ($srcFile in $srcFiles) {
            $relInSkill = $srcFile.FullName.Substring($skillDir.FullName.Length).TrimStart('\', '/')
            $destFile = Join-Path $destSkillDir $relInSkill
            if (Test-Path -LiteralPath $destFile -PathType Container) {
                throw "Hedefte dosya yerine klasör var: $destFile"
            }
            $srcHash = (Get-FileHash -LiteralPath $srcFile.FullName -Algorithm SHA256).Hash
            if (Test-Path -LiteralPath $destFile -PathType Leaf) {
                $destHash = (Get-FileHash -LiteralPath $destFile -Algorithm SHA256).Hash
                if ($srcHash -ne $destHash) {
                    [void]$planOps.Add([PSCustomObject]@{
                        Kind    = 'CopyFile'
                        IsNew   = $false
                        Source  = $srcFile.FullName
                        Target  = $destFile
                        Label   = $null
                        DryVerb = 'DEĞİŞTİR'
                    })
                    $skillChangedCount++
                }
            } else {
                [void]$planOps.Add([PSCustomObject]@{
                    Kind    = 'CopyFile'
                    IsNew   = $true
                    Source  = $srcFile.FullName
                    Target  = $destFile
                    Label   = $null
                    DryVerb = 'KOPYALA'
                })
                $skillChangedCount++
            }
        }
        if ($skillChangedCount -eq 0) {
            [void]$skipped.Add("skill/$($skillDir.Name) (değişmedi: $destSkillDir)")
        } else {
            [void]$installed.Add("skill/$($skillDir.Name) ($destSkillDir)")
        }
    }
} else {
    [void]$skipped.Add("skills (-Only dışı)")
}

# --- 2. agents ---
if ($selectedComponents -contains 'agents') {
    $agentsSrcRoot = Join-Path (Join-Path $scriptRoot 'claude') 'agents'
    if (-not (Test-Path -LiteralPath $agentsSrcRoot -PathType Container)) {
        throw "Kaynak agents klasörü bulunamadı: $agentsSrcRoot"
    }
    $agentsDestRoot = Join-Path $claudeDir 'agents'
    $agentFiles = @(Get-ChildItem -LiteralPath $agentsSrcRoot -Filter '*.md' -File)
    foreach ($agentFile in $agentFiles) {
        $destAgentFile = Join-Path $agentsDestRoot $agentFile.Name
        if (Test-Path -LiteralPath $destAgentFile -PathType Container) {
            throw "Hedefte dosya yerine klasör var: $destAgentFile"
        }
        $srcHash = (Get-FileHash -LiteralPath $agentFile.FullName -Algorithm SHA256).Hash
        if (Test-Path -LiteralPath $destAgentFile -PathType Leaf) {
            $destHash = (Get-FileHash -LiteralPath $destAgentFile -Algorithm SHA256).Hash
            if ($srcHash -eq $destHash) {
                [void]$skipped.Add("agent/$($agentFile.Name) (değişmedi: $destAgentFile)")
            } else {
                [void]$planOps.Add([PSCustomObject]@{
                    Kind    = 'CopyFile'
                    IsNew   = $false
                    Source  = $agentFile.FullName
                    Target  = $destAgentFile
                    Label   = "agent/$($agentFile.Name) ($destAgentFile)"
                    DryVerb = 'DEĞİŞTİR'
                })
                [void]$installed.Add("agent/$($agentFile.Name) ($destAgentFile)")
            }
        } else {
            [void]$planOps.Add([PSCustomObject]@{
                Kind    = 'CopyFile'
                IsNew   = $true
                Source  = $agentFile.FullName
                Target  = $destAgentFile
                Label   = "agent/$($agentFile.Name) ($destAgentFile)"
                DryVerb = 'KOPYALA'
            })
            [void]$installed.Add("agent/$($agentFile.Name) ($destAgentFile)")
        }
    }
} else {
    [void]$skipped.Add("agents (-Only dışı)")
}

# --- 3. claudemd ---
if ($selectedComponents -contains 'claudemd') {
    $claudeTemplatePath = Join-Path (Join-Path $scriptRoot 'claude') 'CLAUDE.md.template'
    $claudeMdTarget = Join-Path $claudeDir 'CLAUDE.md'
    $planItem = Get-MarkedMarkdownPlan -TemplatePath $claudeTemplatePath -TargetPath $claudeMdTarget -Label 'CLAUDE.md'
    if ($null -eq $planItem) {
        [void]$skipped.Add("CLAUDE.md (değişmedi: $claudeMdTarget)")
    } else {
        [void]$planOps.Add($planItem)
        [void]$installed.Add($planItem.Label)
    }
} else {
    [void]$skipped.Add("claudemd (-Only dışı)")
}

# --- 4. gemini ---
if ($selectedComponents -contains 'gemini') {
    $geminiTemplatePath = Join-Path (Join-Path $scriptRoot 'gemini') 'GEMINI.md'
    $geminiMdTarget = Join-Path $geminiDir 'GEMINI.md'
    $planItem = Get-MarkedMarkdownPlan -TemplatePath $geminiTemplatePath -TargetPath $geminiMdTarget -Label 'GEMINI.md'
    if ($null -eq $planItem) {
        [void]$skipped.Add("GEMINI.md (değişmedi: $geminiMdTarget)")
    } else {
        [void]$planOps.Add($planItem)
        [void]$installed.Add($planItem.Label)
    }
} else {
    [void]$skipped.Add("gemini (-Only dışı)")
}

# --- 5. settings ---
if ($selectedComponents -contains 'settings') {
    $snippetPath = Join-Path (Join-Path $scriptRoot 'claude') 'settings.snippet.json'
    $settingsPath = Join-Path $claudeDir 'settings.json'

    if (-not (Test-Path -LiteralPath $snippetPath -PathType Leaf)) {
        throw "Kaynak snippet bulunamadı: $snippetPath"
    }
    $snippetRaw = [System.IO.File]::ReadAllText($snippetPath, [System.Text.Encoding]::UTF8)
    try {
        $snippet = $snippetRaw | ConvertFrom-Json
    } catch {
        throw "Geçersiz JSON ($snippetPath): $($_.Exception.Message)"
    }
    if ($null -eq $snippet) {
        throw "Geçersiz veya boş JSON ($snippetPath)."
    }

    $settingsExists = Test-Path -LiteralPath $settingsPath
    if ($settingsExists) {
        if (Test-Path -LiteralPath $settingsPath -PathType Container) {
            throw "Hedefte dosya yerine klasör var: $settingsPath"
        }
        $targetRaw = [System.IO.File]::ReadAllText($settingsPath, [System.Text.Encoding]::UTF8)
        try {
            $targetSettings = $targetRaw | ConvertFrom-Json
        } catch {
            throw "Geçersiz JSON ($settingsPath): $($_.Exception.Message)"
        }
        if ($null -eq $targetSettings) {
            throw "Geçersiz veya boş JSON ($settingsPath)."
        }
    } else {
        $targetRaw = $null
        $targetSettings = New-Object PSObject
    }

    $settingsChanged = $false

    # permissions.allow birleştirme (yinelemesiz)
    if (Test-JsonProp -Obj $snippet -Name 'permissions') {
        if (Test-JsonProp -Obj $snippet.permissions -Name 'allow') {
            if (-not (Test-JsonProp -Obj $targetSettings -Name 'permissions') -or $null -eq $targetSettings.permissions) {
                Set-JsonProp -Obj $targetSettings -Name 'permissions' -Value (New-Object PSObject)
                $settingsChanged = $true
            }
            $permObj = $targetSettings.permissions
            $allowItems = @()
            if (Test-JsonProp -Obj $permObj -Name 'allow') {
                if ($null -ne $permObj.allow) {
                    if ($permObj.allow -isnot [System.Array]) {
                        $settingsChanged = $true
                    }
                    foreach ($existingEntry in @($permObj.allow)) {
                        $allowItems += $existingEntry
                    }
                } else {
                    $settingsChanged = $true
                }
            } else {
                $settingsChanged = $true
            }

            foreach ($snippetEntry in @($snippet.permissions.allow)) {
                if (@($allowItems) -cnotcontains $snippetEntry) {
                    $allowItems += $snippetEntry
                    $settingsChanged = $true
                }
            }
            [object[]]$allowArray = @($allowItems)
            Set-JsonProp -Obj $permObj -Name 'allow' -Value $allowArray
        }
    }

    # statusLine birleştirme (~ -> forward-slash TargetHome, boşluklara karşı tırnaklı)
    if (Test-JsonProp -Obj $snippet -Name 'statusLine') {
        $rawCommand = [string]$snippet.statusLine.command
        $resolvedCommand = [regex]::Replace($rawCommand, '(?<!")(~[^\s"]*)(?!")', { param($m) '"' + $m.Value.Replace('~', $forwardHome) + '"' })
        $resolvedCommand = $resolvedCommand.Replace('~', $forwardHome)
        $newStatusLine = New-Object PSObject
        Set-JsonProp -Obj $newStatusLine -Name 'type' -Value $snippet.statusLine.type
        Set-JsonProp -Obj $newStatusLine -Name 'command' -Value $resolvedCommand

        $hasStatusLine = (Test-JsonProp -Obj $targetSettings -Name 'statusLine') -and ($null -ne $targetSettings.statusLine)
        if (-not $hasStatusLine) {
            Set-JsonProp -Obj $targetSettings -Name 'statusLine' -Value $newStatusLine
            $settingsChanged = $true
        } elseif ($Force) {
            $oldType = if (Test-JsonProp -Obj $targetSettings.statusLine -Name 'type') { $targetSettings.statusLine.type } else { '' }
            $oldCmd = if (Test-JsonProp -Obj $targetSettings.statusLine -Name 'command') { $targetSettings.statusLine.command } else { '' }
            if ($oldType -cne $newStatusLine.type -or $oldCmd -cne $newStatusLine.command) {
                Set-JsonProp -Obj $targetSettings -Name 'statusLine' -Value $newStatusLine
                $settingsChanged = $true
            } else {
                [void]$skipped.Add("settings.statusLine (değişmedi)")
            }
        } else {
            [void]$planWarnings.Add("statusLine zaten mevcut; değiştirmek için -Force kullanın.")
            [void]$skipped.Add("settings.statusLine (mevcut, -Force yok)")
        }
    }

    if ((Test-JsonProp -Obj $targetSettings -Name 'permissions') -and $null -ne $targetSettings.permissions -and (Test-JsonProp -Obj $targetSettings.permissions -Name 'allow')) {
        if ($null -eq $targetSettings.permissions.allow) {
            $targetSettings.permissions.allow = [object[]]@()
        } elseif ($targetSettings.permissions.allow -isnot [System.Array]) {
            $targetSettings.permissions.allow = [object[]]@($targetSettings.permissions.allow)
        }
    }

    if (-not $settingsExists) {
        $jsonOut = ConvertTo-SafeJson -InputObject $targetSettings -Depth 20
        $finalJsonText = "$jsonOut`n"
        [void]$planOps.Add([PSCustomObject]@{
            Kind    = 'WriteText'
            IsNew   = $true
            Target  = $settingsPath
            Content = $finalJsonText
            Label   = "settings.json ($settingsPath)"
            DryVerb = 'EKLE'
        })
        [void]$installed.Add("settings.json ($settingsPath)")
    } elseif ($settingsChanged) {
        $jsonOut = ConvertTo-SafeJson -InputObject $targetSettings -Depth 20
        $finalJsonText = "$jsonOut`n"
        if ($finalJsonText -ceq $targetRaw) {
            [void]$skipped.Add("settings.json (değişmedi: $settingsPath)")
        } else {
            [void]$planOps.Add([PSCustomObject]@{
                Kind    = 'WriteText'
                IsNew   = $false
                Target  = $settingsPath
                Content = $finalJsonText
                Label   = "settings.json ($settingsPath)"
                DryVerb = 'DEĞİŞTİR'
            })
            [void]$installed.Add("settings.json ($settingsPath)")
        }
    } else {
        [void]$skipped.Add("settings.json (değişmedi: $settingsPath)")
    }
} else {
    [void]$skipped.Add("settings (-Only dışı)")
}

# ============================================================
# AŞAMA 2: YAZMA VE MANIFEST
# ============================================================

foreach ($warnMsg in $planWarnings) {
    Write-Warning $warnMsg
}

$createdFiles = New-Object System.Collections.ArrayList
$replacedFiles = New-Object System.Collections.ArrayList
$createdDirs = New-Object System.Collections.ArrayList

function Save-InstallManifest {
    param(
        [string]$ManifestPath,
        [string]$BaseHome,
        [string]$CreatedAt,
        [System.Collections.ArrayList]$Created,
        [System.Collections.ArrayList]$Replaced,
        [System.Collections.ArrayList]$CreatedDirs
    )
    $manifestObj = [PSCustomObject]@{
        version     = 1
        createdAt   = $CreatedAt
        targetHome  = $BaseHome
        created     = [string[]]@($Created)
        replaced    = [string[]]@($Replaced)
        createdDirs = [string[]]@($CreatedDirs)
    }
    $manifestJson = ConvertTo-SafeJson -InputObject $manifestObj -Depth 10
    [System.IO.File]::WriteAllText($ManifestPath, "$manifestJson`n", $utf8NoBom)
}

if ($DryRun) {
    foreach ($op in $planOps) {
        Write-DryAction -Action $op.DryVerb -Path $op.Target
    }
} elseif ($planOps.Count -gt 0) {
    $manifestCreatedAt = (Get-Date).ToString('o')
    $manifestPath = Join-Path $backupRoot 'manifest.json'
    try {
        if (-not $script:BackupCreated) {
            New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
            $script:BackupCreated = $true
        }
        Save-InstallManifest -ManifestPath $manifestPath -BaseHome $TargetHome -CreatedAt $manifestCreatedAt -Created $createdFiles -Replaced $replacedFiles -CreatedDirs $createdDirs

        foreach ($op in $planOps) {
            $relTarget = Get-RelativePath -BasePath $TargetHome -FullPath $op.Target
            if ($op.IsNew) {
                $prevDirCount = $createdDirs.Count
                $parentDir = Split-Path -Path $op.Target -Parent
                Ensure-DirectoryTracked -DirectoryPath $parentDir -BaseHome $TargetHome -CreatedDirs $createdDirs
                if ($createdDirs.Count -ne $prevDirCount) {
                    Save-InstallManifest -ManifestPath $manifestPath -BaseHome $TargetHome -CreatedAt $manifestCreatedAt -Created $createdFiles -Replaced $replacedFiles -CreatedDirs $createdDirs
                }
            } else {
                Backup-ExistingFile -TargetPath $op.Target
                [void]$replacedFiles.Add($relTarget)
                Save-InstallManifest -ManifestPath $manifestPath -BaseHome $TargetHome -CreatedAt $manifestCreatedAt -Created $createdFiles -Replaced $replacedFiles -CreatedDirs $createdDirs
            }

            if ($op.Kind -eq 'CopyFile') {
                Copy-Item -LiteralPath $op.Source -Destination $op.Target -Force
            } elseif ($op.Kind -eq 'WriteText') {
                [System.IO.File]::WriteAllText($op.Target, $op.Content, $utf8NoBom)
            }

            if ($op.IsNew) {
                [void]$createdFiles.Add($relTarget)
                Save-InstallManifest -ManifestPath $manifestPath -BaseHome $TargetHome -CreatedAt $manifestCreatedAt -Created $createdFiles -Replaced $replacedFiles -CreatedDirs $createdDirs
            }
        }
    } catch {
        Write-Host "HATA: Kurulum yazma aşamasında başarısız oldu: $($_.Exception.Message)"
        Write-Host "Manifest: $manifestPath"
        Write-Host "-Restore `"$backupRoot`" ile geri alın"
        exit 1
    }
}

# --- Özet ---
Write-Host ""
Write-Host "=== Kurulum Özeti ==="
Write-Host "Kurulan / Güncellenen:"
if ($installed.Count -eq 0) {
    Write-Host "  (yok)"
} else {
    foreach ($entry in $installed) {
        Write-Host "  + $entry"
    }
}

Write-Host "Atlanan:"
if ($skipped.Count -eq 0) {
    Write-Host "  (yok)"
} else {
    foreach ($entry in $skipped) {
        Write-Host "  - $entry"
    }
}

if ($DryRun) {
    Write-Host "Yedek yolu: (DryRun - yedek alınmadı)"
} elseif ($script:BackupCreated) {
    Write-Host "Yedek yolu: $backupRoot"
} else {
    Write-Host "Yedek yolu: (oluşturulmadı - değişiklik yok)"
}

Write-Host ""
Write-Host "Sonraki adımlar:"
Write-Host "  - agy kuruluysa (Windows'ta --copy): bash ~/.claude/skills/agent-model-routing/scripts/sync-gemini-skills.sh --copy"
Write-Host "  - 3. taraf eklentiler için README'ye bakın"
