[CmdletBinding()]
param(
    [Parameter()]
    [string] $ExampleRoot = (Join-Path $PSScriptRoot '..\example\windows'),

    [Parameter()]
    [string] $CandidatePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FullPath([string] $Path) {
    return [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path)
}

try {
    $root = Get-FullPath $ExampleRoot
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw "The React Native Windows example build root does not exist: $root"
    }

    if ($CandidatePath) {
        $candidate = Get-FullPath $CandidatePath
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            throw "The selected Windows example executable does not exist: $candidate"
        }
        if ([System.IO.Path]::GetFileName($candidate) -ne 'FFmpegKitExtendedExample.exe') {
            throw "The selected path is not FFmpegKitExtendedExample.exe: $candidate"
        }
        $rootPrefix = $root.TrimEnd('\') + '\'
        if (-not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "The selected executable is outside the known example build root: $candidate"
        }
        $matches = @($candidate)
    }
    else {
        $matches = @(
            Get-ChildItem -LiteralPath $root -Filter 'FFmpegKitExtendedExample.exe' -File -Recurse |
                ForEach-Object { $_.FullName } |
                Sort-Object -Unique
        )
    }

    if ($matches.Count -eq 0) {
        throw "No FFmpegKitExtendedExample.exe was found below the known build root: $root"
    }
    if ($matches.Count -gt 1) {
        throw "Multiple FFmpegKitExtendedExample.exe files were found; pass -CandidatePath to select one: $($matches -join '; ')"
    }

    Write-Output (Get-FullPath $matches[0])
}
catch {
    Write-Error $_
    exit 1
}
