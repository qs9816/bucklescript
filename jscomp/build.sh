#!/bin/sh

set -e

export OCAMLPARAM='_,bin-annot=1,annot=1' 
export OCAMLRUNPARAM=b


export npm_package_name=bs-platform


echo "building the compiler" > build.compile
make -j4 -r  all-compiler  2>>build.compile
echo "building finished" >> build.compile
make libs

# TODO: this quick test is buggy, 
# since a.ml maybe depend on another module 
# we can not just comment it, it will also produce jslambda


TARGET=a


echo ">>EACH FILE TESTING" >> build.compile
make -C test $TARGET.cmj 2>> ../build.compile

cat test/$TARGET.js >> ../build.compile
make -C test -j30 all 2>>../build.compile
echo "<<Test finished" >> ../build.compile



# ocamlbuild  -cflags $OCAMLBUILD_CFLAGS -no-links js_generate_require.byte  -- 2>> ./build.compile

echo "........" >> ./build.compile


echo "Snapshot && update deps" >> ./build.compile

make -C test depend 2>>../build.compile
make -j7 depend snapshotml 2>> ./build.compile
echo "Done" >> ./build.compile
