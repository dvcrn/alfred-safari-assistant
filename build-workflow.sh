#!/usr/bin/env zsh

# Path to this script's directory (i.e. workflow root)
here="$( cd "$( dirname "$0" )"; pwd )"
builddir="${here}/build"

devmode=1
runtests=0
force=0

# log <arg>... | Echo args to STDERR
log() {
  echo "$@" >&2
}

# cleanup | Delete temporary build files
cleanup() {
  log "Cleaning up ..."
  test -d "$builddir" && rm -vrf "${builddir}/"*
}

# usage | Show usage message
usage() {
  cat <<EOS
build-workflow.sh [-h] [-d] [-t]

Build workflow from source code in ./build directory.
Use -d to also build an .alfredworkflow file.

Usage:
  build-workflow.sh [-d] [-t] [-f]
  build-workflow.sh -h

Options:
  -d  Distribution. Also build .alfredworkflow file.
  -f  Force. Overwrite existing files.
  -t  Also run unit tests.
  -h  Show this message and exit.
EOS
}

# -------------------------------------------------------
# CLI options
while getopts ":dfht" opt; do
  case $opt in
    d)
      devmode=0
      ;;
    f)
      force=1
      ;;
    h)
      usage
      exit 0
      ;;
    t)
      runtests=1
      ;;
    \?)
      log "Invalid option: -$OPTARG"
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

test -z "$here" && { log "Couldn't find workflow directory"; exit 1 }


pushd "$here" &> /dev/null
# -------------------------------------------------------
# Run unit tests
test "$runtests" -eq 1 && {
  log "Running unit tests ..."
  go test -v . || exit 1
}

# -------------------------------------------------------
# Build
test -d "${builddir}" && { log "Cleaning build directory ..."; cleanup }

log "Building executable(s) ..."
go build -v -o ./alsf .
zipname="$( ./alsf distname 2>/dev/null )"
outpath="${here}/${zipname}"

log "Hardlinking assets to build directory ..."
# mkdir -vp "$builddir"
mkdir -vp "${builddir}/scripts/"{tab,url}
ln -v *.png "${builddir}/"
ln -v info.plist  "${builddir}/"
ln -v alsf "${builddir}/"
ln -v README.md "${builddir}/"
ln -v LICENCE.txt "${builddir}/"
ln -v scripts/tab/* "${builddir}/scripts/tab/"
ln -v scripts/url/* "${builddir}/scripts/url/"

# -------------------------------------------------------
# Build .alfredworkflow file
test "$devmode" -eq 0 && {
  test -f "${outpath}" && {
    test "$force" -ne 1 && {
      log "Destination file already exists. Use -f to overwrite."
      exit 1
    } || {
      rm -v "${outpath}"
    }
  }
  log "Building .alfredworkflow file ..."
  pushd "$builddir" &> /dev/null
  zip "${outpath}" ./*
  ST_ZIP=$?
  test "$ST_ZIP" -ne 0 && {
    log "Error creating .alfredworkflow file."
    popd &> /dev/null
    popd &> /dev/null
    exit $ST_ZIP
  }
  popd &> /dev/null
  log "Wrote '${zipname}' file in '$( pwd )'"
}

popd &> /dev/null