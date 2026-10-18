param(
  [Parameter(Mandatory)][string]$PackageRoot,
  [Parameter(Mandatory)][string]$ExampleRoot,
  [ValidateSet('debug', 'release')][string]$BuildType = 'release'
)

$ErrorActionPreference = 'Stop'
$PackageRoot = [IO.Path]::GetFullPath($PackageRoot)
$ExampleRoot = [IO.Path]::GetFullPath($ExampleRoot)
$runtimeRoot = Join-Path $ExampleRoot '.windows-runtime'
$localPackages = Join-Path $runtimeRoot '.local-packages'

function Write-Utf8NoBom {
  param([string]$Path, [string]$Content)
  [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function Invoke-External {
  param(
    [Parameter(Mandatory)][string]$FilePath,
    [string[]]$ArgumentList = @(),
    [Parameter(Mandatory)][string]$WorkingDirectory,
    [switch]$CaptureOutput
  )

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  Push-Location -LiteralPath $WorkingDirectory
  try {
    if ($CaptureOutput) {
      $output = & $FilePath @ArgumentList
    } else {
      & $FilePath @ArgumentList
    }
    $exitCode = $LASTEXITCODE
  } finally {
    Pop-Location
    $ErrorActionPreference = $previousErrorActionPreference
  }
  if ($exitCode -ne 0) {
    throw "Command failed with exit code $($exitCode): $FilePath $($ArgumentList -join ' ')"
  }
  if ($CaptureOutput) {
    return $output
  }
}

$node = (Get-Command node.exe -ErrorAction Stop).Source
$npm = (Get-Command npm.cmd -ErrorAction Stop).Source
$npx = (Get-Command npx.cmd -ErrorAction Stop).Source
$nodeDirectory = Split-Path -Parent $node
$npmDirectory = Split-Path -Parent $npm
$npxDirectory = Split-Path -Parent $npx
$pathParts = @($nodeDirectory, $npmDirectory, $npxDirectory) + @($env:PATH -split ';')
$env:PATH = ($pathParts | Where-Object { $_ } | Select-Object -Unique) -join ';'

Write-Host 'Building React Native library with Node.js...'
$bob = Join-Path $PackageRoot 'node_modules/react-native-builder-bob/bin/bob'
if (-not (Test-Path -LiteralPath $bob -PathType Leaf)) {
  Invoke-External -FilePath $npm -ArgumentList @('install') -WorkingDirectory $PackageRoot
}
Invoke-External -FilePath $node -ArgumentList @($bob, 'build') -WorkingDirectory $PackageRoot

New-Item -ItemType Directory -Force -Path $localPackages | Out-Null
Write-Host 'Packing local FFmpegKit Extended dependency for Windows...'
try {
  $packOutput = Invoke-External -FilePath $npm -ArgumentList @(
    'pack', '--ignore-scripts', '--pack-destination', $localPackages
  ) -WorkingDirectory $PackageRoot -CaptureOutput
  $packLines = @($packOutput) | Where-Object { $_ -and $_.ToString().Trim() }
  $packedName = (@($packLines) | Select-Object -Last 1).ToString().Trim()
} catch {
  Write-Warning "npm pack failed; using the local tarball packer. $_"
  $fallback = Invoke-External -FilePath $node -ArgumentList @(
    (Join-Path $PackageRoot 'scripts/pack-local-package.js'), $PackageRoot, $localPackages
  ) -WorkingDirectory $PackageRoot -CaptureOutput
  $packedName = (@($fallback) | Select-Object -Last 1).ToString().Trim()
}

$packedPath = Join-Path $localPackages $packedName
if (-not $packedName -or -not (Test-Path -LiteralPath $packedPath -PathType Leaf)) {
  throw "npm pack did not produce the expected local archive: $packedPath"
}
$archiveHash = (Get-FileHash -LiteralPath $packedPath -Algorithm SHA256).Hash.ToLowerInvariant()
$archiveName = "ffmpeg-kit-extended-local-$archiveHash.tgz"
$archivePath = Join-Path $localPackages $archiveName
if ($packedPath -ne $archivePath) {
  Move-Item -LiteralPath $packedPath -Destination $archivePath -Force
}
Get-ChildItem -LiteralPath $localPackages -Filter 'ffmpeg-kit-extended-local-*.tgz' -File |
  Where-Object { $_.FullName -ne $archivePath } |
  Remove-Item -Force

$runtimePackage = [ordered]@{
  name = 'ffmpeg-kit-extended-react-native-windows-runtime'
  version = '0.0.1'
  private = $true
  scripts = [ordered]@{
    start = 'node node_modules/react-native/cli.js start --config metro.config.js'
    windows = 'node node_modules/react-native/cli.js run-windows --sln ../windows/FFmpegKitExtendedExample.sln'
  }
  dependencies = [ordered]@{
    'ffmpeg-kit-extended' = "file:.local-packages/$archiveName"
    react = '19.2.3'
    'react-native' = '0.84.0'
    'react-native-windows' = '0.84.0'
  }
  devDependencies = [ordered]@{
    '@babel/core' = '^7.25.2'
    '@babel/runtime' = '^7.25.0'
    '@react-native-community/cli' = '20.0.0'
    '@react-native/babel-preset' = '0.84.0'
    '@react-native/metro-config' = '0.84.0'
    '@react-native/typescript-config' = '0.84.0'
    '@types/react' = '^19.2.0'
    typescript = '^5.8.3'
  }
  engines = @{ node = '>=22.11.0' }
}
Write-Utf8NoBom (Join-Path $runtimeRoot 'package.json') (($runtimePackage | ConvertTo-Json -Depth 20) + [Environment]::NewLine)

$runtimeReactNativeConfig = @'
const path = require('path');

module.exports = {
  project: {
    windows: {
      sourceDir: '../windows',
      solutionFile: 'FFmpegKitExtendedExample.sln',
      project: {
        projectFile: 'FFmpegKitExtendedExample\\FFmpegKitExtendedExample.vcxproj',
      },
    },
  },
};
'@
Write-Utf8NoBom (Join-Path $runtimeRoot 'react-native.config.js') $runtimeReactNativeConfig

$runtimeMetroConfig = @'
const path = require('path');
const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');

const runtimeRoot = __dirname;
const exampleRoot = path.resolve(runtimeRoot, '..');
const libraryRoot = path.resolve(exampleRoot, '..');
const runtimeNodeModules = path.resolve(runtimeRoot, 'node_modules');
const windowsRoot = path.resolve(exampleRoot, 'windows').replace(/[/\\]/g, '/');

const config = {
  projectRoot: exampleRoot,
  watchFolders: [libraryRoot],
  resolver: {
    disableHierarchicalLookup: true,
    nodeModulesPaths: [runtimeNodeModules],
    blockList: [new RegExp(windowsRoot + '.*')],
    extraNodeModules: {
      react: path.resolve(runtimeNodeModules, 'react'),
      'react-native': path.resolve(runtimeNodeModules, 'react-native'),
      'react-native-windows': path.resolve(runtimeNodeModules, 'react-native-windows'),
      'ffmpeg-kit-extended': path.resolve(runtimeNodeModules, 'ffmpeg-kit-extended'),
    },
  },
};

module.exports = mergeConfig(getDefaultConfig(exampleRoot), config);
'@
Write-Utf8NoBom (Join-Path $runtimeRoot 'metro.config.js') $runtimeMetroConfig

$linkedPackage = Join-Path $runtimeRoot 'node_modules/ffmpeg-kit-extended'
if (Test-Path -LiteralPath $linkedPackage) {
  Remove-Item -LiteralPath $linkedPackage -Recurse -Force
}
$npmInstallArgs = @('install', '--ignore-scripts', '--legacy-peer-deps', '--no-audit', '--no-fund')
Invoke-External -FilePath $npm -ArgumentList $npmInstallArgs -WorkingDirectory $runtimeRoot
$exampleNodeModules = Join-Path $ExampleRoot 'node_modules'
if (Test-Path -LiteralPath $exampleNodeModules) {
  throw "Staged example unexpectedly contains node_modules: $exampleNodeModules"
}
New-Item -ItemType Junction -Path $exampleNodeModules -Target (Join-Path $runtimeRoot 'node_modules') | Out-Null
Invoke-External -FilePath $node -ArgumentList @(
  (Join-Path $runtimeRoot 'node_modules/react-native/cli.js'), 'autolink-windows', '--no-telemetry'
) -WorkingDirectory $runtimeRoot

$programFilesX86 = [Environment]::GetFolderPath('ProgramFilesX86')
$vswhere = Join-Path $programFilesX86 'Microsoft Visual Studio/Installer/vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
  throw "Visual Studio Installer's vswhere.exe was not found: $vswhere"
}
$vswhereArgs = @(
  '-latest',
  '-products', '*',
  '-version', '[18.6,19.0)',
  '-requires', 'Microsoft.Component.MSBuild',
  '-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
  '-find', 'MSBuild\**\Bin\MSBuild.exe'
)
$msbuildCandidates = @(& $vswhere @vswhereArgs)
if ($LASTEXITCODE -ne 0 -or -not $msbuildCandidates) {
  throw 'Visual Studio 18.6 or later with MSBuild and VC tools was not found.'
}
$msbuild = [string]$msbuildCandidates[0]

$windowsKitBin = Join-Path $programFilesX86 'Windows Kits/10/bin'
$mdmerge = Get-ChildItem -LiteralPath $windowsKitBin -Filter 'mdmerge.exe' -Recurse -File |
  Where-Object { $_.FullName -match '[\\/]x64[\\/]mdmerge\.exe$' } |
  Sort-Object { try { [version]$_.Directory.Parent.Name } catch { [version]'0.0' } } -Descending |
  Select-Object -First 1
if (-not $mdmerge) {
  throw 'Windows SDK mdmerge.exe was not found.'
}
$mdmergeShortPathScript = Join-Path $runtimeRoot '.resolve-mdmerge-short-path.cmd'
$shortPathScriptContent = '@echo off' + [Environment]::NewLine +
  'for %%I in ("' + $mdmerge.Directory.FullName + '") do @echo %%~sI' + [Environment]::NewLine
Write-Utf8NoBom $mdmergeShortPathScript $shortPathScriptContent
$mdmergeShortDirectory = @(& $env:ComSpec /d /c $mdmergeShortPathScript | ForEach-Object { $_.Trim() } | Where-Object { $_ })
Remove-Item -LiteralPath $mdmergeShortPathScript -Force
if ($LASTEXITCODE -ne 0 -or -not $mdmergeShortDirectory) {
  throw "Could not resolve a space-free Windows SDK path for mdmerge.exe: $($mdmerge.Directory.FullName)"
}
$mdmergePath = $mdmergeShortDirectory[0].TrimEnd('\') + '\'

$dotnetRoot = Join-Path $env:ProgramFiles 'dotnet'
$dotnetSdk = Get-ChildItem -LiteralPath (Join-Path $dotnetRoot 'sdk') -Directory |
  Sort-Object { try { [version]$_.Name } catch { [version]'0.0' } } -Descending |
  Select-Object -First 1
if (-not $dotnetSdk) {
  throw "No installed .NET SDK directory was found under $dotnetRoot\sdk."
}
$env:DOTNET_ROOT = $dotnetRoot
$env:DOTNET_ROOT_X64 = $dotnetRoot
$env:DOTNET_MULTILEVEL_LOOKUP = '1'
$env:MSBuildSDKsPath = Join-Path $dotnetSdk.FullName 'Sdks'

$codegenCli = Join-Path $runtimeRoot 'node_modules/ffmpeg-kit-extended/scripts/windows-codegen-entry.js'
$codegenWorkingDirectory = Join-Path $runtimeRoot 'node_modules/ffmpeg-kit-extended'
$codegenWrapper = Join-Path $runtimeRoot '.ffmpeg-kit-windows-codegen.cmd'
$codegenScript = @"
@echo off
set "PATH=$nodeDirectory;$npmDirectory;$npxDirectory;%ProgramFiles%\dotnet;%SystemRoot%\System32;%SystemRoot%\System32\WindowsPowerShell\v1.0;%ProgramFiles%\PowerShell\7;%APPDATA%\npm;%PATH%"
set "DOTNET_ROOT=$dotnetRoot"
set "DOTNET_ROOT(x64)=$dotnetRoot"
set "DOTNET_ROOT(x86)=$programFilesX86\dotnet"
set "DOTNET_MULTILEVEL_LOOKUP=1"
cd /d "$codegenWorkingDirectory"
"$node" "$codegenCli" %*
"@
Write-Utf8NoBom $codegenWrapper $codegenScript

$solution = Join-Path $ExampleRoot 'windows/FFmpegKitExtendedExample.sln'
$solutionDirectory = (Join-Path $ExampleRoot 'windows') + '\'
$configuration = if ($BuildType -eq 'release') { 'Release' } else { 'Debug' }
$codegenCommandProperty = '/p:CodegenCommand="' + $codegenWrapper + '"'
$msbuildArgs = @(
  $solution,
  '/restore',
  '/m',
  "/p:Configuration=$configuration",
  '/p:Platform=x64',
  "/p:SolutionPath=$solution",
  "/p:SolutionDir=$solutionDirectory",
  '/p:SolutionFileName=FFmpegKitExtendedExample.sln',
  $codegenCommandProperty,
  '/p:CodegenCommandArgs=codegen-windows --logging',
  "/p:CodegenCommandWorkingDir=$codegenWorkingDirectory",
  "/p:MdMergePath=$mdmergePath",
  '/p:AppxBundle=false',
  '/p:AppxPackageSigningEnabled=false',
  '/p:RunAutolinkCheck=false',
  '/verbosity:minimal',
  '/nologo'
)
Write-Host "Building Windows application project with MSBuild ($configuration)..."
# React Native Windows invokes Metro's npx command from the build process cwd.
try {
  Invoke-External -FilePath $msbuild -ArgumentList $msbuildArgs -WorkingDirectory $runtimeRoot
} finally {
  Remove-Item -LiteralPath $exampleNodeModules -Force
}
