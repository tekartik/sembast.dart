#/bin/bash

pushd $(dirname $(dirname $BASH_SOURCE))

rm test/tmp -rf
pub run test -j 1 -r expanded

popd

