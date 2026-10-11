$bashCandidates = @(
  Get-Command bash.exe -All -ErrorAction SilentlyContinue |
    ForEach-Object { $_.Source }
  (Join-Path $env:ProgramFiles 'Git\bin\bash.exe')
  (Join-Path $env:ProgramFiles 'Git\usr\bin\bash.exe')
  (Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Git\bin\bash.exe')
)

$availableBashCandidates = $bashCandidates |
  Where-Object {
    $_ -and
    (Test-Path -LiteralPath $_ -PathType Leaf)
  }

$bash = $availableBashCandidates |
  Where-Object { $_ -match '(?i)[\\/]Git[\\/](?:usr[\\/])?bin[\\/]bash\.exe$' } |
  Select-Object -First 1

if (-not $bash) {
  $bash = $availableBashCandidates |
    Where-Object { $_ -match '(?i)[\\/]msys\d*[\\/]usr[\\/]bin[\\/]bash\.exe$' } |
    Select-Object -First 1
}

if (-not $bash) {
  $bash = $availableBashCandidates |
    Where-Object { $_ -match '(?i)[\\/]cygwin\d*[\\/]bin[\\/]bash\.exe$' } |
    Select-Object -First 1
}

if (-not $bash) {
  Write-Error 'Windows launch requires Git Bash, MSYS2, or Cygwin on PATH. WSL Bash cannot run this launcher.'
  exit 1
}

Write-Host "Launching Windows target with $bash"
& $bash --noprofile --norc ../launch.sh windows
exit $LASTEXITCODE
