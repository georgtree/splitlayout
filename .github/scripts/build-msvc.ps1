$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$prefix = Join-Path $root '_ci/runtime'
$tcl = Join-Path $root '_ci/tcl'
$tk = Join-Path $root '_ci/tk'
function Invoke-Native {
    param([string]$Program, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE" }
}
function Invoke-Nmake {
    Invoke-Native nmake /nologo /f makefile.vc @args
}
$env:Path = "$prefix\bin;" + $env:Path
$tclsh = Join-Path $prefix 'bin/tclsh91.exe'
if ($env:RUNTIME_CACHE_HIT -ne 'true') {
    Push-Location "$tcl/win"
    try {
        Invoke-Nmake "INSTALLDIR=$prefix" release
        Invoke-Nmake "INSTALLDIR=$prefix" install
    } finally { Pop-Location }
    Push-Location "$tk/win"
    try {
        Invoke-Nmake "TCLDIR=$tcl" "INSTALLDIR=$prefix" release
        Invoke-Nmake "TCLDIR=$tcl" "INSTALLDIR=$prefix" install
    } finally { Pop-Location }
}
$argparse = (Get-Content "$root/_ci/argparse/package-dir.txt" -Raw).Trim()
$env:TCLLIBPATH = "{$root/_ci/argparse/lib/$argparse} {$root/_ci/tklib/modules/tooltip} {$root/_ci/tcllib/modules}".Replace('\','/')
$env:SPLITLAYOUT_TEST_TOOLTIP = '1'
$out = Join-Path $root '_ci/layout-build'
$buildArgs = @("INSTALLDIR=$prefix", "TCLSH=$tclsh", "OUT_DIR=$out")
Push-Location win
try {
    Invoke-Nmake @buildArgs
    $log = Join-Path $out 'test.log'
    Invoke-Nmake @buildArgs test | Tee-Object -FilePath $log
    if (!(Select-String -Path $log -Quiet -Pattern '^all\.tcl:\s+Total\s+\d+\s+Passed\s+[1-9]\d*\s+Skipped\s+\d+\s+Failed\s+0\s*$')) {
        throw 'MSVC test target did not report a successful Tcltest run'
    }
    if ($env:MAKE_DIST -eq 'true') {
        Invoke-Nmake @buildArgs "DIST_ROOT=$root\_ci\dist" dist-zip
        $archive = Get-Item "$root/_ci/dist/*.zip"
        New-Item -ItemType Directory -Force "$root/_ci/package" | Out-Null
        Copy-Item $archive.FullName "$root/_ci/package/$($archive.BaseName)-windows-msvc.zip"
    }
} finally { Pop-Location }
