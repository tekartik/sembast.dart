#/bin/bash

_DIR=$(dirname $(dirname $BASH_SOURCE))

#dart ${_DIR}/test_runner.dart
pushd ${_DIR}
pub run test -j 1 -r expanded
pub run test test/database_perf_test_slow.dart -j 1 -r expanded
pub run test test/database_perf_test_io_slow.dart -j 1 -r expanded
popd

