# Stage the built lha into a self-contained zip. Windows (MSYS2/mingw64).
#   $env:TARGET  e.g. x86_64-windows
#   $env:LHA_SRC (default $PSScriptRoot\..\upstream\lha)
#   $env:DIST    (default $PSScriptRoot\..\dist)
#
# Stage layout inside dist\lha-$TARGET\:
#   bin\lha.exe          (the binary)
#   man\man1\lha.1
#   README.md
$ErrorActionPreference = 'Stop'

$Root   = Split-Path -Parent $PSScriptRoot
$LhaSrc = if ($env:LHA_SRC) { $env:LHA_SRC } else { Join-Path $Root 'upstream\lha' }
$Dist   = if ($env:DIST)   { $env:DIST }   else { Join-Path $Root 'dist' }
$Target = $env:TARGET
if (-not $Target) { throw 'set $env:TARGET, e.g. x86_64-windows' }

$Bin  = Join-Path $LhaSrc 'src\lha.exe'
$Man  = Join-Path $LhaSrc 'man\lha.1'
if (-not (Test-Path $Bin)) { throw "$Bin not built" }
if (-not (Test-Path $Man)) { throw "$Man not found" }

$Stage = Join-Path $Dist "lha-$Target"
if (Test-Path $Stage) { Remove-Item -Recurse -Force $Stage }
New-Item -ItemType Directory -Force -Path (Join-Path $Stage 'bin')   | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Stage 'man\man1') | Out-Null

Copy-Item $Bin (Join-Path $Stage 'bin\lha.exe')
Copy-Item $Man (Join-Path $Stage 'man\man1\lha.1')

@'
# lha — single-binary release

Self-contained archive from https://github.com/ljh-sh/lha (release tag).
The wrapper LICENSE and NOTICE live there; the `lha` binary carries the
upstream LHa redistribution terms — see the source repo or
https://github.com/jca02266/lha.
'@ | Set-Content -Encoding utf8 (Join-Path $Stage 'README.md')

$zip = Join-Path $Dist "lha-$Target.zip"
Compress-Archive -Path "$Stage\*" -DestinationPath $zip -Force

$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
"$hash  lha-$Target.zip" | Set-Content -Encoding ascii "$zip.sha256"

Write-Host "==> $zip"
Write-Host "==> $zip.sha256"
