#!/bin/bash

# Ensure if a command fails, the script exits.
set -e

# The following vars can be changed to customize the build, for example;
# OPTIMIZE_LEVEL=4 CPYTHON_BRANCH=v3.13.1 ./build-wasi.sh

# Branch of CPython to clone
# If changed, manually delete ./cpython/ directory if it exists.
CPYTHON_BRANCH="${CPYTHON_BRANCH:-v3.13.2}"
# Weather or not to asyncify and optimize using wasm-opt
ASYNCIFY_OPTIMIZE="${ASYNCIFY_OPTIMIZE:-1}"
OPTIMIZE_LEVEL="${OPTIMIZE_LEVEL:-2}"
# Export the Python API, this increases output size by a little bit.
# Not sure how usable it is.
EXPORT_PYTHON_API="${EXPORT_PYTHON_API:-0}"

echo CPython branch: $CPYTHON_BRANCH
echo Asyncify and Optimize: $ASYNCIFY_OPTIMIZE
echo Optimize level: $OPTIMIZE_LEVEL
echo Export python API: $EXPORT_PYTHON_API
echo

# Pythons 'optional' dependencies
# `./lib` and `./include` is currently from https://github.com/singlestore-labs/python-wasi/tree/main/docker
OPT_DEPS_PATH=$(pwd)/deps
# Output directory
OUT_PATH=$(pwd)/out

# Used for pre-compiling .pyc files
BUILD_PYTHON_EXE=$(pwd)/cpython/cross-build/build/python

# Clone cpython if it's not already cloned.
if [ ! -d "./cpython" ]
then
    git clone https://github.com/python/cpython.git --depth=1 -b $CPYTHON_BRANCH
fi

# Set the CWD to ./cpython/
# This will also undo if the script errors.
pushd ./cpython/ > /dev/null

export CFLAGS="-g -D_WASI_EMULATED_GETPID -D_WASI_EMULATED_SIGNAL -D_WASI_EMULATED_PROCESS_CLOCKS -I$OPT_DEPS_PATH/include"
export CPPFLAGS="${CFLAGS}"
export LIBS="-L$OPT_DEPS_PATH/lib"

if [ $EXPORT_PYTHON_API -eq "1" ]
then
    LINKFORSHARED="-Wl,--export-dynamic"
fi

# Build python for building python wasi, if it's not already built.
if [ ! -d "./cross-build/build" ]
then
    echo Building build python
    python3 Tools/wasm/wasi.py configure-build-python -- --config-cache
    python3 Tools/wasm/wasi.py make-build-python
fi

# For some reason, sometimes we get .exe (probably just with wsl somehow?)
if [ -f $BUILD_PYTHON_EXE.exe ]; then
    BUILD_PYTHON_EXE=$BUILD_PYTHON_EXE.exe
fi

# Build python wasi
echo Building python wasi
python3 Tools/wasm/wasi.py configure-host -- --config-cache --includedir $OPT_DEPS_PATH/include --libdir $OPT_DEPS_PATH/lib --disable-test-modules --with-lto=full
python3 Tools/wasm/wasi.py make-host

# 'install' python into ./cross-build/wasm32-wasip1/tmp
# This gives us the python standard library and some other stuff.
echo Installing python to tmp location
rm -rf ./cross-build/wasm32-wasip1/tmp
make -C ./cross-build/wasm32-wasip1 install DESTDIR=./tmp

# Copy everything to a clean location.
echo Copying to $OUT_PATH
rm -rf $OUT_PATH
mkdir $OUT_PATH
cp -f ./cross-build/wasm32-wasip1/tmp/usr/local/bin/python3.*.wasm $OUT_PATH/
cp -rf ./cross-build/wasm32-wasip1/tmp/usr/local/lib $OUT_PATH/

# Copy files for linking libpython.
# Very handy for implementing a custom C module to use wasm imports.
mkdir $OUT_PATH/for_external_builds/
mkdir $OUT_PATH/for_external_builds/include
cp -rf ./cross-build/wasm32-wasip1/tmp/usr/local/include/python3.*/pyconfig.h $OUT_PATH/for_external_builds/include/pyconfig.h
mkdir $OUT_PATH/for_external_builds/lib
cp -rf ./cross-build/wasm32-wasip1/libpython3.*.a $OUT_PATH/for_external_builds/lib/
find ./cross-build/wasm32-wasip1/Modules/ -name \*.a -exec cp {} $OUT_PATH/for_external_builds/lib \;
find $OPT_DEPS_PATH/lib -name \*.a -exec cp {} $OUT_PATH/for_external_builds/lib \;
rm -rf $OUT_PATH/lib/python3.*/config-3.*-*

# The pre-compiled .pyc files don't really work, they get ignored by python.
# We will compile our own with `unchecked-hash` so they will be loaded regardless.
echo Removing __pycache__ folders from $OUT_PATH/lib \(these don\'t work\)
find $OUT_PATH/lib -name '__pycache__' -type d -exec rm -r "{}" \; 2>/dev/null || true

echo Pre-compiling __pycache__ \(which will work\)
pushd $OUT_PATH > /dev/null
PYTHONHOME=$OUT_PATH $BUILD_PYTHON_EXE -m compileall -j 0 -f --invalidation-mode unchecked-hash ./lib
popd > /dev/null
# # We could do this in wasm, but it's much slower as we can't use `-j 0`...
# wasmtime run --wasm max-wasm-stack=8388608 --dir $OUT_PATH::/ --env PYTHONHOME=/ $OUT_PATH/python3.*.wasm -m compileall -f --invalidation-mode unchecked-hash /lib

if [ $ASYNCIFY_OPTIMIZE -eq "1" ]
then
    echo Asyncify and optimize with wasm-opt
    PYTHON_WASM_FILE=($OUT_PATH/python3.*.wasm)
    wasm-opt $PYTHON_WASM_FILE -o ${PYTHON_WASM_FILE%.*}_async.wasm --asyncify -O$OPTIMIZE_LEVEL
fi

popd > /dev/null
