#/bin/bash

pushd $(dirname $(dirname $BASH_SOURCE))

pub run test -j 1 -r expanded

popd

