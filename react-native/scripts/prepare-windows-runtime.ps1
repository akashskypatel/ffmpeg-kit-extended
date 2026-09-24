param(
  [ValidateSet('x64')]
  [string]$Architecture = 'x64',
  [string]$Destination = '',
  [string]$AppRoot = '',
  [string]$CacheRoot = ''
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$resolver = Join-Path $PSScriptRoot 'resolve-ffmpeg-kit-config.js'
$downloader = Join-Path $PSScriptRoot 'download-ffmpeg-kit-artifact.js'
$nodeBinary = if ($env:NODE_BINARY) { $env:NODE_BINARY } else { 'node' }

function Get-CanonicalPath {
  param([Parameter(Mandatory)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Path does not exist: $Path"
  }
  return (Resolve-Path -LiteralPath $Path).Path
}

function Get-FileSha256 {
  param([Parameter(Mandatory)][string]$Path)

  $sha = [Security.Cryptography.SHA256]::Create()
  $stream = [IO.File]::OpenRead($Path)
  try {
    return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant()
  } finally {
    $stream.Dispose()
    $sha.Dispose()
  }
}

function Get-DirectoryFingerprint {
  param([Parameter(Mandatory)][string]$Directory)

  $root = (Get-CanonicalPath $Directory).TrimEnd('\', '/')
  $entries = @(
    Get-ChildItem -LiteralPath $root -Recurse -File |
      Sort-Object FullName |
      ForEach-Object {
        $relative = $_.FullName.Substring($root.Length).TrimStart('\', '/')
        $hash = Get-FileSha256 $_.FullName
        "$relative|$($_.Length)|$hash"
      }
  )
  $payload = [Text.Encoding]::UTF8.GetBytes($entries -join "`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash($payload))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Remove-DirectoryContents {
  param([Parameter(Mandatory)][string]$Directory)

  if (Test-Path -LiteralPath $Directory -PathType Container) {
    Get-ChildItem -LiteralPath $Directory -Force | Remove-Item -Recurse -Force
  }
}

function Expand-ArchiveWithMarker {
  param(
    [Parameter(Mandatory)][string]$Archive,
    [Parameter(Mandatory)][string]$ExtractRoot,
    [Parameter(Mandatory)][string]$SourceIdentity
  )

  $marker = Join-Path $ExtractRoot '.extract_complete'
  $markerMatches = (Test-Path -LiteralPath $marker -PathType Leaf) -and
    ((Get-Content -LiteralPath $marker -Raw) -eq $SourceIdentity)
  if ($markerMatches) {
    return
  }

  if (Test-Path -LiteralPath $ExtractRoot) {
    Remove-Item -LiteralPath $ExtractRoot -Recurse -Force
  }
  $temporaryRoot = "$ExtractRoot.extracting"
  if (Test-Path -LiteralPath $temporaryRoot) {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $temporaryRoot | Out-Null
  try {
    Expand-Archive -LiteralPath $Archive -DestinationPath $temporaryRoot -Force
    Set-Content -NoNewline -LiteralPath (Join-Path $temporaryRoot '.extract_complete') -Value $SourceIdentity
    Move-Item -LiteralPath $temporaryRoot -Destination $ExtractRoot
  } catch {
    if (Test-Path -LiteralPath $temporaryRoot) {
      Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
    throw
  }
}

function Get-ValidatedRuntimeDlls {
  param([Parameter(Mandatory)][string]$RuntimeRoot)

  $dlls = @(
    Get-ChildItem -LiteralPath $RuntimeRoot -Recurse -File |
      Where-Object { $_.Extension -ieq '.dll' }
  )
  if ($dlls.Count -eq 0) {
    throw "No DLLs were found in FFmpegKit Extended Windows runtime: $RuntimeRoot"
  }

  $duplicates = @(
    $dlls |
      Group-Object -Property { $_.Name.ToLowerInvariant() } |
      Where-Object { $_.Count -gt 1 }
  )
  if ($duplicates.Count -gt 0) {
    $details = $duplicates |
      ForEach-Object { "$($_.Name): $($_.Group.FullName -join ', ')" }
    throw "Windows runtime contains duplicate flattened DLL basenames: $($details -join '; ')"
  }

  $mainLibraries = @($dlls | Where-Object { $_.Name -ieq 'libffmpegkit.dll' })
  if ($mainLibraries.Count -ne 1) {
    throw "Windows runtime must contain exactly one libffmpegkit.dll; found $($mainLibraries.Count) under $RuntimeRoot"
  }

  return @(
    $dlls | Sort-Object @{ Expression = { $_.Name.ToLowerInvariant() } }, FullName
  )
}

$resolverArgs = @(
  $resolver,
  '--platform', 'windows',
  '--architecture', $Architecture,
  '--quiet', 'true'
)
if ($AppRoot) {
  $resolverArgs += @('--app-root', (Get-CanonicalPath $AppRoot))
} else {
  $resolverArgs += @('--app-root', $repoRoot)
}

$resolutionJson = & $nodeBinary @resolverArgs
if ($LASTEXITCODE -ne 0) {
  throw 'Failed to resolve FFmpegKit Extended configuration.'
}
$resolution = $resolutionJson | ConvertFrom-Json

$cacheRoot = if ($CacheRoot) {
  [IO.Path]::GetFullPath($CacheRoot)
} else {
  Join-Path $repoRoot "vendor/windows/$Architecture"
}
New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null

$runtimeRoot = $null
if ($resolution.override -and $resolution.override.kind -eq 'local') {
  $overridePath = $resolution.override.resolvedPath
  if (-not (Test-Path -LiteralPath $overridePath)) {
    throw "FFmpegKit Extended local override was not found: $overridePath"
  }

  if (Test-Path -LiteralPath $overridePath -PathType Container) {
    $runtimeRoot = Get-CanonicalPath $overridePath
    $sourceIdentity = "local-directory:${runtimeRoot}:$(Get-DirectoryFingerprint $runtimeRoot)"
    Write-Host "Using local FFmpegKit Extended Windows runtime directory: $runtimeRoot"
  } else {
    $localArchive = Get-CanonicalPath $overridePath
    $archiveHash = Get-FileSha256 $localArchive
    $sourceIdentity = "local-archive:${localArchive}:$archiveHash"
    $archive = Join-Path $cacheRoot "source-$archiveHash.zip"
    $runtimeRoot = Join-Path $cacheRoot "extract-$archiveHash"
    Write-Host "Using local FFmpegKit Extended Windows archive: $localArchive"
    Copy-Item -LiteralPath $localArchive -Destination $archive -Force
    Expand-ArchiveWithMarker -Archive $archive -ExtractRoot $runtimeRoot -SourceIdentity $sourceIdentity
  }
} else {
  $archive = Join-Path $cacheRoot $resolution.filename
  $runtimeRoot = Join-Path $cacheRoot $resolution.cacheKey
  $sourceIdentity = "official:$($resolution.url)"
  if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
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
  Expand-ArchiveWithMarker -Archive $archive -ExtractRoot $runtimeRoot -SourceIdentity $sourceIdentity
}

$dlls = Get-ValidatedRuntimeDlls $runtimeRoot

if ($Destination) {
  $destinationPath = [IO.Path]::GetFullPath($Destination)
  if ([IO.Path]::GetFullPath($runtimeRoot) -eq $destinationPath) {
    throw 'Windows runtime staging destination must differ from the selected runtime root.'
  }
  New-Item -ItemType Directory -Force -Path $destinationPath | Out-Null
  Remove-DirectoryContents $destinationPath
  foreach ($dll in $dlls) {
    Copy-Item -LiteralPath $dll.FullName -Destination (Join-Path $destinationPath $dll.Name) -Force
  }
  $manifest = @(
    $dlls | ForEach-Object {
      $hash = Get-FileSha256 $_.FullName
      "$($_.Name)|$hash"
    }
  )
  Set-Content -LiteralPath (Join-Path $destinationPath '.ffmpegkit_runtime_manifest') -Value $manifest
}

Write-Output $runtimeRoot
