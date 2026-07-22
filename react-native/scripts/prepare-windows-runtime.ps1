param(
  [ValidateSet('x64')]
  [string]$Architecture = 'x64',
  [string]$Destination = '',
  [string]$Version = '0.10.5'
)

$ErrorActionPreference = 'Stop'

$artifact = 'bundle-base-windows-x86_64-shared-lgpl'
$tag = "v$Version-windows"
$url = "https://github.com/akashskypatel/ffmpeg-kit-builders/releases/download/$tag/$artifact.zip"

$repoRoot = Split-Path -Parent $PSScriptRoot
$cacheRoot = Join-Path $repoRoot 'vendor/windows/x64'
$archive = Join-Path $cacheRoot "$artifact.zip"
$extractRoot = Join-Path $cacheRoot $artifact
$marker = Join-Path $extractRoot '.extract_complete'

New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null

if (-not (Test-Path $marker)) {
  if (-not (Test-Path $archive)) {
    Write-Host "Downloading FFmpegKit Extended Windows runtime: $artifact"
    Invoke-WebRequest -Uri $url -OutFile $archive
  }

  if (Test-Path $extractRoot) {
    Remove-Item -Recurse -Force $extractRoot
  }
  New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
  Expand-Archive -Path $archive -DestinationPath $extractRoot -Force
  New-Item -ItemType File -Force -Path $marker | Out-Null
}

$dlls = Get-ChildItem -Path $extractRoot -Recurse -File -Filter '*.dll'
if ($dlls.Count -eq 0) {
  throw "No DLLs were found in $archive"
}

if ($Destination) {
  New-Item -ItemType Directory -Force -Path $Destination | Out-Null
  foreach ($dll in $dlls) {
    Copy-Item -Force $dll.FullName (Join-Path $Destination $dll.Name)
  }
}

Write-Output $extractRoot
