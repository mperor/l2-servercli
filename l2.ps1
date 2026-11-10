# Windows wrapper: runs l2.sh with Git Bash (not WSL bash). Usage: .\l2.ps1 [command] [args]
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

& $bash "$PSScriptRoot/l2.sh" @args
exit $LASTEXITCODE
