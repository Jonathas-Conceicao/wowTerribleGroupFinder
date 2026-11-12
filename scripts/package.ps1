# Builds a local test zip, laid out like a release: dist\TerribleGroupFinder-<version>.zip
# with a single TerribleGroupFinder\ folder inside. For testing only; real releases are built
# by the BigWigs packager in GitHub Actions (scripts\release.bat).
#
# The file set comes from the TOC, the same way install.ps1 derives it, and the TOC's
# @project-version@ is replaced by a dev version in the zipped copy only.
#
# Entry names are written with forward slashes by hand: PowerShell 5.1's Compress-Archive
# writes backslashes, which some unzip tools read as part of the name.

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = (Resolve-Path (Join-Path $scriptDir '..')).Path
$addon = 'TerribleGroupFinder'
$tocName = "$addon.toc"
$tocPath = Join-Path $source $tocName
$tocLines = Get-Content -LiteralPath $tocPath

$files = New-Object System.Collections.Generic.List[string]
foreach ($line in $tocLines) {
    $trimmed = $line.Trim()
    if ($trimmed -and -not $trimmed.StartsWith('#')) { $files.Add($trimmed) }
}
foreach ($entry in @($files)) {
    if ([System.IO.Path]::GetExtension($entry) -ne '.xml') { continue }
    $xmlPath = Join-Path $source $entry
    $xmlDir = Split-Path -Parent $entry
    foreach ($m in [regex]::Matches((Get-Content -LiteralPath $xmlPath -Raw), '(?i)\bfile\s*=\s*"([^"]+)"')) {
        $ref = if ($xmlDir) { Join-Path $xmlDir $m.Groups[1].Value } else { $m.Groups[1].Value }
        if ($files -notcontains $ref) { $files.Add($ref) }
    }
}
$iconLine = $tocLines | Where-Object { $_ -match '^\s*##\s*IconTexture\s*:' } | Select-Object -First 1
if ($iconLine) {
    $iconValue = ($iconLine -replace '^\s*##\s*IconTexture\s*:\s*', '').Trim()
    $iconRel = $iconValue -replace '(?i)^Interface\\AddOns\\TerribleGroupFinder\\', ''
    $iconFile = $null
    foreach ($ext in '.blp', '.tga') {
        if (Test-Path -LiteralPath (Join-Path $source ($iconRel + $ext))) { $iconFile = $iconRel + $ext; break }
    }
    if (-not $iconFile) {
        Write-Host "ERROR: IconTexture $iconValue names no .blp/.tga in $source"
        exit 1
    }
    if ($files -notcontains $iconFile) { $files.Add($iconFile) }
}
# Only Media\Textures ships; Media\Source (art sources) never does.
$texDir = Join-Path $source 'Media\Textures'
if (Test-Path -LiteralPath $texDir) {
    foreach ($tex in Get-ChildItem -LiteralPath $texDir -File -Recurse | Where-Object { $_.Extension -in '.blp', '.tga' }) {
        $rel = $tex.FullName.Substring($source.Length).TrimStart('\')
        if ($files -notcontains $rel) { $files.Add($rel) }
    }

    # The packager ships only what git tracks. Skipped silently without git.
    $gitOk = $false
    try {
        $trackedTex = @(& git -C $source ls-files -- 'Media/Textures' 2>$null)
        $gitOk = ($LASTEXITCODE -eq 0)
    } catch {
        $gitOk = $false
    }
    if ($gitOk) {
        $trackedTex = @($trackedTex | ForEach-Object { $_ -replace '/', '\' })
        foreach ($f in $files) {
            if ($f -like 'Media\Textures\*' -and $trackedTex -notcontains $f) {
                Write-Host "WARNING: $f is not tracked by git - it will not be in a release"
            }
        }
    }
}
# The license ships with the addon (GPL-3.0), as in a release.
if ($files -notcontains 'LICENSE') { $files.Add('LICENSE') }
foreach ($f in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $source $f))) {
        Write-Host "ERROR: the file set includes $f, which does not exist in $source"
        exit 1
    }
}

# Under 'Stop', PowerShell 5.1 turns git's stderr into a terminating error (e.g. no commits yet).
try {
    $describe = & git -C $source describe --tags --always --dirty 2>$null
} catch {
    $describe = $null
}
if ($LASTEXITCODE -ne 0 -or -not $describe) { $describe = 'unknown' }
$version = "$describe-dev"

$dist = Join-Path $source 'dist'
if (-not (Test-Path -LiteralPath $dist)) { New-Item -ItemType Directory -Path $dist | Out-Null }
$zipPath = Join-Path $dist "$addon-$version.zip"
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $tocEntry = $zip.CreateEntry("$addon/$tocName")
    $writer = New-Object System.IO.StreamWriter($tocEntry.Open(), $utf8NoBom)
    $writer.Write(((Get-Content -LiteralPath $tocPath -Raw) -replace '@project-version@', $version))
    $writer.Dispose()
    foreach ($f in $files) {
        $name = "$addon/" + ($f -replace '\\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $source $f), $name) | Out-Null
    }
} finally {
    $zip.Dispose()
}

Write-Host "Packaged $($files.Count + 1) files as $version"
Write-Host $zipPath
