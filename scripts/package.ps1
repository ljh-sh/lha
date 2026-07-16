# Stage the built lha into a self-contained §2.a-bundle. Windows (MSYS2/mingw64).
#   $env:TARGET    e.g. x86_64-windows
#   $env:BUILD_DIR (default $Root\build — out-of-tree, matches scripts/build.sh)
#   $env:LHA_SRC   (default $Root\upstream\lha — verbatim upstream source)
#   $env:DIST      (default $Root\dist)
#
# §2.a-bundle layout inside dist\lha-$TARGET\:
#   bin\lha.exe          (the binary, from out-of-tree BUILD_DIR)
#   src\lha\             (verbatim upstream source, pruned of build artifacts)
#   man\man1\lha.1
#   LICENSE              (§1-§7 verbatim, repo root)
#   README.md            (archive-level pointer back to ljh-sh/lha)
#   TAKEDOWN.md          (contact channel for §1-§7 claims)
#
# Output: dist\lha-$TARGET.zip + dist\lha-$TARGET.zip.sha256
#
# Why .zip on Windows (not .tar.xz): Windows users don't have GNU tar
# or xz natively; .zip is the universal Windows archive format.
$ErrorActionPreference = 'Stop'

$Root     = Split-Path -Parent $PSScriptRoot
$BuildDir = if ($env:BUILD_DIR) { $env:BUILD_DIR } else { Join-Path $Root 'build' }
$LhaSrc   = if ($env:LHA_SRC)   { $env:LHA_SRC }   else { Join-Path $Root 'upstream\lha' }
$Dist     = if ($env:DIST)     { $env:DIST }      else { Join-Path $Root 'dist' }
$Target   = $env:TARGET
if (-not $Target) { throw 'set $env:TARGET, e.g. x86_64-windows' }

$Bin = Join-Path $BuildDir 'src\lha.exe'
$Man = Join-Path $LhaSrc   'man\lha.1'
if (-not (Test-Path $Bin)) { throw "$Bin not built (BUILD_DIR=$BuildDir)" }
if (-not (Test-Path $Man)) { throw "$Man not found" }
$License = Join-Path $Root 'LICENSE'
$Takedown = Join-Path $Root 'TAKEDOWN.md'
if (-not (Test-Path $License))  { throw "$License not found" }
if (-not (Test-Path $Takedown)) { throw "$Takedown not found" }

$Stage = Join-Path $Dist "lha-$Target"
if (Test-Path $Stage) { Remove-Item -Recurse -Force $Stage }
New-Item -ItemType Directory -Force -Path (Join-Path $Stage 'bin')      | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Stage 'man\man1') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Stage 'src')      | Out-Null

Copy-Item $Bin (Join-Path $Stage 'bin\lha.exe')
Copy-Item $Man (Join-Path $Stage 'man\man1\lha.1')

# §2.a — verbatim upstream source (cleaned of build artifacts).
# robocopy is built into every Windows install; its /XF (file) and /XD
# (directory) filters are stable across Windows 7 → 11. We mirror the
# same prune list as scripts/package.sh on POSIX. Robocopy exit codes
# 0..7 are success (0=no-copy, 1=files-copied, 2=extras-deleted, etc.);
# codes >= 8 are real errors — wrapped & checked explicitly.
$LhaStageSrc = Join-Path $Stage 'src\lha'
$robocopied = robocopy $LhaSrc $LhaStageSrc /MIR `
    /XD autom4te.cache .deps .libs .github .git `
        'autom4te.cache' '.deps' '.libs' '.github' '.git' `
        'olddoc' `
    /XF Makefile 'Makefile' 'Makefile.in~' `
        '*.o' '*.exe' '*.in~' '*.stamp' '*~' '.#*' `
        'config.h' 'config.h.in~' 'config.log' 'config.status' `
        'stamp-h1' '.gitignore' '.travis.yml' `
    /NFL /NDL /NJH /NJS /NC /NS /NP
# robocopy exit codes 0..7 are non-error; 8+ are real failures
if ($LASTEXITCODE -ge 8) {
    throw "robocopy failed with code $LASTEXITCODE"
}

# Repo-root LICENSE and TAKEDOWN
Copy-Item $License  (Join-Path $Stage 'LICENSE')
Copy-Item $Takedown (Join-Path $Stage 'TAKEDOWN.md')

# Archive-level README
@"
# lha — single-target §2.a-bundle (release zip)

Source:      https://github.com/ljh-sh/lha (release tag)
Target:      ${Target}
Upstream:    jca02266/lha @ ac20220213 (LHa for UNIX 1.14i)

This archive is laid out per **§2.a** of the ORIGINAL LHA LICENSE
(the redistribution clause we ship under — see `LICENSE`): the
binary, the verbatim upstream source (`src\lha\`), the man page,
the LICENSE (§1-§7 verbatim), and the TAKEDOWN contact channel.

## Install (manual)

    # from a PowerShell or cmd with admin rights:
    # (run ``tar -xvf lha-${Target}.zip`` or unzip with Explorer)
    copy bin\lha.exe                 C:\Windows\
    copy man\man1\lha.1              C:\Program Files\Git\mingw64\share\man\man1\

(Or use Git for Windows's bundled `tar xJf lha-${Target}.zip`.)

## Rebuild from source

    cd src\lha
    autoreconf -is
    ./configure
    make
"@ | Set-Content -Encoding utf8 (Join-Path $Stage 'README.md')

$zip = Join-Path $Dist "lha-$Target.zip"
Compress-Archive -Path "$Stage\*" -DestinationPath $zip -Force

$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
"$hash  lha-$Target.zip" | Set-Content -Encoding ascii "$zip.sha256"

Write-Host "==> $zip"
Write-Host "==> $zip.sha256"
