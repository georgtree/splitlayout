#!/usr/bin/env bash
set -euo pipefail
root=$PWD
prefix="$root/_ci/runtime"
platform=unix
toolchain=linux-gcc
native_path() { printf '%s' "$1"; }
display=(xvfb-run -a -s '-screen 0 1920x1080x24 -dpi 96')
if [[ ${MSYSTEM:-} == UCRT64 ]]; then
    platform=win
    toolchain=windows-ucrt64
    display=()
    native_path() { cygpath -m "$1"; }
fi
export PATH="$prefix/bin:$PATH"
export LD_LIBRARY_PATH="$prefix/lib:${LD_LIBRARY_PATH:-}"
if [[ ${RUNTIME_CACHE_HIT:-false} != true ]]; then
    for package in tcl tk; do
        mkdir -p "$root/_ci/$package-build"
        cd "$root/_ci/$package-build"
        flags=()
        if [[ $package == tk ]]; then flags+=(--with-tcl="$prefix/lib"); fi
        bash "$root/_ci/$package/$platform/configure" --prefix="$prefix" "${flags[@]}"
        make -j2
        make install
    done
fi
mkdir -p "$root/_ci/layout-build"
cd "$root/_ci/layout-build"
bash "$root/configure" --with-tcl="$prefix/lib" --with-tk="$prefix/lib" --prefix="$prefix" --exec-prefix="$prefix"
make
argparse=$(cat "$root/_ci/argparse/package-dir.txt")
export TCLLIBPATH="{$(native_path "$root/_ci/argparse/lib/$argparse")} {$(native_path "$root/_ci/tklib/modules/tooltip")}"
export SPLITLAYOUT_TEST_TOOLTIP=1
"${display[@]}" make test TCLLIBPATH="$TCLLIBPATH" | tee test.log
grep -Eq '^all\.tcl:[[:space:]]+Total[[:space:]]+[0-9]+[[:space:]]+Passed[[:space:]]+[1-9][0-9]*[[:space:]]+Skipped[[:space:]]+[0-9]+[[:space:]]+Failed[[:space:]]+0[[:space:]]*$' test.log
if [[ ${MAKE_DIST:-false} == true ]]; then
    target=dist ext=tar.gz
    if [[ $platform == win ]]; then target=dist-zip ext=zip; fi
    make "$target" DIST_ROOT="$root/_ci/dist"
    archive=("$root"/_ci/dist/*."$ext")
    name=$(basename "${archive[0]}" ".$ext")
    mkdir -p "$root/_ci/package"
    cp "${archive[0]}" "$root/_ci/package/$name-$toolchain.$ext"
fi
