param(
  [ValidateSet('x64', 'arm64')]
  [string]$Architecture = 'x64',
  [string]$Destination = '',
  [string]$AppRoot = ''
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$resolver = Join-Path $PSScriptRoot 'resolve-ffmpeg-kit-config.js'
$downloader = Join-Path $PSScriptRoot 'download-ffmpeg-kit-artifact.js'
$nodeBinary = if ($env:NODE_BINARY) { $env:NODE_BINARY } else { 'node' }

$resolverArgs = @(
  $resolver,
  '--platform', 'windows',
  '--architecture', $Architecture,
  '--quiet', 'true'
)
if ($AppRoot) {
  $resolverArgs += @('--app-root', (Resolve-Path $AppRoot).Path)
} else {
  $resolverArgs += @('--app-root', $repoRoot)
}

$resolutionJson = & $nodeBinary @resolverArgs
if ($LASTEXITCODE -ne 0) {
  throw 'Failed to resolve FFmpegKit Extended configuration.'
}
$resolution = $resolutionJson | ConvertFrom-Json

$cacheRoot = Join-Path $repoRoot "vendor/windows/$Architecture"
New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null

$extractRoot = $null
if ($resolution.override -and $resolution.override.kind -eq 'local' -and
    (Test-Path $resolution.override.resolvedPath -PathType Container)) {
  $extractRoot = $resolution.override.resolvedPath
  Write-Host "Using local FFmpegKit Extended Windows runtime: $extractRoot"
} else {
  $archive = Join-Path $cacheRoot $resolution.filename
  $extractRoot = Join-Path $cacheRoot $resolution.cacheKey
  $marker = Join-Path $extractRoot '.extract_complete'
  $sourceKey = if ($resolution.override) {
    "$($resolution.override.kind):$($resolution.override.value)"
  } else {
    "official:$($resolution.url)"
  }

  $markerMatches = (Test-Path $marker) -and
    ((Get-Content -Raw $marker) -eq $sourceKey)

  if (-not $markerMatches) {
    if ($resolution.override -and $resolution.override.kind -eq 'local') {
      $localArchive = $resolution.override.resolvedPath
      if (-not (Test-Path $localArchive -PathType Leaf)) {
        throw "FFmpegKit Extended local override was not found: $localArchive"
      }
      Write-Host "Using local FFmpegKit Extended Windows archive: $localArchive"
      Copy-Item -Force $localArchive $archive
    } else {
      Write-Host "Preparing FFmpegKit Extended Windows runtime: $($resolution.url)"
      $downloadArgs = @(
        $downloader,
        '--url', $resolution.url,
        '--output', $archive,
        '--retries', '3',
        '--timeout-ms', '30000'
      )
      if ($resolution.checksum) {
        $downloadArgs += @('--checksum-method', $resolution.checksum.method)
        if ($resolution.checksum.url) {
          $downloadArgs += @('--checksum-url', $resolution.checksum.url)
        }
        if ($resolution.checksum.releaseApiUrl) {
          $downloadArgs += @('--release-api-url', $resolution.checksum.releaseApiUrl)
        }
        if ($resolution.checksum.assetName) {
          $downloadArgs += @('--asset-name', $resolution.checksum.assetName)
        }
      }
      & $nodeBinary @downloadArgs
      if ($LASTEXITCODE -ne 0) {
        throw "Failed to prepare FFmpegKit Extended Windows runtime: $($resolution.url)"
      }
    }

    if (Test-Path $extractRoot) {
      Remove-Item -Recurse -Force $extractRoot
    }
    New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
    Expand-Archive -Path $archive -DestinationPath $extractRoot -Force
    Set-Content -NoNewline -Path $marker -Value $sourceKey
  }
}

$dlls = Get-ChildItem -Path $extractRoot -Recurse -File -Filter '*.dll'
if ($dlls.Count -eq 0) {
  throw "No DLLs were found in FFmpegKit Extended Windows runtime: $extractRoot"
}

if ($Destination) {
  New-Item -ItemType Directory -Force -Path $Destination | Out-Null
  foreach ($dll in $dlls) {
    Copy-Item -Force $dll.FullName (Join-Path $Destination $dll.Name)
  }
}

Write-Output $extractRoot
