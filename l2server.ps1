# Windows wrapper: runs l2server.sh with Git Bash (not WSL bash). Usage: .\l2server.ps1 [command] [args]
$git = Get-Command git -ErrorAction SilentlyContinue
$bash = $null
if ($git) {
    # ...\Git\cmd\git.exe or ...\Git\mingw64\bin\git.exe -> ...\Git\bin\bash.exe
    $root = Split-Path (Split-Path $git.Source)
    foreach ($candidate in @((Join-Path $root 'bin\bash.exe'), (Join-Path (Split-Path $root) 'bin\bash.exe'))) {
        if (Test-Path $candidate) { $bash = $candidate; break }
    }
}
if (-not $bash) {
    Write-Error 'Git Bash not found. Install Git for Windows: https://git-scm.com/download/win'
    exit 1
}

# l2server.sh prints commands to run next; they should read the way this script was called
$env:L2_CLI = '.\l2server.ps1'
& $bash "$PSScriptRoot/l2server.sh" @args
exit $LASTEXITCODE
