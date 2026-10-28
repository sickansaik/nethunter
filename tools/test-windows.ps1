param(
    [switch]$Setup,
    [string]$Python
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$localTools = Join-Path $root '.dev-tools'
if ($Setup) {
    New-Item -ItemType Directory -Force (Join-Path $localTools 'downloads') | Out-Null
    $packages = @(
        @{ File='git.7z.exe'; Url='https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.3/PortableGit-2.56.0.3-64-bit.7z.exe'; Hash='4fc27b779829a36df77911e3f4dea09c66c790dd6c5f7dfa3b6a5479f1fe354f' },
        @{ File='shellcheck.zip'; Url='https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.zip'; Hash='8a4e35ab0b331c85d73567b12f2a444df187f483e5079ceffa6bda1faa2e740e' }
    )
    foreach ($package in $packages) {
        $archive = Join-Path (Join-Path $localTools 'downloads') $package.File
        if (!(Test-Path -LiteralPath $archive)) {
            Invoke-WebRequest -Uri $package.Url -OutFile $archive
        }
        if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $package.Hash) {
            throw "Checksum mismatch: $archive. Remove this download and retry."
        }
    }
    $gitArchive = Join-Path $localTools 'downloads/git.7z.exe'
    $gitFolder = Join-Path $localTools 'git'
    if (!(Test-Path -LiteralPath (Join-Path $gitFolder 'bin/bash.exe'))) {
        $sevenZip = Join-Path $env:ProgramFiles '7-Zip/7z.exe'
        if (Test-Path -LiteralPath $sevenZip) {
            & $sevenZip x $gitArchive "-o$gitFolder" -y
            if ($LASTEXITCODE -ne 0) { throw 'Git extraction failed.' }
        } else {
            $process = Start-Process -FilePath $gitArchive -ArgumentList @('-y', ('-o"{0}"' -f $gitFolder)) -WindowStyle Hidden -Wait -PassThru
            if ($process.ExitCode -ne 0) { throw 'Git extraction failed.' }
        }
    }
    Expand-Archive -LiteralPath (Join-Path $localTools 'downloads/shellcheck.zip') -DestinationPath (Join-Path $localTools 'shellcheck') -Force
}
if (!$Python) {
    $bundled = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
    if (Test-Path -LiteralPath $bundled) {
        $Python = $bundled
    } else {
        $command = Get-Command python -ErrorAction SilentlyContinue
        if (!$command -or $command.Source -like '*WindowsApps*') {
            throw 'Python 3.10+ is required. Pass -Python with the path to python.exe.'
        }
        $Python = $command.Source
    }
}
& $Python (Join-Path $PSScriptRoot 'validate.py')
exit $LASTEXITCODE
